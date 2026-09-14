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
        styled
            .frame(width: family.size.width, height: family.size.height)
            .background(background)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(edge), lineWidth: 0.5))
            .environment(\.colorScheme, appearance == .dark ? .dark : .light)
    }

    @ViewBuilder private var styled: some View {
        switch mode {
        case .color: content
        case .idle: content.grayscale(1)
        case .clear: content.grayscale(1).blendMode(.screen)
        }
    }

    private var edge: Double {
        mode == .clear ? 0.3 : (appearance == .dark ? 0.12 : 0.6)
    }

    private var background: some View {
        let colors: [Color] = switch (appearance, mode) {
        case (.dark, .color): [Color(white: 0.2), Color(white: 0.13)]
        case (.dark, .idle): [Color(white: 0.16), Color(white: 0.11)]
        case (.light, .color): [Color(white: 0.98), Color(white: 0.92)]
        case (.light, .idle): [Color(white: 0.9), Color(white: 0.84)]
        case (_, .clear): [Color(red: 0.24, green: 0.31, blue: 0.43), Color(red: 0.15, green: 0.17, blue: 0.26)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}
