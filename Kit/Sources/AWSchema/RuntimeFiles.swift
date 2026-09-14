import Foundation

public struct FeedStatus: Codable, Equatable, Sendable {
    public var ok: Bool
    public var checkedAt: Date
    public var fetchedAt: Date?
    public var error: String?
    public var exitCode: Int32?
    public var stderrTail: [String]?

    public init(
        ok: Bool,
        checkedAt: Date,
        fetchedAt: Date? = nil,
        error: String? = nil,
        exitCode: Int32? = nil,
        stderrTail: [String]? = nil
    ) {
        self.ok = ok
        self.checkedAt = checkedAt
        self.fetchedAt = fetchedAt
        self.error = error
        self.exitCode = exitCode
        self.stderrTail = stderrTail
    }
}

public struct DevTarget: Codable, Equatable, Sendable {
    public var widget: String
    public var scenario: String?

    public init(widget: String, scenario: String? = nil) {
        self.widget = widget
        self.scenario = scenario
    }
}

public struct RuntimeConfig: Codable, Equatable, Sendable {
    public var locale: Language?

    public init(locale: Language? = nil) {
        self.locale = locale
    }
}

public enum AppGroupLayout {
    public static let config = "config.json"
    public static let devTarget = "dev/target.json"
    public static let devData = "dev/data.json"

    public static func widgetDirectory(_ id: String) -> String {
        "widgets/\(id)"
    }

    public static func data(_ id: String) -> String {
        "widgets/\(id)/data.json"
    }

    public static func status(_ id: String) -> String {
        "widgets/\(id)/status.json"
    }

    public static func state(_ id: String) -> String {
        "widgets/\(id)/state.json"
    }

    public static func settings(_ id: String) -> String {
        "widgets/\(id)/settings.json"
    }

    public static func image(_ id: String, _ name: String) -> String {
        "widgets/\(id)/images/\(name)"
    }
}

public enum AWJSON {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }
            let text = try container.decode(String.self)
            guard let date = parseDate(text) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognized date \"\(text)\"; use ISO 8601 like 2026-09-14T09:00:00Z or epoch seconds"
                )
            }
            return date
        }
        return decoder
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func parseDate(_ text: String) -> Date? {
        if let date = fractional.date(from: text) ?? plain.date(from: text) {
            return date
        }
        let trimmed = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: trimmed)
    }
}
