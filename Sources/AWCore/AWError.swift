import AWSchema
import Foundation

public enum AWError: Error, Equatable, Sendable {
    case workspaceNotFound(String)
    case workspaceExists(String)
    case engineNotFound
    case invalidJSON(file: String, reason: String)
    case widgetNotFound(String)
    case toolFailed(tool: String, status: Int32, output: String)

    public var issue: Issue {
        switch self {
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
