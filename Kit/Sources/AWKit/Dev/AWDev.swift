import AWSchema
import SwiftUI
import WidgetKit

public struct AWDevEntry: TimelineEntry, Sendable {
    public let date: Date
    public let widget: String?
    public let scenario: String?
    public let data: Data?
    public let status: FeedStatus?
    public let state: AWState

    public init(date: Date, widget: String?, scenario: String?, data: Data?, status: FeedStatus?, state: AWState) {
        self.date = date
        self.widget = widget
        self.scenario = scenario
        self.data = data
        self.status = status
        self.state = state
    }
}

public struct AWDevProvider: TimelineProvider {
    public let store: AWStore

    public init(store: AWStore = .shared) {
        self.store = store
    }

    public func placeholder(in context: Context) -> AWDevEntry {
        AWDevEntry(date: Date(), widget: nil, scenario: nil, data: nil, status: nil, state: AWState())
    }

    public func getSnapshot(in context: Context, completion: @escaping (AWDevEntry) -> Void) {
        completion(load())
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<AWDevEntry>) -> Void) {
        completion(Timeline(entries: [load()], policy: .never))
    }

    func load(now: Date = Date()) -> AWDevEntry {
        guard let target = store.devTarget() else {
            return AWDevEntry(date: now, widget: nil, scenario: nil, data: nil, status: nil, state: AWState())
        }
        let live = target.scenario == nil
        return AWDevEntry(
            date: now,
            widget: target.widget,
            scenario: target.scenario,
            data: live ? store.data(widget: target.widget) : store.read(AppGroupLayout.devData),
            status: live ? store.status(widget: target.widget) : nil,
            state: store.state(widget: target.widget)
        )
    }
}

public struct AWDevRender<V: AWView>: View {
    private let entry: AWDevEntry

    public init(entry: AWDevEntry) {
        self.entry = entry
    }

    public var body: some View {
        let input = AWTimelineInput(data: entry.data, status: entry.status, state: entry.state, refresh: 1800, now: entry.date)
        if let first = AWTimelineBuilder.build(V.Model.self, input).entries.first {
            V(entry: first)
        }
    }
}

public struct AWDevPlaceholder: View {
    @Environment(\.aw) private var context
    private let entry: AWDevEntry

    public init(entry: AWDevEntry) {
        self.entry = entry
    }

    public var body: some View {
        AWEmptyState(
            symbol: "hammer",
            title: "Agent Widgets · Dev",
            subtitle: entry.widget.map { context.pick(en: "unknown widget \($0)", ru: "нет виджета \($0)") } ?? "aw dev <id>"
        )
    }
}
