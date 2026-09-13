import AWSchema
import Foundation

public enum AWAction: String, Codable, CaseIterable, Sendable {
    case next
    case prev
    case toggle
    case increment
    case set
    case shuffle
    case reset
    case stamp
}

public enum AWDeck {
    /// Card index for a position; a non-zero seed walks the deck in a scrambled order that still visits every card once per cycle.
    public static func index(_ position: Int, count: Int, seed: Int = 0) -> Int {
        guard count > 0 else { return 0 }
        let normalized = ((position % count) + count) % count
        guard seed != 0, count > 2 else { return normalized }
        let magnitude = Int(seed.magnitude % UInt(Int.max))
        var step = magnitude % count
        if step <= 1 {
            step = max(2, count / 3)
        }
        while greatestCommonDivisor(step, count) != 1 {
            step += 1
            if step >= count {
                step = 2
            }
        }
        let shift = (magnitude / count) % count
        return (normalized * step + shift) % count
    }

    static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var (first, second) = (lhs, rhs)
        while second != 0 {
            (first, second) = (second, first % second)
        }
        return abs(first)
    }
}

extension AWState {
    public static let cursorKey = "cursor"
    public static let seedKey = "seed"

    public var seed: Int {
        int(Self.seedKey)
    }

    public var isShuffled: Bool {
        seed != 0
    }

    /// "2026-09-14" for the day `date` falls on: stable keys for per-day state such as habit check-ins.
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public func deckIndex(count: Int, slot: Int = 0, key: String = AWState.cursorKey) -> Int {
        AWDeck.index(slot + int(key), count: count, seed: seed)
    }

    public func applying(
        _ action: AWAction,
        key: String = AWState.cursorKey,
        value: String = "",
        now: Date = Date(),
        random: () -> Int = { Int.random(in: 1...9_999_999) }
    ) -> AWState {
        var copy = self
        switch action {
        case .next:
            copy.set(key, .number(Double(int(key) + 1)))
        case .prev:
            copy.set(key, .number(Double(int(key) - 1)))
        case .toggle:
            copy.set(key, .bool(!bool(key)))
        case .increment:
            copy.set(key, .number(double(key) + (Double(value) ?? 1)))
        case .set:
            copy.set(key, Self.parse(value))
        case .shuffle:
            let candidate = random()
            let next = candidate == 0 || candidate == seed ? (seed == Int.max ? 1 : seed + 1) : candidate
            copy.set(Self.seedKey, .number(Double(next)))
            copy.set(key, .number(0))
        case .reset:
            if key.isEmpty {
                copy.values = [:]
            } else {
                copy.values[key] = nil
            }
        case .stamp:
            copy.set(key, .number(now.timeIntervalSince1970 + (Double(value) ?? 0)))
        }
        return copy
    }

    static func parse(_ text: String) -> JSONValue {
        (try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))) ?? .string(text)
    }
}
