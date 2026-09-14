import CoreGraphics
import Foundation

public struct DeskGeometry: Codable, Sendable, Equatable {
    public var small: CGSize
    public var medium: CGSize
    public var large: CGSize
    public var extraLarge: CGSize
    public var cornerRadius: Double
    public var source: String
    public var measuredAt: Date?

    public init(small: CGSize, medium: CGSize, large: CGSize, extraLarge: CGSize, cornerRadius: Double, source: String, measuredAt: Date? = nil) {
        self.small = small
        self.medium = medium
        self.large = large
        self.extraLarge = extraLarge
        self.cornerRadius = cornerRadius
        self.source = source
        self.measuredAt = measuredAt
    }

    public static let fallback = DeskGeometry(
        small: CGSize(width: 155, height: 155),
        medium: CGSize(width: 329, height: 155),
        large: CGSize(width: 345, height: 345),
        extraLarge: CGSize(width: 715, height: 345),
        cornerRadius: 22,
        source: "fallback"
    )

    /// The geometry previews and window matching use; set with `DeskGeometry.$current.withValue(_:)`.
    @TaskLocal public static var current = DeskGeometry.fallback

    public func size(of family: Family) -> CGSize {
        switch family {
        case .small: small
        case .medium: medium
        case .large: large
        case .extraLarge: extraLarge
        }
    }
}
