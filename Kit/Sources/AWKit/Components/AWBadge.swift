import AWSchema
import SwiftUI

public struct AWBadge: View {
    @Environment(\.aw) private var context
    private let text: String
    private let status: AWStatus
    private let showsSymbol: Bool

    public init(_ text: String, status: AWStatus = .neutral, showsSymbol: Bool = true) {
        self.text = text
        self.status = status
        self.showsSymbol = showsSymbol
    }

    public var body: some View {
        HStack(spacing: 3) {
            if showsSymbol {
                Image(systemName: status.symbol)
                    .font(.system(size: AWType.size(.label, context.family) - 1, weight: .bold))
            }
            AWText(text, .label)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(status.tint(context))
        .background(Capsule().fill(status.tint(context).opacity(0.16)))
    }
}
