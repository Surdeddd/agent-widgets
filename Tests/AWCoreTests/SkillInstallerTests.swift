import Foundation
import Testing
@testable import AWCore

@Test func skillLinksIntoExistingFoldersOnce() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-skill-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let fileManager = FileManager.default
    let source = root.appendingPathComponent("engine/skills/agent-widgets", isDirectory: true)
    try fileManager.createDirectory(at: source, withIntermediateDirectories: true)
    let home = root.appendingPathComponent("home", isDirectory: true)
    try fileManager.createDirectory(at: home.appendingPathComponent(".claude/skills"), withIntermediateDirectories: true)
    try fileManager.createDirectory(at: home.appendingPathComponent(".agents"), withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(at: home.appendingPathComponent(".agents/skills"), withDestinationURL: home.appendingPathComponent(".claude/skills"))
    let installer = SkillInstaller(source: source, home: home)

    let first = try installer.install(["claude", "codex", "agents"])
    #expect(first.map(\.agent) == ["claude", "codex"])
    #expect(first.map(\.state) == [.linked, .noSkillsFolder])
    let link = try fileManager.destinationOfSymbolicLink(atPath: home.appendingPathComponent(".claude/skills/agent-widgets").path)
    #expect(URL(fileURLWithPath: link).standardizedFileURL.path == source.standardizedFileURL.path)

    #expect(try installer.install(["claude"]).map(\.state) == [.alreadyLinked])

    try fileManager.createDirectory(at: home.appendingPathComponent(".codex/skills/agent-widgets"), withIntermediateDirectories: true)
    #expect(try installer.install(["codex"]).map(\.state) == [.occupied])
}
