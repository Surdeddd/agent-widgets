import AWSchema
import Foundation
import Testing
@testable import AWCore

private let tickNow = Date(timeIntervalSince1970: 1_800_000_000)

private func feedSource(_ id: String, every seconds: Int?) -> WidgetSource {
    let manifest = WidgetManifest(
        id: id,
        name: LocalizedText(en: id),
        families: [.small],
        view: "ProbeView",
        feed: seconds.map { FeedSpec(command: "true", every: Interval(seconds: $0)) }
    )
    return WidgetSource(manifest: manifest, directory: URL(fileURLWithPath: "/ws/widgets/\(id)"), swiftFiles: [], samples: [:])
}

private func record(_ secondsAgo: TimeInterval) -> FeedRecord {
    FeedRecord(lastRun: tickNow.addingTimeInterval(-secondsAgo), lastSuccess: nil, lastError: nil)
}

@Test func dueFeedsFollowTheirIntervalWithSlack() {
    let widgets = [
        feedSource("never", every: 900),
        feedSource("almost", every: 900),
        feedSource("fresh", every: 900),
        feedSource("static", every: nil)
    ]
    let records = ["almost": record(880), "fresh": record(600), "static": record(10_000)]
    #expect(Scheduler.due(widgets, records: records, now: tickNow).map(\.id) == ["never", "almost"])
}

private func feedWorkspace() throws -> URL {
    let root = try ProbeWorkspace.make()
    let manifest = WidgetManifest(
        id: "probe",
        name: LocalizedText(en: "Probe"),
        families: [.small],
        view: "ProbeView",
        feed: FeedSpec(command: "./feed.sh", every: Interval(seconds: 900))
    )
    try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("widgets/probe/widget.json"))
    return root
}

@Test func tickSkipsWhileAnotherTickHoldsTheLock() async throws {
    let root = try feedWorkspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    try FileManager.default.createDirectory(at: workspace.stateDir, withIntermediateDirectories: true)
    let held = try #require(TickLock.acquire(workspace.stateDir.appendingPathComponent("tick.lock")))
    defer { held.release() }
    let runner = FakeProcessRunner()
    let outcome = try await Ticker(workspace: workspace, store: AppGroupStore(root: root.appendingPathComponent("group")), runner: runner).tick(now: tickNow)
    #expect(outcome.skipped)
    #expect(runner.calls.isEmpty)
}

@Test func tickRunsDueFeedsRemembersThemAndReloadsWhatChanged() async throws {
    let root = try feedWorkspace()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let store = AppGroupStore(root: root.appendingPathComponent("group", isDirectory: true))
    try store.write(AWJSON.encoder().encode(DevTarget(widget: "probe")), to: AppGroupLayout.devTarget)
    let runner = FakeProcessRunner()
    runner.respond(to: "/bin/zsh -c", with: .ok(#"{"value": 5}"#))
    runner.respond(to: "/usr/bin/open", with: .ok(""))
    let ticker = Ticker(workspace: workspace, store: store, runner: runner)

    let first = try await ticker.tick(now: tickNow)
    #expect(first.runs.map(\.widget) == ["probe"])
    #expect(first.runs.first?.changed == true)
    #expect(first.reloaded == ["aw.probe", "aw.dev"])
    #expect(ticker.records()["probe"]?.lastRun == tickNow)

    let quiet = try await ticker.tick(now: tickNow.addingTimeInterval(60))
    #expect(quiet.runs.isEmpty)

    let forced = try await ticker.tick(now: tickNow.addingTimeInterval(120), force: true)
    #expect(forced.runs.count == 1)
    #expect(forced.reloaded.isEmpty)
}
