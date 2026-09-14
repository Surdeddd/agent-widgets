import AWSchema
import Foundation

public enum HostSettingsGenerator {
    /// Swift literal listing the widgets whose feed takes settings, for the settings window of the host app.
    public static func literal(_ widgets: [WidgetSource]) -> String {
        let entries = widgets.compactMap { widget -> String? in
            guard widget.manifest.feed != nil,
                  let settings = widget.manifest.settings,
                  case .object = settings,
                  let data = try? settings.canonicalData(),
                  let json = String(bytes: data, encoding: .utf8)
            else {
                return nil
            }
            let name = widget.manifest.name
            return "    AWHostWidget(id: \(RegistryGenerator.literal(widget.id)), en: \(RegistryGenerator.literal(name.en)), "
                + "ru: \(RegistryGenerator.literal(name.ru ?? name.en)), defaults: \(RegistryGenerator.literal(json)))"
        }
        return entries.isEmpty ? "[]" : "[\n" + entries.joined(separator: ",\n") + "\n]"
    }
}
