import AWSchema
import CoreGraphics
import Foundation
import Testing
@testable import AWKit
@testable import AWPreview

@MainActor
@Test func longIssueLabelsStayInsideTheirTile() throws {
    let output = FileManager.default.temporaryDirectory.appendingPathComponent("aw-sheet-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: output) }
    let scenario = PreviewScenario(name: "default", data: Data(#"{"value":1,"rows":3}"#.utf8))
    let job = PreviewJob(family: .small, appearance: .dark, mode: .color, scenario: scenario)
    let cells = try MatrixRenderer.render(CrowdedView.self, jobs: [job], output: output, language: .en, store: AWStore(root: nil))
    var noisy = cells
    noisy[0].cell.issues = ["SAMPLE_NOT_LOCALIZED", "TRUNCATION", "OVERFLOW", "TINY_TEXT"].map { Issue(code: $0, severity: .error, message: "x") }
    let quiet = try #require(SheetComposer.compose(title: "t", cells: cells))
    let loud = try #require(SheetComposer.compose(title: "t", cells: noisy))
    #expect(loud.width == quiet.width)
}
