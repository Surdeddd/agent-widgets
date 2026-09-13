import AWSchema
import Foundation
import Testing
@testable import AWCore

private let printed = """
gui/501/com.agentwidgets.probe.tick = {
\tactive count = 0
\tpath = /Users/someone/Library/LaunchAgents/com.agentwidgets.probe.tick.plist
\ttype = LaunchAgent
\tstate = not running
\truns = 414
\tlast exit code = 0
\tresource coalition = {
\t\ttype = resource
\t\tstate = active
\t}
}
"""

private struct DaemonFixture {
    let root: URL
    let home: URL
    let runner = FakeProcessRunner()
    let daemon: Daemon

    init() throws {
        root = try ProbeWorkspace.make()
        home = root.appendingPathComponent("home", isDirectory: true)
        var daemon = Daemon(workspace: try Workspace.load(at: root), runner: runner, home: home, executable: "/opt/aw/bin/aw")
        daemon.domain = "gui/501"
        let trash = root.appendingPathComponent("trash", isDirectory: true)
        daemon.discard = { url in
            try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(url.lastPathComponent))
        }
        self.daemon = daemon
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

@Test func launchAgentRunsTickEveryMinute() throws {
    let fixture = try DaemonFixture()
    defer { fixture.cleanup() }
    let plist = try #require(PropertyListSerialization.propertyList(from: fixture.daemon.plist(), format: nil) as? [String: Any])
    #expect(plist["Label"] as? String == "com.agentwidgets.probe.tick")
    #expect(plist["ProgramArguments"] as? [String] == ["/opt/aw/bin/aw", "tick", "--workspace", fixture.root.path])
    #expect((plist["StartCalendarInterval"] as? [String: Any])?.isEmpty == true)
    #expect(plist["StartInterval"] == nil)
    #expect((plist["EnvironmentVariables"] as? [String: String])?["PATH"]?.hasPrefix("/opt/homebrew/bin:") == true)
    #expect(plist["StandardErrorPath"] as? String == fixture.home.path + "/Library/Logs/agent-widgets/probe.log")
}

@Test func installWritesThePlistAndBootstrapsIt() async throws {
    let fixture = try DaemonFixture()
    defer { fixture.cleanup() }
    fixture.runner.respond(to: "/bin/launchctl bootstrap", with: .ok(""))
    fixture.runner.respond(to: "/bin/launchctl print", with: .ok(printed))
    let status = try await fixture.daemon.install()
    #expect(FileManager.default.fileExists(atPath: fixture.daemon.plistURL.path))
    #expect(fixture.runner.calls.map { $0.prefix(2).joined(separator: " ") } == [
        "/bin/launchctl bootout", "/bin/launchctl bootstrap", "/bin/launchctl print"
    ])
    #expect(fixture.runner.calls[1] == ["/bin/launchctl", "bootstrap", "gui/501", fixture.daemon.plistURL.path])
    #expect(status.installed && status.loaded)
    #expect(status.runs == 414)
}

@Test func failedBootstrapIsAnError() async throws {
    let fixture = try DaemonFixture()
    defer { fixture.cleanup() }
    fixture.runner.respond(to: "/bin/launchctl bootstrap", with: .failure("Bootstrap failed: 5: Input/output error"))
    await #expect(throws: AWError.self) {
        try await fixture.daemon.install()
    }
}

@Test func uninstallStopsTheAgentAndTrashesThePlist() async throws {
    let fixture = try DaemonFixture()
    defer { fixture.cleanup() }
    fixture.runner.respond(to: "/bin/launchctl bootstrap", with: .ok(""))
    _ = try await fixture.daemon.install()
    let status = try await fixture.daemon.uninstall()
    #expect(!status.installed)
    #expect(!status.loaded)
    #expect(FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("trash/com.agentwidgets.probe.tick.plist").path))
}

@Test func statusReadsOnlyTopLevelFields() {
    let status = Daemon.parse(printed, label: "com.agentwidgets.probe.tick")
    #expect(status.loaded)
    #expect(status.state == "not running")
    #expect(status.runs == 414)
    #expect(status.lastExitCode == 0)
    #expect(!Daemon.parse("", label: "x").loaded)
}
