import AWSchema
import Foundation
import Testing
@testable import AWCore

private let fileManager = FileManager.default

private func write(_ text: String, to url: URL) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func makeWorkspace() throws -> URL {
    let root = fileManager.temporaryDirectory.appendingPathComponent("aw-ws-\(UUID().uuidString)")
    try write(
        #"{"name":"Demo","slug":"demo","bundlePrefix":"com.example","teamID":"ABCDE12345","signingIdentity":"Apple Development: x"}"#,
        to: root.appendingPathComponent("aw.json")
    )
    let widget = root.appendingPathComponent("widgets/weather")
    try write(
        #"{"id":"weather","name":"Weather","families":["small"],"view":"WeatherView"}"#,
        to: widget.appendingPathComponent("widget.json")
    )
    try write("struct WeatherView {}", to: widget.appendingPathComponent("WeatherView.swift"))
    try write("struct WeatherData {}", to: widget.appendingPathComponent("WeatherData.swift"))
    try write("{}", to: widget.appendingPathComponent("samples/default.json"))
    try write("{}", to: widget.appendingPathComponent("samples/long.json"))
    return root
}

private func canonical(_ url: URL) -> String {
    url.resolvingSymlinksInPath().path
}

@Test func locateFindsRootFromNestedFolder() throws {
    let root = try makeWorkspace()
    defer { try? fileManager.removeItem(at: root) }
    let workspace = try Workspace.locate(from: root.appendingPathComponent("widgets/weather"))
    #expect(canonical(workspace.root) == canonical(root))
    #expect(workspace.config.slug == "demo")
}

@Test func locateFailsOutsideWorkspace() throws {
    let lonely = fileManager.temporaryDirectory.appendingPathComponent("aw-none-\(UUID().uuidString)")
    try fileManager.createDirectory(at: lonely, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: lonely) }
    #expect(throws: AWError.self) { try Workspace.locate(from: lonely) }
}

@Test func widgetsAreLoadedWithSourcesAndSamples() throws {
    let root = try makeWorkspace()
    defer { try? fileManager.removeItem(at: root) }
    let widgets = try Workspace.load(at: root).widgets()
    #expect(widgets.map(\.manifest.id) == ["weather"])
    #expect(widgets[0].swiftFiles.map(\.lastPathComponent) == ["WeatherData.swift", "WeatherView.swift"])
    #expect(widgets[0].samples.keys.sorted() == ["default", "long"])
}

@Test func widgetLookupFailsForUnknownId() throws {
    let root = try makeWorkspace()
    defer { try? fileManager.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    #expect(throws: AWError.widgetNotFound("nope")) { try workspace.widget("nope") }
    #expect(try workspace.widget("weather").manifest.view == "WeatherView")
}

@Test func widgetLookupRejectsInvalidIds() throws {
    let root = try makeWorkspace()
    defer { try? fileManager.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    do {
        _ = try workspace.widget("../../etc")
        Issue.record("expected widgetIdInvalid")
    } catch let error as AWError {
        #expect(error.issue.code == IssueCode.widgetIdInvalid)
    }
    do {
        _ = try workspace.widget("Bad Id")
        Issue.record("expected widgetIdInvalid")
    } catch let error as AWError {
        #expect(error.issue.code == IssueCode.widgetIdInvalid)
    }
    #expect(throws: AWError.widgetNotFound("nope")) { try workspace.widget("nope") }
}

@Test func validateReportsMissingDefaultSampleAndIdMismatch() throws {
    let root = try makeWorkspace()
    defer { try? fileManager.removeItem(at: root) }
    try write(
        #"{"id":"clocks","name":"Clock","families":["small"],"view":"ClockView"}"#,
        to: root.appendingPathComponent("widgets/clock/widget.json")
    )
    let issues = try Workspace.load(at: root).validate()
    #expect(issues.contains { $0.code == IssueCode.missingDefaultSample && $0.severity == .warning })
    #expect(issues.contains { $0.code == IssueCode.manifestInvalid && $0.message.contains("clock") })
}

@Test func brokenManifestReportsItsPath() throws {
    let root = try makeWorkspace()
    defer { try? fileManager.removeItem(at: root) }
    try write(#"{"id": 3}"#, to: root.appendingPathComponent("widgets/bad/widget.json"))
    do {
        _ = try Workspace.load(at: root).widgets()
        Issue.record("expected invalidJSON")
    } catch let AWError.invalidJSON(file, reason) {
        #expect(file == "widgets/bad/widget.json")
        #expect(!reason.isEmpty)
    }
}

@Test func workspacePathsLiveUnderDotAW() throws {
    let root = try makeWorkspace()
    defer { try? fileManager.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    #expect(workspace.previewsDir(for: "weather").path.hasSuffix(".aw/previews/weather"))
    #expect(workspace.buildDir.path.hasSuffix(".aw/build"))
    #expect(workspace.cacheDir.path.hasSuffix(".aw/cache"))
}

private func makeEngineTree() throws -> URL {
    let root = fileManager.temporaryDirectory.appendingPathComponent("aw-engine-\(UUID().uuidString)")
    try fileManager.createDirectory(at: root.appendingPathComponent("Templates/app"), withIntermediateDirectories: true)
    try write("// package", to: root.appendingPathComponent("Kit/Package.swift"))
    try write("binary", to: root.appendingPathComponent(".build/arm64-apple-macosx/debug/aw"))
    return root
}

@Test func engineLocateUsesAWHome() throws {
    let root = try makeEngineTree()
    defer { try? fileManager.removeItem(at: root) }
    let engine = try Engine.locate(environment: ["AW_HOME": root.path], executable: URL(fileURLWithPath: "/usr/bin/true"))
    #expect(canonical(engine.root) == canonical(root))
    #expect(engine.kitPackage.lastPathComponent == "Kit")
}

@Test func engineLocateWalksUpFromExecutable() throws {
    let root = try makeEngineTree()
    defer { try? fileManager.removeItem(at: root) }
    let executable = root.appendingPathComponent(".build/arm64-apple-macosx/debug/aw")
    let engine = try Engine.locate(environment: [:], executable: executable)
    #expect(canonical(engine.root) == canonical(root))
}

@Test func engineLocateFailsWithoutResources() {
    #expect(throws: AWError.engineNotFound) {
        try Engine.locate(environment: [:], executable: URL(fileURLWithPath: "/usr/bin/true"))
    }
}
