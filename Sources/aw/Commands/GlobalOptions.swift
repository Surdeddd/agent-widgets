import ArgumentParser
import AWCore
import AWSchema
import Foundation

extension Language: @retroactive ExpressibleByArgument {}

struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: ArgumentHelp(L10n.pick(en: "Print machine-readable JSON.", ru: "Вывод в JSON для машин.")))
    var json = false

    @Option(
        name: .long,
        help: ArgumentHelp(L10n.pick(
            en: "Workspace folder (default: search upward from the current folder).",
            ru: "Папка workspace (по умолчанию ищется вверх от текущей)."
        ))
    )
    var workspace: String?

    @Option(name: .long, help: ArgumentHelp(L10n.pick(en: "Output language: en or ru.", ru: "Язык вывода: en или ru.")))
    var lang: Language?

    var language: Language {
        lang ?? L10n.language
    }

    var printer: Printer {
        Printer(json: json)
    }

    func loadWorkspace() throws -> Workspace {
        let start = workspace.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return try Workspace.locate(from: start)
    }
}

enum Console {
    static func note(_ text: String) {
        FileHandle.standardError.write(Data("\(text)\n".utf8))
    }
}

protocol AWCommand: AsyncParsableCommand {
    var global: GlobalOptions { get }
    func execute() async throws -> Int32
}

extension AWCommand {
    func run() async throws {
        let options = global
        let code = await L10n.$language.withValue(options.language) {
            await Self.guarded(options) { try await execute() }
        }
        if code != 0 {
            throw ExitCode(code)
        }
    }

    static func guarded(_ options: GlobalOptions, _ body: () async throws -> Int32) async -> Int32 {
        do {
            return try await body()
        } catch let error as AWError {
            options.printer.emit(CommandResult<NoPayload>(issues: [error.issue])) { _ in "" }
            return 3
        } catch {
            let issue = Issue(code: "UNEXPECTED", severity: .error, message: String(describing: error))
            options.printer.emit(CommandResult<NoPayload>(issues: [issue])) { _ in "" }
            return 1
        }
    }
}
