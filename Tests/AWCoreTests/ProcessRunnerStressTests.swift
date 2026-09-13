import Foundation
import Testing
@testable import AWCore

private func runConcurrently(_ count: Int, _ executable: String, _ arguments: [String]) async throws -> [Int32] {
    let runner = SystemProcessRunner()
    return try await withThrowingTaskGroup(of: Int32.self) { group in
        for _ in 0..<count {
            group.addTask {
                try await runner.run(executable, arguments, cwd: nil, environment: nil, timeout: 20).status
            }
        }
        var collected: [Int32] = []
        for try await status in group {
            collected.append(status)
        }
        return collected
    }
}

@Test(.timeLimit(.minutes(1)))
func runnerSurvivesManyConcurrentShortProcesses() async throws {
    let statuses = try await runConcurrently(150, "/usr/bin/true", [])
    #expect(statuses.count == 150)
    #expect(statuses.allSatisfy { $0 == 0 })
}

@Test(.timeLimit(.minutes(1)))
func runnerNeverHangsOnProcessesThatOutliveTheLaunch() async throws {
    let started = Date()
    let statuses = try await runConcurrently(40, "/bin/sleep", ["0.4"])
    #expect(statuses.count == 40)
    #expect(statuses.allSatisfy { $0 == 0 })
    #expect(Date().timeIntervalSince(started) < 20)
}
