import AWSchema
import SwiftUI
import WidgetKit

public struct AWCountdown: View {
    @Environment(\.aw) private var context
    private let target: Date
    private let label: String?

    public init(to target: Date, label: String? = nil) {
        self.target = target
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let label {
                AWText(label, .label)
                    .foregroundStyle(.secondary)
            }
            Text(target, style: .timer)
                .font(AWType.font(.hero, context.family))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
        }
        .awBlock("AWCountdown")
    }
}

public struct AWClock: View {
    @Environment(\.aw) private var context
    private let date: Date
    private let timeZone: TimeZone
    private let label: String?

    public init(date: Date, timeZone: TimeZone = .current, label: String? = nil) {
        self.date = date
        self.timeZone = timeZone
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                AWText(label, .label)
                    .foregroundStyle(.secondary)
            }
            AWText(Self.format(date, timeZone: timeZone), .hero)
        }
        .awBlock("AWClock")
    }

    public static func format(_ date: Date, timeZone: TimeZone, pattern: String = "HH:mm") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
