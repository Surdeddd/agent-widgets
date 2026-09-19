import AppKit
import CoreGraphics

let arguments = CommandLine.arguments
let output = arguments.count > 1 ? arguments[1] : "packaging/mcpb/icon.png"
let side = 512
let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("no context")
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [red, green, blue, alpha])!
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

let canvas = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: 24, dy: 24)
context.addPath(rounded(canvas, 104))
context.clip()
let backdrop = CGGradient(colorsSpace: space, colors: [color(0.17, 0.18, 0.22), color(0.07, 0.07, 0.09)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(backdrop, start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])

let tile = color(1, 1, 1, 0.09)
let wide = CGRect(x: 84, y: 268, width: 344, height: 160)
let left = CGRect(x: 84, y: 84, width: 160, height: 160)
let right = CGRect(x: 268, y: 84, width: 160, height: 160)
for rect in [wide, left, right] {
    context.addPath(rounded(rect, 38))
    context.setFillColor(tile)
    context.fillPath()
}

let orange = color(1.0, 0.58, 0.16)
let green = color(0.2, 0.84, 0.42)
let center = CGPoint(x: left.midX, y: left.midY)
context.setLineWidth(18)
context.setLineCap(.round)
context.setStrokeColor(color(1, 1, 1, 0.13))
context.addArc(center: center, radius: 46, startAngle: 0, endAngle: .pi * 2, clockwise: false)
context.strokePath()
context.setStrokeColor(orange)
context.addArc(center: center, radius: 46, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 2 * 0.68, clockwise: true)
context.strokePath()

let heights: [CGFloat] = [34, 58, 44, 84, 66]
for (index, height) in heights.enumerated() {
    let bar = CGRect(x: right.minX + 28 + CGFloat(index) * 22, y: right.minY + 34, width: 14, height: height)
    context.addPath(rounded(bar, 5))
    context.setFillColor(index == heights.count - 1 ? green : color(0.2, 0.84, 0.42, 0.45))
    context.fillPath()
}

context.addPath(rounded(CGRect(x: wide.minX + 30, y: wide.maxY - 62, width: 92, height: 30), 9))
context.setFillColor(color(1, 1, 1, 0.92))
context.fillPath()
context.addPath(rounded(CGRect(x: wide.minX + 30, y: wide.maxY - 94, width: 56, height: 14), 6))
context.setFillColor(color(1, 1, 1, 0.35))
context.fillPath()
let points: [CGPoint] = [
    CGPoint(x: wide.minX + 150, y: wide.minY + 44), CGPoint(x: wide.minX + 190, y: wide.minY + 70),
    CGPoint(x: wide.minX + 226, y: wide.minY + 56), CGPoint(x: wide.minX + 262, y: wide.minY + 98),
    CGPoint(x: wide.minX + 314, y: wide.minY + 116)
]
context.setStrokeColor(green)
context.setLineWidth(10)
context.setLineJoin(.round)
context.addLines(between: points)
context.strokePath()

guard let image = context.makeImage() else {
    fatalError("no image")
}
let representation = NSBitmapImageRep(cgImage: image)
guard let data = representation.representation(using: .png, properties: [:]) else {
    fatalError("no png")
}
try data.write(to: URL(fileURLWithPath: output))
print(output)
