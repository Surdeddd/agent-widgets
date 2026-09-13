import AWSchema
import Foundation

public struct AWTimelineInput: Sendable {
    public var data: Data?
    public var status: FeedStatus?
    public var state: AWState
    public var tick: AWTick
    public var refresh: TimeInterval
    public var now: Date

    public init(
        data: Data?,
        status: FeedStatus? = nil,
        state: AWState = AWState(),
        tick: AWTick = .none,
        refresh: TimeInterval,
        now: Date = Date()
    ) {
        self.data = data
        self.status = status
        self.state = state
        self.tick = tick
        self.refresh = refresh
        self.now = now
    }
}

public struct AWTimelineOutput<Model: Sendable>: Sendable {
    public let entries: [AWEntry<Model>]
    public let reloadAfter: Date?
}

public enum AWTimelineBuilder {
    public static func build<Model: Codable & Sendable>(_ type: Model.Type, _ input: AWTimelineInput) -> AWTimelineOutput<Model> {
        let now = input.now
        let reload = now.addingTimeInterval(input.refresh)
        let empty = AWTimelineOutput<Model>(entries: [AWEntry(date: now, data: nil, phase: .empty, state: input.state)], reloadAfter: reload)
        guard let data = input.data else {
            return empty
        }
        let phase = phase(status: input.status, refresh: input.refresh, now: now)
        let fetchedAt = input.status?.fetchedAt
        do {
            if let envelope = try TimelineEnvelope<Model>.decodeIfEnvelope(data) {
                let items = envelope.visible(from: now)
                guard !items.isEmpty else {
                    return empty
                }
                let entries = items.enumerated().map { index, item in
                    AWEntry(date: index == 0 ? now : item.date, data: item.data, phase: phase, fetchedAt: fetchedAt, state: input.state)
                }
                return AWTimelineOutput(entries: entries, reloadAfter: envelope.refreshAfter ?? reload)
            }
            let model = try AWJSON.decoder().decode(Model.self, from: data)
            let entries = tickDates(input.tick, now: now).map {
                AWEntry(date: $0, data: model, phase: phase, fetchedAt: fetchedAt, state: input.state)
            }
            return AWTimelineOutput(entries: entries, reloadAfter: input.tick == .none ? reload : nil)
        } catch {
            let entry = AWEntry<Model>(date: now, data: nil, phase: .error(DecodingErrorFormatter.describe(error)), state: input.state)
            return AWTimelineOutput(entries: [entry], reloadAfter: reload)
        }
    }

    public static func phase(status: FeedStatus?, refresh: TimeInterval, now: Date) -> AWPhase {
        guard let status else {
            return .ok
        }
        guard let fetchedAt = status.fetchedAt else {
            return status.ok ? .ok : .stale(age: 0)
        }
        let age = max(0, now.timeIntervalSince(fetchedAt))
        return !status.ok || age > refresh * 2 ? .stale(age: age) : .ok
    }

    public static func tickDates(_ tick: AWTick, now: Date) -> [Date] {
        switch tick {
        case .none:
            return [now]
        case .everyMinute(let count):
            return aligned(now: now, step: 60, count: count)
        case .every(let seconds, let count):
            return aligned(now: now, step: TimeInterval(max(seconds, 1)), count: count)
        }
    }

    private static func aligned(now: Date, step: TimeInterval, count: Int) -> [Date] {
        let start = (now.timeIntervalSince1970 / step).rounded(.down) * step
        return (0..<max(count, 1)).map { Date(timeIntervalSince1970: start + Double($0) * step) }
    }
}

private struct TimelineWireEntry<Model: Decodable>: Decodable {
    let date: Date
    let data: Model
}

private struct TimelineWire<Model: Decodable>: Decodable {
    let timeline: [TimelineWireEntry<Model>]
    let refreshAfter: Date?
}

struct TimelineEnvelope<Model: Codable & Sendable> {
    struct Item {
        let date: Date
        let data: Model
    }

    let items: [Item]
    let refreshAfter: Date?

    static func decodeIfEnvelope(_ data: Data) throws -> TimelineEnvelope? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["timeline", "refreshAfter"]),
              let raw = object["timeline"] as? [[String: Any]],
              raw.allSatisfy({ $0["date"] != nil && $0["data"] != nil })
        else {
            return nil
        }
        let wire = try AWJSON.decoder().decode(TimelineWire<Model>.self, from: data)
        let items = wire.timeline.map { Item(date: $0.date, data: $0.data) }.sorted { $0.date < $1.date }
        return TimelineEnvelope(items: items, refreshAfter: wire.refreshAfter)
    }

    func visible(from now: Date) -> [Item] {
        let past = items.last { $0.date <= now }
        return (past.map { [$0] } ?? []) + items.filter { $0.date > now }
    }
}
