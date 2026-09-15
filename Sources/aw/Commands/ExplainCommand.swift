import ArgumentParser
import AWCore
import AWMCP
import AWSchema
import Foundation

struct ExplainCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "explain",
        abstract: L10n.pick(
            en: "Explain an issue code: what it means, why it happens and how to fix it.",
            ru: "Объяснить код проблемы: что значит, откуда берётся и как чинить."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Issue code, for example OVERFLOW.", ru: "Код проблемы, например OVERFLOW.")))
    var code: String?

    func execute() async throws -> Int32 {
        guard let code else {
            let entries = IssueCatalog.entries
            global.printer.emit(CommandResult(data: entries)) { list in
                let width = (list ?? []).map(\.code.count).max() ?? 0
                return (list ?? []).map { "\($0.code.padding(toLength: width + 2, withPad: " ", startingAt: 0))\($0.title.localized)" }
                    .joined(separator: "\n")
            }
            return 0
        }
        guard let entry = IssueCatalog.explain(code) else {
            let issue = Issue(
                code: "UNKNOWN_CODE",
                severity: .error,
                message: L10n.pick(en: "No issue code \(code)", ru: "Нет кода \(code)"),
                hint: L10n.pick(en: "`aw explain` lists every code", ru: "`aw explain` покажет все коды")
            )
            global.printer.emit(CommandResult<NoPayload>(issues: [issue])) { _ in "" }
            return 1
        }
        global.printer.emit(CommandResult(data: entry)) { entry in
            entry.map(IssueCatalog.render) ?? ""
        }
        return 0
    }
}

struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: L10n.pick(en: "Serve aw to AI agents over MCP (stdio).", ru: "Отдать aw агентам по MCP (stdio).")
    )

    @Option(help: ArgumentHelp(L10n.pick(
        en: "Workspace folder for tools that get none.",
        ru: "Папка workspace для инструментов, которым её не передали."
    )))
    var workspace: String?

    @Option(help: ArgumentHelp(L10n.pick(
        en: "Seconds a tool call may block before it answers with a job id for aw_wait; 0 means no limit. "
            + "Default: no limit for Claude Code, 45 for other clients.",
        ru: "Сколько секунд вызов может ждать, прежде чем ответить id задания для aw_wait; 0 — без лимита. "
            + "По умолчанию: без лимита для Claude Code, 45 для остальных."
    )))
    var callBudget: Double?

    func run() async throws {
        let folder = workspace.flatMap { $0.isEmpty ? nil : $0 }
        let directory = folder.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let budget = callBudget ?? ProcessInfo.processInfo.environment["AW_MCP_CALL_BUDGET"].flatMap(Double.init)
        try await AWMCPServer.run(MCPContext(directory: directory, callBudget: budget))
    }
}
