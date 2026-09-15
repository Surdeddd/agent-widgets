import AWCore
import AWSchema
import Foundation
import MCP

struct JobInfo: Codable, Equatable, Sendable {
    let id: String
    let tool: String
    let stage: String
    let elapsed: Double
}

struct RunningPayload: Codable, Sendable {
    let job: JobInfo
}

final class JobStage: @unchecked Sendable {
    private let lock = NSLock()
    private var text: String

    init(_ text: String) {
        self.text = text
    }

    var current: String {
        lock.withLock { text }
    }

    func set(_ text: String) {
        lock.withLock { self.text = text }
    }
}

actor JobCenter {
    private struct Entry {
        let id: String
        let tool: String
        let key: String
        let started: Date
        let stage: JobStage
        var task: Task<Void, Never>?
        var cancelled = false
        var result: CallTool.Result?
        var finished: Date?
    }

    private var entries: [String: Entry] = [:]
    private let retention: TimeInterval

    init(retention: TimeInterval = 900) {
        self.retention = retention
    }

    /// Joins the unfinished job with the same key, or starts `work` as a new job that outlives the call that started it.
    nonisolated func start(
        tool: String,
        key: String,
        stage: String,
        work: @escaping @Sendable (JobStage) async throws -> CallTool.Result
    ) async -> String {
        let progress = JobStage(stage)
        let (id, fresh) = await register(tool: tool, key: key, stage: progress)
        guard fresh else { return id }
        let task = Task {
            let result: CallTool.Result
            do {
                result = try await work(progress)
            } catch is CancellationError {
                await self.drop(id)
                return
            } catch let error as AWError {
                result = Reply.failure([error.issue])
            } catch {
                result = Reply.failure([Issue(code: "UNEXPECTED", severity: .error, message: String(describing: error))])
            }
            guard !Task.isCancelled else {
                await self.drop(id)
                return
            }
            await self.finish(id, result: result)
        }
        await attach(id, task: task)
        return id
    }

    /// Waits for the job up to `window` seconds (nil: until it ends), reporting its stage; a cancelled wait cancels the job.
    nonisolated func follow(
        _ id: String,
        window: TimeInterval?,
        progress: ProgressReporter,
        poll: TimeInterval = 0.2
    ) async throws -> CallTool.Result {
        let deadline = window.map { Date().addingTimeInterval($0) }
        var reported: String?
        var pulse = Date()
        do {
            while true {
                if let result = await result(id) {
                    return result
                }
                guard let info = await info(id) else {
                    return Reply.failure([JobIssues.unknown(id)])
                }
                if info.stage != reported || Date().timeIntervalSince(pulse) >= 10 {
                    await progress.report(info.stage, elapsed: info.elapsed)
                    reported = info.stage
                    pulse = Date()
                }
                if let deadline, Date() >= deadline {
                    return Reply.running(info)
                }
                try await Task.sleep(nanoseconds: UInt64(poll * 1_000_000_000))
            }
        } catch is CancellationError {
            await cancel(id)
            throw CancellationError()
        }
    }

    func info(_ id: String) -> JobInfo? {
        guard let entry = entries[id] else { return nil }
        return JobInfo(id: entry.id, tool: entry.tool, stage: entry.stage.current, elapsed: Date().timeIntervalSince(entry.started))
    }

    func result(_ id: String) -> CallTool.Result? {
        entries[id]?.result
    }

    func cancel(_ id: String) {
        guard var entry = entries[id], entry.result == nil else { return }
        entry.cancelled = true
        entry.task?.cancel()
        entries[id] = entry
    }

    private func register(tool: String, key: String, stage: JobStage) -> (String, Bool) {
        prune()
        if let running = entries.values.first(where: { $0.key == key && $0.result == nil && !$0.cancelled }) {
            return (running.id, false)
        }
        let id = "job-" + UUID().uuidString.prefix(8).lowercased()
        entries[id] = Entry(id: id, tool: tool, key: key, started: Date(), stage: stage)
        return (id, true)
    }

    private func attach(_ id: String, task: Task<Void, Never>) {
        entries[id]?.task = task
        if entries[id]?.cancelled == true {
            task.cancel()
        }
    }

    private func finish(_ id: String, result: CallTool.Result) {
        entries[id]?.result = result
        entries[id]?.finished = Date()
    }

    private func drop(_ id: String) {
        entries[id] = nil
    }

    private func prune() {
        let now = Date()
        entries = entries.filter { _, entry in
            entry.finished.map { now.timeIntervalSince($0) < retention } ?? true
        }
    }
}

enum JobIssues {
    static func unknown(_ id: String) -> Issue {
        Issue(
            code: IssueCode.jobUnknown,
            severity: .error,
            message: L10n.pick(
                en: "No job \(id): it finished more than 15 minutes ago, was cancelled, or the server restarted",
                ru: "Нет задания \(id): оно закончилось больше 15 минут назад, отменено или сервер перезапущен"
            ),
            hint: L10n.pick(en: "Call the original tool again", ru: "Вызови исходный инструмент ещё раз")
        )
    }
}

extension Reply {
    static func running(_ info: JobInfo) -> CallTool.Result {
        let text = L10n.pick(
            en: "… \(info.tool) is still running: \(info.stage) (\(Int(info.elapsed)) s). Call aw_wait with {\"job\": \"\(info.id)\"} to keep waiting.",
            ru: "… \(info.tool) ещё идёт: \(info.stage) (\(Int(info.elapsed)) с). Вызови aw_wait с {\"job\": \"\(info.id)\"}, чтобы ждать дальше."
        )
        return make(text, payload: RunningPayload(job: info))
    }
}
