import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct InitCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: L10n.pick(en: "Create a widgets workspace in a folder.", ru: "Создать workspace для виджетов в папке.")
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(
        en: "Folder for the workspace (default: current folder).",
        ru: "Папка для workspace (по умолчанию текущая)."
    )))
    var directory: String?

    @Option(help: ArgumentHelp(L10n.pick(en: "App name shown in the widget gallery.", ru: "Имя приложения в галерее виджетов.")))
    var name: String?

    @Option(help: ArgumentHelp(L10n.pick(en: "Short id used in bundle identifiers.", ru: "Короткий id для bundle id.")))
    var slug: String?

    @Option(
        name: .customLong("bundle-prefix"),
        help: ArgumentHelp(L10n.pick(en: "Reverse-DNS prefix, for example com.yourname.", ru: "Префикс reverse-DNS, например com.yourname."))
    )
    var bundlePrefix: String?

    @Flag(
        name: .customLong("refresh-signing"),
        help: ArgumentHelp(L10n.pick(
            en: "Detect the signing identity again for an existing workspace.",
            ru: "Заново найти подпись для существующего workspace."
        ))
    )
    var refreshSigning = false

    func execute() async throws -> Int32 {
        let path = (directory ?? FileManager.default.currentDirectoryPath) as NSString
        let target = URL(fileURLWithPath: path.expandingTildeInPath)
        let initializer = WorkspaceInitializer(engine: try Engine.current(), runner: SystemProcessRunner())
        let outcome = refreshSigning
            ? try await initializer.refreshSigning(at: target)
            : try await initializer.initialize(
                InitOptions(directory: target, name: name, slug: slug, bundlePrefix: bundlePrefix, locale: global.lang)
            )
        let result = CommandResult(issues: outcome.issues, artifacts: outcome.result.files, data: outcome.result)
        global.printer.emit(result) { data in
            guard let data else { return "" }
            let files = data.files.joined(separator: ", ")
            return L10n.pick(
                en: "✓ workspace ready: \(data.root)\n  files: \(files)\n  next: aw new my-widget --template metric",
                ru: "✓ workspace готов: \(data.root)\n  файлы: \(files)\n  дальше: aw new my-widget --template metric"
            )
        }
        return result.ok ? 0 : 1
    }
}
