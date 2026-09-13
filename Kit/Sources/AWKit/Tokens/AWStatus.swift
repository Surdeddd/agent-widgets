import SwiftUI

public enum AWStatus: String, Codable, CaseIterable, Sendable {
    case ok
    case warning
    case critical
    case info
    case neutral

    public var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .info: "info.circle.fill"
        case .neutral: "circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .ok: .green
        case .warning: .orange
        case .critical: .red
        case .info: .blue
        case .neutral: .secondary
        }
    }

    public func tint(_ context: AWContext) -> Color {
        context.isVibrant ? .primary : color
    }
}

public struct AWTrend: Equatable, Sendable {
    public enum Direction: Sendable {
        case up
        case down
        case flat
    }

    public var direction: Direction
    public var text: String
    public var positiveIsGood: Bool

    public init(direction: Direction, text: String, positiveIsGood: Bool = true) {
        self.direction = direction
        self.text = text
        self.positiveIsGood = positiveIsGood
    }

    public static func percent(_ delta: Double, positiveIsGood: Bool = true) -> AWTrend {
        let direction: Direction = abs(delta) < 0.0005 ? .flat : (delta > 0 ? .up : .down)
        let text = String(format: "%@%.1f%%", delta > 0 ? "+" : "", delta * 100)
        return AWTrend(direction: direction, text: text, positiveIsGood: positiveIsGood)
    }

    public var symbol: String {
        switch direction {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        }
    }

    public var status: AWStatus {
        switch direction {
        case .flat: .neutral
        case .up: positiveIsGood ? .ok : .critical
        case .down: positiveIsGood ? .critical : .ok
        }
    }
}
