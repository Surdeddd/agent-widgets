import AWCore
import AWSchema
import Foundation
import MCP

extension AWTools {
    static let gallery = AWTool(
        "aw_gallery",
        "List ready-made widgets that need no code: AI limits, agent sessions, GitHub contributions, AI spend, 2048, system pulse, focus timer. "
            + "When someone asks for one of these, install it with aw_gallery_add instead of writing a new widget.",
        schema: Schema.object([:], workspace: false),
        title: L10n.pick(en: "List ready-made widgets", ru: "Готовые виджеты"),
        hints: .reading,
        output: OutputSchema.gallery
    ) { _, context in
        let items = Gallery(engine: try context.engine()).list()
        let lines = items.map { "\($0.id) — \($0.summary.localized) [\($0.families.map(\.rawValue).joined(separator: ","))]" }
        return Reply.make(lines.joined(separator: "\n"), payload: ["widgets": items])
    }

    static let galleryAdd = AWTool(
        "aw_gallery_add",
        "Copy a ready-made widget from aw_gallery into widgets/<id>. "
            + "Then call aw_feed_run if it has a feed, aw_preview to look at it and aw_ship to put it on the desktop.",
        schema: Schema.object(["id": Schema.string("Gallery widget id from aw_gallery, for example ai-limits")], required: ["id"]),
        title: L10n.pick(en: "Install a ready-made widget", ru: "Поставить готовый виджет"),
        output: OutputSchema.created
    ) { arguments, context in
        let workspace = try context.workspace(arguments)
        let id = try arguments.required("id")
        let gallery = Gallery(engine: try context.engine())
        let created = try gallery.add(id, to: workspace)
        let hasFeed = gallery.list().first { $0.id == id }?.hasFeed == true
        let next = hasFeed ? "aw_feed_run, aw_preview, aw_ship" : "aw_preview, aw_ship"
        let summary = L10n.pick(
            en: "✓ widgets/\(id) from the gallery (\(created.count) files)\nNext: \(next).",
            ru: "✓ widgets/\(id) из галереи (файлов: \(created.count))\nДальше: \(next)."
        )
        return Reply.make(summary, payload: ["files": created])
    }
}
