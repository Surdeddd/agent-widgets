import AWSchema
import Testing
@testable import AWCore

@Test func everyIssueCodeIsExplainedInBothLanguages() {
    for code in IssueCode.all {
        let entry = IssueCatalog.explain(code)
        #expect(entry != nil, "\(code) has no catalog entry")
        for text in [entry?.title, entry?.cause, entry?.fix].compactMap({ $0 }) {
            #expect(!text.en.isEmpty, "\(code)")
            #expect(!(text.ru ?? "").isEmpty, "\(code)")
        }
    }
    #expect(Set(IssueCatalog.entries.map(\.code)) == Set(IssueCode.all))
    #expect(IssueCatalog.entries.count == IssueCode.all.count)
}

@Test func explainIgnoresCaseAndDashes() {
    #expect(IssueCatalog.explain("overflow")?.code == IssueCode.overflow)
    #expect(IssueCatalog.explain("feed-timeout")?.code == IssueCode.feedTimeout)
    #expect(IssueCatalog.explain("nope") == nil)
}

@Test func renderShowsCauseFixAndExample() throws {
    let entry = try #require(IssueCatalog.explain(IssueCode.overflow))
    let text = L10n.$language.withValue(.en) { IssueCatalog.render(entry) }
    #expect(text.hasPrefix("OVERFLOW — Content does not fit the widget"))
    #expect(text.contains("Why: "))
    #expect(text.contains("Fix: "))
    #expect(text.contains("    if context.family == .small {"))
}
