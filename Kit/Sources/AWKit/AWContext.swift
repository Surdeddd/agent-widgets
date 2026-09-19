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
    public var widget: String?
    public var kind: String?

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

    /// True on the idle desktop and in accented mode: the system strips color, so tints must not carry meaning.
    public var isMonochrome: Bool {
        renderingMode != .fullColor
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

    /// The current locale speaking the language of the widget: pass it to date and number formats so they match the text around them.
    public var locale: Locale {
        var components = Locale.Components(locale: .current)
        components.languageComponents.languageCode = Locale.LanguageCode(language.rawValue)
        components.languageComponents.script = nil
        return Locale(components: components)
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
