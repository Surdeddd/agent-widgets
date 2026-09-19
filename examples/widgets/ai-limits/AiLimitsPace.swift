import Foundation

enum AiLimitsPace {
    struct Sample: Equatable {
        let at: Date
        let value: Double
    }

    static let week: TimeInterval = 7 * 86400

    /// Share of the window that has already passed, nil when the reset or the length is unknown or out of range.
    static func elapsed(resetsAt: Date?, windowHours: Double?, now: Date) -> Double? {
        guard let resetsAt, let windowHours, windowHours > 0 else {
            return nil
        }
        let share = 1 - resetsAt.timeIntervalSince(now) / (windowHours * 3600)
        return share >= 0 && share <= 1 ? share : nil
    }

    /// The moment the limit ends at the pace so far, nil when the window resets first.
    static func runsOut(percent: Double, resetsAt: Date?, windowHours: Double?, now: Date) -> Date? {
        guard percent >= 10, percent < 100, let resetsAt, let windowHours else {
            return nil
        }
        let spent = windowHours * 3600 - resetsAt.timeIntervalSince(now)
        guard spent > 0, spent <= windowHours * 3600 else {
            return nil
        }
        let end = now.addingTimeInterval((100 - percent) * spent / percent)
        return end < resetsAt ? end : nil
    }

    /// History resampled at even steps, the last known value carried over the quiet hours.
    static func series(_ points: [Sample], current: Double?, now: Date, steps: Int = 84) -> [Double] {
        var samples = kept(points, now: now)
        if let current {
            samples.append(Sample(at: now, value: current))
        }
        guard samples.count > 1, let first = samples.first else {
            return samples.map(\.value)
        }
        let total = now.timeIntervalSince(first.at)
        let count = min(steps, max(2, Int(total / 1800) + 1))
        return (0..<count).map { index in
            let moment = first.at.addingTimeInterval(total * Double(index) / Double(count - 1))
            return samples.last { $0.at <= moment }?.value ?? first.value
        }
    }

    static func span(_ points: [Sample], now: Date) -> TimeInterval {
        kept(points, now: now).first.map { now.timeIntervalSince($0.at) } ?? 0
    }

    private static func kept(_ points: [Sample], now: Date) -> [Sample] {
        points
            .filter { $0.at <= now && now.timeIntervalSince($0.at) <= week }
            .sorted { $0.at < $1.at }
    }
}
