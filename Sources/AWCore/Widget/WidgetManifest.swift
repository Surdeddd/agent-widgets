import AWSchema

public struct WidgetManifest: Codable, Equatable, Sendable {
    public static let defaultRefresh = Interval(seconds: 1800)

    public var id: String
    public var kind: String?
    public var name: LocalizedText
    public var description: LocalizedText?
    public var families: [Family]
    public var view: String
    public var refresh: Interval?
    public var feed: FeedSpec?
    public var settings: JSONValue?

    public init(
        id: String,
        kind: String? = nil,
        name: LocalizedText,
        description: LocalizedText? = nil,
        families: [Family],
        view: String,
        refresh: Interval? = nil,
        feed: FeedSpec? = nil,
        settings: JSONValue? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.description = description
        self.families = families
        self.view = view
        self.refresh = refresh
        self.feed = feed
        self.settings = settings
    }

    public var resolvedKind: String {
        kind ?? "aw.\(id)"
    }

    public var resolvedRefresh: Interval {
        refresh ?? Self.defaultRefresh
    }
}
