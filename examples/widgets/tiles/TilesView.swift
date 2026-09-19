import AWKit
import SwiftUI
import WidgetKit

struct TilesData: Codable, Sendable {
    let seed: Int
}

struct TilesView: AWView {
    static let boardKey = "board"

    let entry: AWEntry<TilesData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<TilesData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            let game = TilesGame(encoded: entry.state.string(Self.boardKey) ?? "") ?? TilesGame.start(seed: data.seed, best: 0)
            switch context.family {
            case .small:
                smallBody(game)
            case .medium:
                mediumBody(game)
            default:
                largeBody(game)
            }
        }
    }

    private func smallBody(_ game: TilesGame) -> some View {
        VStack(spacing: AWSpace.xs) {
            HStack {
                AWText("2048", .label)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                AWText("\(game.score)", .label)
            }
            board(game)
            HStack(spacing: AWSpace.xs) {
                ForEach([TilesGame.Direction.left, .up, .down, .right], id: \.rawValue) { direction in
                    arrow(direction, game: game, side: 24)
                }
                restart(game, side: 24)
            }
        }
    }

    private func mediumBody(_ game: TilesGame) -> some View {
        HStack(alignment: .top, spacing: AWSpace.l) {
            board(game)
            VStack(alignment: .leading, spacing: AWSpace.s) {
                HStack(alignment: .top, spacing: AWSpace.l) {
                    figure("\(game.score)", context.pick(en: "score", ru: "счёт"))
                    figure("\(game.best)", context.pick(en: "best", ru: "рекорд"))
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: AWSpace.m) {
                    pad(game, side: 28)
                    Spacer(minLength: 0)
                    restart(game, side: 28)
                        .frame(width: 30)
                }
            }
        }
    }

    private func largeBody(_ game: TilesGame) -> some View {
        VStack(alignment: .leading, spacing: AWSpace.s) {
            HStack(alignment: .top, spacing: AWSpace.xl) {
                figure("\(game.score)", context.pick(en: "score", ru: "счёт"))
                figure("\(game.best)", context.pick(en: "best", ru: "рекорд"))
                Spacer(minLength: 0)
                AWText(context.pick(en: "move \(game.moves)", ru: "ход \(game.moves)"), .caption)
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .center, spacing: AWSpace.s) {
                board(game)
                VStack(spacing: AWSpace.s) {
                    ForEach([TilesGame.Direction.up, .left, .right, .down], id: \.rawValue) { direction in
                        arrow(direction, game: game, side: 40)
                    }
                    restart(game, side: 40)
                }
                .frame(width: 48)
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AWText(value, .display)
                .monospacedDigit()
            AWText(label, .label)
                .foregroundStyle(.secondary)
        }
    }

    private func board(_ game: TilesGame) -> some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let gap = max(side * 0.025, 2)
            let cell = (side - gap * 5) / 4
            ZStack {
                RoundedRectangle(cornerRadius: gap * 2.4, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                VStack(spacing: gap) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<4, id: \.self) { column in
                                tile(game.cells[row * 4 + column], side: cell)
                            }
                        }
                    }
                }
                if game.isOver || game.isWon {
                    verdict(game, side: side, radius: gap * 2.4)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .awBlock("board")
    }

    private func tile(_ value: Int, side: CGFloat) -> some View {
        let digits = String(value).count
        let scale: CGFloat = digits <= 2 ? 0.5 : (digits == 3 ? 0.4 : 0.32)
        return ZStack {
            RoundedRectangle(cornerRadius: side * 0.16, style: .continuous)
                .fill(fill(value))
                .widgetAccentable(value >= 8)
            if value > 0 {
                Text(String(value))
                    .font(.system(size: side * scale, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(ink(value))
            }
        }
        .frame(width: side, height: side)
    }

    private func verdict(_ game: TilesGame, side: CGFloat, radius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.background.opacity(0.78))
            VStack(spacing: 2) {
                Text(game.isWon ? "2048!" : context.pick(en: "Game over", ru: "Конец игры"))
                    .font(.system(size: side * 0.12, weight: .bold, design: .rounded))
                Text(context.pick(en: "score \(game.score)", ru: "счёт \(game.score)"))
                    .font(.system(size: side * 0.075, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pad(_ game: TilesGame, side: CGFloat) -> some View {
        VStack(spacing: 3) {
            arrow(.up, game: game, side: side)
                .frame(width: side + 2)
            HStack(spacing: 3) {
                ForEach([TilesGame.Direction.left, .down, .right], id: \.rawValue) { direction in
                    arrow(direction, game: game, side: side)
                        .frame(width: side + 2)
                }
            }
        }
    }

    @ViewBuilder
    private func arrow(_ direction: TilesGame.Direction, game: TilesGame, side: CGFloat) -> some View {
        if let next = game.moved(direction), !game.isWon {
            AWButton(.set, key: Self.boardKey, value: next.encoded) {
                key(symbol(direction), side: side, active: true)
            }
        } else {
            key(symbol(direction), side: side, active: false)
        }
    }

    private func restart(_ game: TilesGame, side: CGFloat) -> some View {
        let fresh = TilesGame.start(seed: game.moves &+ game.score &+ 1, best: max(game.best, game.score))
        return AWButton(.set, key: Self.boardKey, value: fresh.encoded) {
            key("arrow.counterclockwise", side: side, active: true)
        }
    }

    private func key(_ symbol: String, side: CGFloat, active: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: side * 0.46, weight: .bold))
            .foregroundStyle(active ? Color.primary : Color.primary.opacity(0.25))
            .frame(maxWidth: .infinity, minHeight: side, maxHeight: side)
            .frame(minWidth: side)
            .background(RoundedRectangle(cornerRadius: side * 0.28, style: .continuous).fill(Color.primary.opacity(active ? 0.12 : 0.05)))
    }

    private func symbol(_ direction: TilesGame.Direction) -> String {
        switch direction {
        case .up: "arrow.up"
        case .right: "arrow.right"
        case .down: "arrow.down"
        case .left: "arrow.left"
        }
    }

    private func fill(_ value: Int) -> Color {
        guard value > 0 else {
            return Color.primary.opacity(0.07)
        }
        let step = Double(min(value.trailingZeroBitCount, 11))
        if context.isMonochrome {
            return Color.primary.opacity(0.14 + step * 0.07)
        }
        let palette: [Color] = [
            Color(red: 0.93, green: 0.89, blue: 0.85), Color(red: 0.93, green: 0.88, blue: 0.78),
            Color(red: 0.95, green: 0.69, blue: 0.47), Color(red: 0.96, green: 0.58, blue: 0.39),
            Color(red: 0.96, green: 0.49, blue: 0.37), Color(red: 0.96, green: 0.37, blue: 0.23),
            Color(red: 0.93, green: 0.81, blue: 0.45), Color(red: 0.93, green: 0.80, blue: 0.38),
            Color(red: 0.93, green: 0.78, blue: 0.31), Color(red: 0.93, green: 0.77, blue: 0.25),
            Color(red: 0.93, green: 0.76, blue: 0.18)
        ]
        return palette[min(max(Int(step) - 1, 0), palette.count - 1)]
    }

    private func ink(_ value: Int) -> Color {
        if context.isMonochrome {
            return value >= 64 ? Color(nsColor: .windowBackgroundColor) : Color.primary
        }
        return value <= 4 ? Color(red: 0.47, green: 0.43, blue: 0.40) : .white
    }
}
