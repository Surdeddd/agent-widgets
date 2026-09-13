import AWSchema
import Foundation
import SwiftUI
import Testing
@testable import AWKit
@testable import AWPreview

struct Numbers: Codable, Sendable {
    let value: Int
    let rows: Int
}

struct TallView: AWView {
    let entry: AWEntry<Numbers>

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<(entry.data?.rows ?? 0), id: \.self) { _ in
                Rectangle().fill(Color.gray).frame(height: 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct WordsView: AWView {
    let entry: AWEntry<Numbers>

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        AWText(String(repeating: "word ", count: entry.data?.rows ?? 1), .body, lines: 2)
    }
}

struct GalleryView: AWView {
    let entry: AWEntry<Numbers>
    @Environment(\.aw) private var context

    init(entry: AWEntry<Numbers>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader("Server", symbol: "server.rack", fetchedAt: Date().addingTimeInterval(-300))
                HStack(alignment: .center, spacing: AWSpace.m) {
                    AWMetric("\(data.value)", unit: "ms", label: "Latency", trend: .percent(-0.042, positiveIsGood: false))
                    if !context.isSmall {
                        Spacer(minLength: 0)
                        AWRing(progress: 0.72, tint: .green) { AWText("72%", .headline) }
                            .frame(width: 58, height: 58)
                    }
                }
                if !context.isSmall {
                    AWSparkline([3, 5, 4, 6, 8, 7, 9, 12, 10, 11], tint: .green)
                        .frame(height: context.family == .medium ? 22 : 40)
                }
                if context.family == .large || context.family == .extraLarge {
                    AWList(Array(0..<data.rows).map(RowItem.init), maxRows: 4) { item in
                        AWRow("Node \(item.id)", value: "\(20 + item.id) ms", status: item.id == 2 ? .warning : .ok)
                    }
                }
                Spacer(minLength: 0)
                if context.family != .medium {
                    AWBar(progress: 0.4, tint: .green)
                }
            }
        }
    }
}

struct RowItem: Identifiable {
    let id: Int
}

private func temporaryOutput() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("aw-preview-\(UUID().uuidString)", isDirectory: true)
}

private func scenario(_ json: String, name: String = "default") -> PreviewScenario {
    PreviewScenario(name: name, data: Data(json.utf8))
}

@MainActor
@Test func overflowIsDetectedOnlyWhenContentSpillsOut() throws {
    let output = temporaryOutput()
    defer { try? FileManager.default.removeItem(at: output) }
    let fits = PreviewJob(family: .small, appearance: .dark, mode: .color, scenario: scenario(#"{"value":1,"rows":3}"#))
    let spills = PreviewJob(family: .small, appearance: .dark, mode: .color, scenario: scenario(#"{"value":1,"rows":20}"#, name: "long"))
    let cells = try MatrixRenderer.render(TallView.self, jobs: [fits, spills], output: output, language: .en, store: AWStore(root: nil))
    #expect(!cells[0].cell.issues.contains { $0.code == IssueCode.overflow })
    #expect(cells[1].cell.issues.contains { $0.code == IssueCode.overflow })
    #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent(fits.fileName).path))
}

@MainActor
@Test func truncationIsReportedForAWText() throws {
    let output = temporaryOutput()
    defer { try? FileManager.default.removeItem(at: output) }
    let long = PreviewJob(family: .small, appearance: .light, mode: .color, scenario: scenario(#"{"value":1,"rows":60}"#))
    let short = PreviewJob(family: .small, appearance: .light, mode: .color, scenario: scenario(#"{"value":1,"rows":2}"#, name: "short"))
    let cells = try MatrixRenderer.render(WordsView.self, jobs: [long, short], output: output, language: .en, store: AWStore(root: nil))
    #expect(cells[0].cell.issues.contains { $0.code == IssueCode.truncation && $0.severity == .error })
    #expect(!cells[1].cell.issues.contains { $0.code == IssueCode.truncation })
}

@MainActor
@Test func runnerWritesSheetAndReport() throws {
    let output = temporaryOutput()
    defer { try? FileManager.default.removeItem(at: output) }
    let options = PreviewOptions(
        widget: "tall",
        families: [.small, .medium],
        scenarios: [scenario(#"{"value":1,"rows":3}"#), scenario(#"{"value":1,"rows":20}"#, name: "long")],
        output: output
    )
    let report = try AWPreviewRunner.run(TallView.self, options)
    #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("sheet.png").path))
    #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("report.json").path))
    #expect(report.cells.count == 3 * 2 + 1 * 2)
    #expect(report.hasErrors)
}

@MainActor
@Test func decodeErrorsAreReportedOncePerScenario() throws {
    let output = temporaryOutput()
    defer { try? FileManager.default.removeItem(at: output) }
    let options = PreviewOptions(widget: "tall", families: [.small, .medium], scenarios: [scenario(#"{"value":"x"}"#)], output: output)
    let report = try AWPreviewRunner.run(TallView.self, options)
    #expect(report.issues.filter { $0.code == IssueCode.decode }.count == 1)
}

@MainActor
@Test func componentGalleryFitsEveryFamily() throws {
    let output = ProcessInfo.processInfo.environment["AW_TEST_ARTIFACTS"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? temporaryOutput()
    let options = PreviewOptions(
        widget: "gallery",
        families: Family.allCases,
        scenarios: [scenario(#"{"value":42,"rows":5}"#), PreviewScenario(name: "empty", data: nil)],
        output: output
    )
    let report = try AWPreviewRunner.run(GalleryView.self, options)
    let errors = report.allIssues.filter { $0.severity == .error }
    #expect(errors.isEmpty, "\(errors.map(\.message))")
    if ProcessInfo.processInfo.environment["AW_TEST_ARTIFACTS"] == nil {
        try? FileManager.default.removeItem(at: output)
    }
}
