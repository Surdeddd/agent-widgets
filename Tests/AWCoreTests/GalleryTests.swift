import AWSchema
import Foundation
import Testing
@testable import AWCore

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private func emptyWorkspace() throws -> Workspace {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-gallery-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("widgets"), withIntermediateDirectories: true)
    try Data(#"{"name":"T","slug":"t","bundlePrefix":"com.example","teamID":"ABCDE12345","signingIdentity":"x"}"#.utf8)
        .write(to: root.appendingPathComponent("aw.json"))
    return try Workspace.load(at: root)
}

private func installedEngine() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-engine-\(UUID().uuidString)", isDirectory: true)
    let widget = root.appendingPathComponent("gallery/steps/samples", isDirectory: true)
    try FileManager.default.createDirectory(at: widget, withIntermediateDirectories: true)
    let manifest = #"{"id":"steps","name":{"en":"Steps","ru":"Шаги"},"description":{"en":"Daily steps","ru":"Шаги за день"},"#
        + #""families":["small"],"view":"StepsView"}"#
    try Data(manifest.utf8).write(to: root.appendingPathComponent("gallery/steps/widget.json"))
    try Data("null\n".utf8).write(to: widget.appendingPathComponent("default.json"))
    return root
}

@Test func galleryListsTheWidgetsOfTheRepository() {
    let items = Gallery(engine: Engine(root: repoRoot)).list()
    #expect(items.map(\.id).contains("ai-limits"))
    #expect(items.count >= 5)
    #expect(items.allSatisfy { !$0.name.en.isEmpty && $0.name.ru != nil && !$0.families.isEmpty })
    #expect(items.allSatisfy { !$0.summary.en.isEmpty && $0.summary.ru != nil })
    #expect(items.first { $0.id == "ai-limits" }?.hasFeed == true)
    #expect(items.first { $0.id == "tiles" }?.hasFeed == false)
    #expect(items.map(\.id) == items.map(\.id).sorted())
}

@Test func anInstalledEngineKeepsItsGalleryNextToTheTemplates() throws {
    let root = try installedEngine()
    defer { try? FileManager.default.removeItem(at: root) }
    let items = Gallery(engine: Engine(root: root)).list()
    #expect(items.map(\.id) == ["steps"])
    #expect(items.first?.summary.ru == "Шаги за день")
}

@Test func addingCopiesTheWholeWidgetAndKeepsFeedsRunnable() throws {
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    let created = try Gallery(engine: Engine(root: repoRoot)).add("ai-limits", to: workspace)
    #expect(created.contains("widgets/ai-limits/widget.json"))
    #expect(created.contains("widgets/ai-limits/AiLimitsView.swift"))
    #expect(created.contains("widgets/ai-limits/samples/default.json"))
    #expect(!created.contains { $0.contains("__pycache__") })
    #expect(created == created.sorted())
    let widget = try workspace.widget("ai-limits")
    #expect(widget.manifest.view == "AiLimitsView")
    #expect(FileManager.default.isExecutableFile(atPath: widget.directory.appendingPathComponent("feed.py").path))
}

@Test func cachesAndHiddenFilesStayBehind() throws {
    let root = try installedEngine()
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = root.appendingPathComponent("gallery/steps/__pycache__", isDirectory: true)
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    try Data("x".utf8).write(to: cache.appendingPathComponent("feed.cpython-39.pyc"))
    try Data("x".utf8).write(to: root.appendingPathComponent("gallery/steps/.DS_Store"))
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    let created = try Gallery(engine: Engine(root: root)).add("steps", to: workspace)
    #expect(created == ["widgets/steps/samples/default.json", "widgets/steps/widget.json"])
}

@Test func addingTwiceReportsTheExistingWidget() throws {
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    let gallery = Gallery(engine: Engine(root: repoRoot))
    _ = try gallery.add("tiles", to: workspace)
    do {
        _ = try gallery.add("tiles", to: workspace)
        Issue.record("expected widgetExists")
    } catch let AWError.widgetExists(id) {
        #expect(id == "tiles")
    }
}

@Test func anUnknownGalleryWidgetListsTheKnownOnes() throws {
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    do {
        _ = try Gallery(engine: Engine(root: repoRoot)).add("nope", to: workspace)
        Issue.record("expected galleryUnknown")
    } catch let AWError.galleryUnknown(id, available) {
        #expect(id == "nope")
        #expect(available.contains("ai-limits"))
        #expect(AWError.galleryUnknown(id, available).issue.code == IssueCode.galleryUnknown)
        #expect(AWError.galleryUnknown(id, available).issue.hint?.contains("ai-limits") == true)
    }
    #expect((try? workspace.widget("nope")) == nil)
}

@Test func pathTricksInTheIdAreRejected() throws {
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    #expect(throws: AWError.self) { _ = try Gallery(engine: Engine(root: repoRoot)).add("../Templates", to: workspace) }
}
