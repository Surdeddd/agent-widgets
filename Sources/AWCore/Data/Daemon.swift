import AWSchema
import Foundation

public struct DaemonStatus: Codable, Equatable, Sendable {
    public var label: String
    public var installed: Bool
    public var loaded: Bool
    public var state: String?
    public var runs: Int?
    public var lastExitCode: Int?
}

public struct Daemon: Sendable {
    public let workspace: Workspace
    public let runner: any ProcessRunning
    public let home: URL
    public let executable: String
    public var domain = "gui/\(getuid())"
    public var discard: @Sendable (URL) throws -> Void = { url in
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    public init(
        workspace: Workspace,
        runner: any ProcessRunning,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        executable: String = Daemon.currentExecutable()
    ) {
        self.workspace = workspace
        self.runner = runner
        self.home = home
        self.executable = executable
    }

    public static func currentExecutable() -> String {
        (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath().path
    }

    public var label: String {
        "com.agentwidgets.\(workspace.config.slug).tick"
    }

    public var plistURL: URL {
        home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public var logURL: URL {
        home.appendingPathComponent("Library/Logs/agent-widgets/\(workspace.config.slug).log")
    }

    /// LaunchAgent that runs `aw tick` every minute; an empty StartCalendarInterval never stalls like StartInterval does.
    public func plist() throws -> Data {
        let object: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable, "tick", "--workspace", workspace.root.path],
            "StartCalendarInterval": [String: Any](),
            "RunAtLoad": true,
            "EnvironmentVariables": ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(home.path)/.local/bin"],
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path
        ]
        return try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
    }

    public func install() async throws -> DaemonStatus {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try plist().write(to: plistURL, options: .atomic)
        _ = try? await launchctl(["bootout", "\(domain)/\(label)"])
        let result = try await launchctl(["bootstrap", domain, plistURL.path])
        guard result.succeeded else {
            throw AWError.toolFailed(tool: "launchctl bootstrap", status: result.status, output: result.combinedOutput)
        }
        return await status()
    }

    public func uninstall() async throws -> DaemonStatus {
        _ = try? await launchctl(["bootout", "\(domain)/\(label)"])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try discard(plistURL)
        }
        return await status()
    }

    public func status() async -> DaemonStatus {
        let result = try? await launchctl(["print", "\(domain)/\(label)"])
        var status = Self.parse(result?.succeeded == true ? result?.stdout ?? "" : "", label: label)
        status.installed = FileManager.default.fileExists(atPath: plistURL.path)
        return status
    }

    public static func parse(_ output: String, label: String) -> DaemonStatus {
        var status = DaemonStatus(label: label, installed: false, loaded: !output.isEmpty, state: nil, runs: nil, lastExitCode: nil)
        for line in output.split(separator: "\n") where line.hasPrefix("\t") && !line.hasPrefix("\t\t") {
            let parts = line.dropFirst().split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "state": status.state = parts[1]
            case "runs": status.runs = Int(parts[1])
            case "last exit code": status.lastExitCode = Int(parts[1])
            default: continue
            }
        }
        return status
    }

    private func launchctl(_ arguments: [String]) async throws -> ProcessResult {
        try await runner.run("/bin/launchctl", arguments, cwd: nil, environment: nil, timeout: 30)
    }
}
