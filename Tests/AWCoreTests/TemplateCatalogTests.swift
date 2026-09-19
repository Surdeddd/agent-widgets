import AWSchema
import Foundation
import Testing
@testable import AWCore

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private let integration = ProcessInfo.processInfo.environment["AW_SKIP_INTEGRATION"] == nil

private func emptyWorkspace() throws -> Workspace {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-templates-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("widgets"), withIntermediateDirectories: true)
    try Data(#"{"name":"T","slug":"t","bundlePrefix":"com.example","teamID":"ABCDE12345","signingIdentity":"x"}"#.utf8)
        .write(to: root.appendingPathComponent("aw.json"))
    return try Workspace.load(at: root)
}

@Test func catalogListsTemplatesWithSummaries() {
    let templates = TemplateCatalog(engine: Engine(root: repoRoot)).list()
    #expect(templates.count >= 3)
    #expect(templates.allSatisfy { !$0.summary.en.isEmpty && $0.summary.ru != nil && !$0.families.isEmpty })
}

@Test func anEngineBehindASymlinkStillCreatesTheRightPaths() throws {
    let link = FileManager.default.temporaryDirectory.appendingPathComponent("aw-engine-link-\(UUID().uuidString)")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: repoRoot)
    defer { try? FileManager.default.removeItem(at: link) }
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    let created = try TemplateCatalog(engine: Engine(root: link)).instantiate("metric", id: "disk-space", in: workspace)
    #expect(created.contains("widgets/disk-space/DiskSpaceView.swift"))
    #expect(created.contains("widgets/disk-space/widget.json"))
    #expect(created.allSatisfy { $0.hasPrefix("widgets/disk-space/") && !$0.contains("//") })
    #expect(FileManager.default.fileExists(atPath: workspace.root.appendingPathComponent("widgets/disk-space/DiskSpaceView.swift").path))
}

@Test func typeNamesArePascalCase() {
    #expect(TemplateCatalog.typeName(for: "server-health") == "ServerHealth")
    #expect(TemplateCatalog.typeName(for: "weather") == "Weather")
}

@Test func instantiateSubstitutesTokens() throws {
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    let catalog = TemplateCatalog(engine: Engine(root: repoRoot))
    let created = try catalog.instantiate("metric", id: "disk-space", name: LocalizedText(en: "Disk", ru: "Диск"), families: [.small], in: workspace)
    #expect(created.contains("widgets/disk-space/DiskSpaceView.swift"))
    let widget = try workspace.widget("disk-space")
    #expect(widget.manifest.view == "DiskSpaceView")
    #expect(widget.manifest.name.ru == "Диск")
    #expect(widget.manifest.families == [.small])
    let source = try String(contentsOf: widget.directory.appendingPathComponent("DiskSpaceView.swift"), encoding: .utf8)
    #expect(!source.contains("__"))
    let feed = widget.directory.appendingPathComponent("feed.py").path
    #expect(FileManager.default.isExecutableFile(atPath: feed))
    #expect(throws: AWError.widgetExists("disk-space")) {
        try catalog.instantiate("metric", id: "disk-space", in: workspace)
    }
}

@Test func instantiateRejectsInvalidId() throws {
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    do {
        _ = try TemplateCatalog(engine: Engine(root: repoRoot)).instantiate("metric", id: "Bad Id", in: workspace)
        Issue.record("expected widgetIdInvalid")
    } catch let error as AWError {
        #expect(error.issue.code == IssueCode.widgetIdInvalid)
    }
    let created = (try? FileManager.default.contentsOfDirectory(
        at: workspace.widgetsDir,
        includingPropertiesForKeys: nil
    )) ?? []
    #expect(created.isEmpty)
}

@Test func unknownTemplateListsAlternatives() throws {
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    do {
        _ = try TemplateCatalog(engine: Engine(root: repoRoot)).instantiate("nope", id: "x", in: workspace)
        Issue.record("expected templateUnknown")
    } catch let AWError.templateUnknown(name, available) {
        #expect(name == "nope")
        #expect(available.contains("metric"))
    }
}

@Test(.enabled(if: integration))
func everyTemplateRendersWithoutErrors() async throws {
    let workspace = try emptyWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace.root) }
    let engine = Engine(root: repoRoot)
    let catalog = TemplateCatalog(engine: engine)
    let base = ProcessInfo.processInfo.environment["AW_TEST_KIT_CACHE"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    let cache = KitCache(engine: engine, runner: SystemProcessRunner(), base: base)
    let pipeline = PreviewPipeline(workspace: workspace, cache: cache, runner: SystemProcessRunner())
    for template in catalog.list() {
        let id = "t-\(template.id)"
        _ = try catalog.instantiate(template.id, id: id, in: workspace)
        let outcome = try await pipeline.run(try Workspace.load(at: workspace.root).widget(id), PreviewRequest(language: .en))
        let errors = outcome.allIssues.filter { $0.severity == .error }
        #expect(errors.isEmpty, "\(template.id): \(errors.map { "\($0.code) \($0.message) \($0.file ?? "")" })")
        let hollow = outcome.allIssues.filter { $0.code == IssueCode.underfilled }
        #expect(template.id == "blank" || hollow.isEmpty, "\(template.id): \(hollow.map(\.message))")
        if let artifacts = ProcessInfo.processInfo.environment["AW_TEST_ARTIFACTS"], let sheet = outcome.report?.sheet {
            let destination = URL(fileURLWithPath: artifacts).appendingPathComponent("template-\(template.id).png")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: URL(fileURLWithPath: sheet), to: destination)
        }
    }
}
