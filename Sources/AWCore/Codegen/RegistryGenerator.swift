import AWSchema
import Foundation

public enum RegistryGenerator {
    public static let devKind = "aw.dev"
    public static let chunkSize = 10

    public static func generate(_ widgets: [WidgetSource], devName: String = "Agent Widgets · Dev") -> String {
        let sorted = widgets.sorted { $0.id < $1.id }
        var lines = ["import AppIntents", "import AWKit", "import SwiftUI", "import WidgetKit", ""]
        lines += samples(sorted)
        for widget in sorted {
            lines += widgetStruct(widget.manifest)
        }
        lines += devView(sorted.map(\.manifest), devName: devName)
        lines += bundles(sorted.map(\.manifest))
        return lines.joined(separator: "\n") + "\n"
    }

    static func typeName(_ manifest: WidgetManifest) -> String {
        "AWWidget_" + identifier(manifest.id)
    }

    static func sampleName(_ manifest: WidgetManifest) -> String {
        "s_" + identifier(manifest.id)
    }

    private static func identifier(_ id: String) -> String {
        id.replacingOccurrences(of: "-", with: "_")
    }

    static func literal(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 {
                    result += "\\u{\(String(scalar.value, radix: 16))}"
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result + "\""
    }

    private static func samples(_ widgets: [WidgetSource]) -> [String] {
        var lines = ["enum AWSamples {"]
        for widget in widgets {
            let data = widget.defaultSample.flatMap { try? Data(contentsOf: $0) }
            let value = data.map { "Data(base64Encoded: \"\($0.base64EncodedString())\")" } ?? "nil"
            lines.append("    static let \(sampleName(widget.manifest)): Data? = \(value)")
        }
        lines += ["}", ""]
        return lines
    }

    private static func widgetStruct(_ manifest: WidgetManifest) -> [String] {
        let families = manifest.families.map(\.widgetKitCase).joined(separator: ", ")
        let name = manifest.name
        let summary = manifest.description ?? LocalizedText(en: name.en, ru: name.ru)
        let provider = "AWProvider<\(manifest.view)>(id: \(literal(manifest.id)), refresh: \(manifest.resolvedRefresh.seconds), "
            + "sample: AWSamples.\(sampleName(manifest)))"
        return [
            "struct \(typeName(manifest)): Widget {",
            "    var body: some WidgetConfiguration {",
            "        StaticConfiguration(kind: \(literal(manifest.resolvedKind)), provider: \(provider)) { entry in",
            "            AWWidgetContainer(widget: \(literal(manifest.id)), kind: \(literal(manifest.resolvedKind))) { \(manifest.view)(entry: entry) }",
            "        }",
            "        .configurationDisplayName(L10n.pick(en: \(literal(name.en)), ru: \(literal(name.ru ?? name.en))))",
            "        .description(L10n.pick(en: \(literal(summary.en)), ru: \(literal(summary.ru ?? summary.en))))",
            "        .supportedFamilies([\(families)])",
            "        .contentMarginsDisabled()",
            "    }",
            "}",
            ""
        ]
    }

    private static func devView(_ manifests: [WidgetManifest], devName: String) -> [String] {
        var lines = [
            "struct AWDevView: View {",
            "    let entry: AWDevEntry",
            "",
            "    var body: some View {",
            "        switch entry.widget {"
        ]
        for manifest in manifests {
            lines.append("        case \(literal(manifest.id)): AWDevRender<\(manifest.view)>(entry: entry)")
        }
        lines += [
            "        default: AWDevPlaceholder(entry: entry)",
            "        }",
            "    }",
            "}",
            "",
            "struct AWDevWidget: Widget {",
            "    var body: some WidgetConfiguration {",
            "        StaticConfiguration(kind: \(literal(devKind)), provider: AWDevProvider()) { entry in",
            "            AWWidgetContainer(widget: entry.widget, kind: \(literal(devKind))) { AWDevView(entry: entry) }",
            "        }",
            "        .configurationDisplayName(\(literal(devName)))",
            "        .description(L10n.pick(en: \"Shows the widget an agent is working on.\", ru: \"Показывает виджет, над которым работает агент.\"))",
            "        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])",
            "        .contentMarginsDisabled()",
            "    }",
            "}",
            ""
        ]
        return lines
    }

    private static func bundles(_ manifests: [WidgetManifest]) -> [String] {
        let chunks = stride(from: 0, to: manifests.count, by: chunkSize).map { Array(manifests[$0..<min($0 + chunkSize, manifests.count)]) }
        var lines: [String] = []
        for (index, chunk) in chunks.enumerated() {
            lines.append("struct AWBundle\(index): WidgetBundle {")
            lines.append("    var body: some Widget {")
            lines += chunk.map { "        \(typeName($0))()" }
            lines += ["    }", "}", ""]
        }
        lines += [
            "struct AWIntents: AppIntentsPackage {",
            "    static var includedPackages: [any AppIntentsPackage.Type] { [AWKitIntents.self] }",
            "}",
            ""
        ]
        lines += ["@main", "struct AWMainBundle: WidgetBundle {", "    var body: some Widget {"]
        lines += chunks.indices.map { "        AWBundle\($0)().body" }
        lines += ["        AWDevWidget()", "    }", "}"]
        return lines
    }
}
