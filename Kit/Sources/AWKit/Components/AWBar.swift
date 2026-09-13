import AWSchema
import SwiftUI
import WidgetKit

public struct AWBar: View {
    @Environment(\.aw) private var context
    private let progress: Double
    private let tint: Color
    private let height: CGFloat?

    public init(progress: Double, tint: Color = .accentColor, height: CGFloat? = nil) {
        self.progress = progress
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        let color = context.isVibrant ? Color.primary : tint
        let fraction = min(max(progress, 0), 1)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.height, proxy.size.width * fraction))
                    .opacity(fraction > 0 ? 1 : 0)
                    .widgetAccentable()
            }
        }
        .frame(height: height ?? (context.isSmall ? 5 : 6))
    }
}
