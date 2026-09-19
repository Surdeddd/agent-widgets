import Foundation
import Testing

private func game(_ rows: [[Int]], score: Int = 0, best: Int = 0, moves: Int = 0) -> TilesGame {
    TilesGame(cells: rows.flatMap { $0 }, score: score, best: best, moves: moves)
}

private func rows(_ game: TilesGame) -> [[Int]] {
    stride(from: 0, to: 16, by: 4).map { Array(game.cells[$0..<$0 + 4]) }
}

@Test func aRowSlidesAndMergesOncePerPair() {
    #expect(TilesGame.collapse([2, 2, 2, 2]).line == [4, 4, 0, 0])
    #expect(TilesGame.collapse([2, 2, 2, 2]).gained == 8)
    #expect(TilesGame.collapse([4, 0, 4, 8]).line == [8, 8, 0, 0])
    #expect(TilesGame.collapse([2, 4, 2, 4]).line == [2, 4, 2, 4])
    #expect(TilesGame.collapse([0, 0, 0, 2]).line == [2, 0, 0, 0])
    #expect(TilesGame.collapse([4, 4, 8, 0]).line == [8, 8, 0, 0])
    #expect(TilesGame.collapse([4, 4, 8, 0]).gained == 8)
}

@Test func everyDirectionSlidesTowardsItsEdge() {
    let board = game([
        [2, 0, 0, 2],
        [0, 4, 0, 0],
        [0, 4, 0, 0],
        [8, 0, 0, 0]
    ])
    #expect(rows(TilesGame(cells: board.slid(.left).cells, score: 0, best: 0, moves: 0)) == [[4, 0, 0, 0], [4, 0, 0, 0], [4, 0, 0, 0], [8, 0, 0, 0]])
    #expect(rows(TilesGame(cells: board.slid(.right).cells, score: 0, best: 0, moves: 0)) == [[0, 0, 0, 4], [0, 0, 0, 4], [0, 0, 0, 4], [0, 0, 0, 8]])
    #expect(rows(TilesGame(cells: board.slid(.up).cells, score: 0, best: 0, moves: 0)) == [[2, 8, 0, 2], [8, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
    #expect(rows(TilesGame(cells: board.slid(.down).cells, score: 0, best: 0, moves: 0)) == [[0, 0, 0, 0], [0, 0, 0, 0], [2, 0, 0, 0], [8, 8, 0, 2]])
    #expect(board.slid(.up).gained == 8)
}

@Test func aMoveAddsOneTileScoresAndCounts() throws {
    let board = game([
        [2, 2, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
    ], score: 10, best: 12, moves: 3)
    let next = try #require(board.moved(.left))
    #expect(next.cells[0] == 4)
    #expect(next.cells.filter { $0 != 0 }.count == 2)
    #expect(next.score == 14)
    #expect(next.best == 14)
    #expect(next.moves == 4)
    let spawned = next.cells.enumerated().filter { $0.offset != 0 && $0.element != 0 }.map(\.element)
    #expect(spawned == [2] || spawned == [4])
}

@Test func aMoveThatChangesNothingIsNotAMove() {
    let board = game([
        [2, 4, 8, 16],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
    ])
    #expect(board.moved(.up) == nil)
    #expect(board.moved(.left) == nil)
    #expect(board.moved(.down) != nil)
}

@Test func theSameMoveAlwaysGivesTheSameBoard() throws {
    let board = TilesGame.start(seed: 7, best: 0)
    #expect(board.cells.filter { $0 != 0 }.count == 2)
    #expect(TilesGame.start(seed: 7, best: 0) == board)
    #expect(TilesGame.start(seed: 8, best: 0) != board)
    let direction = try #require(TilesGame.Direction.allCases.first { board.moved($0) != nil })
    #expect(board.moved(direction) == board.moved(direction))
}

@Test func aFullBoardWithoutPairsIsOver() {
    let stuck = game([
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 2]
    ])
    #expect(stuck.isOver)
    #expect(TilesGame.Direction.allCases.allSatisfy { stuck.moved($0) == nil })
    let alive = game([
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 4]
    ])
    #expect(!alive.isOver)
    #expect(!TilesGame.start(seed: 1, best: 0).isOver)
}

@Test func reaching2048Wins() {
    #expect(game([[1024, 1024, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]).moved(.left)?.isWon == true)
    #expect(!TilesGame.start(seed: 1, best: 0).isWon)
}

@Test func theBoardSurvivesTheWidgetState() throws {
    let board = game([
        [2, 0, 0, 1024],
        [0, 4, 0, 0],
        [0, 0, 8, 0],
        [16, 0, 0, 2048]
    ], score: 20480, best: 99999, moves: 812)
    #expect(TilesGame(encoded: board.encoded) == board)
    #expect(board.encoded == "2,0,0,1024,0,4,0,0,0,0,8,0,16,0,0,2048|20480|99999|812")
    #expect(TilesGame(encoded: "") == nil)
    #expect(TilesGame(encoded: "1,2,3|0|0|0") == nil)
    #expect(TilesGame(encoded: "x,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0|0|0|0") == nil)
}

@Test func aNewGameKeepsTheRecord() {
    let fresh = TilesGame.start(seed: 3, best: 4096)
    #expect(fresh.best == 4096)
    #expect(fresh.score == 0)
    #expect(fresh.moves == 0)
}
