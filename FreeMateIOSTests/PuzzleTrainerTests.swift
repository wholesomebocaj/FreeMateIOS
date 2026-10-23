#if canImport(UIKit)
import XCTest
@testable import FreeMateIOS

/// Solves puzzles on the real `PracticeBoard`, so it needs Combine (Xcode only).
@MainActor
final class PuzzleTrainerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "PuzzleTrainerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private let fork = Puzzle(
        id: "fork", prompt: "Win the rook.", fen: "r3k3/8/8/1N6/8/8/8/4K3 w - - 0 1",
        solution: ["b5c7"], hint: "Look at c7.", success: "Nc7+ forks.", theme: .material
    )
    private let blackMate = Puzzle(
        id: "black-mate", prompt: "Mate.", fen: "1r4k1/5ppp/8/8/8/8/5PPP/6K1 b - - 0 1",
        solution: ["b8b1"], hint: "Back rank.", success: "Rb1 mate.", theme: .mate
    )

    private func makeTrainer() -> PuzzleTrainer {
        let set = PuzzleSet(drill: Drill(id: "test", title: "Test", summary: "", puzzles: [fork, blackMate]))
        return PuzzleTrainer(set: set, store: PuzzleProgressStore(defaults: defaults))
    }

    func testSolvingPlaysTheMoveAndSavesProgress() {
        let trainer = makeTrainer()
        trainer.board.select("b5")
        trainer.board.select("c7")

        XCTAssertTrue(trainer.session.isSolved)
        XCTAssertEqual(trainer.board.position["c7"], "wN")
        XCTAssertEqual(trainer.board.lastMove, ["b5", "c7"])
        XCTAssertTrue(trainer.isSolved(fork))
        XCTAssertEqual(PuzzleProgressStore(defaults: defaults).record(for: "drill/test/fork")?.firstTry, true)
    }

    func testWrongMoveSpringsBackAndCountsAMistake() {
        let trainer = makeTrainer()
        trainer.board.select("b5")
        trainer.board.select("d6")

        XCTAssertFalse(trainer.session.isSolved)
        XCTAssertEqual(trainer.session.mistakes, 1)
        XCTAssertEqual(trainer.rejectionCount, 1)
        XCTAssertEqual(trainer.rejectedSquare, "b5")
        XCTAssertEqual(trainer.board.position["b5"], "wN")
        XCTAssertNil(trainer.board.position["d6"])
    }

    func testHintMarksThePieceAndAnswerMarksTheMove() {
        let trainer = makeTrainer()
        trainer.showHint()
        XCTAssertEqual(trainer.board.highlightSquares, [HighlightMark(square: "b5", className: "focus")])

        trainer.showAnswer()
        XCTAssertEqual(trainer.board.highlightSquares.map(\.square), ["b5", "c7"])

        trainer.board.select("b5")
        trainer.board.select("c7")
        XCTAssertTrue(trainer.board.highlightSquares.isEmpty)
        XCTAssertEqual(PuzzleProgressStore(defaults: defaults).record(for: "drill/test/fork")?.firstTry, false)
    }

    func testNextPuzzleFlipsTheBoardForBlack() {
        let trainer = makeTrainer()
        trainer.board.select("b5")
        trainer.board.select("c7")
        trainer.next()

        XCTAssertEqual(trainer.session.index, 1)
        XCTAssertEqual(trainer.board.orientation, "black")
        XCTAssertEqual(trainer.board.fen, blackMate.fen)

        trainer.board.select("b8")
        trainer.board.select("b1")
        XCTAssertTrue(trainer.board.isCheckmate)
        trainer.next()
        XCTAssertTrue(trainer.session.isFinished)
        XCTAssertEqual(trainer.session.firstTryCount, 2)
    }

    func testResumesAtTheFirstUnsolvedPuzzle() {
        PuzzleProgressStore(defaults: defaults).markSolved("drill/test/fork", firstTry: true)
        let trainer = makeTrainer()

        XCTAssertEqual(trainer.session.index, 1)
        XCTAssertEqual(trainer.puzzle.id, "black-mate")
    }
}
#endif
