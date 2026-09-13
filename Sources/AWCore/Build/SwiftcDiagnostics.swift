import AWSchema
import Foundation

public enum SwiftcDiagnostics {
    public static func parse(_ output: String, root: URL) -> [Issue] {
        let prefix = normalize(root.path) + "/"
        var issues: [Issue] = []
        var seen = Set<String>()
        for line in output.split(whereSeparator: \.isNewline) {
            guard let match = String(line).firstMatch(of: #/^(.+?):(\d+):(\d+): error: (.+)$/#) else {
                continue
            }
            let path = normalize(String(match.1))
            let relative = path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
            let message = String(match.4)
            guard seen.insert("\(relative):\(match.2):\(message)").inserted else {
                continue
            }
            issues.append(Issue(
                code: IssueCode.compileError,
                severity: .error,
                message: message,
                hint: L10n.pick(
                    en: "Fix the Swift error; kit API is in skills/agent-widgets/references/components.md",
                    ru: "Исправь ошибку Swift; API кита — в skills/agent-widgets/references/components.md"
                ),
                file: relative,
                line: Int(match.2)
            ))
        }
        return issues
    }

    static func normalize(_ path: String) -> String {
        path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
    }
}
