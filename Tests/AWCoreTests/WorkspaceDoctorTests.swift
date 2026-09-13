import AWSchema
import Foundation
import Testing
@testable import AWCore

private func doctorPaths(_ root: URL) -> InstallPaths {
    InstallPaths(
        installDir: root.appendingPathComponent("Applications", isDirectory: true),
        backups: root.appendingPathComponent("Backups", isDirectory: true),
        searchDirs: [],
        groupContainer: root.appendingPathComponent("Group", isDirectory: true)
    )
}

@Test func workspaceChecksPassWhenInstalledAndPlaced() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let paths = doctorPaths(root)
    let target = paths.installDir.appendingPathComponent("\(workspace.config.appName).app", isDirectory: true)
    try AppBundle.make(at: target, bundleID: workspace.config.appBundleID)
    let runner = FakeProcessRunner()
    runner.respond(
        to: "/usr/bin/pluginkit -m",
        with: .ok("+    com.example.probe.widgets(1.0)\tA1B2\t2026-09-14\t\(target.path)/Contents/PlugIns/Widgets.appex\n")
    )
    let dev = WidgetWindow(id: 9, name: workspace.config.devSlotName, width: 344, height: 170, family: .medium)
    let checks = await Doctor(runner: runner).workspaceChecks(workspace, paths: paths, screenRecording: true, windows: [dev])
    #expect(checks.map(\.id) == ["screen-recording", "app", "extension", "dev-slot"])
    #expect(checks.allSatisfy { $0.status == .pass }, "\(checks.map(\.detail))")
    #expect(checks.last?.detail == "medium")
}

@Test func workspaceChecksExplainWhatIsMissing() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let checks = await Doctor(runner: FakeProcessRunner()).workspaceChecks(workspace, paths: doctorPaths(root), screenRecording: false, windows: [])
    #expect(checks.map(\.id) == ["screen-recording", "app", "dev-slot"])
    #expect(checks.allSatisfy { $0.status == .warn })
    #expect(checks[0].issue?.code == IssueCode.screenRecordingDenied)
    #expect(checks[1].issue?.hint?.contains("aw ship") == true)
}

@Test func feedsWithoutADaemonAreFlagged() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let manifest = WidgetManifest(
        id: "probe",
        name: LocalizedText(en: "Probe"),
        families: [.small],
        view: "ProbeView",
        feed: FeedSpec(command: "./feed.sh", every: Interval(seconds: 900))
    )
    try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("widgets/probe/widget.json"))
    let workspace = try Workspace.load(at: root)
    let missing = await Doctor(runner: FakeProcessRunner()).workspaceChecks(workspace, paths: doctorPaths(root), screenRecording: false, windows: [])
    #expect(missing.first { $0.id == "daemon" }?.issue?.code == IssueCode.daemonMissing)
    let runner = FakeProcessRunner()
    runner.respond(to: "/bin/launchctl print", with: .ok("gui/501/com.agentwidgets.probe.tick = {\n\tstate = not running\n}\n"))
    let running = await Doctor(runner: runner).workspaceChecks(workspace, paths: doctorPaths(root), screenRecording: false, windows: [])
    #expect(running.first { $0.id == "daemon" }?.status == .pass)
}

@Test func devSlotAwayFromTheDesktopComesWithPlacementSteps() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let stranger = WidgetWindow(id: 3, name: "Английский", width: 360, height: 360, family: .large)
    let checks = await Doctor(runner: FakeProcessRunner()).workspaceChecks(workspace, paths: doctorPaths(root), screenRecording: true, windows: [stranger])
    let slot = try #require(checks.first { $0.id == "dev-slot" })
    #expect(slot.status == .warn)
    #expect(slot.issue?.code == IssueCode.widgetNotPlaced)
    #expect(slot.issue?.hint?.contains(workspace.config.devSlotName) == true)
}
