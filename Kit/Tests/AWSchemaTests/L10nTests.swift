import Testing
@testable import AWSchema

@Test func pickFollowsTaskLocalLanguage() {
    L10n.$language.withValue(.ru) {
        #expect(L10n.pick(en: "yes", ru: "да") == "да")
    }
    L10n.$language.withValue(.en) {
        #expect(L10n.pick(en: "yes", ru: "да") == "yes")
    }
}

@Test func nestedScopesRestoreOuterLanguage() {
    L10n.$language.withValue(.ru) {
        L10n.$language.withValue(.en) {
            #expect(L10n.language == .en)
        }
        #expect(L10n.language == .ru)
    }
}
