import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct NewCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: L10n.pick(en: "Create a widget from a template.", ru: "Создать виджет из шаблона.")
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Widget id, for example weather.", ru: "id виджета, например weather.")))
    var id: String

    @Option(help: ArgumentHelp(L10n.pick(en: "Template id (see `aw templates`).", ru: "Шаблон (список — `aw templates`).")))
    var template = "metric"

    @Option(help: ArgumentHelp(L10n.pick(en: "Display name in English.", ru: "Имя в галерее по-английски.")))
    var name: String?

    @Option(name: .customLong("name-ru"), help: ArgumentHelp(L10n.pick(en: "Display name in Russian.", ru: "Имя в галерее по-русски.")))
    var nameRu: String?

    @Option(help: ArgumentHelp(L10n.pick(en: "Families, comma separated: small,medium,large,extraLarge.", ru: "Размеры через запятую.")))
    var families: String?

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let catalog = TemplateCatalog(engine: try Engine.current())
        let title = name.map { LocalizedText(en: $0, ru: nameRu) }
        let parsed = families.map { $0.split(separator: ",").compactMap { Family(rawValue: String($0)) } }
        let created = try catalog.instantiate(template, id: id, name: title, families: parsed, in: workspace)
        let result = CommandResult(artifacts: created, data: created)
        global.printer.emit(result) { _ in
            L10n.pick(
                en: "✓ widgets/\(id) from \"\(template)\" (\(created.count) files)\n  next: aw preview \(id)",
                ru: "✓ widgets/\(id) из шаблона \"\(template)\" (\(created.count) файлов)\n  дальше: aw preview \(id)"
            )
        }
        return 0
    }
}

struct TemplatesCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "templates",
        abstract: L10n.pick(en: "List widget templates.", ru: "Показать шаблоны виджетов.")
    )

    @OptionGroup var global: GlobalOptions

    func execute() async throws -> Int32 {
        let templates = TemplateCatalog(engine: try Engine.current()).list()
        global.printer.emit(CommandResult(data: templates)) { list in
            let width = (list ?? []).map(\.id.count).max() ?? 0
            return (list ?? []).map { template in
                let families = template.families.map(\.rawValue).joined(separator: ",")
                return "\(template.id.padding(toLength: width + 2, withPad: " ", startingAt: 0))\(template.summary.localized)  [\(families)]"
            }
            .joined(separator: "\n")
        }
        return 0
    }
}
