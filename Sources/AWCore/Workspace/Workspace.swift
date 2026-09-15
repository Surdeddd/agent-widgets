import AWSchema
import Foundation

public struct WidgetSource: Sendable {
    public let manifest: WidgetManifest
    public let directory: URL
    public let swiftFiles: [URL]
    public let samples: [String: URL]

    public init(manifest: WidgetManifest, directory: URL, swiftFiles: [URL], samples: [String: URL]) {
        self.manifest = manifest
        self.directory = directory
        self.swiftFiles = swiftFiles
        self.samples = samples
    }

    public var id: String {
        manifest.id
    }

    public var defaultSample: URL? {
        samples["default"]
    }
}

public struct Workspace: Sendable {
    public static let configFile = "aw.json"
    public static let localConfigFile = "aw.local.json"
    public static let manifestFile = "widget.json"

    public let root: URL
    public let config: WorkspaceConfig

    public init(root: URL, config: WorkspaceConfig) {
        self.root = root
        self.config = config
    }

    public static func load(at root: URL) throws -> Workspace {
        let config = try WorkspaceConfig.load(
            base: root.appendingPathComponent(configFile),
            local: root.appendingPathComponent(localConfigFile)
        )
        return Workspace(root: root, config: config)
    }

    public static func locate(from start: URL) throws -> Workspace {
        let found = PathWalk.ancestors(of: start).first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent(configFile).path)
        }
        guard let found else {
            throw AWError.workspaceNotFound(start.path)
        }
        return try load(at: found)
    }

    public var widgetsDir: URL {
        root.appendingPathComponent("widgets", isDirectory: true)
    }

    public var dotAW: URL {
        root.appendingPathComponent(".aw", isDirectory: true)
    }

    public var buildDir: URL {
        dotAW.appendingPathComponent("build", isDirectory: true)
    }

    public var cacheDir: URL {
        dotAW.appendingPathComponent("cache", isDirectory: true)
    }

    public var logsDir: URL {
        dotAW.appendingPathComponent("logs", isDirectory: true)
    }

    public var stateDir: URL {
        dotAW.appendingPathComponent("state", isDirectory: true)
    }

    public var shotsDir: URL {
        dotAW.appendingPathComponent("shots", isDirectory: true)
    }

    public func previewsDir(for id: String) -> URL {
        dotAW.appendingPathComponent("previews", isDirectory: true).appendingPathComponent(id, isDirectory: true)
    }

    public func widgets() throws -> [WidgetSource] {
        let fileManager = FileManager.default
        let entries = (try? fileManager.contentsOfDirectory(
            at: widgetsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return try entries
            .filter { fileManager.fileExists(atPath: $0.appendingPathComponent(Self.manifestFile).path) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map(loadWidget(at:))
    }

    public func widget(_ id: String) throws -> WidgetSource {
        guard WidgetID.isValid(id) else { throw AWError.widgetIdInvalid(id) }
        let match = try widgets().first { $0.manifest.id == id || $0.directory.lastPathComponent == id }
        guard let match else {
            throw AWError.widgetNotFound(id)
        }
        return match
    }

    public func validate() -> [Issue] {
        var issues = config.validate()
        let sources: [WidgetSource]
        do {
            sources = try widgets()
        } catch let error as AWError {
            return issues + [error.issue]
        } catch {
            return issues + [AWError.invalidJSON(file: "widgets", reason: error.localizedDescription).issue]
        }
        issues += ManifestValidator.validate(sources.map(\.manifest))
        for source in sources {
            issues += folderIssues(for: source)
        }
        return issues
    }

    private func folderIssues(for source: WidgetSource) -> [Issue] {
        let folder = source.directory.lastPathComponent
        var issues: [Issue] = []
        let id = source.manifest.id
        if id != folder {
            issues.append(Issue(
                code: IssueCode.manifestInvalid,
                severity: .error,
                message: L10n.pick(
                    en: "Folder widgets/\(folder) holds widget id \"\(id)\"",
                    ru: "В папке widgets/\(folder) лежит виджет с id \"\(id)\""
                ),
                hint: L10n.pick(en: "Rename the folder or the id so they match", ru: "Переименуй папку или id, чтобы совпадали"),
                file: "widgets/\(folder)/\(Self.manifestFile)"
            ))
        }
        if source.defaultSample == nil {
            issues.append(Issue(
                code: IssueCode.missingDefaultSample,
                severity: .warning,
                message: L10n.pick(en: "Widget \(id) has no samples/default.json", ru: "У виджета \(id) нет samples/default.json"),
                hint: L10n.pick(
                    en: "Add sample data shaped like the model so `aw preview` can render the widget",
                    ru: "Добавь пример данных в форме модели, чтобы `aw preview` смог отрисовать виджет"
                ),
                file: "widgets/\(folder)/samples/default.json"
            ))
        }
        return issues
    }

    private func loadWidget(at directory: URL) throws -> WidgetSource {
        let folder = directory.lastPathComponent
        let manifest: WidgetManifest
        do {
            let data = try Data(contentsOf: directory.appendingPathComponent(Self.manifestFile))
            manifest = try JSONDecoder().decode(WidgetManifest.self, from: data)
        } catch {
            throw AWError.invalidJSON(
                file: "widgets/\(folder)/\(Self.manifestFile)",
                reason: DecodingErrorFormatter.describe(error)
            )
        }
        let fileManager = FileManager.default
        let files = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let swiftFiles = files
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let sampleFiles = (try? fileManager.contentsOfDirectory(
            at: directory.appendingPathComponent("samples"),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let samples = Dictionary(
            uniqueKeysWithValues: sampleFiles
                .filter { $0.pathExtension == "json" }
                .map { ($0.deletingPathExtension().lastPathComponent, $0) }
        )
        return WidgetSource(manifest: manifest, directory: directory, swiftFiles: swiftFiles, samples: samples)
    }
}
