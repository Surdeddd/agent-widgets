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
                message: "No aw.json found in \(path) or its parents",
                hint: "Run `aw init` in the folder that should hold your widgets, or pass --workspace"
            )
        case .workspaceExists(let path):
            Issue(
                code: IssueCode.workspaceExists,
                severity: .error,
                message: "\(path) is already an agent-widgets workspace",
                hint: "Use `aw new <id>` to add widgets to it"
            )
        case .engineNotFound:
            Issue(
                code: IssueCode.engineNotFound,
                severity: .error,
                message: "Engine resources (Templates, Kit) were not found next to the aw binary",
                hint: "Reinstall with `make install` or set AW_HOME to the agent-widgets checkout"
            )
        case .invalidJSON(let file, let reason):
            Issue(
                code: IssueCode.invalidJSON,
                severity: .error,
                message: "\(file): \(reason)",
                hint: "Fix the JSON; `aw explain INVALID_JSON` shows the expected shape",
                file: file
            )
        case .widgetNotFound(let id):
            Issue(
                code: IssueCode.widgetNotFound,
                severity: .error,
                message: "Widget \"\(id)\" is not in this workspace",
                hint: "Run `aw list` to see widget ids or `aw new \(id)` to create it"
            )
        case .toolFailed(let tool, let status, let output):
            Issue(
                code: IssueCode.toolMissing,
                severity: .error,
                message: "\(tool) exited with \(status): \(output.prefix(400))",
                hint: "Run `aw doctor` to check the toolchain"
            )
        }
    }
}

public enum DecodingErrorFormatter {
    public static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decoding {
        case .keyNotFound(let key, let context):
            return "missing key \"\(path(context.codingPath + [key]))\""
        case .typeMismatch(let type, let context):
            return "wrong type at \"\(path(context.codingPath))\", expected \(type)"
        case .valueNotFound(let type, let context):
            return "null at \"\(path(context.codingPath))\", expected \(type)"
        case .dataCorrupted(let context):
            let location = context.codingPath.isEmpty ? "" : " at \"\(path(context.codingPath))\""
            return "\(context.debugDescription)\(location)"
        @unknown default:
            return String(describing: decoding)
        }
    }

    private static func path(_ keys: [CodingKey]) -> String {
        keys.map { key in key.intValue.map { "[\($0)]" } ?? key.stringValue }
            .joined(separator: ".")
            .replacingOccurrences(of: ".[", with: "[")
    }
}
