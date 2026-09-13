import Foundation

public struct Toolchain: Sendable {
    public let runner: any ProcessRunning

    public init(runner: any ProcessRunning) {
        self.runner = runner
    }

    public static var targetTriple: String {
        #if arch(arm64)
        "arm64-apple-macos14.0"
        #else
        "x86_64-apple-macos14.0"
        #endif
    }

    public func swiftVersion() async -> String {
        let result = try? await runner.run("/usr/bin/xcrun", ["swiftc", "--version"], cwd: nil, environment: nil, timeout: 60)
        return result?.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
    }
}
