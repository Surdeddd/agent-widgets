import AWSchema
import Foundation

public struct DevShowOutcome: Codable, Sendable {
    public var target: DevTarget
    public var shots: [ShotRecord]
    public var comparisons: [ShotComparison]
    public var issues: [Issue]
    public var seconds: Double?
}

public enum DevSlot {
    /// Switches the dev slot to the widget, waits until the desktop has redrawn it, then captures and compares it with the preview.
    public static func show(
        _ widget: WidgetSource,
        scenario: String?,
        workspace: Workspace,
        runner: any ProcessRunning,
        timeout: TimeInterval = 30,
        store: AppGroupStore? = nil,
        screenRecording: Bool = WindowLocator.screenRecordingAllowed,
        locate: @Sendable () -> [WidgetWindow] = { WindowLocator.current() }
    ) async throws -> DevShowOutcome {
        let config = workspace.config
        let store = store ?? AppGroupStore(config: config)
        let slot = ShotTarget.dev(config)
        let placed = screenRecording ? WindowLocator.find(locate(), names: slot.names, descriptor: slot.descriptor) : []
        let windows = placed.filter { !$0.hidden }
        let shooter = Shooter(directory: workspace.shotsDir, capture: Capture(runner: runner))
        let previous = store.devTarget()
        let baselines = await shooter.baselines(windows)
        let target = try DevSwitch.apply(widget, scenario: scenario, store: store)
        var outcome = DevShowOutcome(target: target, shots: [], comparisons: [], issues: [], seconds: nil)
        guard await Reloader(config: config, runner: runner).reload(kind: RegistryGenerator.devKind) else {
            outcome.issues.append(unreachable(config.appName, widget: widget.id))
            return outcome
        }
        guard screenRecording else {
            outcome.issues.append(ShotIssues.screenRecording(.warning))
            return outcome
        }
        guard !placed.isEmpty else {
            outcome.issues.append(ShotIssues.notPlaced(config.devSlotName, appName: config.appName))
            return outcome
        }
        if windows.count < placed.count {
            outcome.issues.append(ShotIssues.hidden(config.devSlotName, families: placed.filter(\.hidden).compactMap(\.family)))
        }
        guard !windows.isEmpty else {
            return outcome
        }
        if previous == target {
            outcome.shots = await shooter.take(windows, label: RegistryGenerator.devKind)
        } else {
            let started = Date()
            outcome.shots = await shooter.settle(windows, label: RegistryGenerator.devKind, baselines: baselines, timeout: timeout)
            outcome.seconds = Date().timeIntervalSince(started)
            if outcome.shots.contains(where: { !$0.settled }) {
                outcome.issues.append(ShotIssues.unchanged(after: timeout))
            }
        }
        let review = ShotCompare.review(outcome.shots.filter(\.settled), workspace: workspace, target: target)
        outcome.comparisons = review.comparisons
        outcome.issues += review.issues
        return outcome
    }

    static func unreachable(_ appName: String, widget id: String) -> Issue {
        Issue(
            code: IssueCode.installFailed,
            severity: .warning,
            message: L10n.pick(
                en: "Could not reach \(appName) to redraw the dev slot",
                ru: "Не удалось достучаться до \(appName), чтобы перерисовать dev-слот"
            ),
            hint: L10n.pick(en: "Install it first: `aw ship \(id)`", ru: "Сначала установи: `aw ship \(id)`")
        )
    }
}
