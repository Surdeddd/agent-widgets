import AWSchema
import Foundation
import Testing
@testable import AWCore

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private func signedRunner() -> FakeProcessRunner {
    let runner = FakeProcessRunner()
    let listing = "  1) 0123456789ABCDEF0123456789ABCDEF01234567 \"Apple Development: dev@example.com (AAAAAAAAAA)\"\n"
    runner.respond(to: "/usr/bin/security find-identity", with: .ok(listing))
    runner.respond(to: "/usr/bin/security find-certificate", with: .ok("-----BEGIN CERTIFICATE-----\nAA\n-----END CERTIFICATE-----\n"))
    runner.respond(to: "/usr/bin/openssl x509", with: .ok("subject=CN=Apple Development: dev (AAAAAAAAAA), OU=Q1W2E3R4T5, O=Dev, C=US\n"))
    return runner
}

private func unsignedRunner() -> FakeProcessRunner {
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/security find-identity", with: .ok("     0 valid identities found\n"))
    return runner
}

private func temporaryFolder(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("aw-init-\(UUID().uuidString)")
        .appendingPathComponent(name)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func initCreatesWorkspaceWithLocalSigning() async throws {
    let folder = try temporaryFolder("My Widgets")
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let initializer = WorkspaceInitializer(engine: Engine(root: repoRoot), runner: signedRunner())
    let (result, issues) = try await initializer.initialize(InitOptions(directory: folder, bundlePrefix: "com.example"))
    #expect(issues.isEmpty)
    #expect(Set(result.files) == ["aw.json", "aw.local.json", "AGENTS.md", "CLAUDE.md", ".gitignore"])
    let workspace = try Workspace.load(at: folder)
    #expect(workspace.config.slug == "my-widgets")
    #expect(workspace.config.name == "My Widgets")
    #expect(workspace.config.teamID == "Q1W2E3R4T5")
    #expect(workspace.config.resolvedAppGroup == "Q1W2E3R4T5.com.example.my-widgets")
    #expect(workspace.validate().isEmpty)
    let portable = try String(contentsOf: folder.appendingPathComponent("aw.json"), encoding: .utf8)
    #expect(!portable.contains("Q1W2E3R4T5"))
}

@Test func initRefusesExistingWorkspace() async throws {
    let folder = try temporaryFolder("ws")
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let initializer = WorkspaceInitializer(engine: Engine(root: repoRoot), runner: signedRunner())
    _ = try await initializer.initialize(InitOptions(directory: folder))
    await #expect(throws: AWError.self) {
        _ = try await initializer.initialize(InitOptions(directory: folder))
    }
}

@Test func initWithoutSigningWarnsButLoads() async throws {
    let folder = try temporaryFolder("ws")
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    let initializer = WorkspaceInitializer(engine: Engine(root: repoRoot), runner: unsignedRunner())
    let (_, issues) = try await initializer.initialize(InitOptions(directory: folder, bundlePrefix: "com.example"))
    #expect(issues.contains { $0.code == IssueCode.signingMissing && $0.severity == .warning })
    #expect(try Workspace.load(at: folder).validate().contains { $0.code == IssueCode.signingMissing })
}

@Test func initKeepsExistingAgentsFile() async throws {
    let folder = try temporaryFolder("ws")
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    try Data("mine".utf8).write(to: folder.appendingPathComponent("AGENTS.md"))
    let initializer = WorkspaceInitializer(engine: Engine(root: repoRoot), runner: signedRunner())
    let (result, issues) = try await initializer.initialize(InitOptions(directory: folder))
    #expect(!result.files.contains("AGENTS.md"))
    #expect(issues.contains { $0.code == IssueCode.keptExisting })
    #expect(try String(contentsOf: folder.appendingPathComponent("AGENTS.md"), encoding: .utf8) == "mine")
}

@Test func refreshSigningRewritesLocalConfig() async throws {
    let folder = try temporaryFolder("ws")
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    _ = try await WorkspaceInitializer(engine: Engine(root: repoRoot), runner: unsignedRunner())
        .initialize(InitOptions(directory: folder, bundlePrefix: "com.example"))
    let (_, issues) = try await WorkspaceInitializer(engine: Engine(root: repoRoot), runner: signedRunner())
        .refreshSigning(at: folder)
    #expect(issues.isEmpty)
    #expect(try Workspace.load(at: folder).config.teamID == "Q1W2E3R4T5")
}

@Test func slugAndTitleHelpers() {
    #expect(WorkspaceInitializer.slugify("My Widgets!") == "my-widgets")
    #expect(WorkspaceInitializer.slugify("Привет") == "widgets")
    #expect(WorkspaceInitializer.slugify("2025 board") == "w-2025-board")
    #expect(WorkspaceInitializer.slugify("--agent--widgets--") == "agent-widgets")
    #expect(WorkspaceInitializer.titleize("agent-widgets_home") == "Agent Widgets Home")
}
