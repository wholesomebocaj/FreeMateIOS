import XCTest
@testable import FreeMateIOS

@MainActor
final class OpeningTutorialSessionTests: XCTestCase {
    func testPlayingTheMainLineCompletesStepOne() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        XCTAssertEqual(session.phase, .mainLine)
        XCTAssertTrue(session.isUserTurn)

        session.playToEndOfCurrentLine()

        XCTAssertEqual(session.phase, .mainLineComplete)
        XCTAssertEqual(session.feedback, .mainLineComplete)
        XCTAssertTrue(session.mistakes.isEmpty)
        XCTAssertEqual(session.mainLineUserMovesPlayed, session.mainLineUserMoveCount)
        XCTAssertEqual(session.lastMove?.san, "h3")
        XCTAssertEqual(session.fen, session.mainLineMoves.last?.fenAfter)
    }

    func testMainLineHighlightsTheStartAndEndSquares() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        XCTAssertEqual(session.highlightedSquares?.from, "e2")
        XCTAssertEqual(session.highlightedSquares?.to, "e4")

        session.playExpectedMove()

        XCTAssertEqual(session.highlightedSquares?.from, "g1")
        XCTAssertEqual(session.highlightedSquares?.to, "f3")
    }

    func testCorrectMoveAdvancesAndOpponentReplies() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))

        let result = session.submitMove(from: "e2", to: "e4")

        guard case .correct(let move) = result else { return XCTFail("Expected e4 to be accepted, got \(result)") }
        XCTAssertEqual(move.san, "e4")
        XCTAssertTrue(session.isAwaitingOpponent)
        XCTAssertEqual(session.playOpponentMove()?.san, "e5")
        XCTAssertTrue(session.isUserTurn)
        XCTAssertEqual(session.expectedUserMove?.san, "Nf3")
    }

    func testWrongMainLineMoveResetsAndShowsHint() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        let before = session.fen

        let result = session.submitMove(from: "d2", to: "d4")

        guard case .incorrect(let mistake) = result else { return XCTFail("Expected d4 to be rejected, got \(result)") }
        XCTAssertEqual(mistake.kind, .wrongMove)
        XCTAssertEqual(mistake.attempted, "d4")
        XCTAssertEqual(mistake.expected.san, "e4")
        XCTAssertTrue(mistake.hint.contains("from e2 to e4"))
        XCTAssertEqual(session.fen, before, "The piece should go back to where it started")
        XCTAssertEqual(session.feedback, .incorrect(mistake))
        XCTAssertEqual(session.phase, .mainLine)
        XCTAssertEqual(session.mistakes.count, 1)
        XCTAssertEqual(session.expectedUserMove?.san, "e4", "The learner retries the same move")
    }

    func testIllegalMoveIsReportedSeparately() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))

        let result = session.submitMove(from: "e2", to: "e5")

        guard case .incorrect(let mistake) = result else { return XCTFail("Expected an illegal move, got \(result)") }
        XCTAssertEqual(mistake.kind, .illegalMove)
        XCTAssertEqual(mistake.attempted, "e2e5")
        XCTAssertEqual(session.fen, ChessEngine.startingFen)
    }

    func testMovesAreIgnoredWhileTheOpponentIsToMove() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.submitMove(from: "e2", to: "e4")

        XCTAssertEqual(session.submitMove(from: "e7", to: "e5"), .ignored)
        XCTAssertTrue(session.mistakes.isEmpty)
    }

    func testBlackTutorialStartsWithTheOpponentMove() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("caro-kann"))
        XCTAssertTrue(session.isAwaitingOpponent)
        XCTAssertNil(session.highlightedSquares)

        XCTAssertEqual(session.playOpponentMove()?.san, "e4")

        XCTAssertEqual(session.expectedUserMove?.san, "c6")
        XCTAssertEqual(session.highlightedSquares?.from, "c7")
        session.playToEndOfCurrentLine()
        XCTAssertEqual(session.phase, .mainLineComplete)
    }

    func testWhatIfModeStartsWithTheOpponentsAlternative() async throws {
        let opening = try TutorialFixtures.opening("ruy-lopez")
        var session = try OpeningTutorialSession(opening: opening)
        session.playToEndOfCurrentLine()

        session.startWhatIfPractice()

        XCTAssertEqual(session.phase, .whatIf)
        XCTAssertEqual(session.currentVariation?.id, "berlin")
        XCTAssertEqual(session.lastMove?.san, "Bb5", "The board resumes from the branch point")
        XCTAssertTrue(session.isAwaitingOpponent)
        XCTAssertEqual(session.playOpponentMove()?.san, "Nf6")
        XCTAssertEqual(session.expectedUserMove?.san, "O-O")
        XCTAssertNil(session.highlightedSquares, "What-if practice does not give the answer away")
    }

    func testChoosingTheWrongVariationTriggersTheErrorState() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()
        session.playOpponentMove()
        let branchFen = session.fen

        // Black played 3...Nf6, not 3...a6. Retreating with Ba4 answers the wrong line.
        let result = session.submitMove(from: "b5", to: "a4")

        guard case .incorrect(let mistake) = result else { return XCTFail("Expected Ba4 to be rejected, got \(result)") }
        XCTAssertEqual(mistake.kind, .wrongMove)
        XCTAssertEqual(mistake.phase, .whatIf)
        XCTAssertEqual(mistake.variationId, "berlin")
        XCTAssertEqual(mistake.attempted, "Ba4")
        XCTAssertEqual(mistake.expected.san, "O-O")
        XCTAssertTrue(mistake.hint.hasPrefix("Calmly finish king safety."))
        XCTAssertEqual(session.feedback, .incorrect(mistake))
        XCTAssertEqual(session.fen, branchFen)
        XCTAssertEqual(session.phase, .whatIf)
        XCTAssertEqual(session.highlightedSquares?.from, "e1", "A mistake reveals the squares")
        XCTAssertEqual(session.highlightedSquares?.to, "g1")
        XCTAssertTrue(session.completedVariationIds.isEmpty)
    }

    func testRecoveringAfterAMistakeStillCompletesTheVariation() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.miniRuyLopez())
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()
        session.playOpponentMove()

        session.submitMove(from: "b5", to: "a4")
        let result = session.submitMove(from: "e1", to: "g1")

        guard case .correct(let move) = result else { return XCTFail("Expected castling to be accepted, got \(result)") }
        XCTAssertEqual(move.san, "O-O")
        XCTAssertEqual(session.feedback, .variationComplete(TutorialFixtures.miniRuyLopez().variations[0]))
        XCTAssertEqual(session.completedVariationIds, ["berlin"])
        XCTAssertEqual(session.mistakes.count, 1)
        XCTAssertFalse(session.hasMoreVariations)

        session.nextVariation()

        XCTAssertEqual(session.phase, .completed)
        XCTAssertEqual(session.feedback, .tutorialComplete)
    }

    func testEveryVariationCanBePlayedThrough() async throws {
        for opening in try TutorialFixtures.bundledOpenings() {
            var session = try OpeningTutorialSession(opening: opening)
            session.playToEndOfCurrentLine()
            session.startWhatIfPractice()
            while session.phase == .whatIf {
                session.playToEndOfCurrentLine()
                XCTAssertTrue(session.isCurrentLineComplete, "\(opening.id) \(session.currentVariation?.id ?? "")")
                session.nextVariation()
            }
            XCTAssertEqual(session.phase, .completed, opening.id)
            XCTAssertEqual(session.completedVariationIds, opening.variations.map(\.id), opening.id)
            XCTAssertTrue(session.mistakes.isEmpty, opening.id)
        }
    }

    func testRestartInWhatIfReplaysTheSameVariation() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()
        session.playOpponentMove()
        session.playExpectedMove()

        session.restart()

        XCTAssertEqual(session.currentVariation?.id, "berlin")
        XCTAssertEqual(session.cursor, 0)
        XCTAssertTrue(session.isAwaitingOpponent)
    }

    func testStartWhatIfIsIgnoredBeforeTheMainLineIsDone() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.startWhatIfPractice()
        XCTAssertEqual(session.phase, .mainLine)
    }
}
