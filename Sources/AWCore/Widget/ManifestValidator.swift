import AWSchema
import Foundation

public enum ManifestValidator {
    public static let minimumFeedSeconds = 60
    public static let budgetFriendlySeconds = 900

    public static func validate(_ manifests: [WidgetManifest]) -> [Issue] {
        var issues = manifests.flatMap(validate(_:))
        var owners: [String: String] = [:]
        for manifest in manifests {
            let kind = manifest.resolvedKind
            guard let owner = owners[kind] else {
                owners[kind] = manifest.id
                continue
            }
            issues.append(Issue(
                code: IssueCode.duplicateKind,
                severity: .error,
                message: L10n.pick(
                    en: "Widgets \"\(owner)\" and \"\(manifest.id)\" share the kind \"\(kind)\"",
                    ru: "У виджетов \"\(owner)\" и \"\(manifest.id)\" одинаковый kind \"\(kind)\""
                ),
                hint: L10n.pick(
                    en: "Give each widget its own \"kind\" or drop the field to use aw.<id>",
                    ru: "Задай каждому свой \"kind\" или убери поле — будет aw.<id>"
                ),
                file: file(for: manifest)
            ))
        }
        return issues
    }

    public static func validate(_ manifest: WidgetManifest) -> [Issue] {
        let id = manifest.id
        var issues: [Issue] = []
        if !matches(id, "^[a-z][a-z0-9-]{0,39}$") {
            issues.append(invalid(
                manifest,
                en: "Widget id \"\(id)\" is invalid",
                ru: "Некорректный id виджета \"\(id)\"",
                hintEn: "Use lowercase letters, digits and dashes, starting with a letter, up to 40 characters",
                hintRu: "Строчные латинские буквы, цифры и дефис, начинается с буквы, до 40 символов"
            ))
        }
        if !matches(manifest.view, "^[A-Z][A-Za-z0-9_]*$") {
            issues.append(invalid(
                manifest,
                en: "View \"\(manifest.view)\" of \(id) is not a Swift type name",
                ru: "View \"\(manifest.view)\" у \(id) — не имя Swift-типа",
                hintEn: "Set \"view\" to the struct that conforms to AWView, for example \"WeatherView\"",
                hintRu: "Укажи в \"view\" структуру, реализующую AWView, например \"WeatherView\""
            ))
        }
        if manifest.families.isEmpty {
            issues.append(invalid(
                manifest,
                en: "Widget \(id) declares no families",
                ru: "У виджета \(id) не указаны размеры (families)",
                hintEn: "Add at least one of small, medium, large, extraLarge",
                hintRu: "Добавь хотя бы один из small, medium, large, extraLarge"
            ))
        } else if Set(manifest.families).count != manifest.families.count {
            issues.append(invalid(
                manifest,
                en: "Widget \(id) lists a family twice",
                ru: "У виджета \(id) размер указан дважды",
                hintEn: "Remove duplicates from \"families\"",
                hintRu: "Убери повторы из \"families\""
            ))
        }
        if let feed = manifest.feed {
            issues += validate(feed, of: manifest)
        }
        return issues
    }

    private static func validate(_ feed: FeedSpec, of manifest: WidgetManifest) -> [Issue] {
        let id = manifest.id
        let every = feed.every.compact
        var issues: [Issue] = []
        if feed.command.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(invalid(
                manifest,
                en: "Feed command of \(id) is empty",
                ru: "У feed виджета \(id) пустая команда",
                hintEn: "Set \"command\", for example \"python3 feed.py\"",
                hintRu: "Укажи \"command\", например \"python3 feed.py\""
            ))
        }
        if feed.every.seconds < minimumFeedSeconds {
            issues.append(invalid(
                manifest,
                en: "Feed of \(id) runs every \(every), the minimum is 1m",
                ru: "Feed виджета \(id) запускается каждые \(every), минимум — 1m",
                hintEn: "Use 15m or longer; show live seconds with Text(date, style: .timer) instead of reloads",
                hintRu: "Ставь 15m и реже; живые секунды — через Text(date, style: .timer), без перезагрузок"
            ))
        } else if feed.every.seconds < budgetFriendlySeconds {
            issues.append(Issue(
                code: IssueCode.budgetRisk,
                severity: .warning,
                message: L10n.pick(
                    en: "Feed of \(id) runs every \(every); WidgetKit grants about 40–70 reloads a day",
                    ru: "Feed виджета \(id) запускается каждые \(every); WidgetKit даёт примерно 40–70 перезагрузок в сутки"
                ),
                hint: L10n.pick(
                    en: "aw reloads only when data changes, but prefer 15m+ and timeline entries for time-based content",
                    ru: "aw перезагружает только при изменении данных, но лучше 15m+ и timeline entries для всего, что зависит от времени"
                ),
                file: file(for: manifest)
            ))
        }
        return issues
    }

    private static func invalid(_ manifest: WidgetManifest, en: String, ru: String, hintEn: String, hintRu: String) -> Issue {
        Issue(
            code: IssueCode.manifestInvalid,
            severity: .error,
            message: L10n.pick(en: en, ru: ru),
            hint: L10n.pick(en: hintEn, ru: hintRu),
            file: file(for: manifest)
        )
    }

    private static func file(for manifest: WidgetManifest) -> String {
        "widgets/\(manifest.id)/widget.json"
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
