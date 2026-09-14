import AWCore
import AWSchema
import Foundation
import MCP

enum AWTools {
    static let all: [AWTool] = [templates, create, preview, ship, shot, dev, doctor, list, dataSet, feedRun, explain]

    static let templates = AWTool(
        "aw_templates",
        "List widget templates to start from (metric, list, ring, chart, card, image, timer, blank). Call before aw_new when unsure which one fits.",
        schema: Schema.object([:]),
        readOnly: true
    ) { _, context in
        let list = TemplateCatalog(engine: try context.engine()).list()
        let lines = list.map { "\($0.id) — \($0.summary.localized) [\($0.families.map(\.rawValue).joined(separator: ","))]" }
        return Reply.make(lines.joined(separator: "\n"), payload: ["templates": list])
    }

    static let create = AWTool(
        "aw_new",
        "Create widgets/<id> from a template: a Codable model, a SwiftUI AWView, samples and maybe a feed. Start every new widget here, "
            + "then edit the Swift file and samples/*.json, then call aw_preview.",
        schema: Schema.object([
            "id": Schema.string("Widget id: lowercase letters, digits and dashes, for example bangkok-weather"),
            "template": Schema.string("Template id from aw_templates (default metric)"),
            "name": Schema.string("Display name in English"),
            "name_ru": Schema.string("Display name in Russian"),
            "families": Schema.strings("Families to support: small, medium, large, extraLarge")
        ], required: ["id"])
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let id = try arguments.required("id")
        let template = arguments.string("template") ?? "metric"
        let name = arguments.string("name").map { LocalizedText(en: $0, ru: arguments.string("name_ru")) }
        let families = arguments.list("families")?.compactMap(Family.init(rawValue:))
        let created = try TemplateCatalog(engine: try context.engine()).instantiate(template, id: id, name: name, families: families, in: workspace)
        let summary = L10n.pick(
            en: "✓ widgets/\(id) from \"\(template)\": \(created.joined(separator: ", "))\nNext: edit the view and samples, then aw_preview.",
            ru: "✓ widgets/\(id) из шаблона \"\(template)\": \(created.joined(separator: ", "))\nДальше: правь вьюху и сэмплы, затем aw_preview."
        )
        return Reply.make(summary, payload: ["files": created])
    }

    static let preview = AWTool(
        "aw_preview",
        "Render the widget in every family × light/dark × desktop-idle × sample and check the layout (OVERFLOW, TRUNCATION, DECODE…). "
            + "Returns the sheet image and a report. Call after every edit: the widget is done only when the report has no errors and the sheet looks right.",
        schema: Schema.object([
            "id": Schema.string("Widget id"),
            "families": Schema.strings("Only these families"),
            "scenarios": Schema.strings("Only these samples (file names in samples/ without .json)"),
            "full": Schema.boolean("Render every theme and mode for every sample")
        ], required: ["id"]),
        readOnly: true
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let widget = try workspace.widget(try arguments.required("id"))
        let request = PreviewRequest(
            families: arguments.list("families")?.compactMap(Family.init(rawValue:)),
            scenarios: arguments.list("scenarios"),
            full: arguments.bool("full", default: false),
            geometry: GeometryStore.load()
        )
        let outcome = try await context.pipeline(workspace).run(widget, request)
        return Reply.make(Summaries.preview(outcome), issues: outcome.allIssues, payload: outcome, images: [outcome.report?.sheet].compactMap { $0 })
    }

    static let ship = AWTool(
        "aw_ship",
        "Build, sign and install the widget app, point the dev slot on the desktop at this widget and capture the real window. "
            + "Call when aw_preview is clean. Takes 20–60 s.",
        schema: Schema.object([
            "id": Schema.string("Widget id"),
            "scenario": Schema.string("Sample for the dev slot (default: default)"),
            "live": Schema.boolean("Show the live feed data instead of a sample"),
            "force": Schema.boolean("Ship even if the preview has errors"),
            "shot": Schema.boolean("Capture the desktop window (default true)"),
            "timeout": Schema.number("Seconds to wait for the desktop to redraw (default 30)")
        ], required: ["id"])
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let options = ShipOptions(
            scenario: arguments.string("scenario"),
            live: arguments.bool("live", default: false),
            force: arguments.bool("force", default: false),
            shots: arguments.bool("shot", default: true),
            settleTimeout: arguments.number("timeout") ?? 30
        )
        let outcome = try await Shipper(workspace: workspace, engine: try context.engine(), runner: context.runner).ship(try arguments.required("id"), options)
        return Reply.make(Summaries.ship(outcome), issues: outcome.issues, payload: outcome, images: outcome.shots.map(\.path))
    }

    static let shot = AWTool(
        "aw_shot",
        "Capture real widget windows from the desktop (needs Screen Recording and the widget placed). Use it to see the real rendering after aw_ship.",
        schema: Schema.object([
            "kind": Schema.string("Only this widget (id or kind)"),
            "dev": Schema.boolean("Only the dev slot")
        ]),
        readOnly: true
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let capture = try await ShotService.capture(
            workspace,
            kind: arguments.string("kind"),
            dev: arguments.bool("dev", default: false),
            runner: context.runner
        )
        let summary = L10n.pick(en: "\(capture.records.count) window(s) captured", ru: "снято окон: \(capture.records.count)")
        return Reply.make(summary, issues: capture.issues, payload: ["shots": capture.records], images: capture.records.map(\.path))
    }

    static let dev = AWTool(
        "aw_dev",
        "Switch the dev slot on the desktop to a widget and one of its samples (or live data) without rebuilding.",
        schema: Schema.object([
            "id": Schema.string("Widget id"),
            "scenario": Schema.string("Sample name (default: default)"),
            "live": Schema.boolean("Show the live feed data")
        ], required: ["id"])
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let widget = try workspace.widget(try arguments.required("id"))
        let scenario = arguments.bool("live", default: false) ? nil : (arguments.string("scenario") ?? "default")
        let target = try DevSwitch.apply(widget, scenario: scenario, store: AppGroupStore(config: workspace.config))
        let reloaded = await Reloader(config: workspace.config, runner: context.runner).reload(kind: RegistryGenerator.devKind)
        let issues = reloaded ? [] : [Issue(
            code: IssueCode.installFailed,
            severity: .warning,
            message: L10n.pick(en: "The widget app is not installed yet", ru: "Приложение с виджетами ещё не установлено"),
            hint: "aw_ship"
        )]
        return Reply.make(L10n.pick(en: "✓ dev slot → \(target.widget)", ru: "✓ dev-слот → \(target.widget)"), issues: issues, payload: target)
    }

    static let doctor = AWTool(
        "aw_doctor",
        "Check Xcode, XcodeGen, signing, Screen Recording, the installed app, the dev slot and the feed daemon. "
            + "Call first when anything environment-related fails.",
        schema: Schema.object([:]),
        readOnly: true
    ) { arguments, context in
        let doctor = Doctor(runner: context.runner)
        var checks = await doctor.run()
        if let workspace = try? context.workspace(arguments) {
            let screen = WindowLocator.screenRecordingAllowed
            checks += await doctor.workspaceChecks(
                workspace,
                paths: .standard(for: workspace.config),
                screenRecording: screen,
                windows: screen ? WindowLocator.current() : [],
                geometry: GeometryStore.load()
            )
        }
        return Reply.make(DoctorFormatter.human(checks), issues: checks.compactMap(\.issue), payload: ["checks": checks])
    }

    static let list = AWTool(
        "aw_list",
        "List the widgets in the workspace with their families and feeds, plus manifest problems.",
        schema: Schema.object([:]),
        readOnly: true
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let manifests = try workspace.widgets().map(\.manifest)
        let lines = manifests.map { manifest in
            let families = manifest.families.map(\.rawValue).joined(separator: ",")
            let feed = manifest.feed.map { " feed \($0.every.compact)" } ?? ""
            return "\(manifest.id) — \(manifest.name.localized) [\(families)]\(feed)"
        }
        return Reply.make(lines.joined(separator: "\n"), issues: workspace.validate(), payload: ["widgets": manifests])
    }

    static let dataSet = AWTool(
        "aw_data_set",
        "Publish JSON data for a widget right now (checked against the model) and redraw it. Use it to try real-looking data without a feed.",
        schema: Schema.object([
            "id": Schema.string("Widget id"),
            "json": .object(["description": .string("The model as a JSON object (or a string holding it)")]),
            "validate": Schema.boolean("Check the data against the model first (default true)")
        ], required: ["id", "json"])
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let widget = try workspace.widget(try arguments.required("id"))
        guard let raw = arguments.values["json"] else {
            throw AWError.invalidJSON(file: "arguments", reason: "missing \"json\"")
        }
        let data = try raw.stringValue.map { Data($0.utf8) } ?? JSONEncoder().encode(raw)
        guard case .object? = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            throw AWError.invalidJSON(file: "json", reason: "expected one JSON object")
        }
        if arguments.bool("validate", default: true) {
            let validator = DataValidator(pipeline: try context.pipeline(workspace), widget: widget)
            if let issue = await validator.check(data) {
                let summary = L10n.pick(en: "✗ the data does not match the model", ru: "✗ данные не совпадают с моделью")
                return Reply.make(summary, issues: [issue], payload: ["changed": false])
            }
        }
        let store = AppGroupStore(config: workspace.config)
        let changed = try store.publish(data, widget: widget.id)
        try store.writeStatus(FeedStatus(ok: true, checkedAt: Date(), fetchedAt: Date()), widget: widget.id)
        if changed {
            await Reloader(config: workspace.config, runner: context.runner).reload(afterPublishing: widget, store: store)
        }
        let summary = changed
            ? L10n.pick(en: "✓ \(widget.id): data published", ru: "✓ \(widget.id): данные опубликованы")
            : L10n.pick(en: "· \(widget.id): data unchanged", ru: "· \(widget.id): данные не изменились")
        return Reply.make(summary, payload: ["changed": changed])
    }

    static let feedRun = AWTool(
        "aw_feed_run",
        "Run the widget's feed once, check the output against the model and publish it. Call after writing or changing feed.py / feed.sh.",
        schema: Schema.object([
            "id": Schema.string("Widget id"),
            "validate": Schema.boolean("Check the output against the model (default true)")
        ], required: ["id"])
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let widget = try workspace.widget(try arguments.required("id"))
        let store = AppGroupStore(config: workspace.config)
        let validator = arguments.bool("validate", default: true) ? DataValidator(pipeline: try context.pipeline(workspace), widget: widget) : nil
        let check: (@Sendable (Data) async -> Issue?)? = validator.map { validator in { data in await validator.check(data) } }
        let feeds = FeedRunner(workspace: workspace, store: store, runner: context.runner, language: workspace.config.locale ?? L10n.language)
        let run = await feeds.run(widget, validate: check)
        if run.changed {
            await Reloader(config: workspace.config, runner: context.runner).reload(afterPublishing: widget, store: store)
        }
        return Reply.make(Summaries.feed(run), issues: run.issues, payload: run)
    }

    static let explain = AWTool(
        "aw_explain",
        "Explain an issue code from a report: what it means, why it happens and how to fix it. Without a code, lists every code.",
        schema: Schema.object(["code": Schema.string("Issue code, for example OVERFLOW")]),
        readOnly: true
    ) { arguments, _ in
        guard let code = arguments.string("code") else {
            let lines = IssueCatalog.entries.map { "\($0.code) — \($0.title.localized)" }
            return Reply.make(lines.joined(separator: "\n"), payload: ["codes": IssueCatalog.entries.map(\.code)])
        }
        guard let entry = IssueCatalog.explain(code) else {
            return Reply.failure([Issue(
                code: "UNKNOWN_CODE",
                severity: .error,
                message: L10n.pick(en: "No issue code \(code)", ru: "Нет кода \(code)"),
                hint: "aw_explain"
            )])
        }
        return Reply.make(IssueCatalog.render(entry), payload: entry)
    }
}

enum Summaries {
    static func preview(_ outcome: PreviewOutcome) -> String {
        guard let report = outcome.report else {
            return L10n.pick(en: "✗ \(outcome.widget): no preview, see the issues", ru: "✗ \(outcome.widget): превью нет, см. проблемы")
        }
        let errors = outcome.allIssues.filter { $0.severity == .error }.count
        guard errors > 0 else {
            return L10n.pick(
                en: "✓ \(outcome.widget): \(report.cells.count) cells, no errors. Check the sheet image below with your own eyes.",
                ru: "✓ \(outcome.widget): \(report.cells.count) ячеек, ошибок нет. Посмотри лист ниже своими глазами."
            )
        }
        return L10n.pick(
            en: "✗ \(outcome.widget): \(errors) error(s) in \(report.cells.count) cells. Fix them and preview again.",
            ru: "✗ \(outcome.widget): ошибок \(errors) на \(report.cells.count) ячеек. Исправь и повтори превью."
        )
    }

    static func ship(_ outcome: ShipOutcome) -> String {
        let timings = outcome.seconds.sorted { $0.key < $1.key }.map { "\($0.key) \(Int($0.value.rounded())) s" }.joined(separator: " · ")
        guard outcome.stage == .done else {
            return L10n.pick(
                en: "✗ \(outcome.widget) stopped at \(outcome.stage.rawValue) (\(timings))",
                ru: "✗ \(outcome.widget) остановился на этапе \(outcome.stage.rawValue) (\(timings))"
            )
        }
        return L10n.pick(
            en: "✓ \(outcome.widget) is installed and shown in the dev slot (\(timings)); desktop shots: \(outcome.shots.count)",
            ru: "✓ \(outcome.widget) установлен и показан в dev-слоте (\(timings)); снимков со стола: \(outcome.shots.count)"
        )
    }

    static func feed(_ run: FeedRun) -> String {
        guard run.ok else {
            return L10n.pick(en: "✗ \(run.widget): the feed failed", ru: "✗ \(run.widget): feed упал")
        }
        return run.changed
            ? L10n.pick(en: "✓ \(run.widget): new data published", ru: "✓ \(run.widget): новые данные опубликованы")
            : L10n.pick(en: "✓ \(run.widget): data unchanged", ru: "✓ \(run.widget): данные без изменений")
    }
}
