import AWSchema
import Foundation

public enum ShotService {
    /// Captures every placed window of the requested widgets; the issues explain why something could not be captured.
    public static func capture(
        _ workspace: Workspace,
        kind: String?,
        dev: Bool,
        runner: any ProcessRunning
    ) async throws -> (records: [ShotRecord], issues: [Issue]) {
        let targets = try ShotTarget.resolve(workspace, kind: kind, dev: dev)
        guard WindowLocator.screenRecordingAllowed else {
            return ([], [ShotIssues.screenRecording(.error)])
        }
        let windows = WindowLocator.current()
        let shooter = Shooter(directory: workspace.shotsDir, capture: Capture(runner: runner))
        var records: [ShotRecord] = []
        var issues: [Issue] = []
        let single = kind != nil || dev
        for target in targets {
            let found = WindowLocator.find(windows, names: target.names, descriptor: target.descriptor)
            if found.isEmpty && single {
                issues.append(ShotIssues.notPlaced(target.names.first ?? target.label, appName: workspace.config.appName))
            }
            records += await shooter.take(found, label: target.label)
        }
        if records.isEmpty && issues.isEmpty {
            issues.append(ShotIssues.notPlaced(workspace.config.appName, appName: workspace.config.appName))
        }
        return (records, issues)
    }
}
