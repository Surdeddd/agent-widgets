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

private let measuredDesk = DeskGeometry(
    small: CGSize(width: 164, height: 164),
    medium: CGSize(width: 344, height: 164),
    large: CGSize(width: 344, height: 344),
    extraLarge: CGSize(width: 704, height: 344),
    cornerRadius: 27.88,
    source: "chronod"
)

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
    let checks = await Doctor(runner: runner).workspaceChecks(workspace, paths: paths, screenRecording: true, windows: [dev], geometry: measuredDesk)
    #expect(checks.map(\.id) == ["screen-recording", "app", "extension", "dev-slot", "geometry"])
    #expect(checks.allSatisfy { $0.status == .pass }, "\(checks.map(\.detail))")
    #expect(checks.first { $0.id == "dev-slot" }?.detail == "medium")
    #expect(checks.last?.detail == "small 164×164 · medium 344×164 · large 344×344")
}

@Test func workspaceChecksExplainWhatIsMissing() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let checks = await Doctor(runner: FakeProcessRunner())
        .workspaceChecks(workspace, paths: doctorPaths(root), screenRecording: false, windows: [], geometry: nil)
    #expect(checks.map(\.id) == ["screen-recording", "app", "dev-slot", "geometry"])
    #expect(checks.allSatisfy { $0.status == .warn })
    #expect(checks[0].issue?.code == IssueCode.screenRecordingDenied)
    #expect(checks[1].issue?.hint?.contains("aw ship") == true)
    #expect(checks[3].issue?.code == IssueCode.geometryUnknown)
    #expect(checks[3].issue?.hint?.contains("aw geometry --measure") == true)
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
    let missing = await Doctor(runner: FakeProcessRunner())
        .workspaceChecks(workspace, paths: doctorPaths(root), screenRecording: false, windows: [], geometry: nil)
    #expect(missing.first { $0.id == "daemon" }?.issue?.code == IssueCode.daemonMissing)
    let runner = FakeProcessRunner()
    runner.respond(to: "/bin/launchctl print", with: .ok("gui/501/com.agentwidgets.probe.tick = {\n\tstate = not running\n}\n"))
    let running = await Doctor(runner: runner).workspaceChecks(workspace, paths: doctorPaths(root), screenRecording: false, windows: [], geometry: nil)
    #expect(running.first { $0.id == "daemon" }?.status == .pass)
}

@Test func devSlotAwayFromTheDesktopComesWithPlacementSteps() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let stranger = WidgetWindow(id: 3, name: "Английский", width: 360, height: 360, family: .large)
    let checks = await Doctor(runner: FakeProcessRunner())
        .workspaceChecks(workspace, paths: doctorPaths(root), screenRecording: true, windows: [stranger], geometry: nil)
    let slot = try #require(checks.first { $0.id == "dev-slot" })
    #expect(slot.status == .warn)
    #expect(slot.issue?.code == IssueCode.widgetNotPlaced)
    #expect(slot.issue?.hint?.contains(workspace.config.devSlotName) == true)
}
