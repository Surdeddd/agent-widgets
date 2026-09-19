import AppKit
import CoreGraphics
import Foundation

enum Palette {
    static let background = NSColor(red: 0.055, green: 0.06, blue: 0.08, alpha: 1)
    static let panel = NSColor(red: 0.1, green: 0.11, blue: 0.14, alpha: 1)
    static let plain = NSColor(white: 0.92, alpha: 1)
    static let dim = NSColor(white: 0.55, alpha: 1)
    static let red = NSColor(red: 1, green: 0.45, blue: 0.42, alpha: 1)
    static let green = NSColor(red: 0.42, green: 0.86, blue: 0.52, alpha: 1)
    static let yellow = NSColor(red: 1, green: 0.8, blue: 0.35, alpha: 1)
    static let blue = NSColor(red: 0.55, green: 0.72, blue: 1, alpha: 1)
}

struct Step: Decodable {
    var type: String?
    var emit: [String]?
    var emitFile: String?
    var image: String?
    var label: String?
    var clear: Bool?
    var hold: Int?
}

struct StoryFile: Decodable {
    var steps: [Step]
}

struct Frame {
    let lines: [String]
    let image: NSImage?
    let label: String
}

let canvas = CGSize(width: 1280, height: 720)
let terminal = CGRect(x: 36, y: 36, width: 640, height: 648)
let sidePanel = CGRect(x: 700, y: 36, width: 544, height: 648)
let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
let lineHeight: CGFloat = 21
let columns = 70

func color(for line: String) -> NSColor {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    switch trimmed.first {
    case "$": return Palette.plain
    case "✗", "-": return Palette.red
    case "✓", "+": return Palette.green
    case "!": return Palette.yellow
    case "#": return Palette.blue
    default: return Palette.dim
    }
}

func wrap(_ line: String) -> [String] {
    guard line.count > columns else { return [line] }
    var rows: [String] = []
    var current = ""
    for word in line.split(separator: " ", omittingEmptySubsequences: false) {
        if current.count + word.count + 1 > columns, !current.isEmpty {
            rows.append(current)
            current = "    " + word
        } else {
            current += current.isEmpty ? String(word) : " " + word
        }
    }
    rows.append(current)
    return rows
}

final class Story {
    private(set) var frames: [Frame] = []
    private var screen: [String] = []
    var image: NSImage?
    var label = ""

    func hold(_ count: Int) {
        for _ in 0..<count {
            frames.append(Frame(lines: screen, image: image, label: label))
        }
    }

    func type(_ command: String) {
        for count in stride(from: 1, through: command.count, by: 2) {
            frames.append(Frame(lines: screen + ["$ " + String(command.prefix(count))], image: image, label: label))
        }
        screen.append("$ " + command)
        hold(3)
    }

    func emit(_ lines: [String]) {
        screen += lines.flatMap(wrap)
    }

    func clear() {
        screen = []
    }
}

func draw(_ text: String, at point: CGPoint, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    NSAttributedString(string: text, attributes: attributes).draw(at: point)
}

func render(_ frame: Frame, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas.width),
        pixelsHigh: Int(canvas.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    context.cgContext.translateBy(x: 0, y: canvas.height)
    context.cgContext.scaleBy(x: 1, y: -1)
    Palette.background.setFill()
    NSRect(origin: .zero, size: canvas).fill()
    Palette.panel.setFill()
    NSBezierPath(roundedRect: terminal, xRadius: 14, yRadius: 14).fill()
    NSBezierPath(roundedRect: sidePanel, xRadius: 14, yRadius: 14).fill()
    for (index, dot) in [Palette.red, Palette.yellow, Palette.green].enumerated() {
        dot.setFill()
        NSBezierPath(ovalIn: CGRect(x: terminal.minX + 18 + CGFloat(index) * 20, y: terminal.minY + 16, width: 12, height: 12)).fill()
    }
    let visible = Int((terminal.height - 72) / lineHeight)
    for (index, line) in frame.lines.suffix(visible).enumerated() {
        draw(line, at: CGPoint(x: terminal.minX + 22, y: terminal.minY + 48 + CGFloat(index) * lineHeight), color: color(for: line))
    }
    if let image = frame.image {
        draw(frame.label, at: CGPoint(x: sidePanel.minX + 18, y: sidePanel.minY + 14), color: Palette.dim)
        let box = sidePanel.insetBy(dx: 16, dy: 16).offsetBy(dx: 0, dy: 14)
        let ratio = min(box.width / image.size.width, (box.height - 14) / image.size.height)
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        image.draw(in: CGRect(x: box.midX - size.width / 2, y: box.minY + (box.height - 14 - size.height) / 2, width: size.width, height: size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("""
    usage: swift scripts/make-loop.swift <story.json> <frames-dir>
    story: {"steps": [{"type": "aw preview weather"}, {"emitFile": "out.txt", "image": "sheet.png", "label": "sheet.png", "hold": 30},
            {"emit": ["# a note"], "hold": 6}, {"clear": true}]} — paths are relative to the story file
    then:  ffmpeg -framerate 12 -i <frames-dir>/%04d.png -vf "split[a][b];[a]palettegen[p];[b][p]paletteuse" out.gif
    """)
    exit(2)
}
let storyURL = URL(fileURLWithPath: arguments[1])
let base = storyURL.deletingLastPathComponent()
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
do {
    let file = try JSONDecoder().decode(StoryFile.self, from: Data(contentsOf: storyURL))
    let story = Story()
    for step in file.steps {
        if step.clear == true {
            story.clear()
        }
        if let command = step.type {
            story.type(command)
        }
        if let image = step.image {
            story.image = NSImage(contentsOf: base.appendingPathComponent(image))
            story.label = step.label ?? image
        }
        if let name = step.emitFile {
            let text = try String(contentsOf: base.appendingPathComponent(name), encoding: .utf8)
            story.emit(text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        }
        if let lines = step.emit {
            story.emit(lines)
        }
        story.hold(step.hold ?? 0)
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for (index, frame) in story.frames.enumerated() {
        try render(frame, to: output.appendingPathComponent(String(format: "%04d.png", index)))
    }
    print("\(story.frames.count) frames in \(output.path)")
} catch {
    print("failed: \(error)")
    exit(1)
}
