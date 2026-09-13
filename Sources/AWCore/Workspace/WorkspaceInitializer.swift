import AWSchema
import Foundation

public struct InitOptions: Sendable {
    public var directory: URL
    public var name: String?
    public var slug: String?
    public var bundlePrefix: String?
    public var locale: Language?

    public init(directory: URL, name: String? = nil, slug: String? = nil, bundlePrefix: String? = nil, locale: Language? = nil) {
        self.directory = directory
        self.name = name
        self.slug = slug
        self.bundlePrefix = bundlePrefix
        self.locale = locale
    }
}

public struct InitResult: Codable, Equatable, Sendable {
    public var root: String
    public var files: [String]
    public var signing: SigningIdentity?
}

public struct WorkspaceInitializer: Sendable {
    public let engine: Engine
    public let runner: any ProcessRunning

    public init(engine: Engine, runner: any ProcessRunning) {
        self.engine = engine
        self.runner = runner
    }

    public func initialize(_ options: InitOptions) async throws -> (result: InitResult, issues: [Issue]) {
        let fileManager = FileManager.default
        let root = options.directory.standardizedFileURL
        guard !fileManager.fileExists(atPath: root.appendingPathComponent(Workspace.configFile).path) else {
            throw AWError.workspaceExists(root.path)
        }
        try fileManager.createDirectory(at: root.appendingPathComponent("widgets"), withIntermediateDirectories: true)
        let folder = root.lastPathComponent
        var base: [String: JSONValue] = [
            "name": .string(options.name ?? Self.titleize(folder)),
            "slug": .string(options.slug ?? Self.slugify(folder)),
            "bundlePrefix": .string(options.bundlePrefix ?? Self.defaultBundlePrefix())
        ]
        if let locale = options.locale {
            base["locale"] = .string(locale.rawValue)
        }
        let identity = await SigningDetector.detect(runner: runner)
        try Self.writeJSON(.object(base), to: root.appendingPathComponent(Workspace.configFile))
        try Self.writeJSON(Self.signingJSON(identity), to: root.appendingPathComponent(Workspace.localConfigFile))
        var files = [Workspace.configFile, Workspace.localConfigFile]
        var issues: [Issue] = []
        for (template, target) in [("AGENTS.md", "AGENTS.md"), ("CLAUDE.md", "CLAUDE.md"), ("gitignore", ".gitignore")] {
            let destination = root.appendingPathComponent(target)
            if fileManager.fileExists(atPath: destination.path) {
                issues.append(Issue(
                    code: IssueCode.keptExisting,
                    severity: .info,
                    message: L10n.pick(en: "Kept the existing \(target)", ru: "Оставил существующий \(target)")
                ))
                continue
            }
            try fileManager.copyItem(at: engine.templates.appendingPathComponent("workspace/\(template)"), to: destination)
            files.append(target)
        }
        return (InitResult(root: root.path, files: files, signing: identity), issues + Self.signingIssues(identity))
    }

    public func refreshSigning(at directory: URL) async throws -> (result: InitResult, issues: [Issue]) {
        let workspace = try Workspace.locate(from: directory)
        let localURL = workspace.root.appendingPathComponent(Workspace.localConfigFile)
        let identity = await SigningDetector.detect(runner: runner)
        let current = (try? JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: localURL))) ?? .object([:])
        try Self.writeJSON(current.merged(with: Self.signingJSON(identity)), to: localURL)
        let result = InitResult(root: workspace.root.path, files: [Workspace.localConfigFile], signing: identity)
        return (result, Self.signingIssues(identity))
    }

    public static func slugify(_ text: String) -> String {
        var result = ""
        var pendingDash = false
        for scalar in text.lowercased().unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                if pendingDash && !result.isEmpty {
                    result.append("-")
                }
                result.unicodeScalars.append(scalar)
                pendingDash = false
            } else {
                pendingDash = true
            }
        }
        if result.isEmpty {
            return "widgets"
        }
        if let first = result.unicodeScalars.first, ("0"..."9").contains(first) {
            result = "w-" + result
        }
        return String(result.prefix(40))
    }

    public static func titleize(_ text: String) -> String {
        text.split { $0 == "-" || $0 == "_" || $0 == " " }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func defaultBundlePrefix() -> String {
        let user = slugify(NSUserName()).replacingOccurrences(of: "-", with: "")
        return "com.\(user == "widgets" ? "example" : user)"
    }

    static func signingJSON(_ identity: SigningIdentity?) -> JSONValue {
        .object([
            "teamID": .string(identity?.teamID ?? ""),
            "signingIdentity": .string(identity?.name ?? "")
        ])
    }

    static func signingIssues(_ identity: SigningIdentity?) -> [Issue] {
        guard identity?.teamID == nil else {
            return []
        }
        return [Issue(
            code: IssueCode.signingMissing,
            severity: .warning,
            message: L10n.pick(
                en: "No Apple Development signing found; builds will fail until it is set",
                ru: "Подпись Apple Development не найдена; сборка не пройдёт, пока её нет"
            ),
            hint: L10n.pick(
                en: "Xcode → Settings → Accounts → Manage Certificates → + Apple Development, then `aw init --refresh-signing`",
                ru: "Xcode → Settings → Accounts → Manage Certificates → + Apple Development, затем `aw init --refresh-signing`"
            ),
            file: Workspace.localConfigFile
        )]
    }

    static func writeJSON(_ value: JSONValue, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
    }
}
