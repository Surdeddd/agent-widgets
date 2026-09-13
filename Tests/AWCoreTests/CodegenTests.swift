import AWSchema
import Foundation
import Testing
@testable import AWCore

private func source(_ id: String, view: String? = nil, families: [Family] = [.small, .medium], sample: URL? = nil) -> WidgetSource {
    let manifest = WidgetManifest(
        id: id,
        name: LocalizedText(en: "Name \(id)", ru: "Имя \(id)"),
        families: families,
        view: view ?? TemplateCatalog.typeName(for: id) + "View"
    )
    return WidgetSource(
        manifest: manifest,
        directory: URL(fileURLWithPath: "/ws/widgets/\(id)"),
        swiftFiles: [],
        samples: sample.map { ["default": $0] } ?? [:]
    )
}

private let config = WorkspaceConfig(
    name: "Demo Widgets",
    slug: "demo",
    bundlePrefix: "com.example",
    teamID: "ABCDE12345",
    signingIdentity: "Apple Development: dev@example.com (XYZ)"
)

@Test func registryDeclaresEveryWidgetAndTheDevSlot() {
    let code = RegistryGenerator.generate([source("weather"), source("server-health", families: [.large])])
    #expect(code.contains("struct AWWidget_weather: Widget"))
    #expect(code.contains("kind: \"aw.weather\""))
    #expect(code.contains("AWProvider<WeatherView>(id: \"weather\", refresh: 1800"))
    #expect(code.contains(".supportedFamilies([.systemSmall, .systemMedium])"))
    #expect(code.contains("struct AWWidget_server_health: Widget"))
    #expect(code.contains("case \"server-health\": AWDevRender<ServerHealthView>(entry: entry)"))
    #expect(code.contains("kind: \"aw.dev\""))
    #expect(code.contains("AWDevWidget()"))
    #expect(code.contains("L10n.pick(en: \"Name weather\", ru: \"Имя weather\")"))
    #expect(code.contains("AWWidgetContainer(widget: \"weather\", kind: \"aw.weather\") { WeatherView(entry: entry) }"))
    #expect(code.contains("AWWidgetContainer(widget: entry.widget, kind: \"aw.dev\") { AWDevView(entry: entry) }"))
    #expect(code.contains("static var includedPackages: [any AppIntentsPackage.Type] { [AWKitIntents.self] }"))
}

@Test func registryChunksLargeBundles() {
    let widgets = (0..<23).map { source("w\($0)") }
    let code = RegistryGenerator.generate(widgets)
    #expect(code.contains("struct AWBundle0: WidgetBundle"))
    #expect(code.contains("struct AWBundle2: WidgetBundle"))
    #expect(!code.contains("struct AWBundle3: WidgetBundle"))
    #expect(code.contains("AWBundle2().body"))
}

@Test func registryWithoutWidgetsStillHasTheDevSlot() {
    let code = RegistryGenerator.generate([])
    #expect(code.contains("@main"))
    #expect(code.contains("AWDevWidget()"))
    #expect(!code.contains("AWBundle0"))
}

@Test func registryEmbedsDefaultSamples() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("aw-sample-\(UUID().uuidString).json")
    try Data(#"{"a":1}"#.utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let code = RegistryGenerator.generate([source("weather", sample: file)])
    #expect(code.contains("static let s_weather: Data? = Data(base64Encoded: \"\(Data(#"{"a":1}"#.utf8).base64EncodedString())\")"))
}

@Test func literalsEscapeQuotesAndUnicode() {
    #expect(RegistryGenerator.literal("say \"hi\"") == #""say \"hi\"""#)
    #expect(RegistryGenerator.literal("Погода") == "\"Погода\"")
    #expect(RegistryGenerator.literal("Weather / Погода") == "\"Weather / Погода\"")
    #expect(RegistryGenerator.literal("a\\b\nc\u{1}") == #""a\\b\nc\u{1}""#)
}

@Test func yamlQuotingKeepsSlashesAndEscapesControls() {
    #expect(ProjectGenerator.quoted("../../widgets/a b") == "\"../../widgets/a b\"")
    #expect(ProjectGenerator.quoted("Apple Development: a (X)") == "\"Apple Development: a (X)\"")
    #expect(ProjectGenerator.quoted("tab\there\u{1}") == #""tab\there\x01""#)
}

@Test func projectDescribesBothTargets() {
    let generator = ProjectGenerator(
        config: config,
        widgets: [source("weather")],
        buildDir: URL(fileURLWithPath: "/ws/.aw/build"),
        kitPackage: URL(fileURLWithPath: "/engine/Kit"),
        version: "0.1.0",
        buildNumber: "42"
    )
    let yaml = generator.generate()
    #expect(yaml.contains("PRODUCT_BUNDLE_IDENTIFIER: \"com.example.demo\""))
    #expect(yaml.contains("PRODUCT_BUNDLE_IDENTIFIER: \"com.example.demo.widgets\""))
    #expect(yaml.contains("com.apple.security.application-groups: [\"ABCDE12345.com.example.demo\"]"))
    #expect(yaml.contains("CFBundleURLSchemes: [\"aw-demo\"]"))
    #expect(yaml.contains("CODE_SIGN_IDENTITY: \"Apple Development: dev@example.com (XYZ)\""))
    #expect(yaml.contains("- path: \"../../widgets/weather\""))
    #expect(yaml.contains("path: \"/engine/Kit\""))
    #expect(yaml.contains("product: AWKit"))
    #expect(yaml.contains("AWAppGroup: \"ABCDE12345.com.example.demo\""))
}

@Test func relativePathsWalkUpFromTheBuildDir() {
    let generator = ProjectGenerator(
        config: config,
        widgets: [],
        buildDir: URL(fileURLWithPath: "/ws/.aw/build"),
        kitPackage: URL(fileURLWithPath: "/engine/Kit"),
        version: "0.1.0",
        buildNumber: "1"
    )
    #expect(generator.relativePath(to: URL(fileURLWithPath: "/ws/widgets/a b")) == "../../widgets/a b")
}
