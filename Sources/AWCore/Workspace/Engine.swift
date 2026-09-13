import Foundation

public struct Engine: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public var kitPackage: URL {
        root.appendingPathComponent("Kit", isDirectory: true)
    }

    public var templates: URL {
        root.appendingPathComponent("Templates", isDirectory: true)
    }

    public var skills: URL {
        root.appendingPathComponent("skills", isDirectory: true)
    }

    public var version: String {
        EngineVersion.current
    }

    public static func isEngineRoot(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let hasTemplates = FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Templates").path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue
        return hasTemplates && FileManager.default.fileExists(atPath: url.appendingPathComponent("Kit/Package.swift").path)
    }

    public static func locate(environment: [String: String], executable: URL) throws -> Engine {
        if let home = environment["AW_HOME"], !home.isEmpty {
            let url = URL(fileURLWithPath: (home as NSString).expandingTildeInPath)
            guard isEngineRoot(url) else {
                throw AWError.engineNotFound
            }
            return Engine(root: url)
        }
        let start = executable.resolvingSymlinksInPath().deletingLastPathComponent()
        guard let root = PathWalk.ancestors(of: start).prefix(8).first(where: isEngineRoot) else {
            throw AWError.engineNotFound
        }
        return Engine(root: root)
    }

    public static func current() throws -> Engine {
        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        return try locate(environment: ProcessInfo.processInfo.environment, executable: executable)
    }
}
