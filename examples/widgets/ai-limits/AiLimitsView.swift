import AWKit
import SwiftUI

struct AiLimitsWindow: Codable, Sendable {
    let percent: Double
    let resetsAt: Date?
    let windowHours: Double?
}

struct AiLimitsModel: Codable, Sendable, Identifiable {
    let label: String
    let percent: Double

    var id: String { label }
}

struct AiLimitsPoint: Codable, Sendable {
    let at: Date
    let session: Double?
    let week: Double?
}

struct AiLimitsService: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let plan: String?
    let state: String
    let session: AiLimitsWindow?
    let week: AiLimitsWindow?
    let models: [AiLimitsModel]?
    let asOf: Date?
    let history: [AiLimitsPoint]?
}

struct AiLimitsWorst: Codable, Sendable {
    let service: String
    let scope: String
    let percent: Double
    let resetsAt: Date?
    let windowHours: Double?
}

struct AiLimitsData: Codable, Sendable {
    let services: [AiLimitsService]
    let worst: AiLimitsWorst?
}

struct AiLimitsView: AWView {
    let entry: AWEntry<AiLimitsData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<AiLimitsData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(context.pick(en: "AI limits", ru: "Лимиты AI"), symbol: "gauge.with.needle", entry: entry)
                if let worst = data.worst {
                    layout(data, worst: worst)
                } else {
                    AWEmptyState(
                        symbol: "person.badge.key",
                        title: context.pick(en: "No usage data", ru: "Нет данных"),
                        subtitle: signInHint(data)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func layout(_ data: AiLimitsData, worst: AiLimitsWorst) -> some View {
        switch context.family {
        case .small:
            smallBody(worst)
        case .medium:
            mediumBody(data, worst: worst)
        case .large:
            largeBody(data, worst: worst)
        case .extraLarge:
            wideBody(data, worst: worst)
        }
    }

    @ViewBuilder
    private func smallBody(_ worst: AiLimitsWorst) -> some View {
        ring(worst, lineWidth: 7)
            .frame(maxWidth: .infinity)
        Spacer(minLength: 0)
        AWText("\(worst.service) · \(scopeLabel(worst.scope))", .caption)
            .foregroundStyle(.secondary)
        resetLine(worst.resetsAt)
    }

    private func mediumBody(_ data: AiLimitsData, worst: AiLimitsWorst) -> some View {
        HStack(alignment: .top, spacing: AWSpace.l) {
            VStack(alignment: .leading, spacing: AWSpace.xxs) {
                AWText(percentText(remaining(worst.percent)), .hero)
                AWText(leftCaption(worst), .caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                resetLine(worst.resetsAt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: AWSpace.s) {
                ForEach(data.services.prefix(2)) { service in
                    compactBlock(service)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func largeBody(_ data: AiLimitsData, worst: AiLimitsWorst) -> some View {
        HStack(alignment: .center, spacing: AWSpace.l) {
            ring(worst, lineWidth: 8)
                .frame(width: 80, height: 80)
            summary(data, worst: worst)
            Spacer(minLength: 0)
        }
        VStack(alignment: .leading, spacing: AWSpace.s) {
            ForEach(data.services.prefix(2)) { service in
                serviceBlock(service, models: 0, paced: data.services.count == 1)
            }
        }
        Spacer(minLength: 0)
    }

    private func wideBody(_ data: AiLimitsData, worst: AiLimitsWorst) -> some View {
        HStack(alignment: .top, spacing: AWSpace.xl) {
            VStack(alignment: .leading, spacing: AWSpace.m) {
                ring(worst)
                    .frame(width: 168, height: 168)
                summary(data, worst: worst)
                Spacer(minLength: 0)
            }
            .frame(width: 196, alignment: .leading)
            ForEach(data.services.prefix(2)) { service in
                VStack(alignment: .leading, spacing: AWSpace.s) {
                    serviceBlock(service, models: 1, paced: true)
                    trend(service)
                    updated(service)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func summary(_ data: AiLimitsData, worst: AiLimitsWorst) -> some View {
        VStack(alignment: .leading, spacing: AWSpace.xs) {
            AWText("\(worst.service) · \(scopeLabel(worst.scope))", .title)
            resetLine(worst.resetsAt)
            forecast(worst)
        }
    }

    private func leftCaption(_ worst: AiLimitsWorst) -> String {
        let scope = "\(worst.service) \(scopeLabel(worst.scope))"
        return context.pick(en: "left · \(scope)", ru: "осталось · \(scope)")
    }

    private func ring(_ worst: AiLimitsWorst, lineWidth: CGFloat? = nil) -> some View {
        let left = remaining(worst.percent)
        return AWRing(progress: left / 100, tint: status(left).color, lineWidth: lineWidth) {
            VStack(spacing: 0) {
                AWText(percentText(left), .display)
                AWText(context.pick(en: "left", ru: "осталось"), .label)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func serviceTitle(_ service: AiLimitsService) -> some View {
        HStack(spacing: AWSpace.xs) {
            AWText(service.name, .headline)
            if let plan = service.plan {
                AWText(plan, .label)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AWSpace.xxs)
            if service.state == "stale" {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: AWType.size(.caption, context.family), weight: .semibold))
                    .foregroundStyle(AWStatus.warning.tint(context))
            }
        }
    }

    private func compactBlock(_ service: AiLimitsService) -> some View {
        VStack(alignment: .leading, spacing: AWSpace.xs) {
            serviceTitle(service)
            if let note = stateNote(service.state) {
                AWText(note, .caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: AWSpace.m) {
                    windowRow(context.pick(en: "5h", ru: "5 ч"), window: service.session, paced: false)
                    windowRow(context.pick(en: "week", ru: "неделя"), window: service.week, paced: false)
                }
            }
        }
    }

    private func serviceBlock(_ service: AiLimitsService, models: Int, paced: Bool) -> some View {
        VStack(alignment: .leading, spacing: paced ? AWSpace.s : AWSpace.xs) {
            serviceTitle(service)
            if let note = stateNote(service.state) {
                AWText(note, .caption)
                    .foregroundStyle(.secondary)
            } else {
                windowRow(context.pick(en: "5-hour window", ru: "окно 5 часов"), window: service.session, paced: paced)
                windowRow(context.pick(en: "week", ru: "неделя"), window: service.week, paced: paced)
                ForEach((service.models ?? []).prefix(models)) { model in
                    windowRow(model.label, window: AiLimitsWindow(percent: model.percent, resetsAt: nil, windowHours: nil), paced: false)
                }
            }
        }
    }

    @ViewBuilder
    private func trend(_ service: AiLimitsService) -> some View {
        let points = (service.history ?? []).compactMap { point in point.week.map { AiLimitsPace.Sample(at: point.at, value: 100 - $0) } }
        let left = AiLimitsPace.series(points, current: service.week.map { 100 - $0.percent }, now: entry.date)
        if left.count > 3 {
            AWText(trendLabel(AiLimitsPace.span(points, now: entry.date)), .label)
                .foregroundStyle(.secondary)
            AWSparkline(left, tint: .green)
                .frame(maxHeight: .infinity)
        } else {
            Spacer(minLength: 0)
        }
    }

    private func trendLabel(_ span: TimeInterval) -> String {
        let days = Int((span / 86400).rounded())
        let hours = max(1, Int((span / 3600).rounded()))
        if span >= 36 * 3600 {
            return context.pick(en: "week left, last \(days) d", ru: "остаток недели, \(days) дн")
        }
        return context.pick(en: "week left, last \(hours) h", ru: "остаток недели, \(hours) ч")
    }

    @ViewBuilder
    private func updated(_ service: AiLimitsService) -> some View {
        if let asOf = service.asOf, entry.date.timeIntervalSince(asOf) > 3600 {
            AWText(AWFormat.updated(asOf, now: entry.date, language: context.language), .caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func windowRow(_ label: String, window: AiLimitsWindow?, paced: Bool) -> some View {
        if let window {
            let left = remaining(window.percent)
            let elapsed = paced ? elapsedShare(window) : nil
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AWSpace.xs) {
                    AWText(label, .caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: AWSpace.xxs)
                    AWText(percentText(left), .caption)
                        .monospacedDigit()
                }
                AWBar(progress: left / 100, tint: status(left).color)
                    .overlay(alignment: .leading) { paceMark(elapsed) }
                if paced {
                    HStack(spacing: AWSpace.xs) {
                        AWText(paceText(window, elapsed: elapsed), .caption)
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: AWSpace.xxs)
                        resetMoment(window.resetsAt)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func paceMark(_ elapsed: Double?) -> some View {
        if let elapsed {
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 2, height: proxy.size.height + 6)
                    .offset(x: proxy.size.width * (1 - elapsed) - 1, y: -3)
            }
        }
    }

    @ViewBuilder
    private func resetMoment(_ resetsAt: Date?) -> some View {
        if let resetsAt, resetsAt > entry.date {
            if resetsAt.timeIntervalSince(entry.date) > 86400 {
                Text(resetsAt, format: .dateTime.weekday(.abbreviated).hour().minute().locale(context.locale))
                    .font(AWType.font(.caption, context.family))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else {
                Text(resetsAt, style: .timer)
                    .font(AWType.font(.caption, context.family))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func resetLine(_ resetsAt: Date?) -> some View {
        if let resetsAt, resetsAt > entry.date {
            HStack(spacing: AWSpace.xs) {
                AWText(context.pick(en: "resets in", ru: "сброс через"), .caption)
                    .foregroundStyle(.secondary)
                Text(resetsAt, style: .timer)
                    .font(AWType.font(.caption, context.family))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func forecast(_ worst: AiLimitsWorst) -> some View {
        if let runsOut = AiLimitsPace.runsOut(percent: worst.percent, resetsAt: worst.resetsAt, windowHours: worst.windowHours, now: entry.date) {
            HStack(spacing: AWSpace.xs) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: AWType.size(.caption, context.family), weight: .semibold))
                    .foregroundStyle(AWStatus.warning.tint(context))
                AWText(context.pick(en: "runs out at", ru: "кончится в"), .caption)
                    .foregroundStyle(.secondary)
                Text(runsOut, style: .time)
                    .font(AWType.font(.caption, context.family))
                    .monospacedDigit()
            }
        }
    }

    private func elapsedShare(_ window: AiLimitsWindow) -> Double? {
        AiLimitsPace.elapsed(resetsAt: window.resetsAt, windowHours: window.windowHours, now: entry.date).flatMap { $0 > 0.04 ? $0 : nil }
    }

    private func paceText(_ window: AiLimitsWindow, elapsed: Double?) -> String {
        guard let elapsed else {
            return context.pick(en: "just started", ru: "только началось")
        }
        let pace = window.percent / 100 / elapsed
        if pace > 1.15 {
            return context.pick(en: String(format: "%.1f× the even pace", pace), ru: String(format: "%.1f× к ровному темпу", pace))
        }
        if pace < 0.85 {
            return context.pick(en: "under the even pace", ru: "ниже ровного темпа")
        }
        return context.pick(en: "on the even pace", ru: "ровный темп")
    }

    private func signInHint(_ data: AiLimitsData) -> String {
        if data.services.contains(where: { $0.state == "no-auth" || $0.state == "expired" }) {
            return context.pick(en: "Sign in to Claude Code, then run the feed", ru: "Войди в Claude Code и запусти feed")
        }
        return context.pick(en: "Use an agent, and the windows appear", ru: "Поработай агентом — окна появятся")
    }

    private func stateNote(_ state: String) -> String? {
        switch state {
        case "no-auth": context.pick(en: "not signed in", ru: "нет входа")
        case "expired": context.pick(en: "session expired", ru: "сессия истекла")
        case "absent": context.pick(en: "not used yet", ru: "ещё не использован")
        case "error": context.pick(en: "no answer", ru: "нет ответа")
        default: nil
        }
    }

    private func scopeLabel(_ scope: String) -> String {
        scope == "week" ? context.pick(en: "week", ru: "неделя") : context.pick(en: "5h", ru: "5 ч")
    }

    private func remaining(_ percent: Double) -> Double {
        min(max(100 - percent, 0), 100)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func status(_ left: Double) -> AWStatus {
        if left < 15 {
            return .critical
        }
        return left < 40 ? .warning : .ok
    }
}
