import AWCore
import AWSchema
import Foundation
import MCP
import Testing
@testable import AWMCP

private func slowTool(respectingCancellation: Bool) -> AWTool {
    AWTool("aw_slow", "Sleeps", schema: Schema.object([:])) { _, _ in
        if respectingCancellation {
            try await Task.sleep(nanoseconds: 60_000_000_000)
        } else {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return Reply.make("done", payload: ["done": true])
    }
}

@Test func cancelledToolCallThrowsInsteadOfReplying() async throws {
    for respecting in [true, false] {
        let tool = slowTool(respectingCancellation: respecting)
        let started = Date()
        let call = Task { try await tool.call(Arguments([:]), MCPContext()) }
        try await Task.sleep(nanoseconds: 50_000_000)
        call.cancel()
        await #expect(throws: CancellationError.self) { _ = try await call.value }
        #expect(Date().timeIntervalSince(started) < 20)
    }
}

@Test func finishedToolCallStillReplies() async throws {
    let tool = AWTool("aw_quick", "Returns", schema: Schema.object([:])) { _, _ in
        Reply.make("done", payload: ["done": true])
    }
    let result = try await tool.call(Arguments([:]), MCPContext())
    #expect(result.isError != true)
}
