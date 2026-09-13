import Foundation
@testable import AWCore

final class FakeProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [(prefix: String, result: ProcessResult)] = []
    private(set) var calls: [[String]] = []

    func respond(to prefix: String, with result: ProcessResult) {
        lock.withLock { responses.append((prefix, result)) }
    }

    func run(
        _ executable: String,
        _ arguments: [String],
        cwd: URL?,
        environment: [String: String]?,
        timeout: TimeInterval?
    ) async throws -> ProcessResult {
        let command = ([executable] + arguments).joined(separator: " ")
        return lock.withLock {
            calls.append([executable] + arguments)
            let match = responses.last { command.hasPrefix($0.prefix) }
            return match?.result ?? .failure("not faked: \(command)", status: 127)
        }
    }
}

extension ProcessResult {
    static func ok(_ stdout: String) -> ProcessResult {
        ProcessResult(status: 0, stdout: stdout, stderr: "", duration: 0, timedOut: false)
    }

    static func failure(_ stderr: String, status: Int32 = 1) -> ProcessResult {
        ProcessResult(status: status, stdout: "", stderr: stderr, duration: 0, timedOut: false)
    }
}
