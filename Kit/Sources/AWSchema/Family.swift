import Foundation

public enum Family: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large
    case extraLarge

    public static let windowInset: CGFloat = 15

    public var size: CGSize {
        switch self {
        case .small: CGSize(width: 155, height: 155)
        case .medium: CGSize(width: 329, height: 155)
        case .large: CGSize(width: 345, height: 345)
        case .extraLarge: CGSize(width: 715, height: 345)
        }
    }

    public var widgetKitCase: String {
        switch self {
        case .small: ".systemSmall"
        case .medium: ".systemMedium"
        case .large: ".systemLarge"
        case .extraLarge: ".systemExtraLarge"
        }
    }

    public static func nearest(windowSize: CGSize, maxDistance: CGFloat = 40) -> Family? {
        let ranked = allCases.map { family -> (family: Family, distance: CGFloat) in
            let dx = family.size.width + windowInset - windowSize.width
            let dy = family.size.height + windowInset - windowSize.height
            return (family, (dx * dx + dy * dy).squareRoot())
        }
        guard let best = ranked.min(by: { $0.distance < $1.distance }), best.distance <= maxDistance else {
            return nil
        }
        return best.family
    }
}
