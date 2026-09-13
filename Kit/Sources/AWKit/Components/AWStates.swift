import AWSchema
import SwiftUI

public struct AWEmptyState: View {
    @Environment(\.aw) private var context
    private let symbol: String
    private let title: String
    private let subtitle: String?

    public init(symbol: String = "tray", title: String, subtitle: String? = nil) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: AWSpace.xs) {
            Image(systemName: symbol)
                .font(.system(size: context.isSmall ? 22 : 28, weight: .light))
                .foregroundStyle(.secondary)
            AWText(title, .headline, lines: 2)
                .multilineTextAlignment(.center)
            if let subtitle {
                AWText(subtitle, .caption, lines: 3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .awBlock("AWEmptyState")
    }
}

public struct AWPhaseView<Model: Sendable, Content: View>: View {
    @Environment(\.aw) private var context
    private let entry: AWEntry<Model>
    private let content: (Model) -> Content

    public init(_ entry: AWEntry<Model>, @ViewBuilder content: @escaping (Model) -> Content) {
        self.entry = entry
        self.content = content
    }

    public var body: some View {
        if let data = entry.data {
            content(data)
        } else if case .error(let message) = entry.phase {
            AWEmptyState(
                symbol: "exclamationmark.triangle",
                title: context.pick(en: "Data error", ru: "Ошибка данных"),
                subtitle: message
            )
        } else {
            AWEmptyState(
                symbol: "hourglass",
                title: context.pick(en: "Waiting for data", ru: "Ждём данные"),
                subtitle: context.isSmall ? nil : context.pick(en: "fill it with a feed or aw data set", ru: "заполни через feed или aw data set")
            )
        }
    }
}
