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

let pointSizes: [String: CGSize] = [
    "small": CGSize(width: 155, height: 155),
    "medium": CGSize(width: 329, height: 155),
    "large": CGSize(width: 345, height: 345),
    "extraLarge": CGSize(width: 715, height: 345)
]

func cell(_ workspace: URL, _ widget: String, _ family: String, appearance: String) -> CGImage? {
    let url = workspace.appendingPathComponent(".aw/previews/\(widget)/\(family)-\(appearance)-color-default.png")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
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

func place(_ image: CGImage, _ family: String, at origin: CGPoint, in context: CGContext, canvas: CGSize, scale: CGFloat) {
    guard let points = pointSizes[family] else { return }
    let rect = CGRect(
        x: origin.x * scale,
        y: canvas.height - (origin.y + points.height) * scale,
        width: points.width * scale,
        height: points.height * scale
    )
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 36 * scale, color: CGColor(gray: 0, alpha: 0.5))
    context.draw(image, in: rect)
    context.restoreGState()
}

func caption(_ text: String, in context: CGContext, canvas: CGSize, scale: CGFloat) {
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15 * scale, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.62)
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let size = string.size()
    string.draw(at: CGPoint(x: canvas.width - size.width - 40 * scale, y: 30 * scale))
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

func hero(workspace: URL, output: URL, layout: [Placement]) throws {
    let scale: CGFloat = 1.5
    let canvas = CGSize(width: 1600 * scale, height: 900 * scale)
    guard let context = makeContext(canvas) else { throw CocoaError(.fileWriteUnknown) }
    wallpaper(context, size: canvas, scale: scale)
    for item in layout {
        guard let image = cell(workspace, item.widget, item.family, appearance: "dark") else {
            FileHandle.standardError.write(Data("missing \(item.widget) \(item.family)\n".utf8))
            continue
        }
        place(image, item.family, at: CGPoint(x: item.x, y: item.y), in: context, canvas: canvas, scale: scale)
    }
    caption("Rendered by aw preview · every widget written by an AI agent", in: context, canvas: canvas, scale: scale)
    try write(context, to: output)
}

func strip(workspace: URL, widget: String, output: URL) throws {
    let families = ["small", "medium", "large", "extraLarge"].filter { cell(workspace, widget, $0, appearance: "dark") != nil }
    let gap: CGFloat = 28
    let margin: CGFloat = 36
    let width = families.compactMap { pointSizes[$0]?.width }.reduce(0, +) + gap * CGFloat(max(families.count - 1, 0)) + margin * 2
    let height = (families.compactMap { pointSizes[$0]?.height }.max() ?? 155) + margin * 2
    let scale: CGFloat = 2
    let canvas = CGSize(width: width * scale, height: height * scale)
    guard let context = makeContext(canvas) else { throw CocoaError(.fileWriteUnknown) }
    wallpaper(context, size: canvas, scale: scale * 0.5)
    var x = margin
    for family in families {
        guard let image = cell(workspace, widget, family, appearance: "dark"), let size = pointSizes[family] else { continue }
        place(image, family, at: CGPoint(x: x, y: margin), in: context, canvas: canvas, scale: scale)
        x += size.width + gap
    }
    try write(context, to: output)
}

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    print("usage: swift scripts/make-hero.swift hero <workspace> <out.png>\n       swift scripts/make-hero.swift strip <workspace> <widget> <out.png>")
    exit(2)
}
let workspace = URL(fileURLWithPath: arguments[2], isDirectory: true)
do {
    if arguments[1] == "strip", arguments.count >= 5 {
        try strip(workspace: workspace, widget: arguments[3], output: URL(fileURLWithPath: arguments[4]))
    } else {
        let layout = [
            Placement(widget: "weather", family: "large", x: 80, y: 80),
            Placement(widget: "fx", family: "medium", x: 80, y: 445),
            Placement(widget: "github", family: "medium", x: 80, y: 620),
            Placement(widget: "world-clock", family: "medium", x: 449, y: 80),
            Placement(widget: "system-pulse", family: "small", x: 449, y: 255),
            Placement(widget: "focus", family: "small", x: 623, y: 255),
            Placement(widget: "flashcards", family: "large", x: 449, y: 430),
            Placement(widget: "habits", family: "large", x: 818, y: 80),
            Placement(widget: "system-pulse", family: "medium", x: 818, y: 445),
            Placement(widget: "focus", family: "medium", x: 818, y: 620),
            Placement(widget: "world-clock", family: "small", x: 1187, y: 80),
            Placement(widget: "github", family: "small", x: 1361, y: 80),
            Placement(widget: "weather", family: "medium", x: 1187, y: 255),
            Placement(widget: "fx", family: "large", x: 1187, y: 430)
        ]
        try hero(workspace: workspace, output: URL(fileURLWithPath: arguments[3]), layout: layout)
    }
} catch {
    print("failed: \(error)")
    exit(1)
}
