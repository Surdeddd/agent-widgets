import AWSchema
import Foundation

public struct GalleryItem: Codable, Equatable, Sendable {
    public var id: String
    public var name: LocalizedText
    public var summary: LocalizedText
    public var families: [Family]
    public var hasFeed: Bool
}

public struct Gallery: Sendable {
    public let root: URL

    public init(engine: Engine) {
        root = engine.gallery
    }

    public func list() -> [GalleryItem] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return folders
            .compactMap { folder -> GalleryItem? in
                guard let data = try? Data(contentsOf: folder.appendingPathComponent(Workspace.manifestFile)),
                      let manifest = try? JSONDecoder().decode(WidgetManifest.self, from: data),
                      manifest.id == folder.lastPathComponent
                else {
                    return nil
                }
                return GalleryItem(
                    id: manifest.id,
                    name: manifest.name,
                    summary: manifest.description ?? manifest.name,
                    families: manifest.families,
                    hasFeed: manifest.feed != nil
                )
            }
            .sorted { $0.id < $1.id }
    }

    /// Copies a ready-made widget into the workspace and returns the created paths, relative to the workspace.
    public func add(_ id: String, to workspace: Workspace) throws -> [String] {
        guard WidgetID.isValid(id) else {
            throw AWError.widgetIdInvalid(id)
        }
        guard list().contains(where: { $0.id == id }) else {
            throw AWError.galleryUnknown(id, list().map(\.id))
        }
        let source = root.appendingPathComponent(id, isDirectory: true)
        let target = workspace.widgetsDir.appendingPathComponent(id, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw AWError.widgetExists(id)
        }
        var created: [String] = []
        for (file, relative) in PathWalk.files(in: source) where !relative.contains("__pycache__/") {
            let destination = target.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: file, to: destination)
            if ["py", "sh"].contains(destination.pathExtension) {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            }
            created.append("widgets/\(id)/\(relative)")
        }
        return created.sorted()
    }
}
