import CoreGraphics
import Foundation
import ImageIO

/// Compares captured frames by picture, so a ticking clock inside a widget is not mistaken for a redraw or for a widget that never stops redrawing.
public enum FrameDiff {
    static let side = 160
    static let step = 28
    static let steadyShare = 0.03
    static let redrawShare = 0.002
    static let margin = 6

    /// Two frames show the same picture: at most a small part of it moved, like the digits of a running timer.
    public static func alike(_ lhs: Data, _ rhs: Data) -> Bool {
        if lhs == rhs {
            return true
        }
        guard let first = Raster(lhs), let second = Raster(rhs), first.matches(second) else {
            return false
        }
        return Double(first.changed(from: second).count) / Double(first.pixels.count) <= steadyShare
    }

    /// `frame` is a different picture than `baseline`, ignoring the area that keeps moving between `steady` and `frame`.
    public static func differs(_ frame: Data, from baseline: Data?, steadiedBy steady: Data?) -> Bool {
        guard let baseline else {
            return true
        }
        guard let current = Raster(frame), let before = Raster(baseline), current.matches(before) else {
            return frame != baseline
        }
        var moving: Set<Int> = []
        if let steady, let previous = Raster(steady), previous.matches(current) {
            moving = current.area(around: current.changed(from: previous))
        }
        let changed = current.changed(from: before).filter { !moving.contains($0) }
        return Double(changed.count) / Double(current.pixels.count) > redrawShare
    }

    struct Raster {
        let width: Int
        let height: Int
        let pixels: [UInt8]

        init?(_ data: Data) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  image.width > 0, image.height > 0
            else {
                return nil
            }
            let scale = min(1, Double(FrameDiff.side) / Double(max(image.width, image.height)))
            let columns = max(1, Int((Double(image.width) * scale).rounded()))
            let rows = max(1, Int((Double(image.height) * scale).rounded()))
            var buffer = [UInt8](repeating: 0, count: columns * rows)
            let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(
                    data: bytes.baseAddress,
                    width: columns,
                    height: rows,
                    bitsPerComponent: 8,
                    bytesPerRow: columns,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                ) else {
                    return false
                }
                context.interpolationQuality = .medium
                context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: rows))
                return true
            }
            guard drawn else {
                return nil
            }
            width = columns
            height = rows
            pixels = buffer
        }

        func matches(_ other: Raster) -> Bool {
            width == other.width && height == other.height
        }

        func changed(from other: Raster) -> [Int] {
            pixels.indices.filter { abs(Int(pixels[$0]) - Int(other.pixels[$0])) > FrameDiff.step }
        }

        func area(around indices: [Int]) -> Set<Int> {
            guard let first = indices.first else {
                return []
            }
            var (left, right, top, bottom) = (first % width, first % width, first / width, first / width)
            for index in indices {
                left = min(left, index % width)
                right = max(right, index % width)
                top = min(top, index / width)
                bottom = max(bottom, index / width)
            }
            let columns = max(0, left - FrameDiff.margin)...min(width - 1, right + FrameDiff.margin)
            let rows = max(0, top - FrameDiff.margin)...min(height - 1, bottom + FrameDiff.margin)
            var covered: Set<Int> = []
            for row in rows {
                for column in columns {
                    covered.insert(row * width + column)
                }
            }
            return covered
        }
    }
}
