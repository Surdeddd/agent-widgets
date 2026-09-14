import AWSchema
import Foundation
import Testing
@testable import AWCore

@Test func buildStartsFromAFreshProduct() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let runner = FakeProcessRunner()
    runner.respond(to: "xcodegen", with: .ok(""))
    runner.respond(to: "/usr/bin/xcodebuild", with: .ok(""))
    let builder = Builder(workspace: try Workspace.load(at: root), engine: Engine(root: ProbeWorkspace.repoRoot), runner: runner)
    let stale = builder.productPath().appendingPathComponent("Contents/Resources/Metadata.appintents/extract.packagedata")
    try FileManager.default.createDirectory(at: stale.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: stale)
    _ = try await builder.build(sign: false)
    #expect(!FileManager.default.fileExists(atPath: stale.path))
}

@Test func generateWritesRegistryHostAndProject() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let builder = Builder(workspace: try Workspace.load(at: root), engine: Engine(root: ProbeWorkspace.repoRoot), runner: FakeProcessRunner())
    let files = try builder.generate(buildNumber: "7")
    #expect(files == [".aw/build/Extension/Registry.swift", ".aw/build/App/HostApp.swift", ".aw/build/Shared/AWWidgetAction.swift", ".aw/build/project.yml"])
    let registry = try String(contentsOf: root.appendingPathComponent(files[0]), encoding: .utf8)
    #expect(registry.contains("struct AWWidget_probe: Widget"))
    #expect(registry.contains("L10n.pick(en: \"Probe / Test\", ru: \"Проба\")"))
    let host = try String(contentsOf: root.appendingPathComponent(files[1]), encoding: .utf8)
    #expect(host.contains(#"private let appName = "Probe \"Widgets\"""#))
    #expect(host.contains(#"private let appGroup = "ABCDE12345.com.example.probe""#))
    #expect(!host.contains("__"))
    let action = try String(contentsOf: root.appendingPathComponent(files[2]), encoding: .utf8)
    #expect(action.contains("struct AWWidgetAction: AppIntent"))
    let project = try String(contentsOf: root.appendingPathComponent(files[3]), encoding: .utf8)
    #expect(project.contains("CURRENT_PROJECT_VERSION: \"7\""))
    #expect(project.contains("- path: \"../../widgets/probe\""))
}

@Test func buildStopsWhenXcodegenFails() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let runner = FakeProcessRunner()
    runner.respond(to: "xcodegen", with: .failure("spec is broken"))
    let builder = Builder(workspace: try Workspace.load(at: root), engine: Engine(root: ProbeWorkspace.repoRoot), runner: runner)
    let outcome = try await builder.build(sign: false)
    #expect(outcome.app == nil)
    #expect(outcome.issues.contains { $0.message.contains("xcodegen") })
}

@Test func buildReportsGeneratedCodeErrorsWithAManifestHint() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let builder = Builder(workspace: try Workspace.load(at: root), engine: Engine(root: ProbeWorkspace.repoRoot), runner: FakeProcessRunner())
    let output = "\(root.path)/.aw/build/Extension/Registry.swift:9:40: error: cannot find type 'WrongView' in scope"
    let issues = builder.failureIssues(output, status: 65)
    #expect(issues.first?.file == ".aw/build/Extension/Registry.swift")
    #expect(issues.first?.hint?.contains("widget.json") == true)
}

@Test(.enabled(if: ProbeWorkspace.integration))
func generatedProjectCompilesWithoutSigning() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let builder = Builder(workspace: try Workspace.load(at: root), engine: Engine(root: ProbeWorkspace.repoRoot), runner: SystemProcessRunner())
    let outcome = try await builder.build(sign: false, configuration: "Debug")
    #expect(outcome.issues.isEmpty, "\(outcome.issues.map(\.message))")
    #expect(outcome.app != nil)
}
