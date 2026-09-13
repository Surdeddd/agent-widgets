import AWSchema
import Foundation
import WidgetKit

public struct AWProvider<V: AWView>: TimelineProvider {
    public typealias Entry = AWEntry<V.Model>

    public let id: String
    public let refresh: TimeInterval
    public let sample: Data?
    public let store: AWStore

    public init(id: String, refresh: TimeInterval, sample: Data? = nil, store: AWStore = .shared) {
        self.id = id
        self.refresh = refresh
        self.sample = sample
        self.store = store
    }

    public func placeholder(in context: Context) -> Entry {
        output(data: sample, now: Date()).entries.first ?? AWEntry(date: Date(), data: nil, phase: .empty)
    }

    public func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let data = context.isPreview ? store.data(widget: id) ?? sample : store.data(widget: id)
        completion(output(data: data, now: Date()).entries.first ?? placeholder(in: context))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let result = output(data: store.data(widget: id), now: Date())
        completion(Timeline(entries: result.entries, policy: result.reloadAfter.map { .after($0) } ?? .atEnd))
    }

    private func output(data: Data?, now: Date) -> AWTimelineOutput<V.Model> {
        AWTimelineBuilder.build(
            V.Model.self,
            AWTimelineInput(
                data: data,
                status: store.status(widget: id),
                state: store.state(widget: id),
                tick: V.tick,
                refresh: refresh,
                now: now
            )
        )
    }
}
