import AWSchema
import Foundation

public struct AWState: Codable, Equatable, Sendable {
    public var values: [String: JSONValue]

    public init(_ values: [String: JSONValue] = [:]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    public var cursor: Int {
        int("cursor")
    }

    public func int(_ key: String, default fallback: Int = 0) -> Int {
        values[key]?.doubleValue.map { Int($0) } ?? fallback
    }

    public func double(_ key: String, default fallback: Double = 0) -> Double {
        values[key]?.doubleValue ?? fallback
    }

    public func bool(_ key: String, default fallback: Bool = false) -> Bool {
        values[key]?.boolValue ?? fallback
    }

    public func string(_ key: String) -> String? {
        values[key]?.stringValue
    }

    public func date(_ key: String) -> Date? {
        values[key]?.doubleValue.map(Date.init(timeIntervalSince1970:))
    }

    public mutating func set(_ key: String, _ value: JSONValue) {
        values[key] = value
    }

    public func setting(_ key: String, _ value: JSONValue) -> AWState {
        var copy = self
        copy.set(key, value)
        return copy
    }
}
