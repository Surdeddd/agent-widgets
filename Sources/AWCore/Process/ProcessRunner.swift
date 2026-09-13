import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String
    public let duration: TimeInterval
    public let timedOut: Bool

    public init(status: Int32, stdout: String, stderr: String, duration: TimeInterval, timedOut: Bool) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
        self.timedOut = timedOut
    }

    public var succeeded: Bool {
        status == 0 && !timedOut
    }

    public var combinedOutput: String {
        stdout + stderr
    }
}

public protocol ProcessRunning: Sendable {
    func run(
        _ executable: String,
        _ arguments: [String],
        cwd: URL?,
        environment: [String: String]?,
        timeout: TimeInterval?
    ) async throws -> ProcessResult
}

extension ProcessRunning {
    public func run(_ executable: String, _ arguments: [String]) async throws -> ProcessResult {
        try await run(executable, arguments, cwd: nil, environment: nil, timeout: nil)
    }
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(
        _ executable: String,
        _ arguments: [String],
        cwd: URL?,
        environment: [String: String]?,
        timeout: TimeInterval?
    ) async throws -> ProcessResult {
        let process = Process()
        if executable.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
        }
        if let cwd {
            process.currentDirectoryURL = cwd
        }
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, override in override }
        }
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        let stdout = PipeDrain(output.fileHandleForReading)
        let stderr = PipeDrain(errors.fileHandleForReading)
        let started = Date()
        try process.run()
        let flag = TimeoutFlag()
        let watchdog = timeout.map { seconds in
            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled, process.isRunning else { return }
                flag.fire()
                process.terminate()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }
        await Task.detached { process.waitUntilExit() }.value
        watchdog?.cancel()
        return ProcessResult(
            status: process.terminationStatus,
            stdout: stdout.text(),
            stderr: stderr.text(),
            duration: Date().timeIntervalSince(started),
            timedOut: flag.fired
        )
    }
}

private final class PipeDrain: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private let finished = DispatchSemaphore(value: 0)
    private var buffer = Data()

    init(_ handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard let self else { return }
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                self.finished.signal()
            } else {
                self.lock.withLock { self.buffer.append(chunk) }
            }
        }
    }

    func text(grace: TimeInterval = 2) -> String {
        if finished.wait(timeout: .now() + grace) == .timedOut {
            handle.readabilityHandler = nil
        }
        return lock.withLock { String(bytes: buffer, encoding: .utf8) ?? "" }
    }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func fire() {
        lock.withLock { value = true }
    }

    var fired: Bool {
        lock.withLock { value }
    }
}
