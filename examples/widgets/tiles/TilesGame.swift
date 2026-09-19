import Foundation

struct TilesGame: Equatable, Sendable {
    enum Direction: Int, CaseIterable, Sendable {
        case up
        case right
        case down
        case left
    }

    static let side = 4
    static let goal = 2048

    var cells: [Int]
    var score: Int
    var best: Int
    var moves: Int

    var isWon: Bool {
        cells.contains { $0 >= Self.goal }
    }

    var isOver: Bool {
        Direction.allCases.allSatisfy { slid($0).cells == cells }
    }

    var encoded: String {
        "\(cells.map(String.init).joined(separator: ","))|\(score)|\(best)|\(moves)"
    }

    init(cells: [Int], score: Int, best: Int, moves: Int) {
        self.cells = cells
        self.score = score
        self.best = best
        self.moves = moves
    }

    init?(encoded: String) {
        let parts = encoded.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        let values = parts[0].split(separator: ",", omittingEmptySubsequences: false).map { Int($0) }
        guard values.count == Self.side * Self.side, !values.contains(nil),
              let score = Int(parts[1]), let best = Int(parts[2]), let moves = Int(parts[3])
        else {
            return nil
        }
        self.init(cells: values.compactMap { $0 }, score: score, best: best, moves: moves)
    }

    static func start(seed: Int, best: Int) -> TilesGame {
        var game = TilesGame(cells: Array(repeating: 0, count: side * side), score: 0, best: best, moves: 0)
        game.spawn(salt: seed)
        game.spawn(salt: seed &+ 1)
        return game
    }

    /// The board after a move with its new tile, or nil when nothing can slide that way.
    func moved(_ direction: Direction) -> TilesGame? {
        let result = slid(direction)
        guard result.cells != cells else { return nil }
        var next = TilesGame(cells: result.cells, score: score + result.gained, best: best, moves: moves + 1)
        next.best = max(next.best, next.score)
        next.spawn(salt: moves)
        return next
    }

    func slid(_ direction: Direction) -> (cells: [Int], gained: Int) {
        var result = cells
        var gained = 0
        for lane in 0..<Self.side {
            let indices = Self.indices(lane: lane, direction: direction)
            let collapsed = Self.collapse(indices.map { cells[$0] })
            gained += collapsed.gained
            for (slot, index) in indices.enumerated() {
                result[index] = collapsed.line[slot]
            }
        }
        return (result, gained)
    }

    static func collapse(_ line: [Int]) -> (line: [Int], gained: Int) {
        var merged: [Int] = []
        var gained = 0
        var pending: Int?
        for value in line where value != 0 {
            if pending == value {
                merged.append(value * 2)
                gained += value * 2
                pending = nil
            } else {
                if let pending {
                    merged.append(pending)
                }
                pending = value
            }
        }
        if let pending {
            merged.append(pending)
        }
        return (merged + Array(repeating: 0, count: line.count - merged.count), gained)
    }

    private static func indices(lane: Int, direction: Direction) -> [Int] {
        (0..<side).map { step in
            switch direction {
            case .left: lane * side + step
            case .right: lane * side + (side - 1 - step)
            case .up: step * side + lane
            case .down: (side - 1 - step) * side + lane
            }
        }
    }

    private mutating func spawn(salt: Int) {
        let empty = cells.indices.filter { cells[$0] == 0 }
        guard !empty.isEmpty else { return }
        var hash = UInt64(truncatingIfNeeded: salt) &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        for value in cells {
            hash = (hash ^ UInt64(truncatingIfNeeded: value)) &* 1_099_511_628_211
        }
        hash ^= hash >> 29
        cells[empty[Int(hash % UInt64(empty.count))]] = (hash >> 7) % 10 == 0 ? 4 : 2
    }
}
