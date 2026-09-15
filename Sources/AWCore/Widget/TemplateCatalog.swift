import AWSchema
import Foundation

public struct TemplateInfo: Codable, Equatable, Sendable {
    public var id: String
    public var summary: LocalizedText
    public var families: [Family]
}

public struct TemplateCatalog: Sendable {
    public let root: URL

    public init(engine: Engine) {
        root = engine.templates.appendingPathComponent("widgets", isDirectory: true)
    }

    public func list() -> [TemplateInfo] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return folders
            .compactMap { folder in
                (try? Data(contentsOf: folder.appendingPathComponent("template.json")))
                    .flatMap { try? JSONDecoder().decode(TemplateInfo.self, from: $0) }
            }
            .sorted { $0.id < $1.id }
    }

    public func instantiate(
        _ template: String,
        id: String,
        name: LocalizedText? = nil,
        families: [Family]? = nil,
        in workspace: Workspace
    ) throws -> [String] {
        guard WidgetID.isValid(id) else {
            throw AWError.widgetIdInvalid(id)
        }
        let source = root.appendingPathComponent(template, isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.appendingPathComponent("template.json").path) else {
            throw AWError.templateUnknown(template, list().map(\.id))
        }
        let target = workspace.widgetsDir.appendingPathComponent(id, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw AWError.widgetExists(id)
        }
        let type = Self.typeName(for: id)
        let title = name ?? LocalizedText(en: WorkspaceInitializer.titleize(id))
        let replacements = [
            "__ID__": id,
            "__TYPE__": type,
            "__NAME__": title.en,
            "__NAME_RU__": title.ru ?? title.en
        ]
        var created: [String] = []
        for file in files(in: source) {
            let relative = String(file.path.dropFirst(source.path.count + 1))
            guard relative != "template.json" else { continue }
            var destinationPath = relative.replacingOccurrences(of: "__TYPE__", with: type)
            if destinationPath.hasSuffix(".tmpl") {
                destinationPath = String(destinationPath.dropLast(".tmpl".count))
            }
            let destination = target.appendingPathComponent(destinationPath)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if Self.textExtensions.contains(destination.pathExtension), var text = try? String(contentsOf: file, encoding: .utf8) {
                for (token, value) in replacements {
                    text = text.replacingOccurrences(of: token, with: value)
                }
                try text.write(to: destination, atomically: true, encoding: .utf8)
            } else {
                try FileManager.default.copyItem(at: file, to: destination)
            }
            if ["py", "sh"].contains(destination.pathExtension) {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            }
            created.append("widgets/\(id)/\(destinationPath)")
        }
        if let families {
            try patchManifest(at: target.appendingPathComponent(Workspace.manifestFile), families: families)
        }
        return created.sorted()
    }

    public static func typeName(for id: String) -> String {
        id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    private static let textExtensions: Set<String> = ["swift", "json", "py", "sh", "md", "txt"]

    private func files(in directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        return (enumerator?.compactMap { $0 as? URL } ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.path < $1.path }
    }

    private func patchManifest(at url: URL, families: [Family]) throws {
        let manifest = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
        let patched = manifest.merged(with: .object(["families": .array(families.map { .string($0.rawValue) })]))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(patched).write(to: url, options: .atomic)
    }
}
