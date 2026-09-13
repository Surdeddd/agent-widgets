import Foundation

public struct SkillLink: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case linked
        case alreadyLinked
        case occupied
        case noSkillsFolder
    }

    public var agent: String
    public var path: String
    public var state: State
}

public struct SkillInstaller: Sendable {
    public static let folders = [("claude", ".claude/skills"), ("codex", ".codex/skills"), ("agents", ".agents/skills")]

    public let source: URL
    public let home: URL

    public init(source: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.source = source
        self.home = home
    }

    /// Links the skill into each agent's existing skills folder; folders that resolve to the same place are linked once.
    public func install(_ agents: [String]) throws -> [SkillLink] {
        let fileManager = FileManager.default
        var seen = Set<String>()
        var links: [SkillLink] = []
        for (agent, relative) in Self.folders where agents.contains(agent) {
            let folder = home.appendingPathComponent(relative, isDirectory: true)
            let destination = folder.appendingPathComponent(source.lastPathComponent)
            guard fileManager.fileExists(atPath: folder.path) else {
                links.append(SkillLink(agent: agent, path: destination.path, state: .noSkillsFolder))
                continue
            }
            guard seen.insert(folder.resolvingSymlinksInPath().path).inserted else { continue }
            links.append(SkillLink(agent: agent, path: destination.path, state: try link(destination)))
        }
        return links
    }

    private func link(_ destination: URL) throws -> SkillLink.State {
        let fileManager = FileManager.default
        if let existing = try? fileManager.destinationOfSymbolicLink(atPath: destination.path) {
            let resolved = URL(fileURLWithPath: existing, relativeTo: destination.deletingLastPathComponent()).standardizedFileURL.path
            return resolved == source.standardizedFileURL.path ? .alreadyLinked : .occupied
        }
        if fileManager.fileExists(atPath: destination.path) {
            return .occupied
        }
        try fileManager.createSymbolicLink(at: destination, withDestinationURL: source)
        return .linked
    }
}
