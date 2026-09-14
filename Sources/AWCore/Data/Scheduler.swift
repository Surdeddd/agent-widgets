import AWSchema
import Foundation

public struct FeedRecord: Codable, Equatable, Sendable {
    public var lastRun: Date?
    public var lastSuccess: Date?
    public var lastError: String?
}

public enum Scheduler {
    public static let tolerance: TimeInterval = 30

    /// Due when a feed never ran, its settings changed in the app since, or its interval passed; the tolerance absorbs launchd minute boundaries.
    public static func due(
        _ widgets: [WidgetSource],
        records: [String: FeedRecord],
        settingsChanged: [String: Date] = [:],
        now: Date
    ) -> [WidgetSource] {
        widgets.filter { widget in
            guard let feed = widget.manifest.feed else { return false }
            guard let last = records[widget.id]?.lastRun else { return true }
            if let changed = settingsChanged[widget.id], changed > last {
                return true
            }
            return now.timeIntervalSince(last) >= TimeInterval(feed.every.seconds) - tolerance
        }
    }
}

public final class TickLock {
    private let descriptor: Int32

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    public static func acquire(_ url: URL) -> TickLock? {
        let descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        return TickLock(descriptor: descriptor)
    }

    public func release() {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}

public struct TickOutcome: Codable, Sendable {
    public var skipped: Bool
    public var runs: [FeedRun]
    public var reloaded: [String]
}

public struct Ticker: Sendable {
    public static let parallel = 4

    public let workspace: Workspace
    public let store: AppGroupStore
    public let runner: any ProcessRunning

    public init(workspace: Workspace, store: AppGroupStore, runner: any ProcessRunning) {
        self.workspace = workspace
        self.store = store
        self.runner = runner
    }

    public var stateFile: URL {
        workspace.stateDir.appendingPathComponent("feeds.json")
    }

    public func records() -> [String: FeedRecord] {
        (try? Data(contentsOf: stateFile)).flatMap { try? AWJSON.decoder().decode([String: FeedRecord].self, from: $0) } ?? [:]
    }

    public func tick(now: Date = Date(), force: Bool = false, only id: String? = nil) async throws -> TickOutcome {
        try FileManager.default.createDirectory(at: workspace.stateDir, withIntermediateDirectories: true)
        guard let lock = TickLock.acquire(workspace.stateDir.appendingPathComponent("tick.lock")) else {
            return TickOutcome(skipped: true, runs: [], reloaded: [])
        }
        defer { lock.release() }
        var table = records()
        let widgets = try workspace.widgets().filter { id == nil || $0.id == id }
        let due = force
            ? widgets.filter { $0.manifest.feed != nil }
            : Scheduler.due(widgets, records: table, settingsChanged: settingsChanges(widgets), now: now)
        let feeds = FeedRunner(workspace: workspace, store: store, runner: runner, language: workspace.config.locale ?? .current)
        let runs = await Self.runAll(due, feeds: feeds, now: now)
        for run in runs {
            var record = table[run.widget] ?? FeedRecord()
            record.lastRun = now
            if run.ok {
                record.lastSuccess = now
                record.lastError = nil
            } else {
                record.lastError = run.issues.first?.message
            }
            table[run.widget] = record
        }
        try AWJSON.encoder().encode(table).write(to: stateFile, options: .atomic)
        let reloaded = await reload(runs.filter(\.changed), widgets: widgets)
        return TickOutcome(skipped: false, runs: runs, reloaded: reloaded)
    }

    func settingsChanges(_ widgets: [WidgetSource]) -> [String: Date] {
        var changes: [String: Date] = [:]
        for widget in widgets {
            let path = store.url(AppGroupLayout.settings(widget.id)).path
            if let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date {
                changes[widget.id] = date
            }
        }
        return changes
    }

    static func runAll(_ widgets: [WidgetSource], feeds: FeedRunner, now: Date) async -> [FeedRun] {
        await withTaskGroup(of: FeedRun.self) { group in
            var pending = widgets.makeIterator()
            for _ in 0..<parallel {
                guard let widget = pending.next() else { break }
                group.addTask { await feeds.run(widget, now: now) }
            }
            var runs: [FeedRun] = []
            while let run = await group.next() {
                runs.append(run)
                if let widget = pending.next() {
                    group.addTask { await feeds.run(widget, now: now) }
                }
            }
            return runs.sorted { $0.widget < $1.widget }
        }
    }

    private func reload(_ changed: [FeedRun], widgets: [WidgetSource]) async -> [String] {
        let dev = store.devTarget()
        var kinds: [String] = []
        for run in changed {
            guard let manifest = widgets.first(where: { $0.id == run.widget })?.manifest else { continue }
            kinds.append(manifest.resolvedKind)
            if dev?.widget == run.widget && dev?.scenario == nil {
                kinds.append(RegistryGenerator.devKind)
            }
        }
        let reloader = Reloader(config: workspace.config, runner: runner)
        var reloaded: [String] = []
        for kind in kinds where !reloaded.contains(kind) {
            if await reloader.reload(kind: kind) {
                reloaded.append(kind)
            }
        }
        return reloaded
    }
}
