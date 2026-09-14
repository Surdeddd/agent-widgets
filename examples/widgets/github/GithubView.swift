import AWKit
import SwiftUI

struct GithubData: Codable, Sendable {
    let owner: String
    let repo: String
    let stars: Int
    let forks: Int
    let openIssues: Int
    let starsChange: Double?
    let starHistory: [Double]
}

struct GithubView: AWView {
    let entry: AWEntry<GithubData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<GithubData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(title(data), symbol: "star.fill", entry: entry)
                if context.family == .medium {
                    HStack(alignment: .top, spacing: AWSpace.l) {
                        hero(data)
                        if data.starHistory.count > 1 {
                            AWSparkline(data.starHistory, tint: .yellow)
                                .frame(width: 92, height: 44)
                        }
                    }
                    HStack(spacing: AWSpace.l) {
                        AWRow(context.pick(en: "Forks", ru: "Форки"), value: AWFormat.compact(Double(data.forks)), symbol: "tuningfork")
                        AWRow(context.pick(en: "Issues", ru: "Проблемы"), value: AWFormat.compact(Double(data.openIssues)), symbol: "exclamationmark.circle")
                    }
                } else {
                    hero(data)
                    Spacer(minLength: 0)
                    if data.starHistory.count > 1 {
                        AWSparkline(data.starHistory, tint: .yellow)
                            .frame(height: 22)
                    }
                }
            }
        }
    }

    private func title(_ data: GithubData) -> String {
        context.family == .medium ? "\(data.owner)/\(data.repo)" : data.repo
    }

    private func hero(_ data: GithubData) -> some View {
        AWMetric(
            AWFormat.compact(Double(data.stars)),
            label: context.pick(en: "stars", ru: "звёзд"),
            trend: data.starsChange.map { AWTrend.percent($0) }
        )
    }
}
