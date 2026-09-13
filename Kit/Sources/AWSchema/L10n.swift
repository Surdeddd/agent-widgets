import Foundation

public enum L10n {
    @TaskLocal public static var language: Language = .current

    public static func pick(en: String, ru: String) -> String {
        language == .ru ? ru : en
    }
}

extension LocalizedText {
    public var localized: String {
        resolve(L10n.language)
    }
}
