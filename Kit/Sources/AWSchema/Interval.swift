import Foundation

public struct Interval: Codable, Equatable, Hashable, Sendable {
    public let seconds: Int

    public init(seconds: Int) {
        self.seconds = seconds
    }

    public init?(parsing text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard let unit = trimmed.last, let value = Int(trimmed.dropLast()), value > 0 else {
            return nil
        }
        switch unit {
        case "s": seconds = value
        case "m": seconds = value * 60
        case "h": seconds = value * 3600
        case "d": seconds = value * 86400
        default: return nil
        }
    }

    public var compact: String {
        if seconds % 86400 == 0 { return "\(seconds / 86400)d" }
        if seconds % 3600 == 0 { return "\(seconds / 3600)h" }
        if seconds % 60 == 0 { return "\(seconds / 60)m" }
        return "\(seconds)s"
    }

    public var timeInterval: TimeInterval {
        TimeInterval(seconds)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Int.self) {
            guard number > 0 else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Interval must be positive")
            }
            seconds = number
            return
        }
        let text = try container.decode(String.self)
        guard let parsed = Interval(parsing: text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid interval \"\(text)\": use 30s, 15m, 1h or 1d"
            )
        }
        seconds = parsed.seconds
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(compact)
    }
}
