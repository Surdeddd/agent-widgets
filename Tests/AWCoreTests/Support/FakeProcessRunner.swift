import Foundation
@testable import AWCore

final class FakeProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [(prefix: String, results: [ProcessResult])] = []
    private(set) var calls: [[String]] = []

    func respond(to prefix: String, with result: ProcessResult) {
        respond(to: prefix, with: [result])
    }

    func respond(to prefix: String, with results: [ProcessResult]) {
        lock.withLock { responses.append((prefix, results)) }
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
            guard let index = responses.lastIndex(where: { command.hasPrefix($0.prefix) }),
                  let first = responses[index].results.first
            else {
                return .failure("not faked: \(command)", status: 127)
            }
            if responses[index].results.count > 1 {
                responses[index].results.removeFirst()
            }
            return first
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
