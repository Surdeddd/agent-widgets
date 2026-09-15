import AWCore
import AWSchema
import Foundation
import MCP
import Testing
@testable import AWMCP

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.withLock { value }
    }

    func set() {
        lock.withLock { value = true }
    }
}

private final class Messages: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []

    var all: [String] {
        lock.withLock { items }
    }

    func add(_ message: String) {
        lock.withLock { items.append(message) }
    }
}

private func slowJob(seconds: Double, finished: Flag = Flag()) -> AWTool {
    AWTool("aw_fake", "Slow job", schema: Schema.object(["id": Schema.string("Any id")])) { arguments, context in
        try await context.job("aw_fake", key: "aw_fake|\(arguments.fingerprint)", stage: "first") { stage in
            try await Task.sleep(nanoseconds: UInt64(seconds / 2 * 1_000_000_000))
            stage.set("second")
            try await Task.sleep(nanoseconds: UInt64(seconds / 2 * 1_000_000_000))
            finished.set()
            return Reply.make("finished", payload: ["done": true])
        }
    }
}

private func text(_ result: CallTool.Result) -> String {
    var joined = ""
    for item in result.content {
        if case .text(let text, _, _) = item {
            joined += text
        }
    }
    return joined
}

private func jobID(_ result: CallTool.Result) -> String? {
    guard case .object(let payload)? = result.structuredContent,
          case .object(let job)? = payload["job"],
          case .string(let id)? = job["id"] else {
        return nil
    }
    return id
}

@Test func longCallAnswersWithAJobAndWaitFinishesIt() async throws {
    let context = MCPContext()
    let first = try await slowJob(seconds: 0.8).call(Arguments([:]), context, budget: 0.2)
    #expect(text(first).contains("aw_wait"))
    #expect(first.isError != true)
    let id = try #require(jobID(first))
    let final = try await AWTools.wait.call(Arguments(["job": .string(id)]), context, budget: 5)
    #expect(text(final) == "finished")
}

@Test func cancellingTheWaitCancelsTheJob() async throws {
    let context = MCPContext()
    let finished = Flag()
    let first = try await slowJob(seconds: 1.0, finished: finished).call(Arguments([:]), context, budget: 0.1)
    let id = try #require(jobID(first))
    let waiting = Task { try await AWTools.wait.call(Arguments(["job": .string(id)]), context, budget: 5) }
    try await Task.sleep(nanoseconds: 100_000_000)
    waiting.cancel()
    await #expect(throws: CancellationError.self) { _ = try await waiting.value }
    try await Task.sleep(nanoseconds: 1_200_000_000)
    #expect(!finished.isSet)
    #expect(await context.jobs.info(id) == nil)
}

@Test func identicalCallsJoinTheRunningJob() async throws {
    let context = MCPContext()
    let tool = slowJob(seconds: 0.6)
    let first = try await tool.call(Arguments(["id": .string("a")]), context, budget: 0.05)
    let second = try await tool.call(Arguments(["id": .string("a")]), context, budget: 0.05)
    let other = try await tool.call(Arguments(["id": .string("b")]), context, budget: 0.05)
    let firstID = try #require(jobID(first))
    #expect(jobID(second) == firstID)
    #expect(jobID(other) != firstID)
}

@Test func waitingForAnUnknownJobExplainsIt() async throws {
    let result = try await AWTools.wait.call(Arguments(["job": .string("job-nope")]), MCPContext(), budget: 1)
    #expect(result.isError == true)
    #expect(text(result).contains("JOB_UNKNOWN"))
}

@Test func progressFollowsTheJobStages() async throws {
    let messages = Messages()
    let progress = ProgressReporter(token: .string("probe")) { parameters in
        messages.add(parameters.message ?? "")
    }
    let result = try await slowJob(seconds: 0.6).call(Arguments([:]), MCPContext(), progress: progress, budget: nil)
    #expect(text(result) == "finished")
    #expect(messages.all.contains("first"))
    #expect(messages.all.contains("second"))
}

@Test func budgetDependsOnTheClient() async {
    let context = MCPContext()
    #expect(await context.budget() == 45)
    await context.client.set("claude-code")
    #expect(await context.budget() == nil)
    #expect(await MCPContext(callBudget: 20).budget() == 20)
    #expect(await MCPContext(callBudget: 0).budget() == nil)
}
