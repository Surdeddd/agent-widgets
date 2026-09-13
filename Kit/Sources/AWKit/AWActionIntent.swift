import AppIntents
import AWSchema
import SwiftUI
import WidgetKit

public struct AWKitIntents: AppIntentsPackage {}

public struct AWActionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Widget action"
    public static let isDiscoverable = false

    @Parameter(title: "Widget")
    public var widget: String

    @Parameter(title: "Kind")
    public var kind: String

    @Parameter(title: "Action")
    public var action: String

    @Parameter(title: "Key")
    public var key: String

    @Parameter(title: "Value")
    public var value: String

    public init() {}

    public init(widget: String, kind: String, action: AWAction, key: String, value: String) {
        self.widget = widget
        self.kind = kind
        self.action = action.rawValue
        self.key = key
        self.value = value
    }

    public func perform() async throws -> some IntentResult {
        if let action = AWAction(rawValue: action), !widget.isEmpty {
            let store = AWStore.shared
            try store.save(store.state(widget: widget).applying(action, key: key, value: value), widget: widget)
        }
        if !kind.isEmpty {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "aw.dev")
        return .result()
    }
}

public struct AWButton<Label: View>: View {
    @Environment(\.aw) private var context
    private let action: AWAction
    private let key: String
    private let value: String
    private let label: Label

    public init(_ action: AWAction, key: String = AWState.cursorKey, value: String = "", @ViewBuilder label: () -> Label) {
        self.action = action
        self.key = key
        self.value = value
        self.label = label()
    }

    public var body: some View {
        Button(intent: AWActionIntent(widget: context.widget ?? "", kind: context.kind ?? "", action: action, key: key, value: value)) {
            label
        }
        .buttonStyle(.plain)
    }
}

extension AWButton where Label == AWButtonIcon {
    public init(_ action: AWAction, symbol: String, key: String = AWState.cursorKey, value: String = "") {
        self.init(action, key: key, value: value) {
            AWButtonIcon(symbol: symbol)
        }
    }
}

public struct AWButtonIcon: View {
    @Environment(\.aw) private var context
    private let symbol: String

    public init(symbol: String) {
        self.symbol = symbol
    }

    public var body: some View {
        let side: CGFloat = context.isSmall ? 22 : 26
        Image(systemName: symbol)
            .font(.system(size: side * 0.46, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: side, height: side)
            .background(.quaternary, in: Circle())
            .contentShape(Circle())
    }
}
