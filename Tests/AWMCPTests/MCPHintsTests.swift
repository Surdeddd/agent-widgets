import AWSchema
import Testing
@testable import AWMCP

private func rewritten(_ text: String, _ language: Language = .en) -> String {
    L10n.$language.withValue(language) { MCPHints.rewrite(text) }
}

@Test func MCPHintsRewritesEveryMappedCommand() {
    let rows: [(String, String)] = [
        ("`aw preview`", "`aw_preview`"),
        ("`aw ship`", "`aw_ship`"),
        ("`aw shot`", "`aw_shot`"),
        ("`aw slot`", "`aw_slot`"),
        ("`aw dev`", "`aw_dev`"),
        ("`aw doctor`", "`aw_doctor`"),
        ("`aw list`", "`aw_list`"),
        ("`aw new`", "`aw_new`"),
        ("`aw explain`", "`aw_explain`"),
        ("`aw templates`", "`aw_templates`"),
        ("`aw feed run`", "`aw_feed_run`"),
        ("`aw data set`", "`aw_data_set`"),
        ("`aw gallery`", "`aw_gallery`"),
        ("`aw init`", "`aw_init`"),
        ("`aw init ~/Widgets --bundle-prefix com.me`", #"`aw_init {"bundle_prefix": "com.me", "workspace": "~/Widgets"}`"#),
        ("`aw gallery add ai-limits`", #"`aw_gallery_add {"id": "ai-limits"}`"#)
    ]
    for (input, expected) in rows {
        #expect(rewritten(input) == expected, "\(input)")
    }
}

@Test func MCPHintsTurnsPositionalAndFlagsIntoJSON() {
    #expect(rewritten("`aw preview weather --full`") == #"`aw_preview {"full": true, "id": "weather"}`"#)
    #expect(rewritten("`aw shot --dev`") == #"`aw_shot {"dev": true}`"#)
    #expect(rewritten("`aw new <id>`") == #"`aw_new {"id": "<id>"}`"#)
}

@Test func MCPHintsMapsExplainPositionalToCode() {
    #expect(rewritten("`aw explain INVALID_JSON`") == #"`aw_explain {"code": "INVALID_JSON"}`"#)
}

@Test func MCPHintsSplitsFamiliesIntoAnArray() {
    #expect(
        rewritten("`aw preview weather --families small,medium`")
            == #"`aw_preview {"families": ["small", "medium"], "id": "weather"}`"#
    )
}

@Test func MCPHintsParsesANumberValue() {
    #expect(rewritten("`aw slot --timeout 30`") == #"`aw_slot {"timeout": 30}`"#)
}

@Test func MCPHintsMarksShellOnlyCommandsByLanguage() {
    #expect(rewritten("`aw rollback`") == "`aw rollback` (in a shell)")
    #expect(rewritten("`aw geometry --measure`") == "`aw geometry --measure` (in a shell)")
    #expect(rewritten("`aw daemon install`") == "`aw daemon install` (in a shell)")
    #expect(rewritten("`aw rollback`", .ru) == "`aw rollback` (в терминале)")
    #expect(rewritten("`aw install --hard`", .ru) == "`aw install --hard` (в терминале)")
    #expect(rewritten("`aw rollback` (in a shell)") == "`aw rollback` (in a shell)")
    #expect(rewritten("`aw rollback` (в терминале)", .ru) == "`aw rollback` (в терминале)")
    #expect(rewritten("`aw rollback` (in a shell)", .ru) == "`aw rollback` (in a shell)")
    #expect(rewritten("`aw init --refresh-signing`") == #"`aw_init {"refresh_signing": true}`"#)
}

@Test func MCPHintsRewritesBareWorkspaceByLanguage() {
    #expect(rewritten("pass --workspace") == "pass the `workspace` argument")
    #expect(rewritten("передай --workspace", .ru) == "передай аргумент `workspace`")
}

@Test func MCPHintsLeavesTextWithoutHintsUnchanged() {
    #expect(rewritten("just a message") == "just a message")
    #expect(rewritten("Run aw list without ticks") == "Run aw list without ticks")
}

@Test func MCPHintsRewriteIsIdempotent() {
    let input = "Run `aw list` or `aw new weather`. Or `aw rollback` and pass --workspace."
    let once = rewritten(input)
    #expect(once == #"Run `aw_list` or `aw_new {"id": "weather"}`. Or `aw rollback` (in a shell) and pass the `workspace` argument."#)
    #expect(rewritten(once) == once)
    let russian = rewritten(input, .ru)
    #expect(rewritten(russian, .ru) == russian)
}
