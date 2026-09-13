import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct SkillCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: L10n.pick(en: "Install the agent-widgets skill for coding agents.", ru: "Поставить скилл agent-widgets для агентов."),
        subcommands: [SkillInstallCommand.self]
    )
}

struct SkillInstallCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: L10n.pick(
            en: "Link the skill into ~/.claude/skills, ~/.codex/skills and ~/.agents/skills when they exist.",
            ru: "Прилинковать скилл в ~/.claude/skills, ~/.codex/skills и ~/.agents/skills, если они есть."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Option(help: ArgumentHelp(L10n.pick(en: "claude, codex, agents or all.", ru: "claude, codex, agents или all.")))
    var target = "all"

    func execute() async throws -> Int32 {
        let source = try Engine.current().skills.appendingPathComponent("agent-widgets", isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.appendingPathComponent("SKILL.md").path) else {
            throw AWError.engineNotFound
        }
        let agents = target == "all" ? SkillInstaller.folders.map(\.0) : target.split(separator: ",").map(String.init)
        let links = try SkillInstaller(source: source).install(agents)
        let issues = links.filter { $0.state == .occupied }.map { link in
            Issue(
                code: IssueCode.keptExisting,
                severity: .warning,
                message: L10n.pick(en: "\(link.path) already exists and was left alone", ru: "\(link.path) уже есть, не трогаю"),
                hint: L10n.pick(en: "Remove it yourself to link this engine's skill", ru: "Убери его сам, чтобы прилинковать скилл этого движка")
            )
        }
        global.printer.emit(CommandResult(issues: issues, artifacts: links.map(\.path), data: links)) { links in
            (links ?? []).map { link in
                switch link.state {
                case .linked: "✓ \(link.agent): \(link.path)"
                case .alreadyLinked: L10n.pick(en: "· \(link.agent): already linked", ru: "· \(link.agent): уже прилинкован")
                case .occupied: L10n.pick(en: "! \(link.agent): occupied", ru: "! \(link.agent): занято")
                case .noSkillsFolder: L10n.pick(en: "· \(link.agent): no skills folder, skipped", ru: "· \(link.agent): нет папки skills, пропускаю")
                }
            }
            .joined(separator: "\n")
        }
        return 0
    }
}
