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

    private func wait(until condition: () -> Bool) async throws {
        for _ in 0..<150 where !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition(), "Timed out.")
    }

    func testMateInTwoPlaysTheDefenseOnTheBoard() async throws {
        let puzzle = Puzzle(
            id: "m2", prompt: "Mate in two.", fen: "r6k/6pp/7N/8/8/1Q6/8/7K w - - 0 1",
            solution: ["b3g8"], hint: "", success: "", theme: .mate, mateIn: 2
        )
        let trainer = PuzzleTrainer(
            set: PuzzleSet(drill: Drill(id: "m2", title: "M2", summary: "", puzzles: [puzzle])),
            store: PuzzleProgressStore(defaults: defaults),
            activity: ActivityStore(defaults: defaults)
        )
        trainer.board.select("b3")
        trainer.board.select("g8")

        XCTAssertTrue(trainer.isReplying)
        XCTAssertEqual(trainer.board.position["g8"], "wQ")
        try await wait { !trainer.isReplying }
        XCTAssertEqual(trainer.board.position["g8"], "bR", "Rxg8")
        XCTAssertEqual(trainer.board.lastMove, ["a8", "g8"])
        XCTAssertFalse(trainer.session.isSolved)

        trainer.showHint()
        XCTAssertEqual(trainer.board.highlightSquares, [HighlightMark(square: "h6", className: "focus")])
        trainer.board.select("h6")
        trainer.board.select("f7")
        XCTAssertTrue(trainer.session.isSolved)
        XCTAssertTrue(trainer.board.isCheckmate)
        XCTAssertTrue(trainer.isSolved(puzzle))
    }

    func testRushCountsAnswersAndEndsAfterThreeMisses() async throws {
        let mate = Puzzle(id: "m1", prompt: "Mate.", fen: "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1", solution: ["a1a8"], hint: "", success: "", theme: .mate)
        let rush = RushController(pool: Array(repeating: mate, count: 6), store: RushStore(defaults: defaults), activity: ActivityStore(defaults: defaults))
        rush.start()
        XCTAssertEqual(rush.phase, .playing)

        rush.board.select("a1")
        rush.board.select("a8")
        XCTAssertEqual(rush.session.score, 1)
        XCTAssertEqual(rush.lastAnswer, true)
        for _ in 0..<3 {
            try await wait { !rush.isAdvancing }
            rush.board.select("a1")
            rush.board.select("a7")
        }
        try await wait { rush.phase == .over }
        XCTAssertEqual(rush.session.strikes, 3)
        XCTAssertTrue(rush.isNewBest)
        XCTAssertEqual(RushStore(defaults: defaults).best, 1)
    }

    func testBlunderCheckRevealsTheRefutation() async throws {
        let check = BlunderCheck(
            id: "q", fen: "4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1", move: "d1d5", isBlunder: true,
            refutation: "c6d5", explanation: "The pawn guards d5."
        )
        let controller = BlunderCheckController(checks: [check], store: BlunderProgressStore(defaults: defaults), activity: ActivityStore(defaults: defaults))
        XCTAssertEqual(controller.board.highlightSquares.map(\.square), ["d1", "d5"])

        controller.answer(isBlunder: true)
        XCTAssertTrue(controller.session.wasCorrect)
        XCTAssertEqual(controller.board.position["d5"], "wQ")
        try await wait { controller.board.position["d5"] == "bP" }
        XCTAssertEqual(BlunderProgressStore(defaults: defaults).correct, ["q"])

        controller.next()
        XCTAssertTrue(controller.session.isFinished)
    }

    func testResumesAtTheFirstUnsolvedPuzzle() {
        PuzzleProgressStore(defaults: defaults).markSolved("drill/test/fork", firstTry: true)
        let trainer = makeTrainer()

        XCTAssertEqual(trainer.session.index, 1)
        XCTAssertEqual(trainer.puzzle.id, "black-mate")
    }
}
#endif
