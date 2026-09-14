import AWSchema
import Foundation
import Testing
@testable import AWCore

private func show(_ root: URL, runner: FakeProcessRunner, screenRecording: Bool) async throws -> (outcome: DevShowOutcome, store: AppGroupStore) {
    let workspace = try Workspace.load(at: root)
    let store = AppGroupStore(root: root.appendingPathComponent("group", isDirectory: true))
    let outcome = try await DevSlot.show(
        try workspace.widget("probe"),
        scenario: "default",
        workspace: workspace,
        runner: runner,
        store: store,
        screenRecording: screenRecording,
        locate: { [] }
    )
    return (outcome, store)
}

@Test func aDevSlotAwayFromTheDesktopStillSwitchesAndSaysSo() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/open", with: .ok(""))
    let result = try await show(root, runner: runner, screenRecording: true)
    #expect(result.store.devTarget() == DevTarget(widget: "probe", scenario: "default"))
    #expect(result.outcome.issues.map(\.code) == [IssueCode.widgetNotPlaced])
    #expect(result.outcome.issues.first?.hint?.contains("aw slot") == true)
    #expect(result.outcome.shots.isEmpty)
}

@Test func aDevSlotWithoutScreenRecordingWarns() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/open", with: .ok(""))
    let result = try await show(root, runner: runner, screenRecording: false)
    #expect(result.outcome.issues.map(\.code) == [IssueCode.screenRecordingDenied])
    #expect(result.outcome.issues.first?.severity == .warning)
}

@Test func anUnreachableAppIsReportedAfterTheSwitch() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let result = try await show(root, runner: FakeProcessRunner(), screenRecording: true)
    #expect(result.store.devTarget()?.widget == "probe")
    #expect(result.outcome.issues.map(\.code) == [IssueCode.installFailed])
}
