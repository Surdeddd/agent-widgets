import Foundation

public struct Reloader: Sendable {
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public let scheme: String
    public let runner: any ProcessRunning

    public init(config: WorkspaceConfig, runner: any ProcessRunning) {
        scheme = config.resolvedURLScheme
        self.runner = runner
    }

    public func url(kind: String?) -> String {
        guard let kind else {
            return "\(scheme)://reload"
        }
        return "\(scheme)://reload?kind=\(kind.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? kind)"
    }

    @discardableResult
    public func reload(kind: String?) async -> Bool {
        let result = try? await runner.run("/usr/bin/open", ["-g", url(kind: kind)], cwd: nil, environment: nil, timeout: 30)
        return result?.succeeded == true
    }

    /// Redraws a widget after new data, and the dev slot too when it shows that widget live.
    public func reload(afterPublishing widget: WidgetSource, store: AppGroupStore) async {
        await reload(kind: widget.manifest.resolvedKind)
        let dev = store.devTarget()
        if dev?.widget == widget.id && dev?.scenario == nil {
            await reload(kind: RegistryGenerator.devKind)
        }
    }
}
