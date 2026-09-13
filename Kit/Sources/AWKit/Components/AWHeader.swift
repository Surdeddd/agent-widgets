import AWSchema
import SwiftUI

public struct AWHeader: View {
    @Environment(\.aw) private var context
    private let title: String
    private let symbol: String?
    private let fetchedAt: Date?
    private let isStale: Bool
    private let now: Date?
    private let lines: Int

    public init(_ title: String, symbol: String? = nil, fetchedAt: Date? = nil, isStale: Bool = false, lines: Int = 1) {
        self.title = title
        self.symbol = symbol
        self.fetchedAt = fetchedAt
        self.isStale = isStale
        self.now = nil
        self.lines = lines
    }

    public init<Model>(_ title: String, symbol: String? = nil, entry: AWEntry<Model>, lines: Int = 1) {
        self.title = title
        self.symbol = symbol
        self.fetchedAt = entry.fetchedAt
        self.isStale = entry.phase.isStale
        self.now = entry.date
        self.lines = lines
    }

    public var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: AWType.size(.caption, context.family), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            AWText(title, .label, lines: lines)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if isStale {
                AWStaleBadge()
            } else if let fetchedAt, !context.isSmall {
                AWText(AWFormat.freshness(fetchedAt, now: now ?? Date(), language: context.language), .caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .awBlock("AWHeader")
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
