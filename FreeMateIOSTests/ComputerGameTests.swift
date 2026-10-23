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
}
#endif
