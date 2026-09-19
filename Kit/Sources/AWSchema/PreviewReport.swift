import Foundation

public enum Appearance: String, Codable, CaseIterable, Sendable {
    case light
    case dark
}

public enum RenderMode: String, Codable, CaseIterable, Sendable {
    case color
    case idle
    case clear
}

public struct PreviewCell: Codable, Equatable, Sendable {
    public var family: Family
    public var appearance: Appearance
    public var mode: RenderMode
    public var scenario: String
    public var image: String
    public var idealHeight: Double
    public var issues: [Issue]
    /// Share of the content area taken by its largest empty rectangle, and that rectangle as x, y, width, height in fractions of the widget.
    public var emptyShare: Double?
    public var emptyArea: [Double]?

    public init(
        family: Family,
        appearance: Appearance,
        mode: RenderMode,
        scenario: String,
        image: String,
        idealHeight: Double,
        issues: [Issue],
        emptyShare: Double? = nil,
        emptyArea: [Double]? = nil
    ) {
        self.family = family
        self.appearance = appearance
        self.mode = mode
        self.scenario = scenario
        self.image = image
        self.idealHeight = idealHeight
        self.issues = issues
        self.emptyShare = emptyShare
        self.emptyArea = emptyArea
    }
}

public struct PreviewReport: Codable, Equatable, Sendable {
    public var widget: String
    public var sheet: String
    public var cells: [PreviewCell]
    public var issues: [Issue]

    public init(widget: String, sheet: String, cells: [PreviewCell], issues: [Issue]) {
        self.widget = widget
        self.sheet = sheet
        self.cells = cells
        self.issues = issues
    }

    public var allIssues: [Issue] {
        issues + cells.flatMap(\.issues)
    }

    public var hasErrors: Bool {
        allIssues.contains { $0.severity == .error }
    }
}
