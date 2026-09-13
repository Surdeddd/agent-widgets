import AppKit
import SwiftUI

enum PNG {
    @MainActor
    static func render(_ view: some View, scale: CGFloat, opaque: Bool = false) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = opaque
        return renderer.cgImage
    }

    static func data(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    static func write(_ image: CGImage, to url: URL) throws {
        guard let data = data(image) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }
}
