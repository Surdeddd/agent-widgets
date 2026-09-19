import AWSchema
import Foundation

public enum AWError: Error, Equatable, Sendable {
    case workspaceNotFound(String)
    case workspaceExists(String)
    case engineNotFound
    case invalidJSON(file: String, reason: String)
    case widgetNotFound(String)
    case widgetIdInvalid(String)
    case widgetExists(String)
    case templateUnknown(String, [String])
    case galleryUnknown(String, [String])
    case toolFailed(tool: String, status: Int32, output: String)
    case installFailed(String)
    case scenarioNotFound(widget: String, scenario: String, available: [String])

    public var issue: Issue {
        switch self {
        case .installFailed(let reason):
            Issue(
                code: IssueCode.installFailed,
                severity: .error,
                message: reason,
                hint: L10n.pick(en: "Run `aw doctor` to check the setup", ru: "Проверь окружение: `aw doctor`")
            )
        case .scenarioNotFound(let widget, let scenario, let available):
            Issue(
                code: IssueCode.scenarioNotFound,
                severity: .error,
                message: L10n.pick(en: "Widget \(widget) has no samples/\(scenario).json", ru: "У виджета \(widget) нет samples/\(scenario).json"),
                hint: L10n.pick(en: "Available: \(available.joined(separator: ", "))", ru: "Есть: \(available.joined(separator: ", "))")
            )
        case .widgetExists(let id):
            Issue(
                code: IssueCode.widgetExists,
                severity: .error,
                message: L10n.pick(en: "Widget \"\(id)\" already exists", ru: "Виджет \"\(id)\" уже есть"),
                hint: L10n.pick(en: "Pick another id or edit widgets/\(id)", ru: "Выбери другой id или правь widgets/\(id)")
            )
        case .templateUnknown(let name, let available):
            Issue(
                code: IssueCode.templateUnknown,
                severity: .error,
                message: L10n.pick(en: "Unknown template \"\(name)\"", ru: "Нет шаблона \"\(name)\""),
                hint: L10n.pick(en: "Available: \(available.joined(separator: ", "))", ru: "Есть: \(available.joined(separator: ", "))")
            )
        case .galleryUnknown(let name, let available):
            Issue(
                code: IssueCode.galleryUnknown,
                severity: .error,
                message: L10n.pick(en: "No gallery widget \"\(name)\"", ru: "В галерее нет виджета \"\(name)\""),
                hint: L10n.pick(en: "Available: \(available.joined(separator: ", "))", ru: "Есть: \(available.joined(separator: ", "))")
            )
        case .workspaceNotFound(let path):
            Issue(
                code: IssueCode.workspaceNotFound,
                severity: .error,
                message: L10n.pick(en: "No aw.json found in \(path) or its parents", ru: "В \(path) и выше нет aw.json"),
                hint: L10n.pick(
                    en: "Run `aw init` in the folder that should hold your widgets, or pass --workspace",
                    ru: "Запусти `aw init` в папке для виджетов или передай --workspace"
                )
            )
        case .workspaceExists(let path):
            Issue(
                code: IssueCode.workspaceExists,
                severity: .error,
                message: L10n.pick(en: "\(path) is already an agent-widgets workspace", ru: "\(path) уже workspace agent-widgets"),
                hint: L10n.pick(en: "Add widgets with `aw new <id>`", ru: "Добавляй виджеты через `aw new <id>`")
            )
        case .engineNotFound:
            Issue(
                code: IssueCode.engineNotFound,
                severity: .error,
                message: L10n.pick(
                    en: "Engine resources (Templates, Kit) were not found next to the aw binary",
                    ru: "Рядом с бинарём aw не найдены ресурсы движка (Templates, Kit)"
                ),
                hint: L10n.pick(
                    en: "Reinstall with `make install` or set AW_HOME to the agent-widgets checkout",
                    ru: "Переустанови через `make install` или укажи AW_HOME на папку agent-widgets"
                )
            )
        case .invalidJSON(let file, let reason):
            Issue(
                code: IssueCode.invalidJSON,
                severity: .error,
                message: "\(file): \(reason)",
                hint: L10n.pick(
                    en: "Fix the JSON; `aw explain INVALID_JSON` shows the expected shape",
                    ru: "Исправь JSON; `aw explain INVALID_JSON` покажет нужную форму"
                ),
                file: file
            )
        case .widgetNotFound(let id):
            Issue(
                code: IssueCode.widgetNotFound,
                severity: .error,
                message: L10n.pick(en: "Widget \"\(id)\" is not in this workspace", ru: "Виджета \"\(id)\" нет в этом workspace"),
                hint: L10n.pick(
                    en: "Run `aw list` to see widget ids or `aw new \(id)` to create it",
                    ru: "`aw list` покажет id виджетов, `aw new \(id)` создаст новый"
                )
            )
        case .widgetIdInvalid(let id):
            Issue(
                code: IssueCode.widgetIdInvalid,
                severity: .error,
                message: L10n.pick(en: "Widget id \"\(id)\" is not valid", ru: "Недопустимый id виджета «\(id)»"),
                hint: L10n.pick(
                    en: "Use lowercase letters, digits and dashes, starting with a letter, for example `bangkok-weather`",
                    ru: "Строчные буквы, цифры и дефис, первой — буква, например `bangkok-weather`"
                )
            )
        case .toolFailed(let tool, let status, let output):
            Issue(
                code: IssueCode.toolMissing,
                severity: .error,
                message: L10n.pick(
                    en: "\(tool) exited with \(status): \(output.prefix(400))",
                    ru: "\(tool) завершился с кодом \(status): \(output.prefix(400))"
                ),
                hint: L10n.pick(en: "Run `aw doctor` to check the toolchain", ru: "Проверь тулчейн: `aw doctor`")
            )
        }
    }
}
