import AWSchema
import Foundation
import Testing
@testable import AWCore

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private let integration = ProcessInfo.processInfo.environment["AW_SKIP_INTEGRATION"] == nil

private let sample = """
{
  "city": "Bangkok", "temp": 31, "condition": "Partly cloudy", "symbol": "cloud.sun",
  "hourly": [27, 27, 26, 26, 27, 29, 31, 32, 33, 33, 32, 31, 30, 29, 28, 28],
  "days": [
    {"name": "Mon", "symbol": "cloud.sun", "high": 31, "low": 25},
    {"name": "Tue", "symbol": "cloud.rain", "high": 29, "low": 24},
    {"name": "Wed", "symbol": "cloud.bolt.rain", "high": 28, "low": 24},
    {"name": "Thu", "symbol": "sun.max", "high": 33, "low": 26},
    {"name": "Fri", "symbol": "cloud.sun", "high": 32, "low": 26},
    {"name": "Sat", "symbol": "cloud", "high": 30, "low": 25},
    {"name": "Sun", "symbol": "sun.max", "high": 34, "low": 27}
  ]
}
"""

private func block(_ language: String, in text: String) -> String? {
    guard let start = text.range(of: "```\(language)\n"), let end = text.range(of: "\n```", range: start.upperBound..<text.endIndex) else {
        return nil
    }
    return String(text[start.upperBound..<end.lowerBound])
}

@Test func theSkillHasOneSwiftExampleAndItsManifest() throws {
    let skill = try String(contentsOf: repoRoot.appendingPathComponent("skills/agent-widgets/SKILL.md"), encoding: .utf8)
    let code = try #require(block("swift", in: skill))
    let manifest = try #require(block("json", in: skill))
    #expect(code.contains("struct WeatherView: AWView"))
    let decoded = try JSONDecoder().decode(WidgetManifest.self, from: Data(manifest.utf8))
    #expect(decoded.view == "WeatherView")
    #expect(decoded.families == [.small, .medium, .large, .extraLarge])
}

@Test(.enabled(if: integration))
func theSkillExampleFillsEverySizeItDeclares() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-skill-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let folder = root.appendingPathComponent("widgets/weather/samples", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data(#"{"name":"T","slug":"t","bundlePrefix":"com.example","teamID":"ABCDE12345","signingIdentity":"x"}"#.utf8)
        .write(to: root.appendingPathComponent("aw.json"))
    let skill = try String(contentsOf: repoRoot.appendingPathComponent("skills/agent-widgets/SKILL.md"), encoding: .utf8)
    let widget = folder.deletingLastPathComponent()
    try #require(block("swift", in: skill)).write(to: widget.appendingPathComponent("WeatherView.swift"), atomically: true, encoding: .utf8)
    let printed = try #require(block("json", in: skill))
    var manifest = try #require(try JSONSerialization.jsonObject(with: Data(printed.utf8)) as? [String: Any])
    manifest["feed"] = nil
    try JSONSerialization.data(withJSONObject: manifest).write(to: widget.appendingPathComponent(Workspace.manifestFile))
    try sample.write(to: folder.appendingPathComponent("default.json"), atomically: true, encoding: .utf8)
    try "null".write(to: folder.appendingPathComponent("empty.json"), atomically: true, encoding: .utf8)

    let engine = Engine(root: repoRoot)
    let base = ProcessInfo.processInfo.environment["AW_TEST_KIT_CACHE"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    let cache = KitCache(engine: engine, runner: SystemProcessRunner(), base: base)
    let workspace = try Workspace.load(at: root)
    let pipeline = PreviewPipeline(workspace: workspace, cache: cache, runner: SystemProcessRunner())
    let outcome = try await pipeline.run(try workspace.widget("weather"), PreviewRequest(language: .en))
    #expect(outcome.allIssues.isEmpty, "\(outcome.allIssues.map { "\($0.code) \($0.message)" })")
    let judged = (outcome.report?.cells ?? []).filter { $0.scenario == "default" && $0.emptyShare != nil }
    #expect(Set(judged.map(\.family)) == [.small, .medium, .large, .extraLarge])
}
