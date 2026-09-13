import AWSchema
import Foundation

public struct Printer: Sendable {
    public let json: Bool

    public init(json: Bool) {
        self.json = json
    }

    public func render<Payload>(_ result: CommandResult<Payload>, human: (Payload?) -> String) -> String {
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            guard let data = try? encoder.encode(result), let text = String(bytes: data, encoding: .utf8) else {
                return #"{"ok":false,"issues":[{"code":"ENCODING","severity":"error","message":"output encoding failed"}]}"#
            }
            return text
        }
        let body = human(result.data)
        let lines = (body.isEmpty ? [] : [body]) + result.issues.map(Self.format)
        return lines.joined(separator: "\n")
    }

    public func emit<Payload>(_ result: CommandResult<Payload>, human: (Payload?) -> String) {
        let text = render(result, human: human)
        if !text.isEmpty {
            print(text)
        }
    }

    public static func format(_ issue: Issue) -> String {
        let mark: String
        switch issue.severity {
        case .error: mark = "✗"
        case .warning: mark = "!"
        case .info: mark = "·"
        }
        var line = "\(mark) \(issue.code)  \(issue.message)"
        if let file = issue.file {
            line += " (\(file)\(issue.line.map { ":\($0)" } ?? ""))"
        }
        if let hint = issue.hint {
            line += "\n    → \(hint)"
        }
        return line
    }
}
