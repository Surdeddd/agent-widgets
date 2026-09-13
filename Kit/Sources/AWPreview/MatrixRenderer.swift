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
        let context = AWContext(family: job.family, renderingMode: job.mode == .idle ? .vibrant : .fullColor, isPreview: true, language: language)
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
        if let extent = FitProbe.overflow(content, size: size) {
            issues.append(Issue(
                code: IssueCode.overflow,
                severity: .error,
                message: L10n.pick(
                    en: "Content spills \(Int(extent.rounded())) pt outside the \(job.family.rawValue) widget (\(job.scenario.name))",
                    ru: "Содержимое вылезает на \(Int(extent.rounded())) pt за границы \(job.family.rawValue) (\(job.scenario.name))"
                ),
                hint: L10n.pick(
                    en: "Show fewer items in this family, use AWList maxRows, or switch layout with @Environment(\\.aw).family",
                    ru: "Показывай меньше элементов в этом размере, ограничь AWList maxRows или меняй раскладку по @Environment(\\.aw).family"
                )
            ))
        }
        issues += TextFitChecker.issues(for: TextFitChecker.collect(content, size: size), scenario: job.scenario.name)
        let cell = PreviewCell(
            family: job.family,
            appearance: job.appearance,
            mode: job.mode,
            scenario: job.scenario.name,
            image: job.fileName,
            idealHeight: Double(FitProbe.idealHeight(content, width: size.width)),
            issues: issues
        )
        return RenderedCell(job: job, cell: cell, image: image)
    }
}
