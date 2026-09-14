import AWSchema
import Foundation

extension Doctor {
    func feedChecks(_ workspace: Workspace, store: AppGroupStore, now: Date) -> [DoctorCheck] {
        ((try? workspace.widgets()) ?? []).compactMap { widget in
            widget.manifest.feed.map { feedCheck(widget.id, every: $0.every.seconds, status: store.status(widget: widget.id), now: now) }
        }
    }

    /// One line per feed: ok with its age, the last failure, or STALE_DATA once good data is older than three runs.
    func feedCheck(_ id: String, every: Int, status: FeedStatus?, now: Date) -> DoctorCheck {
        let title = "Feed \(id)"
        guard let status, let fetched = status.fetchedAt else {
            let detail = L10n.pick(en: "no data published yet", ru: "данные ещё не публиковались") + Self.failureNote(status)
            return feedWarning(id, title: title, detail: detail, code: IssueCode.staleData)
        }
        let seconds = now.timeIntervalSince(fetched)
        let age = Self.age(seconds)
        if seconds > TimeInterval(every * 3) {
            let detail = L10n.pick(en: "last good data \(age) ago", ru: "последние хорошие данные \(age) назад") + Self.failureNote(status)
            return feedWarning(id, title: title, detail: detail, code: IssueCode.staleData)
        }
        guard status.ok else {
            let detail = L10n.pick(en: "data from \(age) ago", ru: "данные \(age) назад") + Self.failureNote(status)
            return feedWarning(id, title: title, detail: detail, code: IssueCode.feedFailed)
        }
        return DoctorCheck(id: "feed-\(id)", title: title, status: .pass, detail: L10n.pick(en: "ok \(age) ago", ru: "ok \(age) назад"))
    }

    private func feedWarning(_ id: String, title: String, detail: String, code: String) -> DoctorCheck {
        let hint = L10n.pick(
            en: "Run `aw feed run \(id)` and read `aw logs \(id)`; `aw daemon install` keeps it on schedule",
            ru: "Запусти `aw feed run \(id)` и посмотри `aw logs \(id)`; `aw daemon install` держит его по расписанию"
        )
        return DoctorCheck(
            id: "feed-\(id)",
            title: title,
            status: .warn,
            detail: detail,
            issue: Issue(code: code, severity: .warning, message: "\(title): \(detail)", hint: hint)
        )
    }

    static func failureNote(_ status: FeedStatus?) -> String {
        guard let status, !status.ok else { return "" }
        let fallback = [status.exitCode.map { "exit \($0)" }, status.stderrTail?.last].compactMap { $0 }.joined(separator: ": ")
        let reason = status.error ?? fallback
        return L10n.pick(en: "; the last run failed", ru: "; последний запуск упал") + (reason.isEmpty ? "" : ": \(reason)")
    }

    static func age(_ seconds: TimeInterval) -> String {
        let minutes = max(Int(seconds / 60), 0)
        guard minutes >= 60 else { return L10n.pick(en: "\(minutes) min", ru: "\(minutes) мин") }
        let hours = minutes / 60
        guard hours >= 48 else { return L10n.pick(en: "\(hours) h", ru: "\(hours) ч") }
        return L10n.pick(en: "\(hours / 24) d", ru: "\(hours / 24) д")
    }
}
