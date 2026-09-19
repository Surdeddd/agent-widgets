import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import AWCore

private struct Block {
    let rect: CGRect
    let gray: CGFloat
}

private func png(_ blocks: [Block], side: Int = 328) -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    let alpha = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: alpha)!
    context.setFillColor(gray: 0.1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    for block in blocks {
        context.setFillColor(gray: block.gray, alpha: 1)
        context.fill(block.rect)
    }
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}

private let ring = Block(rect: CGRect(x: 40, y: 180, width: 120, height: 120), gray: 0.9)
private let bars = Block(rect: CGRect(x: 30, y: 40, width: 260, height: 90), gray: 0.6)

private func limits(tick: Int) -> Data {
    png([ring, bars, Block(rect: CGRect(x: 200 + tick % 3 * 4, y: 250, width: 10, height: 14), gray: 0.95)])
}

private func weather(tick: Int = 0) -> Data {
    png([Block(rect: CGRect(x: 20, y: 20, width: 288, height: 60), gray: 0.8), Block(rect: CGRect(x: 60 + tick, y: 140, width: 40, height: 40), gray: 0.5)])
}

private final class Frames: @unchecked Sendable {
    private let lock = NSLock()
    private var index = 0
    private let make: (Int) -> Data

    init(_ make: @escaping (Int) -> Data) {
        self.make = make
    }

    func next() -> Data? {
        lock.withLock {
            index += 1
            return make(index)
        }
    }
}

private func desktopFrame(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Fixtures/frames"))
    return try Data(contentsOf: url)
}

@Test func realDesktopFramesWithRunningTimersAreOnePicture() throws {
    let first = try desktopFrame("agents-tick-1")
    let second = try desktopFrame("agents-tick-2")
    let other = try desktopFrame("limits")
    #expect(first != second)
    #expect(FrameDiff.Raster(first) != nil)
    #expect(FrameDiff.alike(first, second))
    #expect(!FrameDiff.alike(first, other))
    #expect(FrameDiff.differs(second, from: other, steadiedBy: first))
    #expect(!FrameDiff.differs(second, from: first, steadiedBy: first))
}

@Test func realDesktopFramesSettleAfterTheSlotSwitches() async throws {
    let frames = [try desktopFrame("agents-tick-1"), try desktopFrame("agents-tick-2")]
    let script = Frames { frames[$0 % 2] }
    let settled = await Capture.settle(baseline: try desktopFrame("limits"), timeout: 5, interval: 0) { script.next() }
    #expect(settled != nil)
}

@Test func aTickingClockIsTheSamePicture() {
    #expect(FrameDiff.alike(limits(tick: 1), limits(tick: 2)))
    #expect(FrameDiff.alike(limits(tick: 1), limits(tick: 1)))
    #expect(!FrameDiff.alike(limits(tick: 1), weather()))
    #expect(!FrameDiff.alike(limits(tick: 1), png([ring])))
}

@Test func framesThatAreNotImagesCompareByBytes() {
    #expect(FrameDiff.alike(Data("a".utf8), Data("a".utf8)))
    #expect(!FrameDiff.alike(Data("a".utf8), Data("b".utf8)))
    #expect(FrameDiff.differs(Data("b".utf8), from: Data("a".utf8), steadiedBy: Data("b".utf8)))
    #expect(FrameDiff.differs(Data("b".utf8), from: nil, steadiedBy: Data("b".utf8)))
}

@Test func onlyTheClockMovingIsNotARedraw() {
    #expect(!FrameDiff.differs(limits(tick: 2), from: limits(tick: 7), steadiedBy: limits(tick: 1)))
    #expect(FrameDiff.differs(limits(tick: 2), from: weather(), steadiedBy: limits(tick: 1)))
    #expect(FrameDiff.differs(png([ring, bars, Block(rect: CGRect(x: 30, y: 140, width: 60, height: 8), gray: 0.7)]), from: png([ring, bars]), steadiedBy: nil))
}

@Test func aWidgetWithALiveTimerStillSettles() async {
    let frames = Frames { limits(tick: $0) }
    let frame = await Capture.settle(baseline: weather(), timeout: 5, interval: 0) { frames.next() }
    #expect(frame != nil)
}

@Test func theSameTickingWidgetIsReportedAsUnchanged() async {
    let frames = Frames { limits(tick: $0) }
    let frame = await Capture.settle(baseline: limits(tick: 40), timeout: 0.3, interval: 0.01) { frames.next() }
    #expect(frame == nil)
}

@Test func aWidgetThatKeepsRedrawingDoesNotSettle() async {
    let frames = Frames { $0 % 2 == 0 ? limits(tick: $0) : weather(tick: $0) }
    let frame = await Capture.settle(baseline: png([]), timeout: 0.3, interval: 0.01) { frames.next() }
    #expect(frame == nil)
}
