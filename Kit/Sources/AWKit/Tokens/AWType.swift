import AWSchema
import SwiftUI

public enum AWTextRole: String, CaseIterable, Sendable {
    case hero
    case title
    case headline
    case body
    case caption
    case label
}

public enum AWType {
    public static func size(_ role: AWTextRole, _ family: Family) -> CGFloat {
        let column = index(family)
        switch role {
        case .hero: return [34, 36, 44, 52][column]
        case .title: return [15, 15, 17, 19][column]
        case .headline: return [13, 13, 14, 15][column]
        case .body: return [13, 13, 14, 15][column]
        case .caption: return [11, 11, 12, 12][column]
        case .label: return [10, 10, 11, 11][column]
        }
    }

    public static func weight(_ role: AWTextRole) -> Font.Weight {
        switch role {
        case .hero, .title, .headline, .label: .semibold
        case .body: .regular
        case .caption: .medium
        }
    }

    public static func design(_ role: AWTextRole) -> Font.Design {
        role == .hero ? .rounded : .default
    }

    public static func tracking(_ role: AWTextRole, _ family: Family) -> CGFloat {
        switch role {
        case .hero: -0.02 * size(role, family)
        case .title: -0.2
        case .label: 0.6
        case .caption: 0.1
        case .headline, .body: 0
        }
    }

    public static func minimumScale(_ role: AWTextRole) -> CGFloat {
        switch role {
        case .hero: 0.5
        case .title: 0.75
        case .headline, .body: 0.8
        case .caption, .label: 0.9
        }
    }

    public static func font(_ role: AWTextRole, _ family: Family) -> Font {
        .system(size: size(role, family), weight: weight(role), design: design(role))
    }

    private static func index(_ family: Family) -> Int {
        switch family {
        case .small: 0
        case .medium: 1
        case .large: 2
        case .extraLarge: 3
        }
    }
}

public enum AWSpace {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
}
