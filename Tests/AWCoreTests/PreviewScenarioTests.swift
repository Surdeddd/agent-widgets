import AWSchema
import Foundation
import Testing
@testable import AWCore

@Test func languageSpecificSamplesReplaceTheDefaultOnes() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let samples = root.appendingPathComponent("widgets/probe/samples")
    try Data(#"{"value": 8}"#.utf8).write(to: samples.appendingPathComponent("default.ru.json"))
    try Data(#"{"value": 9}"#.utf8).write(to: samples.appendingPathComponent("long.json"))
    let workspace = try Workspace.load(at: root)
    let widget = try workspace.widget("probe")
    let pipeline = PreviewPipeline(
        workspace: workspace,
        cache: KitCache(engine: Engine(root: ProbeWorkspace.repoRoot), runner: FakeProcessRunner()),
        runner: FakeProcessRunner()
    )
    let russian = pipeline.scenarios(of: widget, request: PreviewRequest(language: .ru))
    #expect(russian.map(\.0) == ["default", "long"])
    #expect(russian.map(\.1.lastPathComponent) == ["default.ru.json", "long.json"])
    let english = pipeline.scenarios(of: widget, request: PreviewRequest(language: .en))
    #expect(english.map(\.1.lastPathComponent) == ["default.json", "long.json"])
}
