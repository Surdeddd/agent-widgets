import AWCore
import AWSchema
import Foundation
import MCP
import Testing
@testable import AWMCP

private func text(_ result: CallTool.Result) -> String {
    var joined = ""
    for item in result.content {
        if case .text(let text, _, _) = item {
            joined += text
        }
    }
    return joined
}

@Test func wrongArgumentTypeIsReportedAsSuch() async throws {
    let result = try await L10n.$language.withValue(.en) {
        try await AWTools.preview.call(Arguments(["id": .int(123)]), MCPContext())
    }
    #expect(result.isError == true)
    #expect(text(result).contains("INVALID_ARGUMENT"))
    #expect(text(result).contains("\"id\" must be a string, got a number"))
    #expect(!text(result).contains("missing"))
}

@Test func unknownArgumentListsTheKnownOnes() async throws {
    let result = try await L10n.$language.withValue(.en) {
        try await AWTools.preview.call(Arguments(["id": .string("weather"), "famillies": .string("small")]), MCPContext())
    }
    #expect(result.isError == true)
    #expect(text(result).contains("unknown argument \"famillies\""))
    #expect(text(result).contains("families"))
}

@Test func argumentCheckAcceptsListsAsStringsAndNullOptionals() {
    let schema = AWTools.preview.tool.inputSchema
    #expect(ArgumentCheck.problems(["id": .string("x"), "families": .string("small,medium"), "full": .null], schema: schema).isEmpty)
    #expect(ArgumentCheck.problems(["id": .string("x"), "families": .array([.string("small")])], schema: schema).isEmpty)
    #expect(ArgumentCheck.problems(["id": .string("x"), "families": .array([.int(1)])], schema: schema).count == 1)
    #expect(ArgumentCheck.problems(["id": .string("x"), "full": .string("yes")], schema: schema).count == 1)
    #expect(ArgumentCheck.problems([:], schema: schema).count == 1)
    #expect(ArgumentCheck.problems(["id": .null], schema: schema).count == 1)
}

@Test func hintsInRepliesNameToolsAndShellCommands() async throws {
    let empty = FileManager.default.temporaryDirectory.appendingPathComponent("aw-hints-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: empty) }
    let result = try await L10n.$language.withValue(.en) {
        try await AWTools.list.call(Arguments([:]), MCPContext(directory: empty))
    }
    #expect(text(result).contains("WORKSPACE_NOT_FOUND"))
    #expect(text(result).contains("`aw_init`"))
    #expect(text(result).contains("the `workspace` argument"))
    let invalid = try await L10n.$language.withValue(.en) {
        try await AWTools.preview.call(Arguments(["id": .int(1)]), MCPContext())
    }
    #expect(text(invalid).contains("`aw_explain {\"code\": \"INVALID_ARGUMENT\"}`"))
    let warned = L10n.$language.withValue(.en) {
        Reply.make("done", issues: [AWSchema.Issue(code: "X", severity: .warning, message: "careful", hint: "Run `aw list` first")], payload: ["ok": true])
    }
    #expect(text(warned).contains("Run `aw_list` first"))
}
