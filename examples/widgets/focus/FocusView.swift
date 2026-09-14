import AWKit
import SwiftUI

struct FocusConfig: Codable, Sendable {
    let focusMinutes: Int
    let breakMinutes: Int
}

private struct SessionState {
    var phase: String
    var payload: String
    var sessionsToday: Int

    static let idle = SessionState(phase: "idle", payload: "0", sessionsToday: 0)

    func encoded() -> String { "\(phase)|\(payload)|\(sessionsToday)" }

    static func parse(_ raw: String) -> SessionState {
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let sessions = Int(parts[2]) else { return .idle }
        return SessionState(phase: parts[0], payload: parts[1], sessionsToday: sessions)
    }
}

private enum ResolvedPhase {
    case idle
    case running(Date)
    case paused(Int)
    case completed
}

private let focusISOFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

struct FocusView: AWView {
    static var tick: AWTick { .everyMinute(count: 60) }

    let entry: AWEntry<FocusConfig>
    @Environment(\.aw) private var context

    init(entry: AWEntry<FocusConfig>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { config in
            let state = SessionState.parse(entry.state.string("session") ?? "")
            let phase = Self.resolve(state, now: entry.date)
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(context.pick(en: "Focus", ru: "Фокус"), symbol: "timer", entry: entry)
                if context.isSmall {
                    smallBody(phase, state: state, config: config)
                } else {
                    mediumBody(phase, state: state, config: config)
                }
            }
        }
    }

    @ViewBuilder
    private func smallBody(_ phase: ResolvedPhase, state: SessionState, config: FocusConfig) -> some View {
        hero(phase, config: config)
        Spacer(minLength: 0)
        todayLabel(state)
        controls(phase, state: state, config: config)
    }

    @ViewBuilder
    private func mediumBody(_ phase: ResolvedPhase, state: SessionState, config: FocusConfig) -> some View {
        HStack(alignment: .center, spacing: AWSpace.m) {
            VStack(alignment: .leading, spacing: AWSpace.xs) {
                hero(phase, config: config)
                todayLabel(state)
            }
            Spacer(minLength: AWSpace.s)
            VStack(alignment: .trailing, spacing: AWSpace.s) {
                AWText(context.pick(en: "\(config.breakMinutes)m break", ru: "\(config.breakMinutes) мин перерыв"), .caption)
                    .foregroundStyle(.secondary)
                controls(phase, state: state, config: config)
            }
        }
    }

    @ViewBuilder
    private func hero(_ phase: ResolvedPhase, config: FocusConfig) -> some View {
        switch phase {
        case .idle:
            AWMetric(Self.formatDuration(config.focusMinutes * 60), label: context.isSmall ? nil : context.pick(en: "ready", ru: "готово"))
        case .running(let endsAt):
            AWCountdown(to: endsAt, label: context.isSmall ? nil : context.pick(en: "focus", ru: "фокус"))
                .foregroundStyle(context.isVibrant ? Color.primary : Color.orange)
        case .paused(let remaining):
            AWMetric(Self.formatDuration(remaining), label: context.isSmall ? nil : context.pick(en: "paused", ru: "пауза"))
                .foregroundStyle(.secondary)
        case .completed:
            AWMetric(context.pick(en: "Done", ru: "Готово"), label: context.isSmall ? nil : context.pick(en: "great work", ru: "отличная работа"))
        }
    }

    @ViewBuilder
    private func todayLabel(_ state: SessionState) -> some View {
        AWText(context.pick(en: "Today \(state.sessionsToday)", ru: "Сегодня \(state.sessionsToday)"), .caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func controls(_ phase: ResolvedPhase, state: SessionState, config: FocusConfig) -> some View {
        HStack(spacing: AWSpace.s) {
            switch phase {
            case .idle:
                AWButton(.set, symbol: "play.fill", key: "session", value: Self.startValue(state: state, bonus: false, focusMinutes: config.focusMinutes, now: entry.date))
            case .running(let endsAt):
                AWButton(.set, symbol: "pause.fill", key: "session", value: Self.pauseValue(endsAt: endsAt, state: state, now: entry.date))
                AWButton(.set, symbol: "arrow.counterclockwise", key: "session", value: Self.resetValue(state: state, bonus: false))
            case .paused(let remaining):
                AWButton(.set, symbol: "play.fill", key: "session", value: Self.resumeValue(remaining: remaining, state: state, now: entry.date))
                AWButton(.set, symbol: "arrow.counterclockwise", key: "session", value: Self.resetValue(state: state, bonus: false))
            case .completed:
                AWButton(.set, symbol: "play.fill", key: "session", value: Self.startValue(state: state, bonus: true, focusMinutes: config.focusMinutes, now: entry.date))
                AWButton(.set, symbol: "arrow.counterclockwise", key: "session", value: Self.resetValue(state: state, bonus: true))
            }
        }
    }

    private static func resolve(_ state: SessionState, now: Date) -> ResolvedPhase {
        switch state.phase {
        case "running":
            guard let endsAt = focusISOFormatter.date(from: state.payload) else { return .idle }
            return endsAt > now ? .running(endsAt) : .completed
        case "paused":
            return .paused(Int(state.payload) ?? 0)
        default:
            return .idle
        }
    }

    private static func startValue(state: SessionState, bonus: Bool, focusMinutes: Int, now: Date) -> String {
        let endsAt = now.addingTimeInterval(Double(focusMinutes) * 60)
        let sessions = state.sessionsToday + (bonus ? 1 : 0)
        return SessionState(phase: "running", payload: focusISOFormatter.string(from: endsAt), sessionsToday: sessions).encoded()
    }

    private static func pauseValue(endsAt: Date, state: SessionState, now: Date) -> String {
        let remaining = max(0, Int(endsAt.timeIntervalSince(now).rounded()))
        return SessionState(phase: "paused", payload: "\(remaining)", sessionsToday: state.sessionsToday).encoded()
    }

    private static func resumeValue(remaining: Int, state: SessionState, now: Date) -> String {
        let endsAt = now.addingTimeInterval(Double(remaining))
        return SessionState(phase: "running", payload: focusISOFormatter.string(from: endsAt), sessionsToday: state.sessionsToday).encoded()
    }

    private static func resetValue(state: SessionState, bonus: Bool) -> String {
        let sessions = state.sessionsToday + (bonus ? 1 : 0)
        return SessionState(phase: "idle", payload: "0", sessionsToday: sessions).encoded()
    }

    private static func formatDuration(_ totalSeconds: Int) -> String {
        let clamped = max(totalSeconds, 0)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
