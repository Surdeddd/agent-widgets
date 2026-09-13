import AWSchema
import SwiftUI

public struct AWRow: View {
    @Environment(\.aw) private var context
    private let title: String
    private let value: String?
    private let detail: String?
    private let status: AWStatus?
    private let symbol: String?

    public init(_ title: String, value: String? = nil, detail: String? = nil, status: AWStatus? = nil, symbol: String? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
        self.status = status
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: AWSpace.s) {
            if let status {
                Image(systemName: status.symbol)
                    .font(.system(size: AWType.size(.body, context.family), weight: .semibold))
                    .foregroundStyle(status.tint(context))
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: AWType.size(.body, context.family), weight: .medium))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                AWText(title, .body)
                if let detail {
                    AWText(detail, .caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: AWSpace.xs)
            if let value {
                AWText(value, .headline)
                    .monospacedDigit()
            }
        }
    }
}

public struct AWList<Item: Identifiable, Row: View>: View {
    @Environment(\.aw) private var context
    private let items: [Item]
    private let maxRows: Int?
    private let row: (Item) -> Row

    public init(_ items: [Item], maxRows: Int? = nil, @ViewBuilder row: @escaping (Item) -> Row) {
        self.items = items
        self.maxRows = maxRows
        self.row = row
    }

    public var body: some View {
        let limit = maxRows ?? defaultLimit
        let shown = Array(items.prefix(limit))
        VStack(alignment: .leading, spacing: context.isSmall ? 4 : 6) {
            ForEach(shown) { item in
                row(item)
            }
            if items.count > shown.count {
                AWText(context.pick(en: "+\(items.count - shown.count) more", ru: "ещё \(items.count - shown.count)"), .caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var defaultLimit: Int {
        switch context.family {
        case .small: 3
        case .medium: 3
        case .large: 7
        case .extraLarge: 7
        }
    }
}
