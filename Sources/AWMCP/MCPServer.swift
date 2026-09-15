import AWCore
import Foundation
import MCP

public enum AWMCPServer {
    static let instructions = """
    agent-widgets builds native macOS desktop widgets (WidgetKit + SwiftUI). \
    Loop: aw_templates → aw_new → edit widgets/<id>/*.swift and samples/*.json → aw_preview until the report has no errors \
    and the sheet image looks right → aw_ship to install and capture the real widget. \
    Long calls (aw_ship, aw_dev, aw_slot, aw_feed_run) may answer with a job id before they finish: call aw_wait with it. \
    aw_explain explains any issue code; aw_doctor checks the environment. \
    Every tool takes an optional workspace path (the folder with aw.json).
    """

    public static func make(_ context: MCPContext = MCPContext()) async -> Server {
        let server = Server(
            name: AWMCPInfo.serverName,
            version: AWMCPInfo.serverVersion,
            instructions: instructions,
            capabilities: .init(tools: .init(listChanged: false))
        )
        let tools = AWTools.all
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: tools.map(\.tool))
        }
        await server.withMethodHandler(CallTool.self) { [weak server] params in
            guard let tool = tools.first(where: { $0.tool.name == params.name }) else {
                return .init(content: [.text(text: "Unknown tool \(params.name)", annotations: nil, _meta: nil)], isError: true)
            }
            let notifier = server
            let progress = ProgressReporter(token: params._meta?.progressToken) { parameters in
                try? await notifier?.notify(ProgressNotification.message(parameters))
            }
            let budget = await context.budget()
            return try await tool.call(Arguments(params.arguments ?? [:]), context, progress: progress, budget: budget)
        }
        return server
    }

    public static func run(_ context: MCPContext = MCPContext()) async throws {
        let server = await make(context)
        try await server.start(transport: StdioTransport()) { client, _ in
            await context.client.set(client.name)
            FileHandle.standardError.write(Data("aw mcp: client \(client.name) \(client.version)\n".utf8))
        }
        await server.waitUntilCompleted()
    }
}
