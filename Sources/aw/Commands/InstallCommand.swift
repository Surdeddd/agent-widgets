import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct InstallCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: L10n.pick(
            en: "Build the widget app and install it, keeping a backup of the previous one.",
            ru: "Собрать приложение с виджетами и установить, сохранив бэкап прошлого."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Flag(help: ArgumentHelp(L10n.pick(
        en: "Also restart chronod, the system process that draws widgets.",
        ru: "Ещё перезапустить chronod — системный процесс, который рисует виджеты."
    )))
    var hard = false

    @Flag(
        name: .customLong("skip-build"),
        help: ArgumentHelp(L10n.pick(en: "Install the last build without rebuilding.", ru: "Поставить последнюю сборку без пересборки."))
    )
    var skipBuild = false

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let runner = SystemProcessRunner()
        let builder = Builder(workspace: workspace, engine: try Engine.current(), runner: runner)
        var issues: [Issue] = []
        var app = builder.productPath()
        if !skipBuild {
            Console.note(L10n.pick(en: "building…", ru: "сборка…"))
            let build = try await builder.build()
            issues += build.issues
            guard let path = build.app else {
                global.printer.emit(CommandResult(issues: issues, artifacts: [build.log], data: build)) { _ in "" }
                return 4
            }
            app = URL(fileURLWithPath: path)
        }
        let installer = Installer(config: workspace.config, runner: runner, paths: .standard(for: workspace.config))
        let outcome = try await installer.install(app, hard: hard)
        let artifacts = [outcome.app] + [outcome.backup].compactMap { $0 }
        global.printer.emit(CommandResult(issues: issues + outcome.issues, artifacts: artifacts, data: outcome)) { outcome in
            outcome.map(Self.summary) ?? ""
        }
        return outcome.hasErrors ? 3 : 0
    }

    static func summary(_ outcome: InstallOutcome) -> String {
        let seconds = String(format: "%.1f", outcome.seconds)
        let mark = outcome.hasErrors ? "✗" : "✓"
        var lines = [L10n.pick(en: "\(mark) installed \(outcome.app) in \(seconds) s", ru: "\(mark) установлено \(outcome.app) за \(seconds) с")]
        if let backup = outcome.backup {
            lines.append(L10n.pick(en: "  backup: \(backup)", ru: "  бэкап: \(backup)"))
        }
        for path in outcome.retired {
            lines.append(L10n.pick(en: "  old copy moved to backups: \(path)", ru: "  старая копия убрана в бэкапы: \(path)"))
        }
        return lines.joined(separator: "\n")
    }
}

struct RollbackCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "rollback",
        abstract: L10n.pick(
            en: "Swap the installed app with its latest backup.",
            ru: "Поменять установленное приложение местами с последним бэкапом."
        )
    )

    @OptionGroup var global: GlobalOptions

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let installer = Installer(config: workspace.config, runner: SystemProcessRunner(), paths: .standard(for: workspace.config))
        let outcome = try await installer.rollback()
        global.printer.emit(CommandResult(issues: outcome.issues, artifacts: [outcome.app], data: outcome)) { outcome in
            outcome.map(InstallCommand.summary) ?? ""
        }
        return outcome.hasErrors ? 3 : 0
    }
}
