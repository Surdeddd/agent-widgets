import AWSchema
import Foundation
import Testing
@testable import AWCore

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private let integration = ProcessInfo.processInfo.environment["AW_SKIP_INTEGRATION"] == nil

private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func makeWorkspace(view: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-pipeline-\(UUID().uuidString)", isDirectory: true)
    try write(
        #"{"name":"Probe","slug":"probe","bundlePrefix":"com.example","teamID":"ABCDE12345","signingIdentity":"x"}"#,
        to: root.appendingPathComponent("aw.json")
    )
    try write(
        #"{"id":"probe","name":"Probe","families":["small","medium"],"view":"ProbeView"}"#,
        to: root.appendingPathComponent("widgets/probe/widget.json")
    )
    try write(view, to: root.appendingPathComponent("widgets/probe/ProbeView.swift"))
    try write(#"{"value": 7}"#, to: root.appendingPathComponent("widgets/probe/samples/default.json"))
    return root
}

private func kitCache() -> KitCache {
    let base = ProcessInfo.processInfo.environment["AW_TEST_KIT_CACHE"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("aw-kit-\(UUID().uuidString)", isDirectory: true)
    return KitCache(engine: Engine(root: repoRoot), runner: SystemProcessRunner(), base: base)
}

private let goodView = """
import AWKit
import SwiftUI

struct ProbeData: Codable, Sendable {
    let value: Int
}

struct ProbeView: AWView {
    let entry: AWEntry<ProbeData>

    init(entry: AWEntry<ProbeData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            AWMetric("\\(data.value)", label: "Probe")
        }
    }
}
"""

@Test func swiftcDiagnosticsKeepErrorsWithRelativePaths() {
    let output = """
    /ws/widgets/w/WView.swift:12:5: error: cannot find 'Foo' in scope
    /ws/widgets/w/WView.swift:12:5: error: cannot find 'Foo' in scope
    /ws/widgets/w/WView.swift:3:1: warning: variable was never used
    <unknown>:0: error: fatal
    """
    let issues = SwiftcDiagnostics.parse(output, root: URL(fileURLWithPath: "/ws"))
    #expect(issues.count == 1)
    #expect(issues.first?.file == "widgets/w/WView.swift")
    #expect(issues.first?.line == 12)
    #expect(issues.first?.code == IssueCode.compileError)
}

@Test func previewMainCallsTheRunner() {
    #expect(PreviewMainGenerator.generate(view: "WeatherView").contains("AWPreviewMain.run(WeatherView.self)"))
}

@Test(.enabled(if: integration))
func pipelineRendersAndCachesTheBinary() async throws {
    let root = try makeWorkspace(view: goodView)
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let pipeline = PreviewPipeline(workspace: workspace, cache: kitCache(), runner: SystemProcessRunner())
    let first = try await pipeline.run(try workspace.widget("probe"), PreviewRequest(language: .en))
    #expect(first.issues.isEmpty, "\(first.issues.map(\.message))")
    #expect(first.report?.hasErrors == false)
    #expect(first.compiled)
    #expect(FileManager.default.fileExists(atPath: first.report?.sheet ?? "/missing"))
    let second = try await pipeline.run(try workspace.widget("probe"), PreviewRequest(language: .en))
    #expect(!second.compiled)
    #expect(second.report?.cells.count == first.report?.cells.count)
}

@Test(.enabled(if: integration))
func pipelineReportsCompileErrorsWithLocations() async throws {
    let broken = goodView.replacingOccurrences(of: "AWMetric(", with: "AWMetrc(")
    let root = try makeWorkspace(view: broken)
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let pipeline = PreviewPipeline(workspace: workspace, cache: kitCache(), runner: SystemProcessRunner())
    let outcome = try await pipeline.run(try workspace.widget("probe"), PreviewRequest(language: .en))
    let error = try #require(outcome.issues.first { $0.code == IssueCode.compileError })
    #expect(error.file == "widgets/probe/ProbeView.swift")
    #expect(error.line != nil)
    #expect(outcome.report == nil)
}
