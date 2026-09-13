import AWSchema
import Charts
import SwiftUI

public enum AWSparklineStyle: Sendable {
    case line
    case area
}

public struct AWSparkline: View {
    @Environment(\.aw) private var context
    private let values: [Double]
    private let tint: Color
    private let style: AWSparklineStyle
    private let showsLastPoint: Bool

    public init(_ values: [Double], tint: Color = .accentColor, style: AWSparklineStyle = .area, showsLastPoint: Bool = true) {
        self.values = values
        self.tint = tint
        self.style = style
        self.showsLastPoint = showsLastPoint
    }

    public var body: some View {
        let color = context.isVibrant ? Color.primary : tint
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let pad = max((high - low) * 0.12, 0.0001)
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                if style == .area {
                    AreaMark(x: .value("i", index), yStart: .value("low", low - pad), yEnd: .value("v", value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.32), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                }
                LineMark(x: .value("i", index), y: .value("v", value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: context.isSmall ? 1.8 : 2.2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(color)
            }
            if showsLastPoint, let last = values.last {
                PointMark(x: .value("i", values.count - 1), y: .value("v", last))
                    .symbolSize(context.isSmall ? 22 : 30)
                    .foregroundStyle(color)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: (low - pad)...(high + pad))
        .widgetAccentable()
    }
}

public struct AWBarItem: Identifiable, Sendable {
    public var id: String { label }
    public var label: String
    public var value: Double
    public var highlighted: Bool

    public init(_ label: String, _ value: Double, highlighted: Bool = false) {
        self.label = label
        self.value = value
        self.highlighted = highlighted
    }
}

public struct AWBarChart: View {
    @Environment(\.aw) private var context
    private let items: [AWBarItem]
    private let tint: Color
    private let showsLabels: Bool

    public init(_ items: [AWBarItem], tint: Color = .accentColor, showsLabels: Bool = true) {
        self.items = items
        self.tint = tint
        self.showsLabels = showsLabels
    }

    public var body: some View {
        let color = context.isVibrant ? Color.primary : tint
        Chart(items) { item in
            BarMark(x: .value("label", item.label), y: .value("value", item.value), width: .ratio(0.62))
                .cornerRadius(3)
                .foregroundStyle(item.highlighted ? color : color.opacity(0.35))
        }
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXAxis {
            if showsLabels {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: AWType.size(.label, context.family), weight: .medium))
                }
            }
        }
        .widgetAccentable()
    }
}
