import ArgumentParser
import AWCore

@main
struct AgentWidgets: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aw",
        abstract: "Build native macOS widgets with AI agents.",
        version: EngineVersion.current
    )
}
