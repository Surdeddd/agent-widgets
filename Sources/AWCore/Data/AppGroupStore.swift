import AWSchema
import Foundation

public struct AppGroupStore: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public init(
        config: WorkspaceConfig,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        if let override = environment["AW_DATA_DIR"], !override.isEmpty {
            root = URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        } else {
            root = Self.container(group: config.resolvedAppGroup, home: home)
        }
    }

    public static func container(group: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Group Containers", isDirectory: true).appendingPathComponent(group, isDirectory: true)
    }

    public func url(_ relative: String) -> URL {
        root.appendingPathComponent(relative)
    }

    public func read(_ relative: String) -> Data? {
        try? Data(contentsOf: url(relative))
    }

    /// Writes atomically; returns false and leaves the file untouched when the bytes are already there.
    @discardableResult
    public func write(_ data: Data, to relative: String) throws -> Bool {
        guard read(relative) != data else { return false }
        let target = url(relative)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target, options: .atomic)
        return true
    }

    public func devTarget() -> DevTarget? {
        read(AppGroupLayout.devTarget).flatMap { try? AWJSON.decoder().decode(DevTarget.self, from: $0) }
    }
}
