import Foundation
import Testing
@testable import AWSchema

@Test func parseDateAcceptsCommonISOForms() {
    #expect(AWJSON.parseDate("2027-01-15T08:00:00Z") != nil)
    #expect(AWJSON.parseDate("2027-01-15T08:00:00.123Z") != nil)
    #expect(AWJSON.parseDate("2027-01-15T15:00:00.000000+07:00") == AWJSON.parseDate("2027-01-15T08:00:00Z"))
    #expect(AWJSON.parseDate("yesterday") == nil)
}

@Test func feedStatusDecodesEpochAndISO() throws {
    let epoch = try AWJSON.decoder().decode(FeedStatus.self, from: Data(#"{"ok":true,"checkedAt":1800000000}"#.utf8))
    let iso = try AWJSON.decoder().decode(FeedStatus.self, from: Data(#"{"ok":true,"checkedAt":"2027-01-15T08:00:00Z"}"#.utf8))
    #expect(epoch.checkedAt == iso.checkedAt)
}

@Test func badDateExplainsTheExpectedFormat() {
    do {
        _ = try AWJSON.decoder().decode(FeedStatus.self, from: Data(#"{"ok":true,"checkedAt":"soon"}"#.utf8))
        Issue.record("expected a decoding error")
    } catch {
        #expect(DecodingErrorFormatter.describe(error).contains("ISO 8601"))
    }
}

@Test func layoutPathsAreStable() {
    #expect(AppGroupLayout.data("weather") == "widgets/weather/data.json")
    #expect(AppGroupLayout.image("weather", "sky.png") == "widgets/weather/images/sky.png")
    #expect(AppGroupLayout.devTarget == "dev/target.json")
}
