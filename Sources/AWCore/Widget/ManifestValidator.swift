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
            if let owner = owners[kind] {
                issues.append(
                    Issue(
                        code: IssueCode.duplicateKind,
                        severity: .error,
                        message: "Widgets \"\(owner)\" and \"\(manifest.id)\" share the kind \"\(kind)\"",
                        hint: "Give each widget its own \"kind\" or drop the field to use aw.<id>",
                        file: file(for: manifest)
                    )
                )
            } else {
                owners[kind] = manifest.id
            }
        }
        return issues
    }

    public static func validate(_ manifest: WidgetManifest) -> [Issue] {
        var issues: [Issue] = []
        if !matches(manifest.id, "^[a-z][a-z0-9-]{0,39}$") {
            issues.append(invalid(
                manifest,
                "Widget id \"\(manifest.id)\" is invalid",
                hint: "Use lowercase letters, digits and dashes, starting with a letter, up to 40 characters"
            ))
        }
        if !matches(manifest.view, "^[A-Z][A-Za-z0-9_]*$") {
            issues.append(invalid(
                manifest,
                "View \"\(manifest.view)\" of \(manifest.id) is not a Swift type name",
                hint: "Set \"view\" to the struct that conforms to AWView, for example \"WeatherView\""
            ))
        }
        if manifest.families.isEmpty {
            issues.append(invalid(
                manifest,
                "Widget \(manifest.id) declares no families",
                hint: "Add at least one of small, medium, large, extraLarge"
            ))
        } else if Set(manifest.families).count != manifest.families.count {
            issues.append(invalid(manifest, "Widget \(manifest.id) lists a family twice", hint: "Remove duplicates from \"families\""))
        }
        if let feed = manifest.feed {
            issues += validate(feed, of: manifest)
        }
        return issues
    }

    private static func validate(_ feed: FeedSpec, of manifest: WidgetManifest) -> [Issue] {
        var issues: [Issue] = []
        if feed.command.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(invalid(
                manifest,
                "Feed command of \(manifest.id) is empty",
                hint: "Set \"command\", for example \"python3 feed.py\""
            ))
        }
        if feed.every.seconds < minimumFeedSeconds {
            issues.append(invalid(
                manifest,
                "Feed of \(manifest.id) runs every \(feed.every.compact), the minimum is 1m",
                hint: "Use 15m or longer; show live seconds with Text(date, style: .timer) instead of reloads"
            ))
        } else if feed.every.seconds < budgetFriendlySeconds {
            let cadence = "Feed of \(manifest.id) runs every \(feed.every.compact)"
            issues.append(
                Issue(
                    code: IssueCode.budgetRisk,
                    severity: .warning,
                    message: "\(cadence); WidgetKit grants about 40–70 reloads a day",
                    hint: "aw reloads only when data changes, but prefer 15m+ and timeline entries for time-based content",
                    file: file(for: manifest)
                )
            )
        }
        return issues
    }

    private static func invalid(_ manifest: WidgetManifest, _ message: String, hint: String) -> Issue {
        Issue(code: IssueCode.manifestInvalid, severity: .error, message: message, hint: hint, file: file(for: manifest))
    }

    private static func file(for manifest: WidgetManifest) -> String {
        "widgets/\(manifest.id)/widget.json"
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
