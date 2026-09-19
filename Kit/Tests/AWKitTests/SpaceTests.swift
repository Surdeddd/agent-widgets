import AWSchema
import Foundation
import SwiftUI
import Testing
@testable import AWKit
@testable import AWPreview

private func grid(_ rows: [String]) -> SpaceGrid {
    SpaceGrid(columns: rows[0].count, rows: rows.count, inked: rows.flatMap { $0.map { $0 == "#" } })
}

struct CornerView: AWView {
    let entry: AWEntry<Numbers>

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AWHeader("Corner", symbol: "square")
            AWText("42", .hero)
        }
    }
}

struct FullView: AWView {
    let entry: AWEntry<Numbers>

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AWHeader("Full", symbol: "square")
            ForEach(0..<9, id: \.self) { index in
                AWRow("Row number \(index)", value: "\(index * 11)%")
            }
            Spacer(minLength: 0)
        }
    }
}

struct ComposedSmallView: AWView {
    let entry: AWEntry<Numbers>

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AWHeader("Steps", symbol: "figure.walk")
            AWText("8 412", .hero)
            Spacer(minLength: 0)
            AWText("goal 10 000", .caption)
            AWBar(progress: 0.84, tint: .green)
        }
    }
}

struct PackedView: AWView {
    let entry: AWEntry<Numbers>

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        Rectangle()
            .fill(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QuietView: AWView {
    let entry: AWEntry<Numbers>

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        AWEmptyState(symbol: "moon.zzz", title: "All quiet", subtitle: "Nothing to show")
    }
}

@MainActor
private func cell<V: AWView>(_ view: V.Type, family: Family, sample: String = "default") throws -> PreviewCell where V.Model == Numbers {
    let output = FileManager.default.temporaryDirectory.appendingPathComponent("aw-space-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: output) }
    let scenario = PreviewScenario(name: sample, data: Data(#"{"value":1,"rows":1}"#.utf8))
    let job = PreviewJob(family: family, appearance: .dark, mode: .color, scenario: scenario)
    return try MatrixRenderer.render(view, jobs: [job], output: output, language: .en, store: AWStore(root: nil))[0].cell
}

@MainActor
private func issues<V: AWView>(
    _ view: V.Type,
    family: Family,
    data: String? = #"{"value":1,"rows":1}"#,
    sample: String = "default"
) throws -> [AWSchema.Issue] where V.Model == Numbers {
    let output = FileManager.default.temporaryDirectory.appendingPathComponent("aw-space-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: output) }
    let scenario = PreviewScenario(name: sample, data: data.map { Data($0.utf8) })
    let job = PreviewJob(family: family, appearance: .dark, mode: .color, scenario: scenario)
    return try MatrixRenderer.render(view, jobs: [job], output: output, language: .en, store: AWStore(root: nil))[0].cell.issues
}

@Test func theLargestEmptyRectangleIsFound() {
    let area = grid([
        "##....",
        "##....",
        "#.....",
        "######"
    ]).largestEmpty
    #expect(area == SpaceArea(column: 2, row: 0, columns: 4, rows: 3))
    #expect(grid(["##", "##"]).largestEmpty == nil)
    #expect(grid(["..", ".."]).largestEmpty == SpaceArea(column: 0, row: 0, columns: 2, rows: 2))
    #expect(grid(["#.#", "...", "#.#"]).largestEmpty?.cells == 3)
}

@Test func aGapBetweenALabelAndItsValueIsNotAHole() {
    let list = grid([
        "##...#",
        "##...#",
        "##...#",
        "##...#"
    ])
    #expect(list.largestEmpty == nil)
    let stretched = grid([
        "##.........#",
        "##.........#",
        "##.........#"
    ])
    #expect(stretched.largestEmpty == SpaceArea(column: 2, row: 0, columns: 9, rows: 3))
    let open = grid([
        "##....",
        "##....",
        "##...."
    ])
    #expect(open.largestEmpty == SpaceArea(column: 2, row: 0, columns: 4, rows: 3))
}

@Test func theShareCountsTheWholeGrid() {
    let sample = grid([
        "######",
        "###...",
        "###...",
        "###..."
    ])
    #expect(sample.emptyShare == 9.0 / 24.0)
    #expect(grid(["##", "##"]).emptyShare == 0)
}

@Test func theAreaIsNamedByWhereItSits() {
    let wide = grid(Array(repeating: String(repeating: ".", count: 12), count: 6))
    #expect(SpaceArea(column: 8, row: 3, columns: 4, rows: 3).place(in: wide, language: .en) == "bottom right")
    #expect(SpaceArea(column: 0, row: 0, columns: 4, rows: 2).place(in: wide, language: .en) == "top left")
    #expect(SpaceArea(column: 4, row: 2, columns: 4, rows: 2).place(in: wide, language: .en) == "middle")
    #expect(SpaceArea(column: 0, row: 4, columns: 12, rows: 2).place(in: wide, language: .en) == "bottom")
    #expect(SpaceArea(column: 8, row: 0, columns: 4, rows: 6).place(in: wide, language: .ru) == "справа")
    #expect(SpaceArea(column: 8, row: 3, columns: 4, rows: 3).place(in: wide, language: .ru) == "справа внизу")
}

@MainActor
@Test func aBigWidgetWithACornerOfContentIsUnderfilled() throws {
    let found = try issues(CornerView.self, family: .large)
    let issue = try #require(found.first { $0.code == IssueCode.underfilled }, "\(found.map(\.code))")
    #expect(issue.severity == .warning)
    #expect(issue.message.contains("large"))
    #expect(issue.message.contains("default"))
    #expect(issue.hint?.contains("widget.json") == true)
}

@MainActor
@Test func aFilledWidgetAndAComposedSmallOneAreLeftAlone() throws {
    #expect(!(try issues(FullView.self, family: .large)).contains { $0.code == IssueCode.underfilled })
    #expect(!(try issues(ComposedSmallView.self, family: .small)).contains { $0.code == IssueCode.underfilled })
}

@MainActor
@Test func aSmallWidgetMayBreatheButNotSitInACorner() throws {
    #expect((try issues(CornerView.self, family: .small)).contains { $0.code == IssueCode.underfilled })
    #expect(SpaceChecker.threshold(for: .small) > SpaceChecker.threshold(for: .large))
}

@MainActor
@Test func emptyStatesAndSideSamplesAreNotJudged() throws {
    #expect(!(try issues(QuietView.self, family: .large)).contains { $0.code == IssueCode.underfilled })
    #expect(!(try issues(CornerView.self, family: .large, data: nil)).contains { $0.code == IssueCode.underfilled })
    #expect(!(try issues(CornerView.self, family: .large, sample: "idle")).contains { $0.code == IssueCode.underfilled })
}

@MainActor
@Test func theReportTellsAFullWidgetFromOneThatWasNotJudged() throws {
    let full = try cell(PackedView.self, family: .large)
    #expect(full.emptyShare == 0)
    #expect(full.emptyArea == nil)
    let corner = try cell(CornerView.self, family: .large)
    #expect((corner.emptyShare ?? 0) > 0.25)
    #expect(corner.emptyArea?.count == 4)
    #expect(try cell(CornerView.self, family: .large, sample: "idle").emptyShare == nil)
}
