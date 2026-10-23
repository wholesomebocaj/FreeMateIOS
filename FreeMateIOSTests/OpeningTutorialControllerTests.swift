#if canImport(UIKit)
import XCTest
@testable import FreeMateIOS

/// Exercises the tutorial against the real `PracticeBoard`, so it needs Combine (Xcode only).
@MainActor
final class OpeningTutorialControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "OpeningTutorialControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeController(_ id: String = "ruy-lopez") throws -> OpeningTutorialController {
        let tutorial = try OpeningTutorial(opening: TutorialFixtures.opening(id))
        return OpeningTutorialController(tutorial: tutorial, store: OpeningTutorialProgressStore(defaults: defaults))
    }

    func testBoardShowsTheExpectedSquares() async throws {
        let controller = try makeController()

        XCTAssertEqual(controller.board.highlightSquares.map(\.square), ["e2", "e4"])
        XCTAssertEqual(controller.board.orientation, "white")
    }

    func testWrongMoveLeavesThePieceInPlace() async throws {
        let controller = try makeController()
        let before = controller.board.fen

        controller.board.select("d2")
        controller.board.select("d4")

        XCTAssertEqual(controller.board.fen, before)
        XCTAssertEqual(controller.board.position["d2"], "wP")
        XCTAssertNil(controller.board.position["d4"])
        XCTAssertEqual(controller.rejectionCount, 1)
        XCTAssertEqual(controller.board.highlightSquares.map(\.className), ["danger", "danger"])
    }

    func testCorrectMoveIsPlayedAndTheOpponentReplies() async throws {
        let controller = try makeController()

        controller.board.select("e2")
        controller.board.select("e4")

        XCTAssertEqual(controller.board.position["e4"], "wP")
        XCTAssertTrue(controller.session.isAwaitingOpponent)
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(controller.board.position["e5"], "bP")
        XCTAssertEqual(controller.board.highlightSquares.map(\.square), ["g1", "f3"])
    }

    func testBlackTutorialFlipsTheBoardAndPlaysWhitesFirstMove() async throws {
        let controller = try makeController("caro-kann")

        XCTAssertEqual(controller.board.orientation, "black")
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(controller.board.position["e4"], "wP")
        XCTAssertEqual(controller.session.expectedUserMove?.san, "c6")
    }
}
#endif
