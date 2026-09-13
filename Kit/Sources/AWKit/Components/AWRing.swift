import AWSchema
import SwiftUI
import WidgetKit

public struct AWRing<Center: View>: View {
    @Environment(\.aw) private var context
    private let progress: Double
    private let tint: Color
    private let lineWidth: CGFloat?
    private let center: Center

    public init(progress: Double, tint: Color = .accentColor, lineWidth: CGFloat? = nil, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.tint = tint
        self.lineWidth = lineWidth
        self.center = center()
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ring(width: lineWidth ?? min(max(side * 0.14, 3), context.isSmall ? 9 : 11))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .awBlock("AWRing")
    }

    private func ring(width: CGFloat) -> some View {
        let color = context.isVibrant ? Color.primary : tint
        return ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: width)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            center
                .padding(width * 0.5)
        }
        .padding(width / 2)
        .aspectRatio(1, contentMode: .fit)
    }
}

extension AWRing where Center == EmptyView {
    public init(progress: Double, tint: Color = .accentColor, lineWidth: CGFloat? = nil) {
        self.init(progress: progress, tint: tint, lineWidth: lineWidth) { EmptyView() }
    }
}

public struct AWGauge: View {
    @Environment(\.aw) private var context
    private let value: Double
    private let range: ClosedRange<Double>
    private let valueText: String?
    private let label: String?
    private let tint: Color

    public init(value: Double, in range: ClosedRange<Double> = 0...1, valueText: String? = nil, label: String? = nil, tint: Color = .accentColor) {
        self.value = value
        self.range = range
        self.valueText = valueText
        self.label = label
        self.tint = tint
    }

    public var body: some View {
        let span = range.upperBound - range.lowerBound
        let fraction = span > 0 ? min(max((value - range.lowerBound) / span, 0), 1) : 0
        let width: CGFloat = context.isSmall ? 8 : 10
        let color = context.isVibrant ? Color.primary : tint
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(color.opacity(0.18), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(135))
                .widgetAccentable()
            VStack(spacing: 0) {
                AWText(valueText ?? String(format: "%.0f", value), .title)
                    .monospacedDigit()
                if let label {
                    AWText(label, .label)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(width * 1.5)
        }
        .padding(width / 2)
        .aspectRatio(1, contentMode: .fit)
        .awBlock("AWGauge")
    }
}
