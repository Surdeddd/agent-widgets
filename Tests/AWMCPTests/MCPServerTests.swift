import AWCore
import AWSchema
import Foundation
import MCP
import Testing
@testable import AWMCP

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private func connectedClient(directory: URL = repoRoot) async throws -> Client {
    let context = MCPContext(engine: { Engine(root: repoRoot) }, runner: SystemProcessRunner(), directory: directory)
    let server = await AWMCPServer.make(context)
    let pair = await InMemoryTransport.createConnectedPair()
    try await server.start(transport: pair.server)
    let client = Client(name: "aw-tests", version: "1.0")
    _ = try await client.connect(transport: pair.client)
    return client
}

private func texts(_ content: [Tool.Content]) -> String {
    var result = ""
    for item in content {
        if case .text(let text, _, _) = item {
            result += text
        }
    }
    return result
}

@Test func serverListsEveryTool() async throws {
    let client = try await connectedClient()
    let names = try await client.listTools().tools.map(\.name)
    #expect(Set(names) == [
        "aw_templates", "aw_new", "aw_preview", "aw_ship", "aw_shot", "aw_slot", "aw_dev",
        "aw_doctor", "aw_list", "aw_data_set", "aw_feed_run", "aw_explain"
    ])
}

@Test func templatesToolReturnsEveryTemplate() async throws {
    let client = try await connectedClient()
    let result = try await client.callTool(name: "aw_templates")
    let text = texts(result.content)
    for id in ["blank", "card", "chart", "image", "list", "metric", "ring", "timer"] {
        #expect(text.contains(id), "\(id) missing in \(text)")
    }
    #expect(result.isError != true)
}

@Test func explainToolTeachesTheFix() async throws {
    let client = try await connectedClient()
    let result = try await client.callTool(name: "aw_explain", arguments: ["code": .string("overflow")])
    #expect(texts(result.content).contains("OVERFLOW"))
    let unknown = try await client.callTool(name: "aw_explain", arguments: ["code": .string("nope")])
    #expect(unknown.isError == true)
}

@Test func newToolCreatesTheWidgetInTheGivenWorkspace() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-mcp-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let config = #"{"name":"MCP","slug":"mcp-test","bundlePrefix":"com.example","teamID":"ABCDE12345","signingIdentity":"x"}"#
    try Data(config.utf8).write(to: root.appendingPathComponent("aw.json"))
    let client = try await connectedClient()
    let result = try await client.callTool(
        name: "aw_new",
        arguments: ["workspace": .string(root.path), "id": .string("weather"), "template": .string("metric")]
    )
    #expect(result.isError != true, "\(texts(result.content))")
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("widgets/weather/widget.json").path))
    let again = try await client.callTool(name: "aw_new", arguments: ["workspace": .string(root.path), "id": .string("weather")])
    #expect(again.isError == true)
    #expect(texts(again.content).contains("WIDGET_EXISTS"))
}

@Test func replyMakeSetsIsErrorWhenAnIssueIsAnError() {
    let failed = Reply.make("x", issues: [Issue(code: "X", severity: .error, message: "boom")], payload: ["a": 1])
    #expect(failed.isError == true)
    let warned = Reply.make("x", issues: [Issue(code: "W", severity: .warning, message: "careful")], payload: ["a": 1])
    #expect(warned.isError != true)
}

@Test func toolsOutsideAWorkspaceExplainWhatToDo() async throws {
    let empty = FileManager.default.temporaryDirectory.appendingPathComponent("aw-mcp-empty-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: empty) }
    let client = try await connectedClient(directory: empty)
    let result = try await client.callTool(name: "aw_list")
    #expect(result.isError == true)
    #expect(texts(result.content).contains("WORKSPACE_NOT_FOUND"))
}
