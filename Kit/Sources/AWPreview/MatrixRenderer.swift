import AWKit
import AWSchema
import Foundation
import SwiftUI

@MainActor
public enum MatrixRenderer {
    public static func render<V: AWView>(
        _ type: V.Type,
        jobs: [PreviewJob],
        output: URL,
        language: Language,
        store: AWStore
    ) throws -> [RenderedCell] {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        return try jobs.map { try renderCell(type, job: $0, output: output, language: language, store: store) }
    }

    static func entry<V: AWView>(_ type: V.Type, scenario: PreviewScenario) -> AWEntry<V.Model> {
        let input = AWTimelineInput(data: scenario.data, status: scenario.status, state: scenario.state, refresh: 1800, now: Date())
        return AWTimelineBuilder.build(V.Model.self, input).entries.first ?? AWEntry(date: Date(), data: nil, phase: .empty)
    }

    private static func renderCell<V: AWView>(
        _ type: V.Type,
        job: PreviewJob,
        output: URL,
        language: Language,
        store: AWStore
    ) throws -> RenderedCell {
        let context = AWContext(family: job.family, renderingMode: job.mode.renderingMode, isPreview: true, language: language)
        let content = AWFrame(context: context) { V(entry: entry(type, scenario: job.scenario)) }
            .environment(\.colorScheme, job.appearance == .dark ? .dark : .light)
            .environment(\.awStore, store)
        let chrome = ContainerChrome(family: job.family, appearance: job.appearance, mode: job.mode) { content }
        guard let image = PNG.render(chrome, scale: 2) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try PNG.write(image, to: output.appendingPathComponent(job.fileName))
        let size = job.family.size
        var issues: [Issue] = []
        let layout = TextFitChecker.collect(content, size: size)
        if let overflow = TextFitChecker.contentOverflow(layout.content, family: job.family) {
            let amount = Int(overflow.extra.rounded())
            let parts = TextFitChecker.largest(layout.blocks, vertical: overflow.vertical)
            let partsEn = parts.isEmpty ? "" : ". \(overflow.vertical ? "Tallest" : "Widest") parts: \(parts)"
            let partsRu = parts.isEmpty ? "" : ". \(overflow.vertical ? "Самые высокие" : "Самые широкие") части: \(parts)"
            issues.append(overflowIssue(
                en: "Content needs \(amount) pt more than the \(job.family.rawValue) widget has inside its margins (\(job.scenario.name))" + partsEn,
                ru: "Содержимому не хватает \(amount) pt внутри полей \(job.family.rawValue) (\(job.scenario.name))" + partsRu
            ))
        } else if let extent = FitProbe.overflow(content, size: size) {
            issues.append(overflowIssue(
                en: "Content spills \(Int(extent.rounded())) pt outside the \(job.family.rawValue) widget (\(job.scenario.name))",
                ru: "Содержимое вылезает на \(Int(extent.rounded())) pt за границы \(job.family.rawValue) (\(job.scenario.name))"
            ))
        }
        issues += TextFitChecker.issues(for: layout.fits, scenario: job.scenario.name)
        let overflows = issues.contains { $0.code == IssueCode.overflow }
        let space = emptySpace(content, job: job, blocks: layout.blocks, overflows: overflows)
        if let space, let area = space.area,
           let issue = SpaceChecker.issue(grid: space.grid, area: area, family: job.family, scenario: job.scenario.name, language: language) {
            issues.append(issue)
        }
        let cell = PreviewCell(
            family: job.family,
            appearance: job.appearance,
            mode: job.mode,
            scenario: job.scenario.name,
            image: job.fileName,
            idealHeight: Double(FitProbe.idealHeight(content, width: size.width)),
            issues: issues,
            emptyShare: space.map(\.grid.emptyShare),
            emptyArea: space.flatMap { found in found.area.map { Self.fractions($0, in: found.grid, family: job.family) } }
        )
        return RenderedCell(job: job, cell: cell, image: image)
    }

    private static func emptySpace(
        _ content: some View,
        job: PreviewJob,
        blocks: [AWBlock],
        overflows: Bool
    ) -> (grid: SpaceGrid, area: SpaceArea?)? {
        let judged = job.scenario.name == PreviewScenario.defaultName && job.scenario.data != nil
        guard judged, !overflows, !blocks.contains(where: { $0.name.hasPrefix("AWEmptyState") }) else {
            return nil
        }
        return SpaceChecker.measure(content, family: job.family)
    }

    private static func fractions(_ area: SpaceArea, in grid: SpaceGrid, family: Family) -> [Double] {
        let padding = Double(AWMetrics.padding(for: family))
        let full = (width: Double(family.size.width), height: Double(family.size.height))
        let cell = (width: (full.width - padding * 2) / Double(grid.columns), height: (full.height - padding * 2) / Double(grid.rows))
        let left = (padding + cell.width * Double(area.column)) / full.width
        let top = (padding + cell.height * Double(area.row)) / full.height
        return [left, top, cell.width * Double(area.columns) / full.width, cell.height * Double(area.rows) / full.height]
    }

    private static func overflowIssue(en: String, ru: String) -> Issue {
        Issue(
            code: IssueCode.overflow,
            severity: .error,
            message: L10n.pick(en: en, ru: ru),
            hint: L10n.pick(
                en: "Show fewer items in this family, use AWList maxRows, or switch layout with @Environment(\\.aw).family",
                ru: "Показывай меньше элементов в этом размере, ограничь AWList maxRows или меняй раскладку по @Environment(\\.aw).family"
            )
        )
    }
}
