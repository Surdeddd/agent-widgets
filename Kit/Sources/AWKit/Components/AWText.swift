import AWSchema
import SwiftUI
import WidgetKit

public struct AWTextFit: Equatable, Sendable {
    public var text: String
    public var role: AWTextRole
    public var family: Family
    public var lines: Int
    public var width: CGFloat
}

public struct AWTextFitKey: PreferenceKey {
    public static let defaultValue: [AWTextFit] = []

    public static func reduce(value: inout [AWTextFit], nextValue: () -> [AWTextFit]) {
        value.append(contentsOf: nextValue())
    }
}

public struct AWText: View {
    @Environment(\.aw) private var context
    private let string: String
    private let role: AWTextRole
    private let lines: Int

    public init(_ string: String, _ role: AWTextRole = .body, lines: Int = 1) {
        self.string = string
        self.role = role
        self.lines = max(1, lines)
    }

    public var body: some View {
        let shown = role == .label ? string.uppercased() : string
        let snippet = shown.count > 24 ? String(shown.prefix(24)) + "…" : shown
        let text = Text(shown)
            .font(AWType.font(role, context.family))
            .tracking(AWType.tracking(role, context.family))
            .lineLimit(lines)
            .minimumScaleFactor(AWType.minimumScale(role))
            .fixedSize(horizontal: false, vertical: true)
        Group {
            if role == .hero {
                text.monospacedDigit().contentTransition(.numericText()).widgetAccentable()
            } else {
                text
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AWTextFitKey.self,
                    value: [AWTextFit(text: shown, role: role, family: context.family, lines: lines, width: proxy.size.width)]
                )
            }
        )
        .awBlock("AWText “\(snippet)”")
    }
}
