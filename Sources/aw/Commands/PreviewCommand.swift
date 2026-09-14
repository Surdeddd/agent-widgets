import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct PreviewCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview",
        abstract: L10n.pick(
            en: "Render every family, theme and sample into a sheet and check the layout.",
            ru: "Отрендерить все размеры, темы и сэмплы на лист и проверить вёрстку."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Widget id.", ru: "id виджета.")))
    var id: String

    @Option(help: ArgumentHelp(L10n.pick(en: "Only these families, comma separated.", ru: "Только эти размеры, через запятую.")))
    var family: String?

    @Option(help: ArgumentHelp(L10n.pick(en: "Only these samples, comma separated.", ru: "Только эти сэмплы, через запятую.")))
    var scenario: String?

    @Flag(help: ArgumentHelp(L10n.pick(en: "Render every theme × mode for every sample.", ru: "Все темы × режимы для каждого сэмпла.")))
    var full = false

    @Flag(help: ArgumentHelp(L10n.pick(en: "Open the sheet when done.", ru: "Открыть лист после рендера.")))
    var open = false

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let widget = try workspace.widget(id)
        let runner = SystemProcessRunner()
        let cache = KitCache(engine: try Engine.current(), runner: runner)
        if !(await cache.isReady()) {
            FileHandle.standardError.write(Data(L10n.pick(
                en: "compiling the kit once (~20 s)…\n",
                ru: "один раз компилирую кит (~20 с)…\n"
            ).utf8))
        }
        let request = PreviewRequest(
            families: family.map { $0.split(separator: ",").compactMap { Family(rawValue: String($0)) } },
            scenarios: scenario.map { $0.split(separator: ",").map(String.init) },
            full: full,
            language: global.language
        )
        let outcome = try await PreviewPipeline(workspace: workspace, cache: cache, runner: runner).run(widget, request)
        let issues = outcome.allIssues.deduplicated()
        let artifacts = outcome.report.map { report in
            [report.sheet, URL(fileURLWithPath: report.sheet).deletingLastPathComponent().appendingPathComponent("report.json").path]
        } ?? []
        let result = CommandResult(issues: issues, artifacts: artifacts, data: outcome)
        global.printer.emit(result) { data in
            guard let data else { return "" }
            return Self.summary(data)
        }
        if open, let sheet = outcome.report?.sheet {
            _ = try? await runner.run("/usr/bin/open", [sheet])
        }
        return result.ok ? 0 : 1
    }

    static func summary(_ outcome: PreviewOutcome) -> String {
        let mark = outcome.hasErrors ? "✗" : "✓"
        let compile = outcome.compiled
            ? L10n.pick(en: "compiled in \(String(format: "%.1f", outcome.compileSeconds)) s", ru: "сборка \(String(format: "%.1f", outcome.compileSeconds)) с")
            : L10n.pick(en: "cached build", ru: "сборка из кэша")
        guard let report = outcome.report else {
            return "\(mark) \(outcome.widget): \(compile)"
        }
        let render = L10n.pick(
            en: "\(report.cells.count) cells in \(String(format: "%.1f", outcome.renderSeconds)) s",
            ru: "\(report.cells.count) ячеек за \(String(format: "%.1f", outcome.renderSeconds)) с"
        )
        return "\(mark) \(outcome.widget): \(compile), \(render)\n" + L10n.pick(en: "  sheet: \(report.sheet)", ru: "  лист: \(report.sheet)")
    }
}

struct ListCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: L10n.pick(en: "List widgets in this workspace.", ru: "Показать виджеты workspace.")
    )

    @OptionGroup var global: GlobalOptions

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let manifests = try workspace.widgets().map(\.manifest)
        let issues = workspace.validate()
        global.printer.emit(CommandResult(issues: issues, data: manifests)) { list in
            let rows = (list ?? []).map { manifest in
                let families = manifest.families.map(\.rawValue).joined(separator: ",")
                let feed = manifest.feed.map { "feed \($0.every.compact)" } ?? L10n.pick(en: "no feed", ru: "без feed")
                return "\(manifest.id)  \(manifest.name.localized)  [\(families)]  \(feed)"
            }
            return rows.isEmpty ? L10n.pick(en: "no widgets yet — aw new <id>", ru: "виджетов пока нет — aw new <id>") : rows.joined(separator: "\n")
        }
        return issues.contains { $0.severity == .error } ? 1 : 0
    }
}
