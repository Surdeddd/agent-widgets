import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct GalleryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gallery",
        abstract: L10n.pick(en: "Ready-made widgets that need no code.", ru: "Готовые виджеты, которым не нужен код."),
        subcommands: [GalleryListCommand.self, GalleryAddCommand.self],
        defaultSubcommand: GalleryListCommand.self
    )
}

struct GalleryListCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: L10n.pick(en: "List the ready-made widgets.", ru: "Показать готовые виджеты.")
    )

    @OptionGroup var global: GlobalOptions

    func execute() async throws -> Int32 {
        let items = Gallery(engine: try Engine.current()).list()
        global.printer.emit(CommandResult(data: items)) { list in
            let width = (list ?? []).map(\.id.count).max() ?? 0
            let rows = (list ?? []).map { item in
                let families = item.families.map(\.rawValue).joined(separator: ",")
                return "\(item.id.padding(toLength: width + 2, withPad: " ", startingAt: 0))\(item.summary.localized)  [\(families)]"
            }
            let next = L10n.pick(en: "install one: aw gallery add <id>", ru: "поставить: aw gallery add <id>")
            return (rows + ["", next]).joined(separator: "\n")
        }
        return 0
    }
}

struct GalleryAddCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: L10n.pick(en: "Copy a ready-made widget into this workspace.", ru: "Скопировать готовый виджет в это рабочее пространство.")
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Gallery widget id, for example ai-limits.", ru: "id виджета из галереи, например ai-limits.")))
    var id: String

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let gallery = Gallery(engine: try Engine.current())
        let created = try gallery.add(id, to: workspace)
        let hasFeed = gallery.list().first { $0.id == id }?.hasFeed == true
        global.printer.emit(CommandResult(artifacts: created, data: created)) { _ in
            let feed = hasFeed ? "aw feed run \(id) && " : ""
            return L10n.pick(
                en: "✓ widgets/\(id) from the gallery (\(created.count) files)\n  next: \(feed)aw ship \(id)",
                ru: "✓ widgets/\(id) из галереи (файлов: \(created.count))\n  дальше: \(feed)aw ship \(id)"
            )
        }
        return 0
    }
}
