import AWSchema
import SwiftUI
import WidgetKit

public enum AWMetrics {
    public static func padding(for family: Family) -> CGFloat {
        switch family {
        case .small: 14
        case .medium: 15
        case .large: 16
        case .extraLarge: 18
        }
    }

    public static func spacing(for family: Family) -> CGFloat {
        family == .small ? 6 : 8
    }

    public static func cornerRadius(for family: Family) -> CGFloat {
        22
    }
}

public struct AWContentSizeKey: PreferenceKey {
    public static let defaultValue: CGSize = .zero

    public static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

public struct AWFrame<Content: View>: View {
    private let context: AWContext
    private let content: Content

    public init(context: AWContext, @ViewBuilder content: () -> Content) {
        self.context = context
        self.content = content()
    }

    public var body: some View {
        content
            .background(GeometryReader { proxy in Color.clear.preference(key: AWContentSizeKey.self, value: proxy.size) })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(AWMetrics.padding(for: context.family))
            .environment(\.aw, context)
    }
}

public struct AWWidgetContainer<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    private let language: Language
    private let content: Content

    public init(language: Language = L10n.language, @ViewBuilder content: () -> Content) {
        self.language = language
        self.content = content()
    }

    public var body: some View {
        AWFrame(context: AWContext(family: Family(family), renderingMode: AWRenderingMode(renderingMode), language: language)) {
            content
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}
