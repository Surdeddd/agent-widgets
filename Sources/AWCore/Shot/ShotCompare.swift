import AWSchema
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ShotComparison: Codable, Equatable, Sendable {
    public var shot: String
    public var cell: String
    public var image: String
    public var family: Family
    public var deskSize: CGSize
    public var previewSize: CGSize
    public var structure: Double

    public var sizeDelta: CGSize {
        CGSize(width: deskSize.width - previewSize.width, height: deskSize.height - previewSize.height)
    }

    public var sizeMatches: Bool {
        max(abs(sizeDelta.width), abs(sizeDelta.height)) <= ShotCompare.sizeTolerance
    }

    public var matches: Bool {
        sizeMatches && structure >= ShotCompare.structureThreshold
    }

    public var summary: String {
        let mark = matches ? "✓" : "✗"
        let percent = Int((structure * 100).rounded())
        return L10n.pick(
            en: "\(mark) preview vs desktop, \(family.rawValue): outlines agree on \(percent) % → \(image)",
            ru: "\(mark) превью и стол, \(family.rawValue): контуры совпадают на \(percent) % → \(image)"
        )
    }
}

public enum ShotCompare {
    public static let sizeTolerance: CGFloat = 2
    public static let structureThreshold = 0.6
    public static let previewScale: CGFloat = 2

    /// Scores a captured window against the closest preview cell and writes preview · desktop · outlines side by side to `output`.
    public static func compare(_ shot: ShotRecord, cells: [URL], output: URL) throws -> ShotComparison? {
        let images = cells.compactMap { url in loadImage(url).map { (url, $0) } }
        guard let family = shot.window.family, shot.window.width > 0, let first = images.first?.1,
              let captured = loadImage(URL(fileURLWithPath: shot.path))
        else {
            return nil
        }
        let expected = CGSize(width: CGFloat(first.width) / previewScale, height: CGFloat(first.height) / previewScale)
        let scale = CGFloat(captured.width) / CGFloat(shot.window.width)
        let width = max(Int(expected.width.rounded()), 3)
        let height = max(Int(expected.height.rounded()), 3)
        guard let content = content(of: captured, scale: scale),
              let desk = EdgeMap(content.image, width: width, height: height)
        else {
            return nil
        }
        let candidates = images.compactMap { url, image -> Candidate? in
            guard let edges = EdgeMap(image, width: width, height: height) else { return nil }
            return Candidate(url: url, image: image, edges: edges, score: edges.correlation(with: desk))
        }
        guard let best = candidates.max(by: { $0.score < $1.score }) else {
            return nil
        }
        try writeSheet([best.image, content.image, best.edges.overlay(desk)], panel: CGSize(width: best.image.width, height: best.image.height), to: output)
        return ShotComparison(
            shot: shot.path,
            cell: best.url.path,
            image: output.path,
            family: family,
            deskSize: CGSize(width: content.bounds.width / scale, height: content.bounds.height / scale),
            previewSize: expected,
            structure: best.score
        )
    }

    private struct Candidate {
        let url: URL
        let image: CGImage
        let edges: EdgeMap
        let score: Double
    }

    public static func issue(_ comparison: ShotComparison) -> Issue? {
        guard !comparison.matches else { return nil }
        let family = comparison.family.rawValue
        guard comparison.sizeMatches else {
            let desk = format(comparison.deskSize)
            let preview = format(comparison.previewSize)
            return Issue(
                code: IssueCode.shotMismatch,
                severity: .warning,
                message: L10n.pick(
                    en: "The desktop draws \(family) at \(desk) pt, the preview at \(preview) pt",
                    ru: "Стол рисует \(family) размером \(desk) pt, а превью — \(preview) pt"
                ),
                hint: L10n.pick(
                    en: "Run aw geometry --measure, then preview again; \(comparison.image) shows both",
                    ru: "Запусти aw geometry --measure и сделай превью заново; \(comparison.image) показывает оба"
                ),
                file: comparison.image
            )
        }
        let percent = Int((comparison.structure * 100).rounded())
        return Issue(
            code: IssueCode.shotMismatch,
            severity: .warning,
            message: L10n.pick(
                en: "The \(family) widget on the desktop does not look like its preview: outlines agree on \(percent) %",
                ru: "Виджет \(family) на столе не похож на превью: контуры совпадают на \(percent) %"
            ),
            hint: L10n.pick(
                en: "Open \(comparison.image): preview, desktop, outlines — white where both agree, cyan only in the preview, red only on the desktop",
                ru: "Открой \(comparison.image): превью, стол, контуры — белое совпадает, голубое только в превью, красное только на столе"
            ),
            file: comparison.image
        )
    }

    static func content(of image: CGImage, scale: CGFloat) -> (image: CGImage, bounds: CGRect)? {
        let inset = (Family.windowInset / 2 * scale).rounded()
        let window = CGRect(x: inset, y: inset, width: CGFloat(image.width) - 2 * inset, height: CGFloat(image.height) - 2 * inset)
        let opaque = opaqueBounds(image).flatMap { $0.width > window.width / 2 && $0.height > window.height / 2 ? $0 : nil }
        let bounds = opaque ?? window
        return image.cropping(to: bounds).map { ($0, bounds) }
    }

    static func opaqueBounds(_ image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.bindMemory(to: UInt8.self, capacity: width * height * 4) else { return nil }
        var low = (x: width, y: height)
        var high = (x: -1, y: -1)
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 24 {
                low = (min(low.x, x), min(low.y, y))
                high = (max(high.x, x), max(high.y, y))
            }
        }
        guard high.x >= low.x, high.y >= low.y else { return nil }
        return CGRect(x: low.x, y: low.y, width: high.x - low.x + 1, height: high.y - low.y + 1)
    }

    static func loadImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func writeSheet(_ panels: [CGImage?], panel: CGSize, to url: URL) throws {
        let gap = 16
        let panelWidth = Int(panel.width)
        let panelHeight = Int(panel.height)
        let width = panels.count * panelWidth + (panels.count - 1) * gap
        guard let context = CGContext(
            data: nil, width: width, height: panelHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        context.setFillColor(CGColor(gray: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: panelHeight))
        context.interpolationQuality = .high
        for (index, image) in panels.enumerated() {
            guard let image else { continue }
            context.draw(image, in: CGRect(x: index * (panelWidth + gap), y: 0, width: panelWidth, height: panelHeight))
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let sheet = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, sheet, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private static func format(_ size: CGSize) -> String {
        "\(Int(size.width.rounded()))×\(Int(size.height.rounded()))"
    }
}

extension ShotCompare {
    /// Compares dev slot shots with the preview cells of the widget and sample the slot shows; live data is not compared.
    public static func review(_ records: [ShotRecord], workspace: Workspace, target: DevTarget?) -> (comparisons: [ShotComparison], issues: [Issue]) {
        guard let target, let scenario = target.scenario else { return ([], []) }
        let files = (try? FileManager.default.contentsOfDirectory(at: workspace.previewsDir(for: target.widget), includingPropertiesForKeys: nil)) ?? []
        var comparisons: [ShotComparison] = []
        for record in records where record.label == RegistryGenerator.devKind {
            guard let family = record.window.family else { continue }
            let cells = files
                .filter { $0.lastPathComponent.hasPrefix("\(family.rawValue)-") && $0.lastPathComponent.hasSuffix("-\(scenario).png") }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            let output = workspace.shotsDir.appendingPathComponent("\(target.widget)-\(family.rawValue)-compare.png")
            if let comparison = try? compare(record, cells: cells, output: output) {
                comparisons.append(comparison)
            }
        }
        return (comparisons, comparisons.compactMap(issue))
    }
}

struct EdgeMap {
    let width: Int
    let height: Int
    let values: [Float]

    init?(_ image: CGImage, width: Int, height: Int) {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let gray = context.data?.bindMemory(to: UInt8.self, capacity: width * height) else { return nil }
        let luma = (0..<(width * height)).map { Float(gray[$0]) }
        self.width = width
        self.height = height
        values = Self.blur(Self.blur(Self.sobel(luma, width: width, height: height), width: width, height: height), width: width, height: height)
    }

    func correlation(with other: EdgeMap) -> Double {
        guard values.count == other.values.count, values.count > 1 else { return 0 }
        let count = Double(values.count)
        let meanA = values.reduce(0.0) { $0 + Double($1) } / count
        let meanB = other.values.reduce(0.0) { $0 + Double($1) } / count
        var covariance = 0.0
        var varianceA = 0.0
        var varianceB = 0.0
        for index in values.indices {
            let a = Double(values[index]) - meanA
            let b = Double(other.values[index]) - meanB
            covariance += a * b
            varianceA += a * a
            varianceB += b * b
        }
        guard varianceA > 0, varianceB > 0 else { return varianceA == varianceB ? 1 : 0 }
        return max(0, covariance / (varianceA * varianceB).squareRoot())
    }

    func overlay(_ desk: EdgeMap) -> CGImage? {
        guard desk.values.count == values.count,
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let pixels = context.data?.bindMemory(to: UInt8.self, capacity: width * height * 4)
        else {
            return nil
        }
        let preview = normalized()
        let shot = desk.normalized()
        for index in values.indices {
            pixels[index * 4] = UInt8(shot[index] * 255)
            pixels[index * 4 + 1] = UInt8(preview[index] * 255)
            pixels[index * 4 + 2] = UInt8(preview[index] * 255)
            pixels[index * 4 + 3] = 255
        }
        return context.makeImage()
    }

    func normalized() -> [Float] {
        let sorted = values.sorted()
        let ceiling = max(sorted[min(sorted.count - 1, sorted.count * 98 / 100)], 1)
        return values.map { min($0 / ceiling, 1) }
    }

    static func sobel(_ pixels: [Float], width: Int, height: Int) -> [Float] {
        var out = [Float](repeating: 0, count: pixels.count)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let right = pixels[i - width + 1] + 2 * pixels[i + 1] + pixels[i + width + 1]
                let left = pixels[i - width - 1] + 2 * pixels[i - 1] + pixels[i + width - 1]
                let below = pixels[i + width - 1] + 2 * pixels[i + width] + pixels[i + width + 1]
                let above = pixels[i - width - 1] + 2 * pixels[i - width] + pixels[i - width + 1]
                let gx = right - left
                let gy = below - above
                out[i] = (gx * gx + gy * gy).squareRoot()
            }
        }
        return out
    }

    static func blur(_ values: [Float], width: Int, height: Int) -> [Float] {
        var out = [Float](repeating: 0, count: values.count)
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                var count: Float = 0
                for ny in max(y - 1, 0)...min(y + 1, height - 1) {
                    for nx in max(x - 1, 0)...min(x + 1, width - 1) {
                        sum += values[ny * width + nx]
                        count += 1
                    }
                }
                out[y * width + x] = sum / count
            }
        }
        return out
    }
}
