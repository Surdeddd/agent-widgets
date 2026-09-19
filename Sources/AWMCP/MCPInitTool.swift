import AWCore
import AWSchema
import Foundation
import MCP

extension AWTools {
    static let initialize = AWTool(
        "aw_init",
        "Create the widgets workspace — aw.json, the signing found on this Mac and the agent guide — in the folder this server points at, "
            + "or in `workspace`. Call it once when another tool answers WORKSPACE_NOT_FOUND, then go on with aw_gallery or aw_new.",
        schema: Schema.object([
            "name": Schema.string("App name shown in the macOS widget gallery, for example Desk Widgets (default: the folder name)"),
            "bundle_prefix": Schema.string("Reverse-DNS prefix of the bundle ids, for example com.yourname (default: made from the user name)"),
            "refresh_signing": Schema.boolean("Only detect the signing identity again for a workspace that already exists")
        ]),
        title: L10n.pick(en: "Create the widgets workspace", ru: "Создать workspace для виджетов"),
        output: OutputSchema.created
    ) { arguments, context in
        let target = arguments.string("workspace").map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
            ?? context.context.directory
        let initializer = WorkspaceInitializer(engine: try context.engine(), runner: context.runner)
        let options = InitOptions(directory: target, name: arguments.string("name"), bundlePrefix: arguments.string("bundle_prefix"))
        let outcome = arguments.bool("refresh_signing", default: false)
            ? try await initializer.refreshSigning(at: target)
            : try await initializer.initialize(options)
        let summary = L10n.pick(
            en: "✓ workspace ready: \(outcome.result.root)\nNext: aw_gallery for ready-made widgets, or aw_templates and aw_new.",
            ru: "✓ workspace готов: \(outcome.result.root)\nДальше: aw_gallery — готовые виджеты, или aw_templates и aw_new."
        )
        return Reply.make(summary, issues: outcome.issues, payload: ["files": outcome.result.files])
    }
}
