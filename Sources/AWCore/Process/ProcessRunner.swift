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
        try await run(executable, arguments, cwd: nil, environment: nil, timeout: 600)
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
        let process = Self.makeProcess(executable, arguments, cwd: cwd, environment: environment)
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        let stdout = PipeDrain(output.fileHandleForReading)
        let stderr = PipeDrain(errors.fileHandleForReading)
        let exit = ExitSignal()
        process.terminationHandler = { finished in
            exit.finish(finished.terminationStatus)
        }
        let started = Date()
        try process.run()
        if let timeout {
            Self.watch(process, exit: exit, timeout: timeout)
        }
        let (status, timedOut) = await exit.wait()
        return ProcessResult(
            status: status,
            stdout: stdout.text(),
            stderr: stderr.text(),
            duration: Date().timeIntervalSince(started),
            timedOut: timedOut
        )
    }

    private static func makeProcess(_ executable: String, _ arguments: [String], cwd: URL?, environment: [String: String]?) -> Process {
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
        return process
    }

    private static func watch(_ process: Process, exit: ExitSignal, timeout: TimeInterval) {
        let queue = DispatchQueue.global(qos: .utility)
        queue.asyncAfter(deadline: .now() + timeout) {
            guard process.isRunning else { return }
            exit.markTimedOut()
            process.terminate()
            queue.asyncAfter(deadline: .now() + 1.5) {
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }
        queue.asyncAfter(deadline: .now() + timeout + 10) {
            exit.markTimedOut()
            exit.finish(process.isRunning ? -1 : process.terminationStatus)
        }
    }
}

private final class ExitSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var outcome: (Int32, Bool)?
    private var waiter: CheckedContinuation<(Int32, Bool), Never>?
    private var timedOut = false

    func markTimedOut() {
        lock.withLock { timedOut = true }
    }

    func finish(_ status: Int32) {
        lock.lock()
        guard outcome == nil else {
            lock.unlock()
            return
        }
        let value = (status, timedOut)
        outcome = value
        let pending = waiter
        waiter = nil
        lock.unlock()
        pending?.resume(returning: value)
    }

    func wait() async -> (Int32, Bool) {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let outcome {
                lock.unlock()
                continuation.resume(returning: outcome)
                return
            }
            waiter = continuation
            lock.unlock()
        }
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
