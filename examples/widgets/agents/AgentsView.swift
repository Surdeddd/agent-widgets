import AWKit
import SwiftUI

struct AgentSession: Codable, Sendable, Identifiable {
    let id: String
    let agent: String
    let project: String
    let branch: String?
    let title: String?
    let state: String
    let since: Date
}

struct AgentHour: Codable, Sendable {
    let hour: Date
    let sessions: Int
}

struct AgentsData: Codable, Sendable {
    let working: Int
    let waiting: Int
    let silent: Int
    let sessions: [AgentSession]
    let today: Int
    let activity: [AgentHour]?
}

struct AgentsView: AWView {
    let entry: AWEntry<AgentsData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<AgentsData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(context.pick(en: "Agents", ru: "Агенты"), symbol: "person.2.wave.2", entry: entry)
                if data.sessions.isEmpty {
                    AWEmptyState(
                        symbol: "moon.zzz",
                        title: context.pick(en: "All quiet", ru: "Тишина"),
                        subtitle: context.pick(en: "No agent sessions right now", ru: "Сейчас нет сессий агентов")
                    )
                } else {
                    layout(data)
                }
            }
        }
    }

    @ViewBuilder
    private func layout(_ data: AgentsData) -> some View {
        switch context.family {
        case .small:
            HStack(alignment: .center, spacing: AWSpace.s) {
                AWText("\(data.waiting > 0 ? data.waiting : data.working)", .hero)
                    .foregroundStyle(data.waiting > 0 ? AWStatus.warning.tint(context) : Color.primary)
                AWText(heroLabel(data) + "\n" + tally(data, short: false), .caption, lines: 3)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let first = data.sessions.first {
                AWText(first.project, .headline, lines: 2)
                HStack(spacing: AWSpace.xs) {
                    AWText(first.agent == "codex" ? "Codex" : "Claude", .caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: AWSpace.xxs)
                    timer(first.since)
                }
            }
        case .medium:
            HStack(alignment: .top, spacing: AWSpace.l) {
                VStack(alignment: .leading, spacing: AWSpace.xxs) {
                    hero(data)
                    Spacer(minLength: 0)
                    AWText(tally(data, short: false), .caption, lines: 2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 96, alignment: .leading)
                rows(data, count: 3, detailed: false)
            }
        case .large:
            summary(data)
            rows(data, count: 5, detailed: true)
            Spacer(minLength: 0)
            footer(data)
        case .extraLarge:
            HStack(alignment: .top, spacing: AWSpace.xl) {
                VStack(alignment: .leading, spacing: AWSpace.xs) {
                    hero(data)
                    AWText(tally(data, short: true), .caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: AWSpace.s)
                    pulse(data)
                    footer(data)
                }
                .frame(width: 190, alignment: .leading)
                rows(data, count: 6, detailed: true)
            }
        }
    }

    @ViewBuilder
    private func hero(_ data: AgentsData) -> some View {
        let needsYou = data.waiting > 0
        AWText("\(needsYou ? data.waiting : data.working)", .hero)
            .foregroundStyle(needsYou ? AWStatus.warning.tint(context) : Color.primary)
        AWText(heroLabel(data), .caption)
            .foregroundStyle(.secondary)
    }

    private func heroLabel(_ data: AgentsData) -> String {
        data.waiting > 0 ? waitLabel(data.waiting) : workLabel(data.working)
    }

    @ViewBuilder
    private func summary(_ data: AgentsData) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AWSpace.s) {
            AWText("\(data.waiting > 0 ? data.waiting : data.working)", .display)
                .foregroundStyle(data.waiting > 0 ? AWStatus.warning.tint(context) : Color.primary)
            AWText(data.waiting > 0 ? waitLabel(data.waiting) : workLabel(data.working), .body)
            Spacer(minLength: 0)
            AWText(tally(data, short: true), .caption)
                .foregroundStyle(.secondary)
        }
    }

    private func rows(_ data: AgentsData, count: Int, detailed: Bool) -> some View {
        VStack(alignment: .leading, spacing: detailed ? AWSpace.s : AWSpace.xs) {
            ForEach(data.sessions.prefix(count)) { session in
                row(session, detailed: detailed)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ session: AgentSession, detailed: Bool) -> some View {
        HStack(alignment: .center, spacing: AWSpace.s) {
            Image(systemName: symbol(session.state))
                .font(.system(size: AWType.size(.body, context.family), weight: .semibold))
                .foregroundStyle(status(session.state).tint(context))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                AWText(session.project, .headline)
                AWText(detail(session, detailed: detailed), .caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AWSpace.xs)
            timer(session.since)
        }
    }

    private func timer(_ since: Date) -> some View {
        Text(since, style: .timer)
            .font(AWType.font(.caption, context.family))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .frame(width: 54, alignment: .trailing)
    }

    @ViewBuilder
    private func pulse(_ data: AgentsData) -> some View {
        let hours = data.activity ?? []
        if hours.contains(where: { $0.sessions > 0 }) {
            AWText(context.pick(en: "sessions by hour", ru: "сессии по часам"), .label)
                .foregroundStyle(.secondary)
            AWBarChart(hours.enumerated().map { index, item in
                AWBarItem(index % 3 == 2 ? hourLabel(item.hour) : "", Double(item.sessions), highlighted: index == hours.count - 1, id: "\(index)")
            }, tint: .green)
            .frame(height: 104)
        }
    }

    private func hourLabel(_ hour: Date) -> String {
        String(format: "%02d", Calendar.current.component(.hour, from: hour))
    }

    @ViewBuilder
    private func footer(_ data: AgentsData) -> some View {
        AWText(context.pick(en: "\(data.today) sessions today", ru: "сессий сегодня: \(data.today)"), .caption)
            .foregroundStyle(.tertiary)
    }

    private func detail(_ session: AgentSession, detailed: Bool) -> String {
        let agent = session.agent == "codex" ? "Codex" : "Claude"
        guard detailed else {
            return agent
        }
        return "\(agent) · \(session.title ?? session.branch ?? stateLabel(session.state))"
    }

    private func stateLabel(_ state: String) -> String {
        switch state {
        case "waiting": context.pick(en: "waiting for you", ru: "ждёт тебя")
        case "silent": context.pick(en: "gone silent", ru: "затих")
        default: context.pick(en: "working", ru: "работает")
        }
    }

    private func symbol(_ state: String) -> String {
        switch state {
        case "waiting": "exclamationmark.bubble.fill"
        case "silent": "pause.circle.fill"
        default: "bolt.fill"
        }
    }

    private func status(_ state: String) -> AWStatus {
        switch state {
        case "waiting": .warning
        case "silent": .neutral
        default: .ok
        }
    }

    private func waitLabel(_ count: Int) -> String {
        context.pick(en: count == 1 ? "waits for you" : "wait for you", ru: count == 1 ? "ждёт тебя" : "ждут тебя")
    }

    private func workLabel(_ count: Int) -> String {
        context.pick(en: "working", ru: count == 1 ? "работает" : "работают")
    }

    private func tally(_ data: AgentsData, short: Bool) -> String {
        var parts: [String] = []
        if data.waiting > 0 {
            parts.append(context.pick(en: "\(data.working) working", ru: "\(data.working) в работе"))
        }
        if data.silent > 0 {
            parts.append(context.pick(en: "\(data.silent) silent", ru: "\(data.silent) затихли"))
        }
        if parts.isEmpty {
            return context.pick(en: "nobody waits", ru: "никто не ждёт")
        }
        return parts.joined(separator: short ? " · " : "\n")
    }
}
