import AWSchema
import Foundation
import Testing
@testable import AWCore

@Test func cancellingARunStopsTheProcess() async throws {
    let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent("aw-cancel-\(UUID().uuidString).pid")
    defer { try? FileManager.default.removeItem(at: pidFile) }
    let started = Date()
    let run = Task {
        try await SystemProcessRunner().run(
            "/bin/sh",
            ["-c", "echo $$ > '\(pidFile.path)'; exec /bin/sleep 30"],
            cwd: nil,
            environment: nil,
            timeout: 60
        )
    }
    var pid: Int32?
    for _ in 0..<100 where pid == nil {
        try await Task.sleep(nanoseconds: 50_000_000)
        pid = (try? String(contentsOf: pidFile, encoding: .utf8)).flatMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
    let running = try #require(pid)
    run.cancel()
    await #expect(throws: CancellationError.self) { _ = try await run.value }
    #expect(Date().timeIntervalSince(started) < 10)
    #expect(kill(running, 0) != 0)
}

@Test func settleStopsWhenCancelled() async throws {
    let started = Date()
    let wait = Task {
        await Capture.settle(baseline: nil, timeout: 3, interval: 0.02) { nil }
    }
    try await Task.sleep(nanoseconds: 100_000_000)
    wait.cancel()
    let frame = await wait.value
    #expect(frame == nil)
    #expect(Date().timeIntervalSince(started) < 2)
}

@Test func slotWaiterStopsWhenCancelled() async throws {
    let target = ShotTarget(label: "aw.dev", names: ["Probe · Dev"], descriptor: "::com.example.probe.widgets:aw.dev")
    let started = Date()
    let wait = Task {
        await SlotWaiter(families: [], timeout: 3, interval: 0.02).wait(
            target: target,
            locate: { [] },
            sleep: { interval in try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000)) }
        )
    }
    try await Task.sleep(nanoseconds: 100_000_000)
    wait.cancel()
    let windows = await wait.value
    #expect(windows == nil)
    #expect(Date().timeIntervalSince(started) < 2)
}
