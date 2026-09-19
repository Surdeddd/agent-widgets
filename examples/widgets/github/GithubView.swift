import AWKit
import SwiftUI
import WidgetKit

struct GithubReview: Codable, Sendable, Identifiable {
    let repo: String
    let number: Int
    let title: String

    var id: String { "\(repo)#\(number)" }
}

struct GithubDay: Codable, Sendable {
    let date: String
    let count: Int
}

struct GithubData: Codable, Sendable {
    let state: String
    let login: String
    let total: Int
    let today: Int
    let streak: Int
    let longest: Int
    let weeks: [[Int]]
    let recent: [GithubDay]?
    let reviewCount: Int
    let reviews: [GithubReview]
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
                AWHeader(data.login.isEmpty ? "GitHub" : data.login, symbol: "chevron.left.forwardslash.chevron.right", entry: entry)
                if data.state == "ok" {
                    layout(data)
                } else {
                    AWEmptyState(
                        symbol: "terminal",
                        title: context.pick(en: "GitHub CLI needed", ru: "Нужен GitHub CLI"),
                        subtitle: data.state == "no-gh"
                            ? context.pick(en: "brew install gh, then gh auth login", ru: "brew install gh, затем gh auth login")
                            : context.pick(en: "Run gh auth login", ru: "Выполни gh auth login")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func layout(_ data: GithubData) -> some View {
        switch context.family {
        case .small:
            streakHero(data)
            heatmap(data.weeks, count: 13, gap: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        case .medium:
            HStack(alignment: .top, spacing: AWSpace.l) {
                VStack(alignment: .leading, spacing: AWSpace.xxs) {
                    streakHero(data)
                    Spacer(minLength: 0)
                    AWText(todayLabel(data.today), .caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 92, alignment: .leading)
                VStack(alignment: .leading, spacing: AWSpace.xs) {
                    heatmap(data.weeks, count: 20, gap: 2)
                    Spacer(minLength: 0)
                    AWText(yearLabel(data.total), .caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .large:
            stats(data)
            heatmap(Array(data.weeks.dropLast(26)), count: 26, gap: 2)
            heatmap(data.weeks, count: 26, gap: 2)
            Spacer(minLength: 0)
            reviewLine(data)
        case .extraLarge:
            HStack(alignment: .top, spacing: AWSpace.xl) {
                stats(data)
                Spacer(minLength: 0)
                AWText(todayLabel(data.today), .caption)
                    .foregroundStyle(.secondary)
            }
            heatmap(data.weeks, count: 53, gap: 3)
            HStack(alignment: .top, spacing: AWSpace.xl) {
                VStack(alignment: .leading, spacing: AWSpace.xs) {
                    reviews(data, count: 2)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                recentDays(data.recent ?? [])
            }
        }
    }

    @ViewBuilder
    private func streakHero(_ data: GithubData) -> some View {
        AWText("\(data.streak)", .hero)
        AWText(context.pick(en: data.streak == 1 ? "day streak" : "days streak", ru: dayWord(data.streak) + " подряд"), .caption)
            .foregroundStyle(.secondary)
    }

    private func stats(_ data: GithubData) -> some View {
        HStack(alignment: .top, spacing: AWSpace.xl) {
            stat("\(data.total)", context.pick(en: "this year", ru: "за год"))
            stat("\(data.streak)", context.pick(en: "streak", ru: "серия"))
            stat("\(data.longest)", context.pick(en: "longest", ru: "рекорд"))
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AWText(value, .display)
                .monospacedDigit()
            AWText(label, .label)
                .foregroundStyle(.secondary)
        }
    }

    private func heatmap(_ weeks: [[Int]], count: Int, gap: CGFloat) -> some View {
        let shown = Array(weeks.suffix(count))
        return GeometryReader { proxy in
            let columns = CGFloat(max(count, 1))
            let cell = max((proxy.size.width - gap * (columns - 1)) / columns, 1)
            HStack(alignment: .top, spacing: gap) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { day in
                            RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                                .fill(color(day < week.count ? week[day] : -1))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .widgetAccentable()
        }
        .aspectRatio(CGFloat(count) / 7, contentMode: .fit)
        .awBlock("heatmap \(count) weeks")
    }

    @ViewBuilder
    private func recentDays(_ days: [GithubDay]) -> some View {
        if days.contains(where: { $0.count > 0 }) {
            VStack(alignment: .leading, spacing: AWSpace.xs) {
                AWText(context.pick(en: "Last \(days.count) days", ru: "Последние \(days.count) дн"), .label)
                    .foregroundStyle(.secondary)
                AWBarChart(days.enumerated().map { index, day in
                    AWBarItem((days.count - 1 - index) % 2 == 0 ? dayNumber(day.date) : "", Double(day.count), highlighted: index == days.count - 1, id: day.date)
                }, tint: .green)
            }
            .frame(width: 264)
        }
    }

    private func dayNumber(_ date: String) -> String {
        Int(date.suffix(2)).map(String.init) ?? ""
    }

    @ViewBuilder
    private func reviews(_ data: GithubData, count: Int) -> some View {
        if data.reviews.isEmpty {
            AWRow(context.pick(en: "No reviews waiting", ru: "Ревью никто не ждёт"), symbol: "checkmark.circle")
        } else {
            AWText(context.pick(en: "Reviews waiting · \(data.reviewCount)", ru: "Ждут ревью · \(data.reviewCount)"), .label)
                .foregroundStyle(.secondary)
            AWList(Array(data.reviews.prefix(count)), maxRows: count) { review in
                AWRow(review.title, detail: "\(review.repo) #\(review.number)", symbol: "arrow.triangle.pull")
            }
        }
    }

    @ViewBuilder
    private func reviewLine(_ data: GithubData) -> some View {
        if let first = data.reviews.first {
            AWRow(
                first.title,
                value: data.reviewCount > 1 ? "+\(data.reviewCount - 1)" : nil,
                detail: "\(first.repo) #\(first.number)",
                symbol: "arrow.triangle.pull"
            )
        } else {
            AWRow(context.pick(en: "No reviews waiting", ru: "Ревью никто не ждёт"), symbol: "checkmark.circle")
        }
    }

    private func color(_ level: Int) -> Color {
        if level < 0 {
            return .clear
        }
        let base: Color = context.isMonochrome ? .primary : .green
        let opacity: [Double] = [0.1, 0.35, 0.55, 0.78, 1]
        return level == 0 ? Color.primary.opacity(0.1) : base.opacity(opacity[min(level, 4)])
    }

    private func todayLabel(_ count: Int) -> String {
        context.pick(en: "\(count) today", ru: "сегодня \(count)")
    }

    private func yearLabel(_ count: Int) -> String {
        context.pick(en: "\(count) contributions this year", ru: "вкладов за год: \(count)")
    }

    private func dayWord(_ count: Int) -> String {
        let tens = count % 100
        let ones = count % 10
        if tens >= 11 && tens <= 14 {
            return "дней"
        }
        if ones == 1 {
            return "день"
        }
        return (2...4).contains(ones) ? "дня" : "дней"
    }
}
