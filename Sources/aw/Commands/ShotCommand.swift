import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct ShotCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "shot",
        abstract: L10n.pick(en: "Capture the real widget windows on the desktop.", ru: "Снять реальные окна виджетов со стола.")
    )

    @OptionGroup var global: GlobalOptions

    @Option(help: ArgumentHelp(L10n.pick(en: "Only this widget (id or kind).", ru: "Только этот виджет (id или kind).")))
    var kind: String?

    @Flag(help: ArgumentHelp(L10n.pick(en: "Only the dev slot.", ru: "Только dev-слот.")))
    var dev = false

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let capture = try await ShotService.capture(workspace, kind: kind, dev: dev, runner: SystemProcessRunner())
        let review = ShotCompare.review(capture.records, workspace: workspace, target: AppGroupStore(config: workspace.config).devTarget())
        let artifacts = capture.records.map(\.path) + review.comparisons.map(\.image)
        global.printer.emit(CommandResult(issues: capture.issues + review.issues, artifacts: artifacts, data: capture.records)) { records in
            let shots = (records ?? []).map { "✓ \($0.label) \($0.window.family?.rawValue ?? "?") → \($0.path)" }
            return (shots + review.comparisons.map(\.summary)).joined(separator: "\n")
        }
        if capture.issues.contains(where: { $0.code == IssueCode.screenRecordingDenied }) {
            return 3
        }
        return capture.records.isEmpty ? 1 : 0
    }
}

struct DevCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "dev",
        abstract: L10n.pick(
            en: "Point the dev slot on the desktop at a widget and one of its samples.",
            ru: "Направить dev-слот на столе на виджет и один из его сэмплов."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Widget id.", ru: "id виджета.")))
    var id: String

    @Option(help: ArgumentHelp(L10n.pick(en: "Sample to show (default: default).", ru: "Какой сэмпл показать (по умолчанию default).")))
    var scenario: String?

    @Flag(help: ArgumentHelp(L10n.pick(en: "Show the live feed data instead of a sample.", ru: "Показывать живые данные feed вместо сэмпла.")))
    var live = false

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let widget = try workspace.widget(id)
        let target = try DevSwitch.apply(widget, scenario: live ? nil : (scenario ?? "default"), store: AppGroupStore(config: workspace.config))
        let reloaded = await Reloader(config: workspace.config, runner: SystemProcessRunner()).reload(kind: RegistryGenerator.devKind)
        let issues = reloaded ? [] : [Issue(
            code: IssueCode.installFailed,
            severity: .warning,
            message: L10n.pick(
                en: "Could not reach \(workspace.config.appName) to redraw the dev slot",
                ru: "Не удалось достучаться до \(workspace.config.appName), чтобы перерисовать dev-слот"
            ),
            hint: L10n.pick(en: "Install it first: `aw ship \(widget.id)`", ru: "Сначала установи: `aw ship \(widget.id)`")
        )]
        global.printer.emit(CommandResult(issues: issues, data: target)) { target in
            guard let target else { return "" }
            let source = target.scenario.map { "samples/\($0).json" } ?? L10n.pick(en: "live data", ru: "живые данные")
            return L10n.pick(en: "✓ dev slot → \(target.widget) (\(source))", ru: "✓ dev-слот → \(target.widget) (\(source))")
        }
        return 0
    }
}
