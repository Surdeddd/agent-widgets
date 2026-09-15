import AWSchema
import SwiftUI

@MainActor
enum SheetComposer {
    private struct Row: Identifiable {
        let id: Int
        let label: String
        let cells: [RenderedCell]
    }

    static func compose(title: String, cells: [RenderedCell]) -> CGImage? {
        var rows: [Row] = []
        for cell in cells {
            if let last = rows.last, last.label == cell.job.rowLabel {
                rows[rows.count - 1] = Row(id: last.id, label: last.label, cells: last.cells + [cell])
            } else {
                rows.append(Row(id: rows.count, label: cell.job.rowLabel, cells: [cell]))
            }
        }
        let sheet = VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.label)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            tile(cell)
                        }
                    }
                }
            }
        }
        .padding(28)
        .background(Color(white: 0.09))
        return PNG.render(sheet, scale: 1, opaque: true)
    }

    private static func tile(_ rendered: RenderedCell) -> some View {
        let family = rendered.job.family
        let failing = rendered.cell.issues.contains { $0.severity == .error }
        let codes = Set(rendered.cell.issues.map(\.code)).sorted().joined(separator: " ")
        return VStack(alignment: .leading, spacing: 5) {
            Image(decorative: rendered.image, scale: 2)
                .resizable()
                .frame(width: family.size.width, height: family.size.height)
                .overlay(
                    RoundedRectangle(cornerRadius: AWMetrics.cornerRadius(for: family), style: .continuous)
                        .strokeBorder(failing ? Color.red : Color.clear, lineWidth: 3)
                )
            Text("\(family.rawValue)  ideal \(Int(rendered.cell.idealHeight))/\(Int(family.size.height))  \(codes)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(failing ? Color.red : Color.white.opacity(0.55))
                .lineLimit(3)
                .frame(width: family.size.width, alignment: .leading)
        }
    }
}

import AWKit
