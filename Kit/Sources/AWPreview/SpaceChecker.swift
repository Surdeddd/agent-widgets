import AWKit
import AWSchema
import CoreGraphics
import Foundation
import SwiftUI

struct SpaceArea: Equatable, Sendable {
    let column: Int
    let row: Int
    let columns: Int
    let rows: Int

    var cells: Int {
        columns * rows
    }

    func place(in grid: SpaceGrid, language: Language) -> String {
        let centerX = (Double(column) + Double(columns) / 2) / Double(grid.columns)
        let centerY = (Double(row) + Double(rows) / 2) / Double(grid.rows)
        let spansWidth = columns * 4 >= grid.columns * 3
        let spansHeight = rows * 4 >= grid.rows * 3
        let horizontal = spansWidth ? nil : (centerX < 0.4 ? 0 : (centerX > 0.6 ? 2 : 1))
        let vertical = spansHeight ? nil : (centerY < 0.4 ? 0 : (centerY > 0.6 ? 2 : 1))
        let english = Self.words(horizontal, vertical, sides: ["left", "", "right"], levels: ["top", "", "bottom"], middle: "middle")
        let russian = Self.words(horizontal, vertical, sides: ["слева", "", "справа"], levels: ["вверху", "", "внизу"], middle: "посередине")
        return language == .ru ? [russian.side, russian.level].filter { !$0.isEmpty }.joined(separator: " ")
            : [english.level, english.side].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func words(_ horizontal: Int?, _ vertical: Int?, sides: [String], levels: [String], middle: String) -> (side: String, level: String) {
        let side = horizontal.map { sides[$0] } ?? ""
        let level = vertical.map { levels[$0] } ?? ""
        return side.isEmpty && level.isEmpty ? (middle, "") : (side, level)
    }
}

struct SpaceGrid: Equatable, Sendable {
    let columns: Int
    let rows: Int
    let inked: [Bool]

    var emptyShare: Double {
        guard let area = largestEmpty, !inked.isEmpty else { return 0 }
        return Double(area.cells) / Double(inked.count)
    }

    /// A gap inside a row with content on both sides — a label on the left, a value on the right — reads as one line, not as a hole, up to half the width.
    var bridged: [Bool] {
        var cells = inked
        for row in 0..<rows {
            var column = 0
            while column < columns {
                guard !inked[row * columns + column] else {
                    column += 1
                    continue
                }
                var end = column
                while end < columns, !inked[row * columns + end] {
                    end += 1
                }
                if column > 0, end < columns, (end - column) * 2 <= columns {
                    for index in column..<end {
                        cells[row * columns + index] = true
                    }
                }
                column = end
            }
        }
        return cells
    }

    /// The largest rectangle of cells with nothing drawn in them.
    var largestEmpty: SpaceArea? {
        let inked = bridged
        var heights = [Int](repeating: 0, count: columns)
        var best: SpaceArea?
        for row in 0..<rows {
            for column in 0..<columns {
                heights[column] = inked[row * columns + column] ? 0 : heights[column] + 1
            }
            for start in 0..<columns where heights[start] > 0 {
                var lowest = heights[start]
                for end in start..<columns {
                    lowest = min(lowest, heights[end])
                    if lowest == 0 {
                        break
                    }
                    let width = end - start + 1
                    if width * lowest > (best?.cells ?? 0) {
                        best = SpaceArea(column: start, row: row - lowest + 1, columns: width, rows: lowest)
                    }
                }
            }
        }
        return best
    }
}

@MainActor
enum SpaceChecker {
    static let gridRows = 6
    static let inkShare = 0.015
    static let inkAlpha: UInt8 = 20

    static func threshold(for family: Family) -> Double {
        switch family {
        case .small: 0.4
        case .medium: 0.3
        case .large, .extraLarge: 0.25
        }
    }

    /// Where the rendered content leaves one big empty rectangle; nil when the widget uses its space.
    static func measure(_ content: some View, family: Family) -> (grid: SpaceGrid, area: SpaceArea?)? {
        let size = family.size
        guard let image = PNG.render(content.frame(width: size.width, height: size.height), scale: 1),
              let grid = grid(of: image, padding: AWMetrics.padding(for: family))
        else {
            return nil
        }
        return (grid, grid.largestEmpty)
    }

    static func issue(grid: SpaceGrid, area: SpaceArea, family: Family, scenario: String, language: Language) -> Issue? {
        let share = Double(area.cells) / Double(grid.inked.count)
        guard share >= threshold(for: family) else {
            return nil
        }
        let percent = Int((share * 100).rounded())
        let english = area.place(in: grid, language: .en)
        let russian = area.place(in: grid, language: .ru)
        return Issue(
            code: IssueCode.underfilled,
            severity: .warning,
            message: L10n.pick(
                en: "\(percent) % of the \(family.rawValue) widget is one empty area, \(english) (\(scenario))",
                ru: "\(percent) % виджета \(family.rawValue) — одна пустая область, \(russian) (\(scenario))"
            ),
            hint: L10n.pick(
                en: "A size has to earn its space: show what only this size can hold (more rows, a breakdown, a trend), make the hero bigger, "
                    + "or drop \(family.rawValue) from \"families\" in widget.json",
                ru: "Размер должен оправдывать своё место: покажи то, что влезает только сюда (больше строк, разбивку, тренд), укрупни главное "
                    + "или убери \(family.rawValue) из \"families\" в widget.json"
            )
        )
    }

    static func grid(of image: CGImage, padding: CGFloat) -> SpaceGrid? {
        let width = image.width
        let height = image.height
        var alpha = [UInt8](repeating: 0, count: width * height)
        let drawn = alpha.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        let inset = Int(padding.rounded())
        let area = (width: width - inset * 2, height: height - inset * 2)
        guard drawn, area.width > gridRows, area.height > gridRows else {
            return nil
        }
        let rows = gridRows
        let columns = max(1, Int((Double(area.width) / Double(area.height) * Double(rows)).rounded()))
        var inked = [Bool](repeating: false, count: rows * columns)
        for row in 0..<rows {
            for column in 0..<columns {
                let left = inset + column * area.width / columns
                let right = inset + (column + 1) * area.width / columns
                let top = inset + row * area.height / rows
                let bottom = inset + (row + 1) * area.height / rows
                var count = 0
                for y in top..<bottom {
                    for x in left..<right where alpha[y * width + x] > inkAlpha {
                        count += 1
                    }
                }
                let total = max((right - left) * (bottom - top), 1)
                inked[row * columns + column] = Double(count) / Double(total) >= inkShare
            }
        }
        return SpaceGrid(columns: columns, rows: rows, inked: inked)
    }
}
