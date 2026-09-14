import AWSchema
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import AWCore

private struct Scene {
    var size: CGSize
    var background: CGFloat
    var ink: CGFloat
    var blocks: [CGRect]
}

private let layout = [
    CGRect(x: 12, y: 130, width: 60, height: 10),
    CGRect(x: 12, y: 90, width: 100, height: 28),
    CGRect(x: 12, y: 60, width: 130, height: 12),
    CGRect(x: 12, y: 40, width: 90, height: 12),
    CGRect(x: 12, y: 14, width: 140, height: 8)
]

private let moved = [
    CGRect(x: 92, y: 12, width: 60, height: 10),
    CGRect(x: 40, y: 124, width: 100, height: 28),
    CGRect(x: 80, y: 40, width: 20, height: 60),
    CGRect(x: 120, y: 70, width: 30, height: 30),
    CGRect(x: 30, y: 60, width: 8, height: 50)
]

private func render(_ scene: Scene, scale: CGFloat = 2, margin: CGFloat = 0) throws -> CGImage {
    let width = Int((scene.size.width + 2 * margin) * scale)
    let height = Int((scene.size.height + 2 * margin) * scale)
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: margin, y: margin)
    let factor = scene.size.width / 164
    context.setFillColor(CGColor(gray: scene.background, alpha: 1))
    context.fill(CGRect(origin: .zero, size: scene.size))
    context.setFillColor(CGColor(gray: scene.ink, alpha: 1))
    for block in scene.blocks {
        context.fill(CGRect(x: block.minX * factor, y: block.minY * factor, width: block.width * factor, height: block.height * factor))
    }
    return try #require(context.makeImage())
}

private func save(_ image: CGImage, _ url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}

private func shot(_ scene: Scene, in root: URL) throws -> ShotRecord {
    let url = root.appendingPathComponent("shot.png")
    try save(try render(scene, margin: Family.windowInset / 2), url)
    let window = WidgetWindow(
        id: 7,
        name: "Demo · Dev",
        width: Int(scene.size.width + Family.windowInset),
        height: Int(scene.size.height + Family.windowInset),
        family: .small
    )
    return ShotRecord(label: RegistryGenerator.devKind, window: window, path: url.path, settled: true)
}

private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("aw-compare-\(UUID().uuidString)", isDirectory: true)
}

private let small = CGSize(width: 164, height: 164)

@Test func aTintedDesktopWindowStillMatchesItsPreview() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let cell = root.appendingPathComponent("small-dark-idle-default.png")
    try save(try render(Scene(size: small, background: 0.2, ink: 0.9, blocks: layout)), cell)
    let record = try shot(Scene(size: small, background: 0.07, ink: 0.45, blocks: layout), in: root)
    let output = root.appendingPathComponent("compare.png")
    let comparison = try #require(try ShotCompare.compare(record, cells: [cell], output: output))
    #expect(comparison.structure > 0.9)
    #expect(comparison.sizeDelta == .zero)
    #expect(comparison.matches)
    #expect(ShotCompare.issue(comparison) == nil)
    let sheet = try #require(ShotCompare.loadImage(output))
    #expect(sheet.width == 3 * 328 + 2 * 16)
    #expect(sheet.height == 328)
}

@Test func movedContentDoesNotMatch() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let cell = root.appendingPathComponent("small-dark-idle-default.png")
    try save(try render(Scene(size: small, background: 0.2, ink: 0.9, blocks: layout)), cell)
    let record = try shot(Scene(size: small, background: 0.2, ink: 0.9, blocks: moved), in: root)
    let comparison = try #require(try ShotCompare.compare(record, cells: [cell], output: root.appendingPathComponent("compare.png")))
    #expect(comparison.structure < ShotCompare.structureThreshold)
    let issue = try #require(ShotCompare.issue(comparison))
    #expect(issue.code == IssueCode.shotMismatch)
    #expect(issue.severity == .warning)
    #expect(issue.file == comparison.image)
}

@Test func aPreviewAtTheWrongSizeIsReported() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let builtIn = CGSize(width: 155, height: 155)
    let cell = root.appendingPathComponent("small-dark-idle-default.png")
    try save(try render(Scene(size: builtIn, background: 0.2, ink: 0.9, blocks: layout)), cell)
    let record = try shot(Scene(size: small, background: 0.2, ink: 0.9, blocks: layout), in: root)
    let comparison = try #require(try ShotCompare.compare(record, cells: [cell], output: root.appendingPathComponent("compare.png")))
    #expect(comparison.deskSize == small)
    #expect(comparison.sizeDelta == CGSize(width: 9, height: 9))
    #expect(!comparison.matches)
    let issue = try #require(ShotCompare.issue(comparison))
    #expect(issue.message.contains("164×164"))
    #expect(issue.hint?.contains("aw geometry --measure") == true)
}

@Test func theClosestCellIsChosen() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let wrong = root.appendingPathComponent("small-light-color-default.png")
    let right = root.appendingPathComponent("small-dark-idle-default.png")
    try save(try render(Scene(size: small, background: 0.95, ink: 0.1, blocks: moved)), wrong)
    try save(try render(Scene(size: small, background: 0.2, ink: 0.9, blocks: layout)), right)
    let record = try shot(Scene(size: small, background: 0.1, ink: 0.6, blocks: layout), in: root)
    let comparison = try #require(try ShotCompare.compare(record, cells: [wrong, right], output: root.appendingPathComponent("compare.png")))
    #expect(comparison.cell == right.path)
    #expect(comparison.matches)
}

@Test func devSlotShotsAreComparedWithTheSampleOnTheSlot() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let cells = workspace.previewsDir(for: "probe")
    try save(try render(Scene(size: small, background: 0.2, ink: 0.9, blocks: layout)), cells.appendingPathComponent("small-dark-idle-default.png"))
    try save(try render(Scene(size: small, background: 0.2, ink: 0.9, blocks: moved)), cells.appendingPathComponent("small-dark-idle-long.png"))
    let record = try shot(Scene(size: small, background: 0.1, ink: 0.6, blocks: layout), in: root)
    let review = ShotCompare.review([record], workspace: workspace, target: DevTarget(widget: "probe", scenario: "default"))
    #expect(review.comparisons.map { URL(fileURLWithPath: $0.cell).lastPathComponent } == ["small-dark-idle-default.png"])
    #expect(review.comparisons.first?.image == workspace.shotsDir.appendingPathComponent("probe-small-compare.png").path)
    #expect(review.issues.isEmpty)
    #expect(ShotCompare.review([record], workspace: workspace, target: DevTarget(widget: "probe")).comparisons.isEmpty)
    var widgetShot = record
    widgetShot.label = "probe"
    #expect(ShotCompare.review([widgetShot], workspace: workspace, target: DevTarget(widget: "probe", scenario: "default")).comparisons.isEmpty)
    let stale = try shot(Scene(size: small, background: 0.2, ink: 0.9, blocks: moved), in: root)
    let mismatch = ShotCompare.review([stale], workspace: workspace, target: DevTarget(widget: "probe", scenario: "default"))
    #expect(mismatch.comparisons.map { URL(fileURLWithPath: $0.cell).lastPathComponent } == ["small-dark-idle-default.png"])
    #expect(mismatch.issues.map(\.code) == [IssueCode.shotMismatch])
}
