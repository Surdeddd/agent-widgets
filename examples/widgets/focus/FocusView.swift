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
                    dial(phase, config: config)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    controls(phase, state: state, config: config)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(alignment: .center, spacing: AWSpace.l) {
                        dial(phase, config: config)
                            .frame(width: 104, height: 104)
                        VStack(alignment: .leading, spacing: AWSpace.xs) {
                            AWText(title(phase), .title)
                            AWText(context.pick(en: "\(state.sessionsToday) sessions today", ru: "сессий сегодня: \(state.sessionsToday)"), .caption)
                                .foregroundStyle(.secondary)
                            AWText(
                                context.pick(en: "\(config.focusMinutes)m focus · \(config.breakMinutes)m break", ru: "\(config.focusMinutes) мин фокус · \(config.breakMinutes) мин перерыв"),
                                .caption
                            )
                            .foregroundStyle(.tertiary)
                            Spacer(minLength: 0)
                            controls(phase, state: state, config: config)
                        }
                    }
                }
            }
        }
    }

    private func dial(_ phase: ResolvedPhase, config: FocusConfig) -> some View {
        let total = Double(max(config.focusMinutes, 1) * 60)
        return AWRing(progress: fraction(phase, total: total), tint: tint(phase), lineWidth: context.isSmall ? 6 : 8) {
            face(phase, config: config)
        }
    }

    @ViewBuilder
    private func face(_ phase: ResolvedPhase, config: FocusConfig) -> some View {
        let size: CGFloat = context.isSmall ? 17 : 22
        switch phase {
        case .idle:
            clock(Self.formatDuration(config.focusMinutes * 60), size: size)
        case .running(let endsAt):
            Text(endsAt, style: .timer)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: context.isSmall ? 54 : 70)
        case .paused(let remaining):
            clock(Self.formatDuration(remaining), size: size)
                .foregroundStyle(.secondary)
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: size * 1.2, weight: .bold))
                .foregroundStyle(AWStatus.ok.tint(context))
        }
    }

    private func clock(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func fraction(_ phase: ResolvedPhase, total: Double) -> Double {
        switch phase {
        case .idle: 1
        case .running(let endsAt): min(max(endsAt.timeIntervalSince(entry.date) / total, 0), 1)
        case .paused(let remaining): min(max(Double(remaining) / total, 0), 1)
        case .completed: 1
        }
    }

    private func tint(_ phase: ResolvedPhase) -> Color {
        switch phase {
        case .running: .orange
        case .completed: .green
        default: .secondary
        }
    }

    private func title(_ phase: ResolvedPhase) -> String {
        switch phase {
        case .idle: context.pick(en: "Ready", ru: "Готов")
        case .running: context.pick(en: "In focus", ru: "В фокусе")
        case .paused: context.pick(en: "Paused", ru: "Пауза")
        case .completed: context.pick(en: "Done", ru: "Готово")
        }
    }

    private func controls(_ phase: ResolvedPhase, state: SessionState, config: FocusConfig) -> some View {
        HStack(spacing: AWSpace.s) {
            switch phase {
            case .idle:
                key("play.fill", Self.startValue(state: state, bonus: false, focusMinutes: config.focusMinutes, now: entry.date))
            case .running(let endsAt):
                key("pause.fill", Self.pauseValue(endsAt: endsAt, state: state, now: entry.date))
                key("arrow.counterclockwise", Self.resetValue(state: state, bonus: false))
            case .paused(let remaining):
                key("play.fill", Self.resumeValue(remaining: remaining, state: state, now: entry.date))
                key("arrow.counterclockwise", Self.resetValue(state: state, bonus: false))
            case .completed:
                key("play.fill", Self.startValue(state: state, bonus: true, focusMinutes: config.focusMinutes, now: entry.date))
                key("arrow.counterclockwise", Self.resetValue(state: state, bonus: true))
            }
        }
    }

    private func key(_ symbol: String, _ value: String) -> some View {
        let height: CGFloat = context.isSmall ? 24 : 28
        return AWButton(.set, key: "session", value: value) {
            Image(systemName: symbol)
                .font(.system(size: height * 0.44, weight: .bold))
                .frame(width: context.isSmall ? 44 : 52, height: height)
                .background(RoundedRectangle(cornerRadius: height * 0.3, style: .continuous).fill(Color.primary.opacity(0.12)))
        }
    }

    private static func resolve(_ state: SessionState, now: Date) -> ResolvedPhase {
        switch state.phase {
        case "running":
            guard let endsAt = AWJSON.parseDate(state.payload, now: now) else { return .idle }
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
