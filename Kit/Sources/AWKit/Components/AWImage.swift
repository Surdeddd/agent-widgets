import AppKit
import AWSchema
import SwiftUI

private struct AWStoreKey: EnvironmentKey {
    static let defaultValue = AWStore.shared
}

extension EnvironmentValues {
    public var awStore: AWStore {
        get { self[AWStoreKey.self] }
        set { self[AWStoreKey.self] = newValue }
    }
}

public struct AWImage: View {
    @Environment(\.awStore) private var store
    private let widget: String
    private let name: String
    private let contentMode: ContentMode

    public init(widget: String, name: String, contentMode: ContentMode = .fill) {
        self.widget = widget
        self.name = name
        self.contentMode = contentMode
    }

    public var body: some View {
        picture
            .awBlock("AWImage \(name)")
    }

    @ViewBuilder
    private var picture: some View {
        if let url = store.imageURL(widget: widget, name: name), let image = NSImage(contentsOf: url) {
            if contentMode == .fill {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}
