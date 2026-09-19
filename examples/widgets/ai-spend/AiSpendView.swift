import AWKit
import SwiftUI

struct AiSpendDay: Codable, Sendable {
    let date: String
    let usd: Double
    let tokens: Int
}

struct AiSpendModel: Codable, Sendable, Identifiable {
    let label: String
    let usd: Double
    let tokens: Int

    var id: String { label }
}

struct AiSpendData: Codable, Sendable {
    let todayUsd: Double
    let weekUsd: Double
    let monthUsd: Double
    let monthTokens: Int
    let days: [AiSpendDay]
    let byModel: [AiSpendModel]
    let planUsd: Double?
    let leverage: Double?
    let unpricedTokens: Int
    let pricesAsOf: String
    let codexTokens: Int
}

struct AiSpendView: AWView {
    let entry: AWEntry<AiSpendData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<AiSpendData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(context.pick(en: "AI spend", ru: "Расход AI"), symbol: "dollarsign.circle", entry: entry)
                switch context.family {
                case .small:
                    smallBody(data)
                case .medium:
                    mediumBody(data)
                default:
                    largeBody(data)
                }
            }
        }
    }

    @ViewBuilder
    private func smallBody(_ data: AiSpendData) -> some View {
        AWText(Self.money(data.todayUsd), .hero)
        AWText(context.pick(en: "today · API value", ru: "сегодня · по ценам API"), .caption)
            .foregroundStyle(.secondary)
        Spacer(minLength: 0)
        figure(Self.money(data.weekUsd), context.pick(en: "7 days", ru: "7 дней"), role: .title)
    }

    private func mediumBody(_ data: AiSpendData) -> some View {
        HStack(alignment: .top, spacing: AWSpace.l) {
            VStack(alignment: .leading, spacing: AWSpace.xxs) {
                AWText(Self.money(data.todayUsd), .hero)
                AWText(context.pick(en: "today · API value", ru: "сегодня · по ценам API"), .caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                figure(Self.money(data.weekUsd), context.pick(en: "7 days", ru: "7 дней"), role: .title)
            }
            .frame(width: 132, alignment: .leading)
            chart(data, count: 14)
        }
    }

    @ViewBuilder
    private func largeBody(_ data: AiSpendData) -> some View {
        HStack(alignment: .top, spacing: AWSpace.xl) {
            figure(Self.money(data.todayUsd), context.pick(en: "today", ru: "сегодня"), role: .display)
            figure(Self.money(data.weekUsd), context.pick(en: "7 days", ru: "7 дней"), role: .display)
            figure(Self.money(data.monthUsd), context.pick(en: "30 days", ru: "30 дней"), role: .display)
        }
        chart(data, count: 14)
            .frame(height: 84)
        VStack(alignment: .leading, spacing: AWSpace.s) {
            ForEach(data.byModel.prefix(3)) { model in
                modelRow(model, total: data.monthUsd)
            }
        }
        Spacer(minLength: 0)
        footer(data)
    }

    private func figure(_ value: String, _ label: String, role: AWTextRole) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AWText(value, role)
                .monospacedDigit()
            AWText(label, .label)
                .foregroundStyle(.secondary)
        }
    }

    private func chart(_ data: AiSpendData, count: Int) -> some View {
        let days = Array(data.days.suffix(count))
        let items = days.enumerated().map { index, day in
            AWBarItem(Self.dayLabel(day.date, index: index, count: days.count), day.usd, highlighted: index == days.count - 1, id: day.date)
        }
        return AWBarChart(items, tint: .green)
    }

    private func modelRow(_ model: AiSpendModel, total: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: AWSpace.xs) {
                AWText(model.label, .caption)
                Spacer(minLength: AWSpace.xxs)
                AWText(Self.money(model.usd), .caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            AWBar(progress: total > 0 ? model.usd / total : 0, tint: .green)
        }
    }

    @ViewBuilder
    private func footer(_ data: AiSpendData) -> some View {
        if let plan = data.planUsd, let leverage = data.leverage, leverage >= 1 {
            AWText(
                context.pick(
                    en: "\(Self.factor(leverage))× your \(Self.money(plan)) plan at API prices",
                    ru: "\(Self.factor(leverage))× к тарифу \(Self.money(plan)) по ценам API"
                ),
                .caption
            )
            .foregroundStyle(.secondary)
        } else {
            AWText(context.pick(en: "at API prices of \(data.pricesAsOf)", ru: "по ценам API на \(data.pricesAsOf)"), .caption)
                .foregroundStyle(.tertiary)
        }
    }

    static func money(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        }
        if value >= 100_000 {
            return String(format: "$%.0fK", value / 1000)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = value < 100 ? 2 : 0
        formatter.maximumFractionDigits = value < 100 ? 2 : 0
        return "$" + (formatter.string(from: NSNumber(value: value)) ?? "0")
    }

    static func factor(_ value: Double) -> String {
        value >= 10 ? String(Int(value.rounded())) : String(format: "%.1f", value)
    }

    static func dayLabel(_ date: String, index: Int, count: Int) -> String {
        guard index == count - 1 || index == count / 2 else {
            return ""
        }
        return String(date.suffix(2))
    }
}
