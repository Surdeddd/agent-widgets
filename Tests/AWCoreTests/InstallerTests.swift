import AWSchema
import Foundation
import Testing
@testable import AWCore

private let probeConfig = WorkspaceConfig(name: "Probe", slug: "probe", bundlePrefix: "com.example", teamID: "ABCDE12345", signingIdentity: "x")

private func minute(_ index: Int) -> Date {
    Date(timeIntervalSince1970: 1_800_000_000 + Double(index) * 60)
}

private struct InstallFixture {
    let root: URL
    let runner = FakeProcessRunner()
    let paths: InstallPaths
    let installer: Installer

    init(registered: Bool = true, container: Bool = true) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-install-\(UUID().uuidString)", isDirectory: true)
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let other = root.appendingPathComponent("Other", isDirectory: true)
        let paths = InstallPaths(
            installDir: apps,
            backups: root.appendingPathComponent("Backups", isDirectory: true),
            searchDirs: [apps, other],
            groupContainer: root.appendingPathComponent("Group", isDirectory: true)
        )
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        if container {
            try FileManager.default.createDirectory(at: paths.groupContainer, withIntermediateDirectories: true)
        }
        let trash = root.appendingPathComponent("Trash", isDirectory: true)
        var installer = Installer(config: probeConfig, runner: runner, paths: paths)
        installer.pollInterval = 0
        installer.containerTimeout = 0
        installer.launchRetryDelay = 0
        installer.discard = { url in
            try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(UUID().uuidString))
        }
        let listing = registered
            ? "+    com.example.probe.widgets(1.0)\tA1B2\t2026-09-14 00:00:00 +0000\t\(installer.target.path)/Contents/PlugIns/Widgets.appex\n"
            : "(no matches)\n"
        runner.respond(to: "/usr/bin/pluginkit -m", with: .ok(listing))
        runner.respond(to: "/usr/bin/open -g", with: .ok(""))
        self.root = root
        self.paths = paths
        self.installer = installer
    }

    var commands: [String] {
        runner.calls.map { $0.joined(separator: " ") }
    }

    var trashed: Int {
        (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Trash").path).count) ?? 0
    }

    func built(_ marker: String) throws -> URL {
        let url = root.appendingPathComponent("Build/\(UUID().uuidString)/Probe.app", isDirectory: true)
        try AppBundle.make(at: url, bundleID: probeConfig.appBundleID, marker: marker)
        return url
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

@Test func freshInstallPlacesTheAppAndWakesItUp() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    let built = try fixture.built("v1")
    let outcome = try await fixture.installer.install(built)
    let target = fixture.installer.target
    #expect(outcome.issues.isEmpty, "\(outcome.issues.map(\.message))")
    #expect(outcome.backup == nil)
    #expect(outcome.registered && outcome.containerReady)
    #expect(AppBundle.marker(of: target) == "v1")
    #expect(AppBundle.marker(of: built) == "v1")
    #expect(fixture.commands.contains("\(Installer.lsregister) -f \(target.path)"))
    #expect(fixture.commands.contains("/usr/bin/pkill -9 -f \(Installer.pattern(target.path))"))
    #expect(fixture.commands.last == "/usr/bin/open -g \(target.path)")
}

@Test func reinstallBacksUpAndKeepsTheNewestThree() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    for version in 1...5 {
        _ = try await fixture.installer.install(try fixture.built("v\(version)"), now: minute(version))
    }
    #expect(AppBundle.marker(of: fixture.installer.target) == "v5")
    #expect(fixture.installer.backups().map { AppBundle.marker(of: $0) } == ["v2", "v3", "v4"])
    #expect(fixture.trashed == 1)
}

@Test func sameBundleCopiesElsewhereAreRetiredAndNeverRotated() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    let legacy = fixture.paths.searchDirs[1].appendingPathComponent("Legacy Widgets.app", isDirectory: true)
    let stranger = fixture.paths.searchDirs[1].appendingPathComponent("Stranger.app", isDirectory: true)
    try AppBundle.make(at: legacy, bundleID: probeConfig.appBundleID, marker: "legacy")
    try AppBundle.make(at: stranger, bundleID: "com.example.stranger", marker: "stranger")
    let first = try await fixture.installer.install(try fixture.built("v1"), now: minute(1))
    #expect(first.retired == [legacy.path])
    #expect(!FileManager.default.fileExists(atPath: legacy.path))
    #expect(AppBundle.marker(of: stranger) == "stranger")
    #expect(fixture.commands.contains("/usr/bin/pkill -9 -f \(Installer.pattern(legacy.path))"))
    for version in 2...6 {
        _ = try await fixture.installer.install(try fixture.built("v\(version)"), now: minute(version))
    }
    let retired = try FileManager.default.contentsOfDirectory(
        at: fixture.paths.backups.appendingPathComponent("retired", isDirectory: true),
        includingPropertiesForKeys: nil
    )
    #expect(retired.map { AppBundle.marker(of: $0) } == ["legacy"])
}

@Test func killPatternEscapesRegexCharacters() {
    #expect(Installer.pattern("/Applications/A (1).app") == #"/Applications/A \(1\)\.app/Contents/"#)
}

@Test func unregisteredExtensionIsAddedAndReported() async throws {
    let fixture = try InstallFixture(registered: false)
    defer { fixture.cleanup() }
    let outcome = try await fixture.installer.install(try fixture.built("v1"))
    #expect(!outcome.registered)
    #expect(!outcome.hasErrors)
    #expect(outcome.issues.contains { $0.code == IssueCode.installFailed && $0.severity == .warning })
    #expect(fixture.commands.contains("/usr/bin/pluginkit -a \(fixture.installer.target.path)/Contents/PlugIns/Widgets.appex"))
}

@Test func missingGroupContainerIsReported() async throws {
    let fixture = try InstallFixture(container: false)
    defer { fixture.cleanup() }
    let outcome = try await fixture.installer.install(try fixture.built("v1"))
    #expect(!outcome.containerReady)
    #expect(!outcome.hasErrors)
    #expect(outcome.issues.contains { $0.code == IssueCode.installFailed && $0.severity == .warning })
}

@Test func failedLaunchIsAnError() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    fixture.runner.respond(to: "/usr/bin/open -g", with: .failure("LSOpenURLsWithRole() failed"))
    let outcome = try await fixture.installer.install(try fixture.built("v1"))
    #expect(outcome.hasErrors)
    #expect(fixture.commands.filter { $0.hasPrefix("/usr/bin/open -g") }.count == Installer.launchAttempts)
}

@Test func strayRegistrationsOfTheExtensionAreRemoved() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    let own = "\(fixture.installer.target.path)/Contents/PlugIns/Widgets.appex"
    let strayApp = "/Users/someone/w/.aw/build/DerivedData/Build/Products/Release/Probe.app"
    let stray = "\(strayApp)/Contents/PlugIns/Widgets.appex"
    let listing = """
    +    com.example.probe.widgets(1.0)\tA1\t2026-09-14 00:00:00 +0000\t\(own)
     from spotlight     com.example.probe.widgets(1.0)\tB2\t2026-09-14 00:00:00 +0000\t\(stray)
     (2 plug-ins)
    """
    fixture.runner.respond(to: "/usr/bin/pluginkit -m -v -D", with: .ok(listing))
    let outcome = try await fixture.installer.install(try fixture.built("v1"))
    #expect(outcome.unregistered == [strayApp])
    #expect(fixture.commands.contains("/usr/bin/pluginkit -r \(stray)"))
    #expect(fixture.commands.contains("\(Installer.lsregister) -u \(strayApp)"))
    #expect(!fixture.commands.contains("/usr/bin/pluginkit -r \(own)"))
}

@Test func launchRetriesWhileTheOldCopyIsStillClosing() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    fixture.runner.respond(to: "/usr/bin/open -g", with: [.failure("LSOpenURLsWithRole() failed"), .ok("")])
    let outcome = try await fixture.installer.install(try fixture.built("v1"))
    #expect(!outcome.hasErrors)
    #expect(fixture.commands.filter { $0.hasPrefix("/usr/bin/open -g") }.count == 2)
}

@Test func rollbackSwapsWithTheLatestBackup() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    _ = try await fixture.installer.install(try fixture.built("v1"), now: minute(1))
    _ = try await fixture.installer.install(try fixture.built("v2"), now: minute(2))
    let outcome = try await fixture.installer.rollback(now: minute(3))
    #expect(AppBundle.marker(of: fixture.installer.target) == "v1")
    #expect(fixture.installer.backups().map { AppBundle.marker(of: $0) } == ["v2"])
    #expect(outcome.backup.flatMap { AppBundle.marker(of: URL(fileURLWithPath: $0)) } == "v2")
}

@Test func rollbackWithoutBackupsFails() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    await #expect(throws: AWError.self) {
        try await fixture.installer.rollback()
    }
}

@Test func foreignOrMissingAppsAreRejected() async throws {
    let fixture = try InstallFixture()
    defer { fixture.cleanup() }
    let foreign = fixture.root.appendingPathComponent("Foreign.app", isDirectory: true)
    try AppBundle.make(at: foreign, bundleID: "com.example.other")
    await #expect(throws: AWError.self) {
        try await fixture.installer.install(foreign)
    }
    await #expect(throws: AWError.self) {
        try await fixture.installer.install(fixture.root.appendingPathComponent("Missing.app"))
    }
    #expect(!FileManager.default.fileExists(atPath: fixture.installer.target.path))
}

@Test func standardPathsFollowTheConfig() {
    let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
    let paths = InstallPaths.standard(for: probeConfig, home: home)
    #expect(paths.installDir.path == "/Applications")
    #expect(paths.backups.path == "/Users/someone/Library/Application Support/agent-widgets/com.example.probe/backups")
    #expect(paths.searchDirs.map(\.path) == ["/Applications", "/Users/someone/Applications"])
    #expect(paths.groupContainer.path == "/Users/someone/Library/Group Containers/ABCDE12345.com.example.probe")
}
