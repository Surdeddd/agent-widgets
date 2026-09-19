import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Placement {
    let widget: String
    let family: String
    let x: CGFloat
    let y: CGFloat
}

let previewScale: CGFloat = 2

func cell(_ workspace: URL, _ widget: String, _ family: String) -> CGImage? {
    let url = workspace.appendingPathComponent(".aw/previews/\(widget)/\(family)-dark-color-default.png")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func points(_ image: CGImage) -> CGSize {
    CGSize(width: CGFloat(image.width) / previewScale, height: CGFloat(image.height) / previewScale)
}

func wallpaper(_ context: CGContext, size: CGSize, scale: CGFloat) {
    let space = CGColorSpaceCreateDeviceRGB()
    let base = [
        CGColor(red: 0.04, green: 0.06, blue: 0.16, alpha: 1),
        CGColor(red: 0.13, green: 0.07, blue: 0.27, alpha: 1),
        CGColor(red: 0.42, green: 0.15, blue: 0.32, alpha: 1)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: space, colors: base, locations: [0, 0.62, 1]) {
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])
    }
    let glows: [(CGPoint, CGFloat, CGColor)] = [
        (CGPoint(x: size.width * 0.82, y: size.height * 0.18), 520 * scale, CGColor(red: 0.98, green: 0.55, blue: 0.35, alpha: 0.55)),
        (CGPoint(x: size.width * 0.12, y: size.height * 0.92), 480 * scale, CGColor(red: 0.25, green: 0.45, blue: 0.95, alpha: 0.45)),
        (CGPoint(x: size.width * 0.55, y: size.height * 0.55), 420 * scale, CGColor(red: 0.55, green: 0.3, blue: 0.85, alpha: 0.3))
    ]
    for (center, radius, color) in glows {
        let colors = [color, color.copy(alpha: 0) ?? color] as CFArray
        if let glow = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
    }
}

func place(_ image: CGImage, at origin: CGPoint, in context: CGContext, canvas: CGSize, scale: CGFloat) {
    let size = points(image)
    let rect = CGRect(x: origin.x * scale, y: canvas.height - (origin.y + size.height) * scale, width: size.width * scale, height: size.height * scale)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 36 * scale, color: CGColor(gray: 0, alpha: 0.5))
    context.draw(image, in: rect)
    context.restoreGState()
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, at point: CGPoint, in context: CGContext, fromRight: Bool = false) {
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white.withAlphaComponent(alpha)
    ]
    let attributed = NSAttributedString(string: string, attributes: attributes)
    let origin = fromRight ? CGPoint(x: point.x - attributed.size().width, y: point.y) : point
    attributed.draw(at: origin)
    NSGraphicsContext.restoreGraphicsState()
}

func write(_ context: CGContext, to url: URL) throws {
    let isJPEG = ["jpg", "jpeg"].contains(url.pathExtension.lowercased())
    let type = isJPEG ? UTType.jpeg : UTType.png
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    let options = isJPEG ? [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary : nil
    CGImageDestinationAddImage(destination, image, options)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

func makeContext(_ size: CGSize) -> CGContext? {
    CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

func draw(_ layout: [Placement], workspace: URL, in context: CGContext, canvas: CGSize, scale: CGFloat) {
    for item in layout {
        guard let image = cell(workspace, item.widget, item.family) else {
            FileHandle.standardError.write(Data("missing \(item.widget) \(item.family)\n".utf8))
            continue
        }
        place(image, at: CGPoint(x: item.x, y: item.y), in: context, canvas: canvas, scale: scale)
    }
}

func hero(workspace: URL, output: URL) throws {
    let scale: CGFloat = 1.5
    let canvas = CGSize(width: 1600 * scale, height: 900 * scale)
    guard let context = makeContext(canvas) else { throw CocoaError(.fileWriteUnknown) }
    wallpaper(context, size: canvas, scale: scale)
    let layout = [
        Placement(widget: "ai-limits", family: "extraLarge", x: 64, y: 64),
        Placement(widget: "agents", family: "large", x: 64, y: 428),
        Placement(widget: "github", family: "large", x: 424, y: 428),
        Placement(widget: "ai-spend", family: "large", x: 808, y: 64),
        Placement(widget: "tiles", family: "large", x: 1168, y: 64),
        Placement(widget: "system-pulse", family: "medium", x: 808, y: 428),
        Placement(widget: "focus", family: "medium", x: 1168, y: 428),
        Placement(widget: "agents", family: "medium", x: 808, y: 608),
        Placement(widget: "ai-limits", family: "small", x: 1168, y: 608),
        Placement(widget: "tiles", family: "small", x: 1348, y: 608)
    ]
    draw(layout, workspace: workspace, in: context, canvas: canvas, scale: scale)
    text(
        "Rendered by aw preview · every widget written by an AI agent",
        size: 15 * scale, weight: .medium, alpha: 0.62,
        at: CGPoint(x: canvas.width - 64 * scale, y: 44 * scale), in: context, fromRight: true
    )
    try write(context, to: output)
}

func social(workspace: URL, output: URL) throws {
    let canvas = CGSize(width: 1280, height: 640)
    guard let context = makeContext(canvas) else { throw CocoaError(.fileWriteUnknown) }
    wallpaper(context, size: canvas, scale: 0.8)
    text("agent-widgets", size: 58, weight: .bold, alpha: 1, at: CGPoint(x: 64, y: 500), in: context)
    text("Native macOS widgets, built by your AI agent", size: 27, weight: .medium, alpha: 0.78, at: CGPoint(x: 66, y: 452), in: context)
    text("aw CLI · SwiftUI kit · layout-checked previews · MCP", size: 19, weight: .regular, alpha: 0.55, at: CGPoint(x: 66, y: 416), in: context)
    let layout = [
        Placement(widget: "ai-limits", family: "extraLarge", x: 64, y: 264),
        Placement(widget: "agents", family: "large", x: 808, y: 40),
        Placement(widget: "github", family: "medium", x: 808, y: 412)
    ]
    draw(layout, workspace: workspace, in: context, canvas: canvas, scale: 1)
    try write(context, to: output)
}

func strip(workspace: URL, widget: String, output: URL) throws {
    let cells = ["small", "medium", "large", "extraLarge"].compactMap { cell(workspace, widget, $0) }
    let gap: CGFloat = 28
    let margin: CGFloat = 36
    let width = cells.map { points($0).width }.reduce(0, +) + gap * CGFloat(max(cells.count - 1, 0)) + margin * 2
    let height = (cells.map { points($0).height }.max() ?? 164) + margin * 2
    let scale: CGFloat = 2
    let canvas = CGSize(width: width * scale, height: height * scale)
    guard let context = makeContext(canvas) else { throw CocoaError(.fileWriteUnknown) }
    wallpaper(context, size: canvas, scale: scale * 0.5)
    var x = margin
    for image in cells {
        place(image, at: CGPoint(x: x, y: margin), in: context, canvas: canvas, scale: scale)
        x += points(image).width + gap
    }
    try write(context, to: output)
}

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    print("""
    usage: swift scripts/make-hero.swift hero <workspace> <out.jpg>
           swift scripts/make-hero.swift social <workspace> <out.png>
           swift scripts/make-hero.swift strip <workspace> <widget> <out.jpg>
    """)
    exit(2)
}
let workspace = URL(fileURLWithPath: arguments[2], isDirectory: true)
do {
    switch arguments[1] {
    case "strip" where arguments.count >= 5:
        try strip(workspace: workspace, widget: arguments[3], output: URL(fileURLWithPath: arguments[4]))
    case "social":
        try social(workspace: workspace, output: URL(fileURLWithPath: arguments[3]))
    default:
        try hero(workspace: workspace, output: URL(fileURLWithPath: arguments[3]))
    }
} catch {
    print("failed: \(error)")
    exit(1)
}
