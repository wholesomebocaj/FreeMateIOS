#if canImport(UIKit)
import XCTest
@testable import FreeMateIOS

/// Plays games on the real `PracticeBoard`, so it needs Combine (Xcode only).
@MainActor
final class ComputerGameTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "ComputerGameTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeGame() -> ComputerGame {
        let game = ComputerGame(defaults: defaults)
        game.thinkingDelay = .zero
        return game
    }

    private func waitForReply(_ game: ComputerGame) async throws {
        for _ in 0..<200 where game.isThinking {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(game.isThinking, "The computer did not reply in time.")
    }

    func testComputerRepliesToTheLearnersMove() async throws {
        let game = makeGame()
        game.newGame(as: .white)

        game.board.select("e2")
        game.board.select("e4")
        XCTAssertTrue(game.isThinking)
        XCTAssertFalse(game.canMove)
        try await waitForReply(game)

        XCTAssertEqual(game.board.history.count, 2)
        XCTAssertTrue(game.isLearnersTurn)
        XCTAssertTrue(game.canMove)
    }

    func testComputerOpensWhenTheLearnerPlaysBlack() async throws {
        let game = makeGame()
        game.newGame(as: .black)
        try await waitForReply(game)

        XCTAssertEqual(game.board.history.count, 1)
        XCTAssertEqual(game.board.orientation, "black")
        XCTAssertTrue(game.isLearnersTurn)
    }

    func testUndoTakesBackTheMoveAndTheReply() async throws {
        let game = makeGame()
        game.newGame(as: .white)
        XCTAssertFalse(game.canUndo)

        game.board.select("d2")
        game.board.select("d4")
        try await waitForReply(game)
        game.undo()

        XCTAssertTrue(game.board.history.isEmpty)
        XCTAssertEqual(game.board.fen, ChessEngine.startingFen)
        XCTAssertTrue(game.isLearnersTurn)
    }

    func testResigningCountsAsALossAndIsSaved() async throws {
        let game = makeGame()
        game.newGame(as: .white)
        game.board.select("e2")
        game.board.select("e4")
        try await waitForReply(game)

        game.resign()

        XCTAssertEqual(game.result, .resigned)
        XCTAssertFalse(game.canMove)
        XCTAssertEqual(ComputerGame(defaults: defaults).record, ComputerGameRecord(wins: 0, draws: 0, losses: 1))
    }

    func testLevelIsSaved() {
        let game = makeGame()
        game.level = .fair

        XCTAssertEqual(ComputerGame(defaults: defaults).level, .fair)
    }

    // MARK: - Coaching

    /// White's queen can take a pawn on d5 that c6 defends.
    private let queenTrap = "4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1"

    private func wait(until condition: () -> Bool) async throws {
        for _ in 0..<300 where !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition(), "Timed out.")
    }

    func testBlunderWarningPausesTheComputerUntilTakenBack() async throws {
        let game = makeGame()
        game.newGame(as: .white, from: queenTrap)
        game.board.select("d1")
        game.board.select("d5")
        try await waitForReply(game)

        XCTAssertEqual(game.warning?.kind, .losesPiece(.queen, on: "d5"))
        XCTAssertEqual(game.board.history.count, 1)
        XCTAssertFalse(game.canMove)
        XCTAssertEqual(game.board.highlightSquares, [HighlightMark(square: "d5", className: "danger")])

        game.takeBackWarnedMove()

        XCTAssertNil(game.warning)
        XCTAssertTrue(game.board.history.isEmpty)
        XCTAssertEqual(game.board.fen, queenTrap)
        XCTAssertTrue(game.board.highlightSquares.isEmpty)
        XCTAssertTrue(game.canMove)
    }

    func testPlayingOnAfterAWarningLetsTheComputerReply() async throws {
        let game = makeGame()
        game.newGame(as: .white, from: queenTrap)
        game.board.select("d1")
        game.board.select("d5")
        try await waitForReply(game)

        game.ignoreWarning()
        try await waitForReply(game)

        XCTAssertNil(game.warning)
        XCTAssertEqual(game.board.history.count, 2)
        XCTAssertEqual(game.board.history.last?.san, "cxd5")
    }

    func testNoWarningWhenWarningsAreOff() async throws {
        let game = makeGame()
        game.warnsAboutBlunders = false
        game.newGame(as: .white, from: queenTrap)
        game.board.select("d1")
        game.board.select("d5")
        try await waitForReply(game)

        XCTAssertNil(game.warning)
        XCTAssertEqual(game.board.history.count, 2)
        XCTAssertFalse(ComputerGame(defaults: defaults).warnsAboutBlunders)
    }

    func testHintMarksTheBestMove() async throws {
        let game = makeGame()
        game.newGame(as: .white, from: "4k3/8/8/3q4/8/2N5/8/4K3 w - - 0 1")
        game.showHint()
        try await wait { !game.isFindingHint }

        XCTAssertEqual(game.board.highlightSquares, [
            HighlightMark(square: "c3", className: "focus"),
            HighlightMark(square: "d5", className: "target"),
        ])

        game.board.select("c3")
        game.board.select("d5")

        XCTAssertTrue(game.board.highlightSquares.isEmpty)
    }

    func testReviewGradesEachOfTheLearnersMoves() async throws {
        let game = makeGame()
        game.warnsAboutBlunders = false
        game.newGame(as: .white, from: queenTrap)
        game.board.select("d1")
        game.board.select("d5")
        try await waitForReply(game)
        game.board.select("e1")
        game.board.select("e2")
        try await waitForReply(game)
        game.resign()

        let review = ComputerGameReview(game: game)
        XCTAssertEqual(review.learnerPlies, [0, 2])
        XCTAssertEqual(review.selectedPly, 3)
        review.start()
        try await wait { review.isFinished }

        XCTAssertEqual(review.reviewed[0]?.quality, .blunder)
        XCTAssertEqual(review.reviewed[0]?.reason, .hung(.queen, on: "d5"))
        XCTAssertNotNil(review.reviewed[2])
        XCTAssertEqual(review.count(.blunder), 1)

        review.selectNextMistake()
        XCTAssertEqual(review.selectedPly, 0)
        XCTAssertEqual(review.board.fen, game.positions[1])

        review.toggleBetterMove()
        XCTAssertTrue(review.showsBetterMove)
        XCTAssertEqual(review.board.fen, queenTrap)
        XCTAssertEqual(review.board.highlightSquares.map(\.className), ["focus", "target"])
    }
}
#endif
