import AWSchema
import Foundation

public enum DevSwitch {
    /// Points the dev slot at a widget: a sample name copies that sample, nil shows the live data.
    public static func apply(_ widget: WidgetSource, scenario: String?, store: AppGroupStore) throws -> DevTarget {
        if let scenario {
            guard let sample = widget.samples[scenario] else {
                throw AWError.scenarioNotFound(
                    widget: widget.id,
                    scenario: scenario,
                    available: widget.samples.keys.filter { !$0.contains(".") }.sorted()
                )
            }
            try store.write(try Data(contentsOf: sample), to: AppGroupLayout.devData)
        }
        let target = DevTarget(widget: widget.id, scenario: scenario)
        try store.write(try AWJSON.encoder().encode(target), to: AppGroupLayout.devTarget)
        return target
    }
}
