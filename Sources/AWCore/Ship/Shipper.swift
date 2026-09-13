import AWSchema
import Foundation

public struct ShipOptions: Sendable {
    public var scenario: String?
    public var live: Bool
    public var force: Bool
    public var shots: Bool
    public var settleTimeout: TimeInterval

    public init(scenario: String? = nil, live: Bool = false, force: Bool = false, shots: Bool = true, settleTimeout: TimeInterval = 30) {
        self.scenario = scenario
        self.live = live
        self.force = force
        self.shots = shots
        self.settleTimeout = settleTimeout
    }
}

public struct ShipOutcome: Codable, Sendable {
    public enum Stage: String, Codable, Sendable {
        case preview
        case build
        case install
        case done
    }

    public var widget: String
    public var stage: Stage
    public var preview: PreviewOutcome?
    public var build: BuildOutcome?
    public var install: InstallOutcome?
    public var dev: DevTarget?
    public var shots: [ShotRecord] = []
    public var issues: [Issue] = []
    public var seconds: [String: Double] = [:]

    public var exitCode: Int32 {
        switch stage {
        case .preview: 1
        case .build: 4
        case .install: 3
        case .done: 0
        }
    }
}

public struct Shipper: Sendable {
    public let workspace: Workspace
    public let engine: Engine
    public let runner: any ProcessRunning

    public init(workspace: Workspace, engine: Engine, runner: any ProcessRunning) {
        self.workspace = workspace
        self.engine = engine
        self.runner = runner
    }

    public func ship(_ id: String, _ options: ShipOptions, note: @Sendable (String) -> Void = { _ in }) async throws -> ShipOutcome {
        let widget = try workspace.widget(id)
        if let scenario = options.scenario, !options.live, widget.samples[scenario] == nil {
            throw AWError.scenarioNotFound(widget: widget.id, scenario: scenario, available: widget.samples.keys.filter { !$0.contains(".") }.sorted())
        }
        var outcome = ShipOutcome(widget: widget.id, stage: .preview)
        var watch = Stopwatch()
        note(L10n.pick(en: "preview…", ru: "превью…"))
        guard try await preview(widget, options, into: &outcome) else {
            return outcome
        }
        outcome.seconds["preview"] = watch.lap()
        outcome.stage = .build
        note(L10n.pick(en: "build…", ru: "сборка…"))
        let build = try await Builder(workspace: workspace, engine: engine, runner: runner).build()
        outcome.seconds["build"] = watch.lap()
        outcome.build = build
        outcome.issues += build.issues
        guard let app = build.app else {
            return outcome
        }
        let shooter = Shooter(directory: workspace.shotsDir, capture: Capture(runner: runner))
        let windows = options.shots ? devWindows(into: &outcome) : []
        let baselines = await shooter.baselines(windows)
        outcome.stage = .install
        note(L10n.pick(en: "install…", ru: "установка…"))
        let installed = try await Installer(config: workspace.config, runner: runner, paths: .standard(for: workspace.config))
            .install(URL(fileURLWithPath: app))
        outcome.seconds["install"] = watch.lap()
        outcome.install = installed
        outcome.issues += installed.issues
        guard !installed.hasErrors else {
            return outcome
        }
        outcome.dev = try DevSwitch.apply(
            widget,
            scenario: options.live ? nil : (options.scenario ?? "default"),
            store: AppGroupStore(config: workspace.config)
        )
        await Reloader(config: workspace.config, runner: runner).reload(kind: RegistryGenerator.devKind)
        outcome.stage = .done
        guard !windows.isEmpty else {
            return outcome
        }
        note(L10n.pick(en: "waiting for the desktop to redraw…", ru: "жду перерисовку на столе…"))
        outcome.shots = await shooter.settle(windows, label: RegistryGenerator.devKind, baselines: baselines, timeout: options.settleTimeout)
        outcome.seconds["shot"] = watch.lap()
        if outcome.shots.contains(where: { !$0.settled }) {
            outcome.issues.append(ShotIssues.unchanged(after: options.settleTimeout))
        }
        return outcome
    }

    private func preview(_ widget: WidgetSource, _ options: ShipOptions, into outcome: inout ShipOutcome) async throws -> Bool {
        let preview = try await PreviewPipeline(workspace: workspace, cache: KitCache(engine: engine, runner: runner), runner: runner)
            .run(widget, PreviewRequest())
        outcome.preview = preview
        let errors = preview.allIssues.filter { $0.severity == .error }.deduplicated()
        guard !errors.isEmpty else {
            return true
        }
        guard options.force else {
            outcome.issues += errors
            return false
        }
        outcome.issues += errors.map(\.downgraded)
        return true
    }

    private func devWindows(into outcome: inout ShipOutcome) -> [WidgetWindow] {
        guard WindowLocator.screenRecordingAllowed else {
            outcome.issues.append(ShotIssues.screenRecording(.warning))
            return []
        }
        let target = ShotTarget.dev(workspace.config)
        let windows = WindowLocator.find(WindowLocator.current(), names: target.names, descriptor: target.descriptor)
        if windows.isEmpty {
            outcome.issues.append(ShotIssues.notPlaced(workspace.config.devSlotName, appName: workspace.config.appName))
        }
        return windows
    }
}

struct Stopwatch {
    private var last = Date()

    mutating func lap() -> Double {
        let now = Date()
        defer { last = now }
        return now.timeIntervalSince(last)
    }
}
