import AWSchema
import SwiftUI

public struct AWHeader: View {
    @Environment(\.aw) private var context
    private let title: String
    private let symbol: String?
    private let fetchedAt: Date?
    private let isStale: Bool

    public init(_ title: String, symbol: String? = nil, fetchedAt: Date? = nil, isStale: Bool = false) {
        self.title = title
        self.symbol = symbol
        self.fetchedAt = fetchedAt
        self.isStale = isStale
    }

    public init<Model>(_ title: String, symbol: String? = nil, entry: AWEntry<Model>) {
        self.init(title, symbol: symbol, fetchedAt: entry.fetchedAt, isStale: entry.phase.isStale)
    }

    public var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: AWType.size(.caption, context.family), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            AWText(title, .label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if isStale {
                AWStaleBadge()
            } else if let fetchedAt, !context.isSmall {
                AWText(AWFormat.freshness(fetchedAt, language: context.language), .caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

public struct AWStaleBadge: View {
    @Environment(\.aw) private var context

    public init() {}

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: AWType.size(.label, context.family), weight: .semibold))
            AWText(context.pick(en: "stale", ru: "устарело"), .label)
        }
        .foregroundStyle(AWStatus.warning.tint(context))
    }
}
