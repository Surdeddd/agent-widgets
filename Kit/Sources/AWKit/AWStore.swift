import AWSchema
import Foundation

public struct AWStore: Sendable {
    public static let shared = AWStore(appGroup: Bundle.main.object(forInfoDictionaryKey: "AWAppGroup") as? String)

    public let root: URL?

    public init(root: URL?) {
        self.root = root
    }

    public init(appGroup: String?) {
        if let override = ProcessInfo.processInfo.environment["AW_DATA_DIR"], !override.isEmpty {
            root = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            root = appGroup.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
        }
    }

    public func url(_ relative: String) -> URL? {
        root?.appendingPathComponent(relative)
    }

    public func read(_ relative: String) -> Data? {
        url(relative).flatMap { try? Data(contentsOf: $0) }
    }

    public func write(_ data: Data, to relative: String) throws {
        guard let target = url(relative) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target, options: .atomic)
    }

    public func data(widget id: String) -> Data? {
        read(AppGroupLayout.data(id))
    }

    public func status(widget id: String) -> FeedStatus? {
        decode(FeedStatus.self, at: AppGroupLayout.status(id))
    }

    public func state(widget id: String) -> AWState {
        decode(AWState.self, at: AppGroupLayout.state(id)) ?? AWState()
    }

    public func save(_ state: AWState, widget id: String) throws {
        try write(AWJSON.encoder().encode(state), to: AppGroupLayout.state(id))
    }

    public func devTarget() -> DevTarget? {
        decode(DevTarget.self, at: AppGroupLayout.devTarget)
    }

    public func runtimeConfig() -> RuntimeConfig? {
        decode(RuntimeConfig.self, at: AppGroupLayout.config)
    }

    public func imageURL(widget id: String, name: String) -> URL? {
        url(AppGroupLayout.image(id, name))
    }

    private func decode<T: Decodable>(_ type: T.Type, at relative: String) -> T? {
        read(relative).flatMap { try? AWJSON.decoder().decode(type, from: $0) }
    }
}
