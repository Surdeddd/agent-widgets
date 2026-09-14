import AWSchema
import Foundation
import Testing
@testable import AWCore

@Test func russianPreviewOfAFeedWidgetWarnsWithoutARussianSample() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let manifest = WidgetManifest(
        id: "probe",
        name: LocalizedText(en: "Probe"),
        families: [.small],
        view: "ProbeView",
        feed: FeedSpec(command: "./feed.py", every: Interval(seconds: 900))
    )
    try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("widgets/probe/widget.json"))
    let widget = try Workspace.load(at: root).widget("probe")
    let issues = PreviewPipeline.localizationIssues(widget, PreviewRequest(language: .ru))
    #expect(issues.map(\.code) == [IssueCode.sampleNotLocalized])
    #expect(issues.first?.hint?.contains("AW_LANG=ru ./feed.py > samples/default.ru.json") == true)
    #expect(PreviewPipeline.localizationIssues(widget, PreviewRequest(language: .en)).isEmpty)
    try Data(#"{"value": 8}"#.utf8).write(to: root.appendingPathComponent("widgets/probe/samples/default.ru.json"))
    #expect(PreviewPipeline.localizationIssues(try Workspace.load(at: root).widget("probe"), PreviewRequest(language: .ru)).isEmpty)
}

@Test func widgetsWithoutAFeedNeedNoRussianSample() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let widget = try Workspace.load(at: root).widget("probe")
    #expect(PreviewPipeline.localizationIssues(widget, PreviewRequest(language: .ru)).isEmpty)
}
