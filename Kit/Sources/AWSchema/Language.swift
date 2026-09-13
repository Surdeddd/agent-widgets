import Foundation

public enum Language: String, Codable, CaseIterable, Sendable {
    case en
    case ru

    public static var current: Language {
        detect(environment: ProcessInfo.processInfo.environment, preferred: Locale.preferredLanguages)
    }

    public static func detect(environment: [String: String], preferred: [String]) -> Language {
        if let value = environment["AW_LANG"], let language = Language(prefixOf: value) {
            return language
        }
        return preferred.lazy.compactMap(Language.init(prefixOf:)).first ?? .en
    }

    public init?(prefixOf identifier: String) {
        self.init(rawValue: String(identifier.lowercased().prefix(2)))
    }
}
