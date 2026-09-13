import ArgumentParser
import AWCore
import AWSchema

@main
struct AgentWidgets: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aw",
        abstract: L10n.pick(
            en: "Build native macOS widgets with AI agents.",
            ru: "Нативные виджеты macOS руками AI-агентов."
        ),
        version: EngineVersion.current,
        subcommands: [DoctorCommand.self]
    )
}
