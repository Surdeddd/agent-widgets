import AWSchema
import Foundation
import SwiftUI
import Testing
@testable import AWKit

private final class LocaleBox: @unchecked Sendable {
    var seen: Locale?
}

private struct LocaleProbe: View {
    @Environment(\.locale) private var locale
    let box: LocaleBox

    var body: some View {
        box.seen = locale
        return Text(Date(timeIntervalSince1970: 1_789_776_000), format: .dateTime.weekday(.wide))
    }
}

@MainActor
private func seenLocale(_ language: Language) -> Locale? {
    let box = LocaleBox()
    let context = AWContext(family: .small, language: language)
    let renderer = ImageRenderer(content: AWFrame(context: context) { LocaleProbe(box: box) }.frame(width: 164, height: 164))
    _ = renderer.cgImage
    return box.seen
}

@MainActor
@Test func theFrameHandsTheWidgetLocaleToSystemDateText() {
    #expect(seenLocale(.ru)?.language.languageCode?.identifier == "ru")
    #expect(seenLocale(.en)?.language.languageCode?.identifier == "en")
}

@Test func aSparklineKeepsItsOwnScaleUnlessARangeIsGiven() {
    let free = AWSparkline.domain(of: [80, 83, 85], range: nil)
    #expect(free.lowerBound < 80 && free.lowerBound > 78)
    #expect(free.upperBound > 85 && free.upperBound < 87)
    let fixed = AWSparkline.domain(of: [80, 83, 85], range: 0...100)
    #expect(fixed.lowerBound <= 0 && fixed.lowerBound > -5)
    #expect(fixed.upperBound >= 100 && fixed.upperBound < 105)
    let flat = AWSparkline.domain(of: [5, 5, 5], range: nil)
    #expect(flat.lowerBound < flat.upperBound)
    #expect(AWSparkline.domain(of: [], range: nil).lowerBound < AWSparkline.domain(of: [], range: nil).upperBound)
}
