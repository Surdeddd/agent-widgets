import AWSchema
import SwiftUI

public struct AWMetric: View {
    @Environment(\.aw) private var context
    private let value: String
    private let unit: String?
    private let label: String?
    private let trend: AWTrend?

    public init(_ value: String, unit: String? = nil, label: String? = nil, trend: AWTrend? = nil) {
        self.value = value
        self.unit = unit
        self.label = label
        self.trend = trend
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let label {
                AWText(label, .label)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                AWText(value, .hero)
                if let unit {
                    AWText(unit, .headline)
                        .foregroundStyle(.secondary)
                }
            }
            if let trend {
                AWTrendLabel(trend)
            }
        }
        .awBlock("AWMetric \(value)")
    }
}

public struct AWTrendLabel: View {
    @Environment(\.aw) private var context
    private let trend: AWTrend

    public init(_ trend: AWTrend) {
        self.trend = trend
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: trend.symbol)
                .font(.system(size: AWType.size(.caption, context.family), weight: .bold))
            AWText(trend.text, .caption)
                .monospacedDigit()
        }
        .foregroundStyle(trend.status.tint(context))
    }
}
