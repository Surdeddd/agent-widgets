import AWSchema
import Foundation

public struct KitCache: Sendable {
    public static let modules = ["AWSchema", "AWKit", "AWPreview"]

    public let engine: Engine
    public let runner: any ProcessRunning
    public let base: URL

    public init(engine: Engine, runner: any ProcessRunning, base: URL? = nil) {
        self.engine = engine
        self.runner = runner
        self.base = base ?? KitCache.defaultBase()
    }

    public static func defaultBase() -> URL {
        if let override = ProcessInfo.processInfo.environment["AW_CACHE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true).appendingPathComponent("kit", isDirectory: true)
        }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("agent-widgets/kit", isDirectory: true)
    }

    public func fingerprint() async -> String {
        let files = Self.modules.flatMap { Fingerprint.swiftFiles(in: sources(of: $0)) }
        let version = await Toolchain(runner: runner).swiftVersion()
        let digest = Fingerprint.of(files: files, root: engine.kitPackage, extra: [version, Toolchain.targetTriple])
        return String(digest.prefix(16))
    }

    public func isReady() async -> Bool {
        isComplete(base.appendingPathComponent(await fingerprint(), isDirectory: true))
    }

    public func ensure() async throws -> URL {
        let key = await fingerprint()
        let target = base.appendingPathComponent(key, isDirectory: true)
        if isComplete(target) {
            return target
        }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let lock = try FileLock(base.appendingPathComponent(".lock"))
        defer { lock.unlock() }
        if isComplete(target) {
            return target
        }
        let staging = base.appendingPathComponent("\(key).staging-\(getpid())", isDirectory: true)
        try? FileManager.default.removeItem(at: staging)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        for module in Self.modules {
            try await compile(module, into: staging)
        }
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.moveItem(at: staging, to: target)
        return target
    }

    func isComplete(_ directory: URL) -> Bool {
        Self.modules.allSatisfy {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("lib\($0).a").path)
        }
    }

    private func sources(of module: String) -> URL {
        engine.kitPackage.appendingPathComponent("Sources/\(module)", isDirectory: true)
    }

    private func compile(_ module: String, into directory: URL) async throws {
        let files = Fingerprint.swiftFiles(in: sources(of: module)).map(\.path)
        let arguments = [
            "swiftc", "-emit-library", "-static", "-emit-module", "-parse-as-library",
            "-module-name", module, "-swift-version", "5", "-target", Toolchain.targetTriple, "-Onone",
            "-I", directory.path,
            "-emit-module-path", directory.appendingPathComponent("\(module).swiftmodule").path,
            "-o", directory.appendingPathComponent("lib\(module).a").path
        ] + files
        let result = try await runner.run("/usr/bin/xcrun", arguments, cwd: directory, environment: nil, timeout: 900)
        guard result.succeeded else {
            throw AWError.toolFailed(tool: "swiftc \(module)", status: result.status, output: String(result.combinedOutput.suffix(2000)))
        }
    }
}
