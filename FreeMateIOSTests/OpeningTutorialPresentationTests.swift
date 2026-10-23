import XCTest
@testable import FreeMateIOS

@MainActor
final class OpeningTutorialPresentationTests: XCTestCase {
    func testMainLineCardNamesTheMove() async throws {
        let session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))

        XCTAssertEqual(session.card.style, .guide)
        XCTAssertEqual(session.card.title, "Play 1. e4")
        XCTAssertEqual(session.card.message, "Claim the center")
        XCTAssertNil(session.card.action)
        XCTAssertEqual(session.progressSummary, TutorialProgressSummary(title: "Main Line", detail: "0 of 9 moves", fraction: 0, caption: "C92 · Ruy Lopez: Closed"))
    }

    func testMistakeTurnsTheCardIntoAGentleHint() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.submitMove(from: "d2", to: "d4")

        XCTAssertEqual(session.card.style, .hint)
        XCTAssertEqual(session.card.eyebrow, "Not quite")
        XCTAssertEqual(session.card.title, "Try 1. e4")
        XCTAssertTrue(session.card.message.contains("from e2 to e4"))
        XCTAssertEqual(session.card.sceneID, "main", "A mistake updates the card in place instead of sliding a new one in")
    }

    func testFinishingTheMainLineOffersToBranchOut() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.playToEndOfCurrentLine()

        XCTAssertEqual(session.card.sceneID, "main-complete")
        XCTAssertEqual(session.card.action, .startBranching)
        XCTAssertEqual(session.card.actionTitle, "Branch Out")
        XCTAssertEqual(session.progressSummary.fraction, 1)
    }

    func testBranchingCardAsksWhatIf() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()

        XCTAssertEqual(session.card.sceneID, "branch-berlin")
        XCTAssertEqual(session.card.title, "What if Black tries something else?")

        session.playOpponentMove()

        XCTAssertEqual(session.card.style, .branching)
        XCTAssertEqual(session.card.title, "What if Black plays 3... Nf6 instead?")
        XCTAssertEqual(session.card.message, "Try to respond.")
        XCTAssertTrue(session.card.showsHintButton)
        XCTAssertEqual(session.card.sceneID, "branch-berlin")
        XCTAssertEqual(session.progressSummary.title, "Branching Variations")
        XCTAssertEqual(session.progressSummary.detail, "1 of 6")
        XCTAssertEqual(session.progressSummary.caption, "C65 · Berlin Defense")
        XCTAssertEqual(session.card.eyebrow, "Branching out")
    }

    func testHintButtonRevealsTheAnswer() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.opening("ruy-lopez"))
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()
        session.playOpponentMove()

        session.revealHint()

        XCTAssertFalse(session.card.showsHintButton)
        XCTAssertEqual(session.card.detail, "Calmly finish king safety. e4 can wait. Move the king from e1 to g1.")
        XCTAssertEqual(session.highlightedSquares?.to, "g1")
    }

    func testVariationCompleteCardMovesOn() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.miniRuyLopez())
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()
        session.playToEndOfCurrentLine()

        XCTAssertEqual(session.card.style, .success)
        XCTAssertEqual(session.card.title, "You handled the Berlin Defense")
        XCTAssertEqual(session.card.action, .finish)
        XCTAssertEqual(session.card.actionTitle, "Finish Tutorial")
    }

    func testCompletionStatsCountAccuracy() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.miniRuyLopez())
        session.submitMove(from: "d2", to: "d4")
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()
        session.playToEndOfCurrentLine()
        session.nextVariation()

        XCTAssertEqual(session.phase, .completed)
        // Five correct moves (e4, Nf3, Bb5, Ba4, O-O) and one mistake.
        XCTAssertEqual(session.completionStats, TutorialCompletionStats(mainLineMoves: 4, variations: 1, mistakes: 1, accuracy: 83))
    }

    func testMasteryStatusFromSavedProgress() async throws {
        let opening = try TutorialFixtures.opening("ruy-lopez")
        var progress = OpeningTutorialProgress()
        XCTAssertEqual(progress.status(for: opening), .notStarted)

        progress.bestPercent = 20
        XCTAssertEqual(progress.status(for: opening), .inProgress(percent: 20))

        progress.mainLineCompleted = true
        progress.completedVariationIds = ["berlin", "classical"]
        XCTAssertEqual(progress.status(for: opening), .inProgress(percent: 73))

        progress.completedVariationIds = Set(opening.variations.map(\.id))
        XCTAssertEqual(progress.status(for: opening), .mastered)
        XCTAssertEqual(TutorialMasteryStatus.mastered.label, "Mastered")
    }

    func testPreviewShowsTheSignaturePosition() async throws {
        let tutorials = try OpeningTutorialLibrary.decode(Data(contentsOf: TutorialFixtures.catalogURL))
        let ruy = try XCTUnwrap(tutorials.first { $0.id == "ruy-lopez" })

        XCTAssertEqual(ruy.previewFen, "r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3")
    }

    func testRestartTutorialGoesBackToTheFirstMove() async throws {
        var session = try OpeningTutorialSession(opening: TutorialFixtures.miniRuyLopez())
        session.submitMove(from: "d2", to: "d4")
        session.playToEndOfCurrentLine()
        session.startWhatIfPractice()

        session.restartTutorial()

        XCTAssertEqual(session.phase, .mainLine)
        XCTAssertEqual(session.fen, ChessEngine.startingFen)
        XCTAssertTrue(session.mistakes.isEmpty)
        XCTAssertEqual(session.expectedUserMove?.san, "e4")
    }
}
