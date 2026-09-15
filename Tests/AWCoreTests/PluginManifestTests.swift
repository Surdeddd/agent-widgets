import Foundation
import Testing
@testable import AWCore

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private func json(_ path: String) throws -> [String: Any] {
    let data = try Data(contentsOf: repoRoot.appendingPathComponent(path))
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@Test func pluginManifestsCarryTheEngineVersion() throws {
    let plugin = try json(".claude-plugin/plugin.json")
    #expect(plugin["name"] as? String == "agent-widgets")
    #expect(plugin["version"] as? String == EngineVersion.current)
    let market = try json(".claude-plugin/marketplace.json")
    let entries = try #require(market["plugins"] as? [[String: Any]])
    #expect(entries.first?["name"] as? String == "agent-widgets")
    #expect(entries.first?["version"] as? String == EngineVersion.current)
    #expect(entries.first?["source"] as? String == "./")
}

@Test func pluginStartsTheMCPServerWithTheWorkspaceOption() throws {
    let plugin = try json(".claude-plugin/plugin.json")
    let servers = try #require(plugin["mcpServers"] as? [String: Any])
    let server = try #require(servers["agent-widgets"] as? [String: Any])
    let args = try #require(server["args"] as? [String])
    #expect(server["command"] as? String == "aw")
    #expect(Array(args.prefix(2)) == ["mcp", "--workspace"])
}
