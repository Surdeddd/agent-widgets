import AppIntents
import AWSchema
import os
import SwiftUI
import WidgetKit

private let actionLog = Logger(subsystem: "com.agentwidgets.kit", category: "action")

public struct AWActionRequest: Sendable, Equatable {
    public var widget: String
    public var kind: String
    public var action: AWAction
    public var key: String
    public var value: String

    public init(widget: String, kind: String, action: AWAction, key: String, value: String) {
        self.widget = widget
        self.kind = kind
        self.action = action
        self.key = key
        self.value = value
    }
}

public enum AWActionRunner {
    /// Applies a button action to the widget's state and reloads its timelines.
    public static func run(widget: String, kind: String, action: String, key: String, value: String, store: AWStore = .shared) throws {
        let process = Bundle.main.bundleIdentifier ?? "?"
        actionLog.notice("perform \(action, privacy: .public) key=\(key, privacy: .public) widget=\(widget, privacy: .public) in \(process, privacy: .public)")
        if let action = AWAction(rawValue: action), !widget.isEmpty {
            do {
                try store.save(store.state(widget: widget).applying(action, key: key, value: value), widget: widget)
            } catch {
                let root = store.root?.path ?? "nil"
                actionLog.error("save failed in \(process, privacy: .public), root \(root, privacy: .public): \(String(describing: error), privacy: .public)")
                throw error
            }
        }
        if !kind.isEmpty {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "aw.dev")
    }
}

public enum AWButtonIntents {
    /// Set by the generated widget bundle: the intent type must live in the extension's own module for macOS to register it.
    public nonisolated(unsafe) static var factory: (@Sendable (AWActionRequest) -> any AppIntent)?

    public static func intent(for request: AWActionRequest) -> any AppIntent {
        factory?(request) ?? AWActionIntent(widget: request.widget, kind: request.kind, action: request.action, key: request.key, value: request.value)
    }
}

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
        try AWActionRunner.run(widget: widget, kind: kind, action: action, key: key, value: value)
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
        let request = AWActionRequest(widget: context.widget ?? "", kind: context.kind ?? "", action: action, key: key, value: value)
        button(AWButtonIntents.intent(for: request))
    }

    private func button<Intent: AppIntent>(_ intent: Intent) -> AnyView {
        AnyView(
            Button(intent: intent) {
                label
            }
            .buttonStyle(.plain)
        )
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
