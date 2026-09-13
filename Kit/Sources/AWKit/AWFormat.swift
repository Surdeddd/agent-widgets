import AWSchema
import Foundation

public enum AWFormat {
    public static func freshness(_ fetchedAt: Date, now: Date = Date(), language: Language = L10n.language) -> String {
        let age = max(0, now.timeIntervalSince(fetchedAt))
        let russian = language == .ru
        switch age {
        case ..<60:
            return russian ? "только что" : "just now"
        case ..<3600:
            let minutes = Int(age / 60)
            return russian ? "\(minutes) мин назад" : "\(minutes)m ago"
        case ..<86400:
            let hours = Int(age / 3600)
            return russian ? "\(hours) ч назад" : "\(hours)h ago"
        default:
            let days = Int(age / 86400)
            return russian ? "\(days) дн назад" : "\(days)d ago"
        }
    }

    public static func updated(_ fetchedAt: Date, now: Date = Date(), language: Language = L10n.language) -> String {
        let text = freshness(fetchedAt, now: now, language: language)
        return language == .ru ? "обновлено \(text)" : "updated \(text)"
    }

    public static func compact(_ value: Double) -> String {
        let magnitude = abs(value)
        let units: [(Double, String)] = [(1e9, "B"), (1e6, "M"), (1e3, "K")]
        guard let (divisor, suffix) = units.first(where: { magnitude >= $0.0 }) else {
            return value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        }
        let scaled = value / divisor
        let text = String(format: "%.1f", scaled).replacingOccurrences(of: ".0", with: "")
        return text + suffix
    }
}
