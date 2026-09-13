import AWKit
import AWSchema
import CoreGraphics
import Foundation

public struct PreviewScenario: Sendable {
    public var name: String
    public var data: Data?
    public var state: AWState
    public var status: FeedStatus?
    public var source: String?

    public init(name: String, data: Data?, state: AWState = AWState(), status: FeedStatus? = nil, source: String? = nil) {
        self.name = name
        self.data = data
        self.state = state
        self.status = status
        self.source = source
    }

    public static func load(name: String, path: URL) -> PreviewScenario {
        let raw = try? Data(contentsOf: path)
        let trimmed = raw.map { String(bytes: $0, encoding: .utf8) ?? "" }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let data = trimmed.isEmpty || trimmed == "null" ? nil : raw
        let base = path.deletingPathExtension()
        let state = sidecar(base.appendingPathExtension("state.json")).flatMap { try? AWJSON.decoder().decode(AWState.self, from: $0) }
        let status = sidecar(base.appendingPathExtension("status.json")).flatMap { try? AWJSON.decoder().decode(FeedStatus.self, from: $0) }
        return PreviewScenario(name: name, data: data, state: state ?? AWState(), status: status, source: path.path)
    }

    private static func sidecar(_ url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    /// Adds the next two entries of every timeline sample as their own scenarios, named by their distance from now.
    public static func expandingTimelines(_ scenarios: [PreviewScenario], now: Date) -> [PreviewScenario] {
        scenarios.flatMap { [$0] + $0.upcoming(now: now) }
    }

    func upcoming(now: Date) -> [PreviewScenario] {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["timeline", "refreshAfter"]),
              let items = object["timeline"] as? [[String: Any]]
        else {
            return []
        }
        let dated = items
            .compactMap { item -> (date: Date, payload: Any)? in
                guard let date = item["date"].flatMap(Self.date), let payload = item["data"] else { return nil }
                return (date, payload)
            }
            .sorted { $0.date < $1.date }
        let future = dated.filter { $0.date > now }
        let next = dated.contains { $0.date <= now } ? future : Array(future.dropFirst())
        return next.prefix(2).compactMap { item in
            guard let json = try? JSONSerialization.data(withJSONObject: item.payload, options: [.fragmentsAllowed]) else { return nil }
            let name = "\(self.name)+\(Self.offset(item.date.timeIntervalSince(now)))"
            return PreviewScenario(name: name, data: json, state: state, status: status, source: source)
        }
    }

    static func date(_ raw: Any) -> Date? {
        if let text = raw as? String {
            return AWJSON.parseDate(text)
        }
        return (raw as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
    }

    static func offset(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes < 60 ? "\(minutes)m" : "\(Int((Double(minutes) / 60).rounded()))h"
    }
}

public struct PreviewJob: Sendable {
    public var family: Family
    public var appearance: Appearance
    public var mode: RenderMode
    public var scenario: PreviewScenario

    public init(family: Family, appearance: Appearance, mode: RenderMode, scenario: PreviewScenario) {
        self.family = family
        self.appearance = appearance
        self.mode = mode
        self.scenario = scenario
    }

    public var fileName: String {
        "\(family.rawValue)-\(appearance.rawValue)-\(mode.rawValue)-\(scenario.name).png"
    }

    public var rowLabel: String {
        "\(scenario.name) · \(appearance.rawValue) · \(mode == .idle ? "desktop idle" : "color")"
    }
}

public enum PreviewPlan {
    public static func jobs(families: [Family], scenarios: [PreviewScenario], full: Bool) -> [PreviewJob] {
        let ordered = scenarios.sorted { lhs, rhs in
            if lhs.name == "default" { return rhs.name != "default" }
            if rhs.name == "default" { return false }
            return lhs.name < rhs.name
        }
        var jobs: [PreviewJob] = []
        for scenario in ordered {
            for (appearance, mode) in combinations(for: scenario, full: full) {
                jobs += families.map { PreviewJob(family: $0, appearance: appearance, mode: mode, scenario: scenario) }
            }
        }
        return jobs
    }

    private static func combinations(for scenario: PreviewScenario, full: Bool) -> [(Appearance, RenderMode)] {
        if full {
            return [(.light, .color), (.dark, .color), (.light, .idle), (.dark, .idle)]
        }
        if scenario.name == "default" {
            return [(.light, .color), (.dark, .color), (.dark, .idle)]
        }
        return [(.dark, .color)]
    }
}

public struct RenderedCell {
    public var job: PreviewJob
    public var cell: PreviewCell
    public var image: CGImage
}
