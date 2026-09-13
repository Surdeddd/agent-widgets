import AppKit
import AWKit
import AWSchema
import SwiftUI

@MainActor
enum FitProbe {
    static func idealHeight(_ view: some View, width: CGFloat) -> CGFloat {
        NSHostingView(rootView: view.frame(width: width)).fittingSize.height
    }

    static func overflow(_ view: some View, size: CGSize) -> CGFloat? {
        let margin = max(size.height, 120)
        let canvas = view
            .frame(width: size.width, height: size.height)
            .padding(margin)
        guard let image = PNG.render(canvas, scale: 1),
              let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else {
            return nil
        }
        let width = image.width
        let height = image.height
        let rowBytes = image.bytesPerRow
        let bytesPerPixel = max(1, image.bitsPerPixel / 8)
        let alphaOffset = alphaIndex(image.alphaInfo, bytesPerPixel: bytesPerPixel)
        let inner = CGRect(x: margin - 2, y: margin - 2, width: size.width + 4, height: size.height + 4)
        var extent: CGFloat = 0
        var spilled = 0
        for y in 0..<height {
            for x in 0..<width where !inner.contains(CGPoint(x: x, y: y)) {
                let alpha = bytes[y * rowBytes + x * bytesPerPixel + alphaOffset]
                guard alpha > 24 else { continue }
                spilled += 1
                let dx = max(inner.minX - CGFloat(x), CGFloat(x) - inner.maxX, 0)
                let dy = max(inner.minY - CGFloat(y), CGFloat(y) - inner.maxY, 0)
                extent = max(extent, max(dx, dy))
            }
        }
        return spilled > 12 ? extent : nil
    }

    private static func alphaIndex(_ info: CGImageAlphaInfo, bytesPerPixel: Int) -> Int {
        switch info {
        case .premultipliedFirst, .first, .noneSkipFirst: 0
        default: bytesPerPixel - 1
        }
    }
}
