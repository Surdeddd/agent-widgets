import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct GeometryCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "geometry",
        abstract: L10n.pick(
            en: "Show the desktop widget sizes previews use; --measure reads them from this Mac.",
            ru: "Показать размеры виджетов, по которым рисует превью; --measure снимает их с этого мака."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Flag(help: ArgumentHelp(L10n.pick(en: "Measure the sizes from the system log and save them.", ru: "Снять размеры из системного лога и сохранить.")))
    var measure = false

    func execute() async throws -> Int32 {
        var issues: [Issue] = []
        var geometry = GeometryStore.current()
        if measure {
            if let measured = await GeometryProbe.measure(runner: SystemProcessRunner()) {
                try GeometryStore.save(measured)
                geometry = measured
            } else {
                issues.append(GeometryIssues.unknown)
            }
        } else if geometry.source == DeskGeometry.fallback.source {
            issues.append(GeometryIssues.unknown)
        }
        let result = CommandResult(issues: issues, artifacts: [GeometryStore.url().path], data: geometry)
        global.printer.emit(result) { data in
            data.map(Self.table) ?? ""
        }
        return measure && !issues.isEmpty ? 1 : 0
    }

    static func table(_ geometry: DeskGeometry) -> String {
        let header = L10n.pick(en: "family      widget      window", ru: "семейство   виджет      окно")
        var lines = ["\(header)   (\(geometry.source))"]
        for family in Family.allCases {
            let size = geometry.size(of: family)
            let window = CGSize(width: size.width + Family.windowInset, height: size.height + Family.windowInset)
            lines.append(pad(family.rawValue) + pad(format(size)) + format(window))
        }
        lines.append(L10n.pick(en: "corner radius ", ru: "радиус угла ") + String(format: "%.2f", geometry.cornerRadius))
        return lines.joined(separator: "\n")
    }

    private static func pad(_ text: String) -> String {
        text.padding(toLength: 12, withPad: " ", startingAt: 0)
    }

    private static func format(_ size: CGSize) -> String {
        "\(Int(size.width.rounded()))×\(Int(size.height.rounded()))"
    }
}
