import AWSchema
import Foundation

public struct InstallPaths: Sendable {
    public var installDir: URL
    public var backups: URL
    public var searchDirs: [URL]
    public var groupContainer: URL

    public init(installDir: URL, backups: URL, searchDirs: [URL], groupContainer: URL) {
        self.installDir = installDir
        self.backups = backups
        self.searchDirs = searchDirs
        self.groupContainer = groupContainer
    }

    public static func standard(for config: WorkspaceConfig, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> InstallPaths {
        let installDir = URL(fileURLWithPath: (config.resolvedInstallDir as NSString).expandingTildeInPath, isDirectory: true)
        let candidates = [
            installDir,
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]
        var seen = Set<String>()
        return InstallPaths(
            installDir: installDir,
            backups: home.appendingPathComponent("Library/Application Support/agent-widgets/\(config.appBundleID)/backups", isDirectory: true),
            searchDirs: candidates.filter { seen.insert($0.standardizedFileURL.path).inserted },
            groupContainer: AppGroupStore.container(group: config.resolvedAppGroup, home: home)
        )
    }
}

public struct InstallOutcome: Codable, Sendable {
    public var app: String
    public var backup: String?
    public var retired: [String]
    public var registered: Bool
    public var containerReady: Bool
    public var issues: [Issue]
    public var seconds: Double

    public var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }
}

public struct Installer: Sendable {
    public static let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    public static let keptBackups = 3

    public let config: WorkspaceConfig
    public let runner: any ProcessRunning
    public let paths: InstallPaths
    public var pollInterval: TimeInterval = 0.5
    public var containerTimeout: TimeInterval = 10
    public var discard: @Sendable (URL) throws -> Void = { url in
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    public init(config: WorkspaceConfig, runner: any ProcessRunning, paths: InstallPaths) {
        self.config = config
        self.runner = runner
        self.paths = paths
    }

    public var target: URL {
        paths.installDir.appendingPathComponent("\(config.appName).app", isDirectory: true)
    }

    private var retiredDir: URL {
        paths.backups.appendingPathComponent("retired", isDirectory: true)
    }

    public func install(_ built: URL, hard: Bool = false, now: Date = Date()) async throws -> InstallOutcome {
        let started = Date()
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: built.path) else {
            throw AWError.installFailed(L10n.pick(en: "No built app at \(built.path)", ru: "Нет собранного приложения: \(built.path)"))
        }
        guard Self.bundleID(of: built) == config.appBundleID else {
            throw AWError.installFailed(L10n.pick(
                en: "\(built.path) is not the \(config.appBundleID) app",
                ru: "\(built.path) — не приложение \(config.appBundleID)"
            ))
        }
        try fileManager.createDirectory(at: paths.backups, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.installDir, withIntermediateDirectories: true)
        let stamp = Stamp.string(now)
        var backup: URL?
        if fileManager.fileExists(atPath: target.path) {
            let destination = Self.unique(paths.backups.appendingPathComponent("\(stamp).app", isDirectory: true))
            try fileManager.copyItem(at: target, to: destination)
            backup = destination
        }
        try place(built)
        let retired = try retireCopies(stamp: stamp)
        try rotate()
        return await activate(started: started, backup: backup, retired: retired, hard: hard)
    }

    public func rollback(now: Date = Date()) async throws -> InstallOutcome {
        let started = Date()
        guard let latest = backups().last else {
            throw AWError.installFailed(L10n.pick(
                en: "No backups of \(config.appName) in \(paths.backups.path)",
                ru: "Нет бэкапов \(config.appName) в \(paths.backups.path)"
            ))
        }
        let fileManager = FileManager.default
        var saved: URL?
        if fileManager.fileExists(atPath: target.path) {
            let destination = Self.unique(paths.backups.appendingPathComponent("\(Stamp.string(now)).app", isDirectory: true))
            try fileManager.copyItem(at: target, to: destination)
            saved = destination
            _ = try fileManager.replaceItemAt(target, withItemAt: latest)
        } else {
            try fileManager.createDirectory(at: paths.installDir, withIntermediateDirectories: true)
            try fileManager.moveItem(at: latest, to: target)
        }
        return await activate(started: started, backup: saved, retired: [], hard: false)
    }

    public func backups() -> [URL] {
        Self.names(in: paths.backups, suffix: ".app").map { paths.backups.appendingPathComponent($0, isDirectory: true) }
    }

    public func isRegistered() async -> Bool {
        let result = try? await runner.run("/usr/bin/pluginkit", ["-m", "-v", "-i", config.extensionBundleID], cwd: nil, environment: nil, timeout: 30)
        return Self.registered(result?.stdout ?? "", under: target)
    }

    public static func registered(_ listing: String, under app: URL) -> Bool {
        let prefix = app.standardizedFileURL.path + "/Contents/PlugIns/"
        return listing.split(whereSeparator: \.isNewline).contains { $0.contains(prefix) }
    }

    public static func bundleID(of app: URL) -> String? {
        guard let data = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }

    static func pattern(_ path: String) -> String {
        var escaped = ""
        for character in path + "/Contents/" {
            if "\\^$.|?*+()[]{}".contains(character) {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        return escaped
    }

    static func unique(_ url: URL) -> URL {
        let base = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent()
        var candidate = url
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base)-\(index).\(url.pathExtension)", isDirectory: true)
            index += 1
        }
        return candidate
    }

    private static func names(in directory: URL, suffix: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(suffix) }
            .sorted()
    }

    private func place(_ built: URL) throws {
        let fileManager = FileManager.default
        let staging = paths.backups.appendingPathComponent(".staging", isDirectory: true)
        let staged = staging.appendingPathComponent(target.lastPathComponent, isDirectory: true)
        if fileManager.fileExists(atPath: staged.path) {
            try discard(staged)
        }
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        try fileManager.copyItem(at: built, to: staged)
        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(target, withItemAt: staged)
        } else {
            try fileManager.moveItem(at: staged, to: target)
        }
    }

    private func retireCopies(stamp: String) throws -> [String] {
        let fileManager = FileManager.default
        let own = target.standardizedFileURL.path
        var retired: [String] = []
        for directory in paths.searchDirs {
            for name in Self.names(in: directory, suffix: ".app") {
                let app = directory.appendingPathComponent(name, isDirectory: true)
                guard app.standardizedFileURL.path != own, Self.bundleID(of: app) == config.appBundleID else { continue }
                try fileManager.createDirectory(at: retiredDir, withIntermediateDirectories: true)
                try fileManager.moveItem(at: app, to: Self.unique(retiredDir.appendingPathComponent("\(stamp)-\(name)", isDirectory: true)))
                retired.append(app.path)
            }
        }
        return retired
    }

    private func rotate() throws {
        for old in backups().dropLast(Self.keptBackups) {
            try discard(old)
        }
    }

    private func activate(started: Date, backup: URL?, retired: [String], hard: Bool) async -> InstallOutcome {
        _ = try? await runner.run(Self.lsregister, ["-f", target.path], cwd: nil, environment: nil, timeout: 60)
        for path in [target.path] + retired {
            _ = try? await runner.run("/usr/bin/pkill", ["-9", "-f", Self.pattern(path)], cwd: nil, environment: nil, timeout: 10)
        }
        if hard {
            _ = try? await runner.run("/usr/bin/killall", ["chronod"], cwd: nil, environment: nil, timeout: 10)
        }
        var issues: [Issue] = []
        let registered = await ensureRegistered()
        if !registered {
            issues.append(unregisteredIssue)
        }
        let opened = try? await runner.run("/usr/bin/open", ["-g", target.path], cwd: nil, environment: nil, timeout: 30)
        if opened?.succeeded != true {
            issues.append(launchIssue)
        }
        let containerReady = await waitForContainer()
        if !containerReady {
            issues.append(containerIssue)
        }
        return InstallOutcome(
            app: target.path,
            backup: backup?.path,
            retired: retired,
            registered: registered,
            containerReady: containerReady,
            issues: issues,
            seconds: Date().timeIntervalSince(started)
        )
    }

    private func ensureRegistered() async -> Bool {
        if await isRegistered() {
            return true
        }
        let plugins = target.appendingPathComponent("Contents/PlugIns", isDirectory: true)
        if let appex = Self.names(in: plugins, suffix: ".appex").first {
            _ = try? await runner.run("/usr/bin/pluginkit", ["-a", plugins.appendingPathComponent(appex).path], cwd: nil, environment: nil, timeout: 30)
        }
        for _ in 0..<5 {
            if await isRegistered() {
                return true
            }
            await pause(pollInterval)
        }
        return false
    }

    private func waitForContainer() async -> Bool {
        let deadline = Date().addingTimeInterval(containerTimeout)
        repeat {
            if FileManager.default.fileExists(atPath: paths.groupContainer.path) {
                return true
            }
            await pause(pollInterval)
        } while Date() < deadline
        return FileManager.default.fileExists(atPath: paths.groupContainer.path)
    }

    private func pause(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private var unregisteredIssue: Issue {
        Issue(
            code: IssueCode.installFailed,
            severity: .warning,
            message: L10n.pick(
                en: "macOS has not registered the widget extension from \(target.path) yet",
                ru: "macOS ещё не зарегистрировала расширение виджетов из \(target.path)"
            ),
            hint: L10n.pick(
                en: "Run `aw install --hard`; if the widget gallery still misses them, log out and back in",
                ru: "Запусти `aw install --hard`; если в галерее виджетов их всё нет — перелогинься"
            )
        )
    }

    private var launchIssue: Issue {
        Issue(
            code: IssueCode.installFailed,
            severity: .error,
            message: L10n.pick(en: "Could not launch \(target.path)", ru: "Не удалось запустить \(target.path)"),
            hint: L10n.pick(
                en: "Check the signature: codesign --verify --deep \"\(target.path)\"",
                ru: "Проверь подпись: codesign --verify --deep \"\(target.path)\""
            )
        )
    }

    private var containerIssue: Issue {
        Issue(
            code: IssueCode.installFailed,
            severity: .warning,
            message: L10n.pick(
                en: "The App Group container \(config.resolvedAppGroup) did not appear",
                ru: "Контейнер App Group \(config.resolvedAppGroup) не появился"
            ),
            hint: L10n.pick(
                en: "Widgets read their data from it: check that teamID in aw.local.json matches the signing certificate",
                ru: "Из него виджеты читают данные: проверь, что teamID в aw.local.json совпадает с сертификатом подписи"
            )
        )
    }
}
