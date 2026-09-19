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
        subcommands: [
            InitCommand.self,
            GalleryCommand.self,
            NewCommand.self,
            PreviewCommand.self,
            ShipCommand.self,
            BuildCommand.self,
            InstallCommand.self,
            DevCommand.self,
            ShotCommand.self,
            SlotCommand.self,
            GeometryCommand.self,
            RollbackCommand.self,
            FeedCommand.self,
            DataCommand.self,
            TickCommand.self,
            DaemonCommand.self,
            LogsCommand.self,
            ExplainCommand.self,
            MCPCommand.self,
            SkillCommand.self,
            ListCommand.self,
            TemplatesCommand.self,
            DoctorCommand.self
        ]
    )
}
