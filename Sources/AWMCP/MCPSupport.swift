import AWCore
import AWSchema
import Foundation
import MCP

public struct MCPContext: Sendable {
    public var engine: @Sendable () throws -> Engine
    public var runner: any ProcessRunning
    public var directory: URL
    public var callBudget: TimeInterval?
    let jobs = JobCenter()
    let client = ClientProfile()

    public init(
        engine: @escaping @Sendable () throws -> Engine = { try Engine.current() },
        runner: any ProcessRunning = SystemProcessRunner(),
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        callBudget: TimeInterval? = nil
    ) {
        self.engine = engine
        self.runner = runner
        self.directory = directory
        self.callBudget = callBudget
    }

    func workspace(_ arguments: Arguments) throws -> Workspace {
        let start = arguments.string("workspace").map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) } ?? directory
        return try Workspace.locate(from: start)
    }

    func pipeline(_ workspace: Workspace) throws -> PreviewPipeline {
        PreviewPipeline(workspace: workspace, cache: KitCache(engine: try engine(), runner: runner), runner: runner)
    }

    /// Seconds one call may block: `callBudget` when set (0 means no limit), none for Claude Code, 45 for other clients.
    func budget() async -> TimeInterval? {
        if let callBudget {
            return callBudget > 0 ? callBudget : nil
        }
        return await client.name == "claude-code" ? nil : 45
    }
}

struct CallEnvironment: Sendable {
    let context: MCPContext
    let progress: ProgressReporter
    let budget: TimeInterval?

    var runner: any ProcessRunning {
        context.runner
    }

    func workspace(_ arguments: Arguments) throws -> Workspace {
        try context.workspace(arguments)
    }

    func engine() throws -> Engine {
        try context.engine()
    }

    func pipeline(_ workspace: Workspace) throws -> PreviewPipeline {
        try context.pipeline(workspace)
    }

    func report(_ message: String) async {
        await progress.report(message, elapsed: 0)
    }

    /// Runs `work` as a job, joining an identical one that is still running, and answers within the budget.
    func job(
        _ tool: String,
        key: String,
        stage: String,
        work: @escaping @Sendable (JobStage) async throws -> CallTool.Result
    ) async throws -> CallTool.Result {
        let id = await context.jobs.start(tool: tool, key: key, stage: stage, work: work)
        return try await context.jobs.follow(id, window: budget, progress: progress)
    }

    func follow(_ id: String, limit: TimeInterval?) async throws -> CallTool.Result {
        let window = [budget, limit].compactMap { $0 }.min()
        return try await context.jobs.follow(id, window: window, progress: progress)
    }
}

struct Arguments: Sendable {
    let values: [String: Value]

    init(_ values: [String: Value]) {
        self.values = values
    }

    var fingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(values)).flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
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
    static func object(_ properties: [String: Value], required: [String] = [], workspace: Bool = true) -> Value {
        var all = properties
        if workspace {
            all["workspace"] = string("Path to the workspace folder (the one with aw.json). Defaults to the server's working directory.")
        }
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
    let run: @Sendable (Arguments, CallEnvironment) async throws -> CallTool.Result

    init(
        _ name: String,
        _ description: String,
        schema: Value,
        readOnly: Bool = false,
        run: @escaping @Sendable (Arguments, CallEnvironment) async throws -> CallTool.Result
    ) {
        tool = Tool(name: name, description: description, inputSchema: schema, annotations: .init(readOnlyHint: readOnly))
        self.run = run
    }

    func call(
        _ arguments: Arguments,
        _ context: MCPContext,
        progress: ProgressReporter = .silent,
        budget: TimeInterval? = nil
    ) async throws -> CallTool.Result {
        let environment = CallEnvironment(context: context, progress: progress, budget: budget)
        do {
            let result = try await run(arguments, environment)
            try Task.checkCancellation()
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AWError {
            try Task.checkCancellation()
            return Reply.failure([error.issue])
        } catch {
            try Task.checkCancellation()
            return Reply.failure([Issue(code: "UNEXPECTED", severity: .error, message: String(describing: error))])
        }
    }
}

enum Reply {
    static func make<Payload: Codable>(_ summary: String, issues: [Issue] = [], payload: Payload, images: [String] = []) -> CallTool.Result {
        let text = ([summary] + issues.deduplicated().map(Printer.format)).filter { !$0.isEmpty }.joined(separator: "\n")
        let content = [Tool.Content.text(text: text, annotations: nil, _meta: nil)] + images.compactMap(image)
        let isError = issues.contains { $0.severity == .error }
        return (try? CallTool.Result(content: content, structuredContent: payload, isError: isError))
            ?? CallTool.Result(content: content, isError: isError)
    }

    static func failure(_ issues: [Issue]) -> CallTool.Result {
        CallTool.Result(content: [.text(text: issues.map(Printer.format).joined(separator: "\n"), annotations: nil, _meta: nil)], isError: true)
    }

    static func image(_ path: String) -> Tool.Content? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return .image(data: data.base64EncodedString(), mimeType: "image/png", annotations: nil, _meta: nil)
    }
}
