import CoreGraphics
import Foundation
import Testing
@testable import AWSchema

@Test func familySizesMatchMeasuredContent() {
    #expect(Family.small.size == CGSize(width: 155, height: 155))
    #expect(Family.medium.size == CGSize(width: 329, height: 155))
    #expect(Family.large.size == CGSize(width: 345, height: 345))
    #expect(Family.extraLarge.size == CGSize(width: 715, height: 345))
}

@Test func familyFromWindowUsesNearestNeighbour() {
    #expect(Family.nearest(windowSize: CGSize(width: 360, height: 360)) == .large)
    #expect(Family.nearest(windowSize: CGSize(width: 720, height: 344)) == .extraLarge)
    #expect(Family.nearest(windowSize: CGSize(width: 170, height: 170)) == .small)
    #expect(Family.nearest(windowSize: CGSize(width: 1200, height: 900)) == nil)
}

@Test func familySizesFollowTheMeasuredDesk() {
    let desk = DeskGeometry(
        small: CGSize(width: 164, height: 164),
        medium: CGSize(width: 344, height: 164),
        large: CGSize(width: 344, height: 344),
        extraLarge: CGSize(width: 704, height: 344),
        cornerRadius: 27.88,
        source: "chronod"
    )
    DeskGeometry.$current.withValue(desk) {
        #expect(Family.small.size == CGSize(width: 164, height: 164))
        #expect(Family.extraLarge.size == CGSize(width: 704, height: 344))
        #expect(Family.nearest(windowSize: CGSize(width: 360, height: 180)) == .medium)
    }
    #expect(Family.small.size == CGSize(width: 155, height: 155))
}

@Test func familyWidgetKitNames() {
    #expect(Family.allCases.map(\.widgetKitCase) == [".systemSmall", ".systemMedium", ".systemLarge", ".systemExtraLarge"])
}

@Test func intervalParsesUnits() throws {
    #expect(Interval(parsing: "30s")?.seconds == 30)
    #expect(Interval(parsing: "15m")?.seconds == 900)
    #expect(Interval(parsing: "2h")?.seconds == 7200)
    #expect(Interval(parsing: "1d")?.seconds == 86400)
    #expect(Interval(parsing: "soon") == nil)
    #expect(Interval(parsing: "0m") == nil)
    let decoded = try JSONDecoder().decode([Interval].self, from: Data(#"["5m", 120]"#.utf8))
    #expect(decoded.map(\.seconds) == [300, 120])
}

@Test func intervalEncodesAsCompactString() throws {
    let data = try JSONEncoder().encode([Interval(seconds: 900), Interval(seconds: 90)])
    #expect(String(bytes: data, encoding: .utf8) == #"["15m","90s"]"#)
}

@Test func localizedTextAcceptsStringOrObject() throws {
    let plain = try JSONDecoder().decode(LocalizedText.self, from: Data(#""Weather""#.utf8))
    #expect(plain.resolve(.ru) == "Weather")
    let pair = try JSONDecoder().decode(LocalizedText.self, from: Data(#"{"en":"Weather","ru":"Погода"}"#.utf8))
    #expect(pair.resolve(.ru) == "Погода")
    #expect(pair.resolve(.en) == "Weather")
    #expect(pair.all == ["Weather", "Погода"])
}

@Test func localizedTextRequiresEnglish() {
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(LocalizedText.self, from: Data(#"{"ru":"Погода"}"#.utf8))
    }
}

@Test func languageDetectionPrefersEnvThenLocale() {
    #expect(Language.detect(environment: ["AW_LANG": "ru"], preferred: ["en-US"]) == .ru)
    #expect(Language.detect(environment: ["AW_LANG": "xx"], preferred: ["ru-RU"]) == .ru)
    #expect(Language.detect(environment: [:], preferred: ["ru-RU", "en"]) == .ru)
    #expect(Language.detect(environment: [:], preferred: ["de-DE"]) == .en)
}

@Test func jsonValueRoundTripsAndMerges() throws {
    let base = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"a":1,"b":{"c":2,"d":3},"l":[1,true,null,"x"]}"#.utf8))
    let overlay = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"b":{"d":4},"e":5}"#.utf8))
    let merged = base.merged(with: overlay)
    let expected = try JSONDecoder().decode(
        JSONValue.self,
        from: Data(#"{"a":1,"b":{"c":2,"d":4},"e":5,"l":[1,true,null,"x"]}"#.utf8)
    )
    #expect(merged == expected)
    let reencoded = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(merged))
    #expect(reencoded == merged)
}

@Test func jsonValueCanonicalFormIgnoresKeyOrder() throws {
    let first = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"b":1,"a":[2,3]}"#.utf8))
    let second = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"a":[2,3],"b":1}"#.utf8))
    #expect(try first.canonicalData() == second.canonicalData())
}

@Test func reportHasErrorsWhenAnyCellHasError() {
    let bad = Issue(code: IssueCode.overflow, severity: .error, message: "too tall")
    let cell = PreviewCell(
        family: .small,
        appearance: .light,
        mode: .color,
        scenario: "default",
        image: "small-light-color-default.png",
        idealHeight: 200,
        issues: [bad]
    )
    #expect(PreviewReport(widget: "w", sheet: "sheet.png", cells: [cell], issues: []).hasErrors)
    #expect(!PreviewReport(widget: "w", sheet: "sheet.png", cells: [], issues: []).hasErrors)
}

@Test func issueRoundTripsThroughJSON() throws {
    let issue = Issue(code: IssueCode.buildError, severity: .error, message: "m", hint: "h", file: "a.swift", line: 3)
    let decoded = try JSONDecoder().decode(Issue.self, from: JSONEncoder().encode(issue))
    #expect(decoded == issue)
}
