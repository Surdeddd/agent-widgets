import Foundation
import WidgetKit

public enum AWPhase: Sendable, Equatable {
    case ok
    case stale(age: TimeInterval)
    case empty
    case error(String)

    public var isStale: Bool {
        if case .stale = self {
            return true
        }
        return false
    }
}

public struct AWEntry<Model: Sendable>: TimelineEntry, Sendable {
    public let date: Date
    public let data: Model?
    public let phase: AWPhase
    public let fetchedAt: Date?
    public let state: AWState

    public init(date: Date, data: Model?, phase: AWPhase, fetchedAt: Date? = nil, state: AWState = AWState()) {
        self.date = date
        self.data = data
        self.phase = phase
        self.fetchedAt = fetchedAt
        self.state = state
    }

    public static func preview(
        _ data: Model?,
        phase: AWPhase = .ok,
        fetchedAt: Date? = nil,
        state: AWState = AWState(),
        date: Date = Date()
    ) -> AWEntry {
        AWEntry(date: date, data: data, phase: phase, fetchedAt: fetchedAt, state: state)
    }
}
