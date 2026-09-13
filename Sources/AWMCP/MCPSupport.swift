import AWCore
import AWSchema
import Foundation
import MCP

public struct MCPContext: Sendable {
    public var engine: @Sendable () throws -> Engine
    public var runner: any ProcessRunning
    public var directory: URL

    public init(
        engine: @escaping @Sendable () throws -> Engine = { try Engine.current() },
        runner: any ProcessRunning = SystemProcessRunner(),
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    ) {
        self.engine = engine
        self.runner = runner
        self.directory = directory
    }

    func workspace(_ arguments: Arguments) throws -> Workspace {
        let start = arguments.string("workspace").map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) } ?? directory
        return try Workspace.locate(from: start)
    }

    func pipeline(_ workspace: Workspace) throws -> PreviewPipeline {
        PreviewPipeline(workspace: workspace, cache: KitCache(engine: try engine(), runner: runner), runner: runner)
    }
}

struct Arguments: Sendable {
    let values: [String: Value]

    init(_ values: [String: Value]) {
        self.values = values
    }

    func string(_ key: String) -> String? {
        guard let value = values[key]?.stringValue, !value.isEmpty else { return nil }
        return value
    }

    func bool(_ key: String, default fallback: Bool) -> Bool {
        values[key]?.boolValue ?? fallback
    }

    func number(_ key: String) -> Double? {
        values[key]?.doubleValue ?? values[key]?.intValue.map(Double.init)
    }

    func list(_ key: String) -> [String]? {
        if let array = values[key]?.arrayValue {
            return array.compactMap(\.stringValue)
        }
        return string(key)?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    func required(_ key: String) throws -> String {
        guard let value = string(key) else {
            throw AWError.invalidJSON(file: "arguments", reason: "missing \"\(key)\"")
        }
        return value
    }
}

enum Schema {
    static func object(_ properties: [String: Value], required: [String] = []) -> Value {
        var all = properties
        all["workspace"] = string("Path to the workspace folder (the one with aw.json). Defaults to the server's working directory.")
        return .object([
            "type": .string("object"),
            "properties": .object(all),
            "required": .array(required.map(Value.string))
        ])
    }

    static func string(_ description: String) -> Value {
        .object(["type": .string("string"), "description": .string(description)])
    }

    static func boolean(_ description: String) -> Value {
        .object(["type": .string("boolean"), "description": .string(description)])
    }

    static func number(_ description: String) -> Value {
        .object(["type": .string("number"), "description": .string(description)])
    }

    static func strings(_ description: String) -> Value {
        .object(["type": .string("array"), "items": .object(["type": .string("string")]), "description": .string(description)])
    }
}

struct AWTool: Sendable {
    let tool: Tool
    let run: @Sendable (Arguments, MCPContext) async throws -> CallTool.Result

    init(
        _ name: String,
        _ description: String,
        schema: Value,
        readOnly: Bool = false,
        run: @escaping @Sendable (Arguments, MCPContext) async throws -> CallTool.Result
    ) {
        tool = Tool(name: name, description: description, inputSchema: schema, annotations: .init(readOnlyHint: readOnly))
        self.run = run
    }

    func call(_ arguments: Arguments, _ context: MCPContext) async -> CallTool.Result {
        do {
            return try await run(arguments, context)
        } catch let error as AWError {
            return Reply.failure([error.issue])
        } catch {
            return Reply.failure([Issue(code: "UNEXPECTED", severity: .error, message: String(describing: error))])
        }
    }
}

enum Reply {
    static func make<Payload: Codable>(_ summary: String, issues: [Issue] = [], payload: Payload, images: [String] = []) -> CallTool.Result {
        let text = ([summary] + issues.deduplicated().map(Printer.format)).filter { !$0.isEmpty }.joined(separator: "\n")
        let content = [Tool.Content.text(text: text, annotations: nil, _meta: nil)] + images.compactMap(image)
        return (try? CallTool.Result(content: content, structuredContent: payload, isError: false)) ?? CallTool.Result(content: content, isError: false)
    }

    static func failure(_ issues: [Issue]) -> CallTool.Result {
        CallTool.Result(content: [.text(text: issues.map(Printer.format).joined(separator: "\n"), annotations: nil, _meta: nil)], isError: true)
    }

    static func image(_ path: String) -> Tool.Content? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return .image(data: data.base64EncodedString(), mimeType: "image/png", annotations: nil, _meta: nil)
    }
}
