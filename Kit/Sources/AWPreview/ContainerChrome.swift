import AWKit
import AWSchema
import SwiftUI

struct ContainerChrome<Content: View>: View {
    let family: Family
    let appearance: Appearance
    let mode: RenderMode
    let content: Content

    init(family: Family, appearance: Appearance, mode: RenderMode, @ViewBuilder content: () -> Content) {
        self.family = family
        self.appearance = appearance
        self.mode = mode
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AWMetrics.cornerRadius(for: family), style: .continuous)
        content
            .grayscale(mode == .idle ? 1 : 0)
            .frame(width: family.size.width, height: family.size.height)
            .background(background)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(appearance == .dark ? 0.12 : 0.6), lineWidth: 0.5))
            .environment(\.colorScheme, appearance == .dark ? .dark : .light)
    }

    private var background: some View {
        let colors: [Color] = switch (appearance, mode) {
        case (.dark, .color): [Color(white: 0.2), Color(white: 0.13)]
        case (.dark, .idle): [Color(white: 0.16), Color(white: 0.11)]
        case (.light, .color): [Color(white: 0.98), Color(white: 0.92)]
        case (.light, .idle): [Color(white: 0.9), Color(white: 0.84)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}
