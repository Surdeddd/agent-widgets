import AWKit
import SwiftUI

struct FxRate: Codable, Sendable, Identifiable {
    let code: String
    let name: String
    let rate: Double
    let changePct: Double
    let history: [Double]
    var id: String { code }
}

struct FxData: Codable, Sendable {
    let base: String
    let rates: [FxRate]
}

struct FxView: AWView {
    let entry: AWEntry<FxData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<FxData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            if data.rates.isEmpty {
                AWEmptyState(symbol: "banknote", title: context.pick(en: "No rates yet", ru: "Курсов пока нет"))
            } else {
                let hero = data.rates[0]
                let rest = Array(data.rates.dropFirst())
                switch context.family {
                case .small:
                    small(data, hero)
                case .medium:
                    medium(data, hero, rest)
                default:
                    large(data, hero, rest)
                }
            }
        }
    }

    private func small(_ data: FxData, _ hero: FxRate) -> some View {
        VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
            AWHeader(data.base, symbol: "banknote.fill", entry: entry)
            AWMetric(formatRate(hero.rate), unit: hero.code, label: hero.name, trend: .percent(hero.changePct))
            Spacer(minLength: 0)
            if hero.history.count > 1 {
                AWSparkline(hero.history, tint: .accentColor)
                    .frame(height: 26)
            }
        }
    }

    private func medium(_ data: FxData, _ hero: FxRate, _ rest: [FxRate]) -> some View {
        VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
            AWHeader(data.base, symbol: "banknote.fill", entry: entry)
            HStack(alignment: .top, spacing: AWSpace.l) {
                VStack(alignment: .leading, spacing: AWSpace.xs) {
                    AWMetric(formatRate(hero.rate), unit: hero.code, label: hero.name, trend: .percent(hero.changePct))
                    if hero.history.count > 1 {
                        AWSparkline(hero.history, tint: .accentColor)
                            .frame(height: 22)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AWSpace.xxs) {
                    ForEach(rest.prefix(3)) { rate in
                        row(rate)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func large(_ data: FxData, _ hero: FxRate, _ rest: [FxRate]) -> some View {
        VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
            AWHeader(data.base, symbol: "banknote.fill", entry: entry)
            AWMetric(formatRate(hero.rate), unit: hero.code, label: hero.name, trend: .percent(hero.changePct))
            if hero.history.count > 1 {
                AWSparkline(hero.history, tint: .accentColor)
                    .frame(height: 58)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: AWSpace.xs) {
                ForEach(rest) { rate in
                    row(rate)
                }
            }
        }
    }

    private func row(_ rate: FxRate) -> some View {
        HStack(alignment: .firstTextBaseline) {
            AWText(rate.code, .label)
            Spacer(minLength: AWSpace.xs)
            VStack(alignment: .trailing, spacing: 1) {
                AWText(formatRate(rate.rate), .body)
                AWTrendLabel(.percent(rate.changePct))
            }
        }
    }

    private func formatRate(_ value: Double) -> String {
        value < 10 ? String(format: "%.4f", value) : String(format: "%.2f", value)
    }
}
