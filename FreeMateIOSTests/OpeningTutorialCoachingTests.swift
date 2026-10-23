import XCTest
@testable import FreeMateIOS

@MainActor
final class OpeningTutorialCoachingTests: XCTestCase {
    func testMainLineCoachNamesTheMove() async throws {
        let session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))

        XCTAssertEqual(session.stageLabel, "Step 1 · Main line")
        XCTAssertEqual(session.coachMessage.title, "Play 1. e4: Claim the center")
        XCTAssertNil(session.feedbackMessage)
        XCTAssertEqual(session.progressPercent, 0)
    }

    func testMistakeFeedbackIsAGentleHint() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.submitMove(from: "d2", to: "d4")

        let message = try XCTUnwrap(session.feedbackMessage)
        XCTAssertEqual(message.tone, .hint)
        XCTAssertEqual(message.title, "d4 is not the move in this line")
        XCTAssertTrue(message.body.contains("from e2 to e4"))
    }

    func testWhatIfCoachDescribesTheOpponentsChoiceWithoutTheAnswer() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()
        session.playOpponentMove()

        XCTAssertEqual(session.stageLabel, "Step 2 · What if?")
        XCTAssertEqual(session.coachMessage.title, "What if: Berlin Defense")
        XCTAssertTrue(session.coachMessage.body.hasPrefix("Black played 3... Nf6."))
        XCTAssertFalse(session.coachMessage.body.contains("O-O"))
    }

    func testCompletedTutorialReportsMistakes() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.miniRuyLopez())
        session.submitMove(from: "d2", to: "d4")
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()
        session.playToEndOfCurrentLine()
        session.nextVariation()

        XCTAssertEqual(session.progressPercent, 100)
        XCTAssertEqual(session.coachMessage.title, "Mini Ruy Lopez complete")
        XCTAssertEqual(session.coachMessage.body, "1 mistake along the way. Replay any time to tidy them up.")
    }
}
