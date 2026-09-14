import AppIntents
import AWSchema
import Foundation
import Testing
@testable import AWKit

@Test func deckVisitsEveryCardOncePerCycle() {
    for count in 1...50 {
        for seed in [0, 1, 2, 7, 123_456, 9_999_999, -42] {
            let order = (0..<count).map { AWDeck.index($0, count: count, seed: seed) }
            #expect(Set(order) == Set(0..<count), "count \(count) seed \(seed)")
        }
    }
}

@Test func deckWrapsBothWays() {
    #expect(AWDeck.index(-1, count: 5) == 4)
    #expect(AWDeck.index(7, count: 5) == 2)
    #expect(AWDeck.index(3, count: 0) == 0)
}

@Test func seededDeckIsScrambledButStable() {
    let plain = (0..<10).map { AWDeck.index($0, count: 10) }
    let shuffled = (0..<10).map { AWDeck.index($0, count: 10, seed: 4_242) }
    #expect(plain == Array(0..<10))
    #expect(shuffled != plain)
    #expect(shuffled == (0..<10).map { AWDeck.index($0, count: 10, seed: 4_242) })
}

@Test func stepActionsMoveTheCursor() {
    let state = AWState()
    #expect(state.applying(.next).cursor == 1)
    #expect(state.applying(.prev).cursor == -1)
    #expect(state.applying(.next).applying(.next).deckIndex(count: 3, slot: 2) == 1)
}

@Test func valueActionsEditAnyKey() {
    let state = AWState()
    #expect(state.applying(.toggle, key: "done").bool("done"))
    #expect(!state.applying(.toggle, key: "done").applying(.toggle, key: "done").bool("done"))
    #expect(state.applying(.increment, key: "cups").int("cups") == 1)
    #expect(state.applying(.increment, key: "cups", value: "2.5").double("cups") == 2.5)
    #expect(state.applying(.set, key: "mode", value: "focus").string("mode") == "focus")
    #expect(state.applying(.set, key: "goal", value: "8").int("goal") == 8)
    #expect(state.applying(.set, key: "on", value: "true").bool("on"))
}

@Test func shuffleNeedsANewSeedAndRestartsTheDeck() {
    let moved = AWState().applying(.next).applying(.next)
    let shuffled = moved.applying(.shuffle) { 77 }
    #expect(shuffled.seed == 77)
    #expect(shuffled.cursor == 0)
    #expect(shuffled.isShuffled)
    #expect(shuffled.applying(.shuffle) { 77 }.seed == 78)
    #expect(AWState().applying(.shuffle) { 0 }.seed == 1)
    #expect(!shuffled.applying(.reset, key: AWState.seedKey).isShuffled)
}

@Test func resetClearsOneKeyOrEverything() {
    let state = AWState(["cursor": .number(3), "done": .bool(true)])
    #expect(state.applying(.reset).values["cursor"] == nil)
    #expect(state.applying(.reset).bool("done"))
    #expect(state.applying(.reset, key: "").values.isEmpty)
}

@Test func stampRecordsTheTapMomentPlusAnOffset() {
    let tap = Date(timeIntervalSince1970: 1_800_000_000)
    let started = AWState().applying(.stamp, key: "endsAt", value: "1500", now: tap)
    #expect(started.date("endsAt") == tap.addingTimeInterval(1500))
    #expect(AWState().applying(.stamp, key: "at", now: tap).date("at") == tap)
    #expect(AWState().date("missing") == nil)
}

@Test func dayKeysAreAbsoluteDates() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
    let lateEvening = Date(timeIntervalSince1970: 1_789_390_000)
    #expect(AWState.dayKey(lateEvening, calendar: calendar) == "2026-09-14")
    #expect(AWState.dayKey(lateEvening.addingTimeInterval(86_400), calendar: calendar) == "2026-09-15")
}

@Test func buttonIntentCarriesTheWidgetFromContext() {
    let intent = AWActionIntent(widget: "cards", kind: "aw.cards", action: .next, key: "cursor", value: "")
    #expect(intent.widget == "cards")
    #expect(intent.kind == "aw.cards")
    #expect(intent.action == "next")
}

@Test func runnerSavesStateForTheWidget() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-runner-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AWStore(root: root)
    try AWActionRunner.run(widget: "cards", kind: "", action: "next", key: "cursor", value: "", store: store)
    try AWActionRunner.run(widget: "cards", kind: "", action: "next", key: "cursor", value: "", store: store)
    #expect(store.state(widget: "cards").cursor == 2)
    try AWActionRunner.run(widget: "", kind: "", action: "next", key: "cursor", value: "", store: store)
    #expect(store.state(widget: "cards").cursor == 2)
}

private struct ProbeIntent: AppIntent {
    static let title: LocalizedStringResource = "Probe"
    func perform() async throws -> some IntentResult { .result() }
}

@Test func buttonsUseTheGeneratedIntentWhenTheBundleProvidesOne() {
    let request = AWActionRequest(widget: "cards", kind: "aw.cards", action: .next, key: "cursor", value: "")
    AWButtonIntents.factory = nil
    #expect(AWButtonIntents.intent(for: request) is AWActionIntent)
    AWButtonIntents.factory = { _ in ProbeIntent() }
    defer { AWButtonIntents.factory = nil }
    #expect(AWButtonIntents.intent(for: request) is ProbeIntent)
}
