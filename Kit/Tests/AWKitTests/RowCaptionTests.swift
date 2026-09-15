import AWSchema
import Foundation
import SwiftUI
import Testing
@testable import AWKit
@testable import AWPreview

struct LoadLineView: AWView {
    let entry: AWEntry<Numbers>

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AWText("1049д 15ч", .hero)
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                AWText("Нагрузка 88.9 · 99.9 · 77.8", .caption)
            }
        }
    }
}

@MainActor
@Test func aCaptionSqueezedNextToAnIconIsReportedAsTruncated() throws {
    let output = FileManager.default.temporaryDirectory.appendingPathComponent("aw-row-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: output) }
    let scenario = PreviewScenario(name: "default", data: Data(#"{"value":1,"rows":1}"#.utf8))
    let job = PreviewJob(family: .small, appearance: .dark, mode: .color, scenario: scenario)
    let cells = try MatrixRenderer.render(LoadLineView.self, jobs: [job], output: output, language: .ru, store: AWStore(root: nil))
    #expect(cells[0].cell.issues.contains { $0.code == IssueCode.truncation }, "\(cells[0].cell.issues.map(\.code))")
}
