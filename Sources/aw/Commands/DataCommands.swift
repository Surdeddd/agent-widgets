import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct FeedCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "feed",
        abstract: L10n.pick(en: "Run widget feeds.", ru: "Запуск feed виджетов."),
        subcommands: [FeedRunCommand.self]
    )
}

struct FeedRunCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: L10n.pick(
            en: "Run a widget's feed once, check the output against the model and publish it.",
            ru: "Один раз запустить feed виджета, сверить вывод с моделью и опубликовать."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Widget id.", ru: "id виджета.")))
    var id: String

    @Flag(name: .customLong("no-validate"), help: ArgumentHelp(L10n.pick(en: "Skip the model check.", ru: "Без сверки с моделью.")))
    var noValidate = false

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let widget = try workspace.widget(id)
        let runner = SystemProcessRunner()
        let validator = noValidate ? nil : DataValidator(
            pipeline: PreviewPipeline(workspace: workspace, cache: KitCache(engine: try Engine.current(), runner: runner), runner: runner),
            widget: widget
        )
        let check: (@Sendable (Data) async -> Issue?)? = validator.map { validator in { data in await validator.check(data) } }
        let feeds = FeedRunner(
            workspace: workspace,
            store: AppGroupStore(config: workspace.config),
            runner: runner,
            language: workspace.config.locale ?? global.language
        )
        let run = await feeds.run(widget, validate: check)
        if run.changed {
            await DataReload.after(publishing: widget, workspace: workspace, runner: runner)
        }
        global.printer.emit(CommandResult(issues: run.issues, artifacts: [feeds.logFile(for: widget.id).path], data: run)) { run in
            guard let run else { return "" }
            return DataReload.line(run)
        }
        return run.ok ? 0 : 1
    }
}

struct TickCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "tick",
        abstract: L10n.pick(
            en: "Run the feeds that are due; the daemon calls this every minute.",
            ru: "Запустить feed, которым пора; daemon зовёт это раз в минуту."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Flag(help: ArgumentHelp(L10n.pick(en: "Run every feed now.", ru: "Запустить все feed сейчас.")))
    var force = false

    @Option(help: ArgumentHelp(L10n.pick(en: "Only this widget.", ru: "Только этот виджет.")))
    var widget: String?

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let ticker = Ticker(workspace: workspace, store: AppGroupStore(config: workspace.config), runner: SystemProcessRunner())
        let outcome = try await ticker.tick(force: force, only: widget)
        let issues = outcome.runs.flatMap(\.issues)
        global.printer.emit(CommandResult(issues: issues, data: outcome)) { outcome in
            guard let outcome else { return "" }
            if outcome.skipped {
                return L10n.pick(en: "· another tick is still running", ru: "· предыдущий tick ещё работает")
            }
            if outcome.runs.isEmpty {
                return L10n.pick(en: "· nothing is due", ru: "· никому не пора")
            }
            return outcome.runs.map(DataReload.line).joined(separator: "\n")
        }
        return outcome.runs.contains { !$0.ok } ? 1 : 0
    }
}

struct DaemonCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: L10n.pick(en: "Keep feeds fresh with a LaunchAgent.", ru: "Держать feed свежими через LaunchAgent."),
        subcommands: [DaemonInstallCommand.self, DaemonUninstallCommand.self, DaemonStatusCommand.self]
    )

    static func summary(_ status: DaemonStatus) -> String {
        guard status.installed else {
            return L10n.pick(en: "· \(status.label) is not installed", ru: "· \(status.label) не установлен")
        }
        let state = status.state ?? L10n.pick(en: "not loaded", ru: "не загружен")
        let runs = status.runs.map { L10n.pick(en: ", \($0) runs", ru: ", запусков: \($0)") } ?? ""
        let exit = status.lastExitCode.map { L10n.pick(en: ", last exit \($0)", ru: ", последний код \($0)") } ?? ""
        return "\(status.loaded ? "✓" : "!") \(status.label): \(state)\(runs)\(exit)"
    }
}

struct DaemonInstallCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: L10n.pick(en: "Install the LaunchAgent that runs aw tick every minute.", ru: "Поставить LaunchAgent, который раз в минуту зовёт aw tick.")
    )

    @OptionGroup var global: GlobalOptions

    func execute() async throws -> Int32 {
        let daemon = Daemon(workspace: try global.loadWorkspace(), runner: SystemProcessRunner())
        let status = try await daemon.install()
        global.printer.emit(CommandResult(artifacts: [daemon.plistURL.path, daemon.logURL.path], data: status)) { status in
            status.map(DaemonCommand.summary) ?? ""
        }
        return status.loaded ? 0 : 3
    }
}

struct DaemonUninstallCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: L10n.pick(en: "Stop the LaunchAgent and move its plist to the Trash.", ru: "Остановить LaunchAgent и убрать его plist в Корзину.")
    )

    @OptionGroup var global: GlobalOptions

    func execute() async throws -> Int32 {
        let status = try await Daemon(workspace: try global.loadWorkspace(), runner: SystemProcessRunner()).uninstall()
        global.printer.emit(CommandResult(data: status)) { status in
            status.map(DaemonCommand.summary) ?? ""
        }
        return 0
    }
}

struct DaemonStatusCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: L10n.pick(en: "Show whether the LaunchAgent is loaded.", ru: "Показать, загружен ли LaunchAgent.")
    )

    @OptionGroup var global: GlobalOptions

    func execute() async throws -> Int32 {
        let status = await Daemon(workspace: try global.loadWorkspace(), runner: SystemProcessRunner()).status()
        global.printer.emit(CommandResult(data: status)) { status in
            status.map(DaemonCommand.summary) ?? ""
        }
        return status.loaded ? 0 : 1
    }
}

struct DataCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "data",
        abstract: L10n.pick(en: "Read or push widget data directly.", ru: "Прочитать или напрямую пушнуть данные виджета."),
        subcommands: [DataSetCommand.self, DataGetCommand.self]
    )
}

struct DataSetCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: L10n.pick(en: "Publish JSON for a widget and redraw it.", ru: "Опубликовать JSON для виджета и перерисовать его.")
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Widget id.", ru: "id виджета.")))
    var id: String

    @Argument(help: ArgumentHelp(L10n.pick(en: "JSON text, or @path to a JSON file.", ru: "JSON-текст или @путь к JSON-файлу.")))
    var json: String

    @Flag(name: .customLong("no-validate"), help: ArgumentHelp(L10n.pick(en: "Skip the model check.", ru: "Без сверки с моделью.")))
    var noValidate = false

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let widget = try workspace.widget(id)
        let runner = SystemProcessRunner()
        let data = json.hasPrefix("@") ? try Data(contentsOf: URL(fileURLWithPath: String(json.dropFirst()))) : Data(json.utf8)
        guard case .object? = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            throw AWError.invalidJSON(file: json.hasPrefix("@") ? String(json.dropFirst()) : "data", reason: "expected one JSON object")
        }
        if !noValidate {
            let pipeline = PreviewPipeline(workspace: workspace, cache: KitCache(engine: try Engine.current(), runner: runner), runner: runner)
            if let issue = await DataValidator(pipeline: pipeline, widget: widget).check(data) {
                global.printer.emit(CommandResult<NoPayload>(issues: [issue])) { _ in "" }
                return 1
            }
        }
        let store = AppGroupStore(config: workspace.config)
        let changed = try store.publish(data, widget: widget.id)
        try store.writeStatus(FeedStatus(ok: true, checkedAt: Date(), fetchedAt: Date()), widget: widget.id)
        if changed {
            await DataReload.after(publishing: widget, workspace: workspace, runner: runner)
        }
        let path = store.url(AppGroupLayout.data(widget.id)).path
        global.printer.emit(CommandResult(artifacts: [path], data: ["changed": changed])) { _ in
            changed
                ? L10n.pick(en: "✓ \(widget.id): data published", ru: "✓ \(widget.id): данные опубликованы")
                : L10n.pick(en: "· \(widget.id): data unchanged", ru: "· \(widget.id): данные не изменились")
        }
        return 0
    }
}

struct DataGetCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: L10n.pick(en: "Print the published data and feed status.", ru: "Показать опубликованные данные и статус feed.")
    )

    struct Payload: Codable, Sendable {
        var data: JSONValue?
        var status: FeedStatus?
    }

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Widget id.", ru: "id виджета.")))
    var id: String

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let widget = try workspace.widget(id)
        let store = AppGroupStore(config: workspace.config)
        let data = store.read(AppGroupLayout.data(widget.id)).flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
        let payload = Payload(data: data, status: store.status(widget: widget.id))
        global.printer.emit(CommandResult(artifacts: [store.url(AppGroupLayout.data(widget.id)).path], data: payload)) { payload in
            guard let payload, let data = payload.data, let text = try? String(bytes: data.canonicalData(), encoding: .utf8) else {
                return L10n.pick(en: "· \(widget.id) has no data yet", ru: "· у \(widget.id) пока нет данных")
            }
            let status = payload.status.map { status in
                status.ok
                    ? L10n.pick(en: "feed ok", ru: "feed в порядке")
                    : L10n.pick(en: "feed failed: \(status.error ?? "?")", ru: "feed упал: \(status.error ?? "?")")
            } ?? ""
            return [text, status].filter { !$0.isEmpty }.joined(separator: "\n")
        }
        return 0
    }
}

struct LogsCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: L10n.pick(en: "Show the feed log of a widget.", ru: "Показать лог feed виджета.")
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: ArgumentHelp(L10n.pick(en: "Widget id.", ru: "id виджета.")))
    var id: String

    @Option(name: .customShort("n"), help: ArgumentHelp(L10n.pick(en: "How many lines.", ru: "Сколько строк.")))
    var lines = 50

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let widget = try workspace.widget(id)
        let file = FeedRunner(workspace: workspace, store: AppGroupStore(config: workspace.config), runner: SystemProcessRunner()).logFile(for: widget.id)
        let tail = LogFile.tail(file, lines: lines) ?? []
        global.printer.emit(CommandResult(artifacts: [file.path], data: tail)) { tail in
            let text = (tail ?? []).joined(separator: "\n")
            return text.isEmpty ? L10n.pick(en: "· no feed runs yet", ru: "· feed ещё не запускался") : text
        }
        return 0
    }
}

enum DataReload {
    static func after(publishing widget: WidgetSource, workspace: Workspace, runner: any ProcessRunning) async {
        let reloader = Reloader(config: workspace.config, runner: runner)
        await reloader.reload(kind: widget.manifest.resolvedKind)
        let dev = AppGroupStore(config: workspace.config).devTarget()
        if dev?.widget == widget.id && dev?.scenario == nil {
            await reloader.reload(kind: RegistryGenerator.devKind)
        }
    }

    static func line(_ run: FeedRun) -> String {
        let seconds = String(format: "%.1f", run.seconds)
        guard run.ok else {
            return L10n.pick(en: "✗ \(run.widget) failed in \(seconds) s", ru: "✗ \(run.widget) упал за \(seconds) с")
        }
        return run.changed
            ? L10n.pick(en: "✓ \(run.widget) new data in \(seconds) s", ru: "✓ \(run.widget) новые данные за \(seconds) с")
            : L10n.pick(en: "✓ \(run.widget) unchanged in \(seconds) s", ru: "✓ \(run.widget) без изменений за \(seconds) с")
    }
}
