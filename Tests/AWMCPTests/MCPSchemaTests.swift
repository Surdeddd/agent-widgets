import AWSchema
import Foundation
import MCP
import Testing
@testable import AWCore
@testable import AWMCP

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private func outputSchema(_ name: String) throws -> Value {
    try #require(AWTools.all.first { $0.tool.name == name }?.tool.outputSchema)
}

@Test func everyToolHasATitleHintsAndAnObjectOutputSchema() throws {
    for tool in AWTools.all.map(\.tool) {
        #expect(tool.title?.isEmpty == false, "\(tool.name)")
        #expect(tool.annotations.readOnlyHint != nil, "\(tool.name)")
        #expect(tool.annotations.idempotentHint != nil, "\(tool.name)")
        let schema = try #require(tool.outputSchema, "\(tool.name)")
        guard case .object(let object) = schema else {
            Testing.Issue.record("\(tool.name): the output schema is not an object")
            continue
        }
        #expect(object["type"] == .string("object"), "\(tool.name)")
    }
}

@Test func realAnswersMatchTheirOutputSchemas() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-schema-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let config = #"{"name":"Schema","slug":"schema-test","bundlePrefix":"com.example","teamID":"ABCDE12345","signingIdentity":"x"}"#
    try Data(config.utf8).write(to: root.appendingPathComponent("aw.json"))
    let context = MCPContext(engine: { Engine(root: repoRoot) }, runner: SystemProcessRunner(), directory: root)
    let calls: [(String, [String: Value])] = [
        ("aw_templates", [:]),
        ("aw_new", ["id": .string("weather"), "template": .string("metric")]),
        ("aw_list", [:]),
        ("aw_explain", ["code": .string("OVERFLOW")]),
        ("aw_explain", [:]),
        ("aw_doctor", [:])
    ]
    for (name, arguments) in calls {
        let tool = try #require(AWTools.all.first { $0.tool.name == name })
        let result = try await tool.call(Arguments(arguments), context)
        let value = try #require(result.structuredContent, "\(name) returned no structured content")
        let problems = SchemaValidator.errors(value, try outputSchema(name))
        #expect(problems.isEmpty, "\(name): \(problems)")
    }
}

@Test func longToolAnswersMatchTheirOutputSchemas() throws {
    let running = try #require(Reply.running(JobInfo(id: "job-1", tool: "aw_ship", stage: "build…", elapsed: 12)).structuredContent)
    for name in ["aw_ship", "aw_dev", "aw_slot", "aw_feed_run", "aw_wait"] {
        #expect(SchemaValidator.errors(running, try outputSchema(name)).isEmpty, "\(name)")
    }
    var outcome = ShipOutcome(widget: "weather", stage: .done)
    outcome.seconds["build"] = 12.5
    let shipped = try #require(Reply.make("done", payload: outcome).structuredContent)
    #expect(SchemaValidator.errors(shipped, try outputSchema("aw_ship")).isEmpty)
    let run = FeedRun(widget: "weather", ok: true, changed: false, seconds: 0.4, issues: [])
    let fed = try #require(Reply.make("done", payload: run).structuredContent)
    #expect(SchemaValidator.errors(fed, try outputSchema("aw_feed_run")).isEmpty)
}

@Test func schemaValidatorCatchesWrongTypesAndMissingFields() {
    #expect(!SchemaValidator.errors(.object(["files": .string("x")]), OutputSchema.created).isEmpty)
    #expect(!SchemaValidator.errors(.object([:]), OutputSchema.created).isEmpty)
    #expect(SchemaValidator.errors(.object(["files": .array([.string("a")])]), OutputSchema.created).isEmpty)
    #expect(!SchemaValidator.errors(.object(["code": .string("X")]), OutputSchema.explain).isEmpty)
}

@Test func structuredContentSurvivesNonFiniteNumbers() throws {
    let value = try #require(Reply.structured(["structure": Double.nan]))
    #expect(value == .object(["structure": .string("NaN")]))
}
