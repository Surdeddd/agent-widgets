import Foundation

public enum Family: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large
    case extraLarge

    public static let windowInset: CGFloat = 16

    public var size: CGSize {
        DeskGeometry.current.size(of: self)
    }

    public var widgetKitCase: String {
        switch self {
        case .small: ".systemSmall"
        case .medium: ".systemMedium"
        case .large: ".systemLarge"
        case .extraLarge: ".systemExtraLarge"
        }
    }

    public static func nearest(windowSize: CGSize, in geometry: DeskGeometry = DeskGeometry.current, maxDistance: CGFloat = 40) -> Family? {
        let ranked = allCases.map { family -> (family: Family, distance: CGFloat) in
            let size = geometry.size(of: family)
            let dx = size.width + windowInset - windowSize.width
            let dy = size.height + windowInset - windowSize.height
            return (family, (dx * dx + dy * dy).squareRoot())
        }
        guard let best = ranked.min(by: { $0.distance < $1.distance }), best.distance <= maxDistance else {
            return nil
        }
        return best.family
    }
}
