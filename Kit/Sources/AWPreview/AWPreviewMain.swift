import AWKit
import AWSchema
import Foundation

public struct PreviewOptions: Sendable {
    public var widget: String
    public var families: [Family]
    public var scenarios: [PreviewScenario]
    public var output: URL
    public var language: Language
    public var full: Bool
    public var images: URL?

    public init(
        widget: String,
        families: [Family],
        scenarios: [PreviewScenario],
        output: URL,
        language: Language = .en,
        full: Bool = false,
        images: URL? = nil
    ) {
        self.widget = widget
        self.families = families
        self.scenarios = scenarios
        self.output = output
        self.language = language
        self.full = full
        self.images = images
    }
}

@MainActor
public enum AWPreviewRunner {
    public static func run<V: AWView>(_ type: V.Type, _ options: PreviewOptions) throws -> PreviewReport {
        try L10n.$language.withValue(options.language) {
            try FileManager.default.createDirectory(at: options.output, withIntermediateDirectories: true)
            let store = try prepareStore(options)
            let scenarios = PreviewScenario.expandingTimelines(options.scenarios, now: Date())
            var issues = decodeIssues(type, scenarios)
            if options.scenarios.isEmpty {
                issues.append(Issue(
                    code: IssueCode.missingDefaultSample,
                    severity: .error,
                    message: L10n.pick(en: "No sample scenarios to render", ru: "Нет сценариев с данными для рендера"),
                    hint: L10n.pick(en: "Add samples/default.json shaped like the model", ru: "Добавь samples/default.json в форме модели")
                ))
            }
            let jobs = PreviewPlan.jobs(families: options.families, scenarios: scenarios, full: options.full)
            let cells = try MatrixRenderer.render(type, jobs: jobs, output: options.output, language: options.language, store: store)
            let sheet = options.output.appendingPathComponent("sheet.png")
            if let image = SheetComposer.compose(title: "\(options.widget) — aw preview", cells: cells) {
                try PNG.write(image, to: sheet)
            }
            let report = PreviewReport(widget: options.widget, sheet: sheet.path, cells: cells.map(\.cell), issues: issues)
            let encoder = AWJSON.encoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(report).write(to: options.output.appendingPathComponent("report.json"), options: .atomic)
            return report
        }
    }

    static func decodeIssues<V: AWView>(_ type: V.Type, _ scenarios: [PreviewScenario]) -> [Issue] {
        scenarios.compactMap { scenario in
            let entry = MatrixRenderer.entry(type, scenario: scenario)
            guard case .error(let message) = entry.phase else { return nil }
            return Issue(
                code: IssueCode.decode,
                severity: .error,
                message: L10n.pick(
                    en: "Sample \"\(scenario.name)\" does not match the model: \(message)",
                    ru: "Сэмпл \"\(scenario.name)\" не совпадает с моделью: \(message)"
                ),
                hint: L10n.pick(
                    en: "Make the JSON keys and types match the Codable model",
                    ru: "Приведи ключи и типы JSON к Codable-модели"
                ),
                file: scenario.source
            )
        }
    }

    private static func prepareStore(_ options: PreviewOptions) throws -> AWStore {
        let root = options.output.appendingPathComponent(".store", isDirectory: true)
        let images = root.appendingPathComponent(AppGroupLayout.widgetDirectory(options.widget)).appendingPathComponent("images")
        try? FileManager.default.removeItem(at: images)
        try FileManager.default.createDirectory(at: images.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let source = options.images, FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(at: source, to: images)
        }
        return AWStore(root: root)
    }
}

public enum AWPreviewMain {
    public static func run<V: AWView>(_ type: V.Type) -> Never {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let code = MainActor.assumeIsolated { execute(type, arguments: arguments) }
        exit(code)
    }

    @MainActor
    static func execute<V: AWView>(_ type: V.Type, arguments: [String]) -> Int32 {
        guard let command = arguments.first else {
            print("usage: preview render|validate ...")
            return 2
        }
        let options = PreviewArguments(Array(arguments.dropFirst()))
        switch command {
        case "render":
            return render(type, options)
        case "validate":
            return validate(type, options)
        default:
            print("unknown command \(command)")
            return 2
        }
    }

    @MainActor
    private static func render<V: AWView>(_ type: V.Type, _ arguments: PreviewArguments) -> Int32 {
        guard let widget = arguments.value("widget"), let output = arguments.value("out") else {
            print("render needs --widget and --out")
            return 2
        }
        let families = (arguments.value("families") ?? "small,medium,large")
            .split(separator: ",")
            .compactMap { Family(rawValue: String($0)) }
        let scenarios = arguments.values("scenario").compactMap { pair -> PreviewScenario? in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return PreviewScenario.load(name: parts[0], path: URL(fileURLWithPath: parts[1]))
        }
        let options = PreviewOptions(
            widget: widget,
            families: families,
            scenarios: scenarios,
            output: URL(fileURLWithPath: output, isDirectory: true),
            language: arguments.value("language").flatMap(Language.init(rawValue:)) ?? .en,
            full: arguments.flag("full"),
            images: arguments.value("images").map { URL(fileURLWithPath: $0, isDirectory: true) }
        )
        let geometry = arguments.value("geometry")
            .flatMap { try? JSONDecoder().decode(DeskGeometry.self, from: Data($0.utf8)) } ?? .fallback
        do {
            let report = try DeskGeometry.$current.withValue(geometry) {
                try AWPreviewRunner.run(type, options)
            }
            return report.hasErrors ? 1 : 0
        } catch {
            print("render failed: \(error)")
            return 3
        }
    }

    @MainActor
    private static func validate<V: AWView>(_ type: V.Type, _ arguments: PreviewArguments) -> Int32 {
        guard let path = arguments.value("data") else {
            print("validate needs --data")
            return 2
        }
        let scenario = PreviewScenario.load(name: "data", path: URL(fileURLWithPath: path))
        let issues = AWPreviewRunner.decodeIssues(type, [scenario])
        let object: [String: Any] = issues.isEmpty ? ["ok": true] : ["ok": false, "error": issues[0].message]
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
           let text = String(bytes: data, encoding: .utf8) {
            print(text)
        }
        return issues.isEmpty ? 0 : 1
    }
}

struct PreviewArguments {
    private var pairs: [(String, String)] = []
    private var flags: Set<String> = []

    init(_ arguments: [String]) {
        var index = 0
        while index < arguments.count {
            let item = arguments[index]
            guard item.hasPrefix("--") else {
                index += 1
                continue
            }
            let key = String(item.dropFirst(2))
            if index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") {
                pairs.append((key, arguments[index + 1]))
                index += 2
            } else {
                flags.insert(key)
                index += 1
            }
        }
    }

    func value(_ key: String) -> String? {
        pairs.last { $0.0 == key }?.1
    }

    func values(_ key: String) -> [String] {
        pairs.filter { $0.0 == key }.map(\.1)
    }

    func flag(_ key: String) -> Bool {
        flags.contains(key)
    }
}
