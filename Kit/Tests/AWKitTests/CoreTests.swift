import AWSchema
import Foundation
import Testing
@testable import AWKit

private struct Weather: Codable, Sendable, Equatable {
    let city: String
    let temp: Double
}

private struct Log: Codable, Sendable {
    let timeline: [String]
    let title: String
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let weatherJSON = Data(#"{"city":"Bangkok","temp":31}"#.utf8)

private func build(
    _ data: Data?,
    status: FeedStatus? = nil,
    tick: AWTick = .none,
    refresh: TimeInterval = 1800,
    at date: Date = now
) -> AWTimelineOutput<Weather> {
    AWTimelineBuilder.build(Weather.self, AWTimelineInput(data: data, status: status, tick: tick, refresh: refresh, now: date))
}

@Test func buildWithoutDataIsEmpty() {
    let output = build(nil)
    #expect(output.entries.count == 1)
    #expect(output.entries[0].phase == .empty)
    #expect(output.reloadAfter == now.addingTimeInterval(1800))
}

@Test func buildDecodesModel() {
    let output = build(weatherJSON)
    #expect(output.entries.first?.data == Weather(city: "Bangkok", temp: 31))
    #expect(output.entries.first?.phase == .ok)
}

@Test func buildReportsDecodeError() {
    let output = build(Data(#"{"city":3}"#.utf8))
    guard case .error(let message) = output.entries.first?.phase else {
        Issue.record("expected an error phase")
        return
    }
    #expect(message.contains("city"))
}

@Test func buildMarksStaleWhenFeedFailed() {
    let status = FeedStatus(ok: false, checkedAt: now, fetchedAt: now.addingTimeInterval(-600), error: "boom")
    #expect(build(weatherJSON, status: status).entries[0].phase.isStale)
}

@Test func buildMarksStaleOnlyWhenOld() {
    let old = FeedStatus(ok: true, checkedAt: now, fetchedAt: now.addingTimeInterval(-4000))
    let fresh = FeedStatus(ok: true, checkedAt: now, fetchedAt: now.addingTimeInterval(-100))
    #expect(build(weatherJSON, status: old).entries[0].phase.isStale)
    #expect(build(weatherJSON, status: fresh).entries[0].phase == .ok)
    #expect(build(weatherJSON, status: fresh).entries[0].fetchedAt == now.addingTimeInterval(-100))
}

@Test func buildExpandsTicksOnMinuteBoundaries() {
    let output = build(weatherJSON, tick: .everyMinute(count: 3), at: now.addingTimeInterval(25))
    #expect(output.entries.count == 3)
    #expect(output.entries.map { $0.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) } == [0, 0, 0])
    #expect(output.entries[0].date == now)
    #expect(output.reloadAfter == nil)
}

@Test func buildReadsTimelineEnvelope() throws {
    let data = Data("""
    {"timeline":[
      {"date":"2027-01-15T08:00:00Z","data":{"city":"B","temp":30}},
      {"date":"2027-01-15T07:00:00Z","data":{"city":"B","temp":29}},
      {"date":"2027-01-15T09:00:00.123456+00:00","data":{"city":"B","temp":31}}
    ]}
    """.utf8)
    let at = try #require(AWJSON.parseDate("2027-01-15T08:30:00Z"))
    let output = build(data, at: at)
    #expect(output.entries.map { $0.data?.temp } == [30, 31])
    #expect(output.entries[0].date == at)
}

@Test func modelWithTimelineFieldIsNotAnEnvelope() {
    let output = AWTimelineBuilder.build(
        Log.self,
        AWTimelineInput(data: Data(#"{"timeline":["a"],"title":"t"}"#.utf8), refresh: 1800, now: now)
    )
    #expect(output.entries[0].data?.title == "t")
}

@Test func stateHelpersRoundTrip() throws {
    var state = AWState()
    #expect(state.cursor == 0)
    state.set("cursor", .number(3))
    state.set("on", .bool(true))
    state.set("name", .string("x"))
    #expect(state.cursor == 3)
    #expect(state.bool("on"))
    #expect(state.string("name") == "x")
    #expect(state.setting("cursor", .number(4)).cursor == 4)
    let decoded = try AWJSON.decoder().decode(AWState.self, from: AWJSON.encoder().encode(state))
    #expect(decoded == state)
}

@Test func storeRoundTripsFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-store-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AWStore(root: root)
    try store.write(weatherJSON, to: AppGroupLayout.data("w"))
    #expect(store.data(widget: "w") == weatherJSON)
    try store.save(AWState(["cursor": .number(2)]), widget: "w")
    #expect(store.state(widget: "w").cursor == 2)
    let status = FeedStatus(ok: true, checkedAt: now, fetchedAt: now)
    try store.write(AWJSON.encoder().encode(status), to: AppGroupLayout.status("w"))
    #expect(store.status(widget: "w") == status)
    try store.write(AWJSON.encoder().encode(DevTarget(widget: "w", scenario: "long")), to: AppGroupLayout.devTarget)
    #expect(store.devTarget()?.scenario == "long")
    #expect(AWStore(root: nil).data(widget: "w") == nil)
}

@Test func freshnessSpeaksBothLanguages() {
    #expect(AWFormat.updated(now.addingTimeInterval(-300), now: now, language: .en) == "updated 5m ago")
    #expect(AWFormat.updated(now.addingTimeInterval(-300), now: now, language: .ru) == "обновлено 5 мин назад")
    #expect(AWFormat.freshness(now.addingTimeInterval(-10), now: now, language: .en) == "just now")
    #expect(AWFormat.freshness(now.addingTimeInterval(-7200), now: now, language: .ru) == "2 ч назад")
}

@Test func compactNumbers() {
    #expect(AWFormat.compact(999) == "999")
    #expect(AWFormat.compact(1234) == "1.2K")
    #expect(AWFormat.compact(2_000_000) == "2M")
    #expect(AWFormat.compact(-15_300) == "-15.3K")
}

@Test func plainDataGetsFreshnessEntriesThatTurnStaleOnTime() {
    let status = FeedStatus(ok: true, checkedAt: now, fetchedAt: now.addingTimeInterval(-3000))
    let output = build(weatherJSON, status: status, refresh: 1800)
    #expect(output.entries.map(\.date) == [now, now.addingTimeInterval(900)])
    #expect(output.entries[0].phase == .ok)
    #expect(output.entries[1].phase.isStale)
    #expect(output.reloadAfter == now.addingTimeInterval(1800))
}

@Test func contextMapsFamiliesBothWays() {
    for family in Family.allCases {
        #expect(Family(family.widgetFamily) == family)
    }
    #expect(AWContext(family: .small, language: .ru).pick(en: "a", ru: "б") == "б")
}

@Test func theContextLocaleSpeaksTheWidgetLanguageAndKeepsTheRegion() {
    let september = Date(timeIntervalSince1970: 1_789_776_000)
    let russian = AWContext(family: .small, language: .ru).locale
    let english = AWContext(family: .small, language: .en).locale
    #expect(russian.language.languageCode?.identifier == "ru")
    #expect(english.language.languageCode?.identifier == "en")
    #expect(september.formatted(.dateTime.month(.wide).locale(russian)).lowercased().hasPrefix("сентябр"))
    #expect(september.formatted(.dateTime.month(.wide).locale(english)) == "September")
    #expect(russian.region == Locale.current.region)
}
