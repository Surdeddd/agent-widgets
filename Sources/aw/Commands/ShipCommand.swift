import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct ShipCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "ship",
        abstract: L10n.pick(
            en: "Preview, build, install, point the dev slot at the widget and capture the real window.",
            ru: "Превью, сборка, установка, dev-слот на виджет и снимок реального окна."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Widget id.", ru: "id виджета.")))
    var id: String

    @Option(help: ArgumentHelp(L10n.pick(en: "Sample for the dev slot (default: default).", ru: "Сэмпл для dev-слота (по умолчанию default).")))
    var scenario: String?

    @Flag(help: ArgumentHelp(L10n.pick(en: "Dev slot shows the live feed data.", ru: "Dev-слот показывает живые данные feed.")))
    var live = false

    @Flag(help: ArgumentHelp(L10n.pick(en: "Ship even if the preview has errors.", ru: "Отгрузить, даже если в превью ошибки.")))
    var force = false

    @Flag(name: .customLong("no-shot"), help: ArgumentHelp(L10n.pick(en: "Skip the desktop screenshot.", ru: "Без снимка со стола.")))
    var noShot = false

    @Option(help: ArgumentHelp(L10n.pick(en: "Seconds to wait for the desktop to redraw.", ru: "Сколько секунд ждать перерисовки на столе.")))
    var timeout: Double = 30

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let shipper = Shipper(workspace: workspace, engine: try Engine.current(), runner: SystemProcessRunner())
        let options = ShipOptions(scenario: scenario, live: live, force: force, shots: !noShot, settleTimeout: timeout)
        let outcome = try await shipper.ship(id, options) { Console.note($0) }
        let artifacts = [outcome.preview?.report?.sheet].compactMap { $0 } + outcome.shots.map(\.path) + outcome.comparisons.map(\.image)
        global.printer.emit(CommandResult(issues: outcome.issues.deduplicated(), artifacts: artifacts, data: outcome)) { outcome in
            outcome.map(Self.summary) ?? ""
        }
        return outcome.exitCode
    }

    static func summary(_ outcome: ShipOutcome) -> String {
        let labels = [
            ("preview", L10n.pick(en: "preview", ru: "превью")),
            ("build", L10n.pick(en: "build", ru: "сборка")),
            ("install", L10n.pick(en: "install", ru: "установка")),
            ("shot", L10n.pick(en: "redraw", ru: "перерисовка"))
        ]
        let unit = L10n.pick(en: "s", ru: "с")
        let timings = labels.compactMap { key, label in
            outcome.seconds[key].map { "\(label) \(String(format: "%.0f", $0)) \(unit)" }
        }
        .joined(separator: " · ")
        let headline: String
        switch outcome.stage {
        case .done:
            headline = L10n.pick(
                en: "✓ \(outcome.widget) shipped: \(timings)",
                ru: "✓ \(outcome.widget) отгружен: \(timings)"
            )
        case .unverified:
            headline = L10n.pick(
                en: "✗ \(outcome.widget) is installed, but nobody has seen it on the desktop: \(timings)",
                ru: "✗ \(outcome.widget) установлен, но на столе его никто не видел: \(timings)"
            )
        case .preview, .build, .install:
            headline = L10n.pick(
                en: "✗ \(outcome.widget) stopped at \(outcome.stage.rawValue): \(timings)",
                ru: "✗ \(outcome.widget) остановился на этапе \(outcome.stage.rawValue): \(timings)"
            )
        }
        var lines = [headline]
        if let sheet = outcome.preview?.report?.sheet {
            lines.append(L10n.pick(en: "  sheet: \(sheet)", ru: "  лист: \(sheet)"))
        }
        for shot in outcome.shots {
            lines.append(L10n.pick(en: "  desktop: \(shot.path)", ru: "  стол: \(shot.path)"))
        }
        lines += outcome.comparisons.map { "  " + $0.summary }
        return lines.joined(separator: "\n")
    }
}
