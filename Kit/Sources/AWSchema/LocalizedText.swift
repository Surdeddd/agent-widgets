import Foundation

public struct LocalizedText: Codable, Equatable, Hashable, Sendable {
    public var en: String
    public var ru: String?

    public init(en: String, ru: String? = nil) {
        self.en = en
        self.ru = ru
    }

    public var all: [String] {
        [en] + (ru.map { [$0] } ?? [])
    }

    public func resolve(_ language: Language) -> String {
        switch language {
        case .en: en
        case .ru: ru ?? en
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let plain = try? container.decode(String.self) {
            self.init(en: plain)
            return
        }
        let object = try container.decode([String: String].self)
        guard let english = object["en"] else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "LocalizedText needs an \"en\" value"
            )
        }
        self.init(en: english, ru: object["ru"])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let ru {
            try container.encode(["en": en, "ru": ru])
        } else {
            try container.encode(en)
        }
    }
}
