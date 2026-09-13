import AWSchema
import SwiftUI
import WidgetKit

public enum AWRenderingMode: String, CaseIterable, Sendable {
    case fullColor
    case accented
    case vibrant

    public init(_ mode: WidgetRenderingMode) {
        if mode == .vibrant {
            self = .vibrant
        } else if mode == .accented {
            self = .accented
        } else {
            self = .fullColor
        }
    }
}

public struct AWContext: Equatable, Sendable {
    public var family: Family
    public var size: CGSize
    public var renderingMode: AWRenderingMode
    public var isPreview: Bool
    public var language: Language

    public init(
        family: Family,
        renderingMode: AWRenderingMode = .fullColor,
        isPreview: Bool = false,
        language: Language = L10n.language
    ) {
        self.family = family
        self.size = family.size
        self.renderingMode = renderingMode
        self.isPreview = isPreview
        self.language = language
    }

    public var isVibrant: Bool {
        renderingMode == .vibrant
    }

    public var isSmall: Bool {
        family == .small
    }

    public var isWide: Bool {
        family == .medium || family == .extraLarge
    }

    public func pick(en: String, ru: String) -> String {
        language == .ru ? ru : en
    }
}

private struct AWContextKey: EnvironmentKey {
    static let defaultValue = AWContext(family: .medium)
}

extension EnvironmentValues {
    public var aw: AWContext {
        get { self[AWContextKey.self] }
        set { self[AWContextKey.self] = newValue }
    }
}

extension Family {
    public init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        case .systemExtraLarge: self = .extraLarge
        default: self = .medium
        }
    }

    public var widgetFamily: WidgetFamily {
        switch self {
        case .small: .systemSmall
        case .medium: .systemMedium
        case .large: .systemLarge
        case .extraLarge: .systemExtraLarge
        }
    }
}
