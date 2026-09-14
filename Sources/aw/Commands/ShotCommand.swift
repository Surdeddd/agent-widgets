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

    @Option(help: ArgumentHelp(L10n.pick(en: "Seconds to wait for the desktop to redraw.", ru: "Сколько секунд ждать перерисовки на столе.")))
    var timeout: Double = 30

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let widget = try workspace.widget(id)
        let outcome = try await DevSlot.show(
            widget,
            scenario: live ? nil : (scenario ?? "default"),
            workspace: workspace,
            runner: SystemProcessRunner(),
            timeout: timeout
        )
        let artifacts = outcome.shots.map(\.path) + outcome.comparisons.map(\.image)
        global.printer.emit(CommandResult(issues: outcome.issues, artifacts: artifacts, data: outcome)) { outcome in
            outcome.map(Self.summary) ?? ""
        }
        return 0
    }

    static func summary(_ outcome: DevShowOutcome) -> String {
        let source = outcome.target.scenario.map { "samples/\($0).json" } ?? L10n.pick(en: "live data", ru: "живые данные")
        var lines = [L10n.pick(en: "✓ dev slot → \(outcome.target.widget) (\(source))", ru: "✓ dev-слот → \(outcome.target.widget) (\(source))")]
        if let seconds = outcome.seconds {
            lines.append(L10n.pick(en: "  redrawn in \(Int(seconds.rounded())) s", ru: "  перерисован за \(Int(seconds.rounded())) с"))
        }
        lines += outcome.shots.map { "  \($0.window.family?.rawValue ?? "?") → \($0.path)" }
        lines += outcome.comparisons.map { "  " + $0.summary }
        return lines.joined(separator: "\n")
    }
}
