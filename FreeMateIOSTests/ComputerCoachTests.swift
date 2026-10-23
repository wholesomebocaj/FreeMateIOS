import XCTest
@testable import FreeMateIOS

final class ComputerCoachTests: XCTestCase {
    /// Plays SAN moves from the start and returns every position and the moves in UCI.
    private func game(_ sans: [String]) throws -> (positions: [String], moves: [String]) {
        let engine = try ChessEngine(fen: ChessEngine.startingFen)
        var positions = [engine.fen()]
        var moves: [String] = []
        for san in sans {
            let move = try XCTUnwrap(engine.legalMoves().first { $0.san == san }, "No legal \(san)")
            engine.move(from: move.from, to: move.to, promotion: move.promotion)
            positions.append(engine.fen())
            moves.append(move.uci)
        }
        return (positions, moves)
    }

    func testWarnsWhenTheQueenTakesADefendedPawn() throws {
        let warning = try XCTUnwrap(ComputerCoach.warning(fen: "4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1", move: "d1d5"))

        XCTAssertEqual(warning.kind, .losesPiece(.queen, on: "d5"))
        XCTAssertEqual(warning.square, "d5")
        XCTAssertNotEqual(warning.betterMove, "d1d5")
        XCTAssertEqual(warning.message, "After this move, the computer can win your queen on d5.")
    }

    func testNoWarningForASafeMove() {
        XCTAssertNil(ComputerCoach.warning(fen: "4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1", move: "d1d2"))
        XCTAssertNil(ComputerCoach.warning(fen: ChessEngine.startingFen, move: "e2e4"))
    }

    func testNoWarningForMissingAFreePiece() {
        // Ignoring the hanging queen is a missed chance, not a loss, so it is not a blunder.
        XCTAssertNil(ComputerCoach.warning(fen: "4k3/8/8/3q4/8/2N5/1K6/8 w - - 0 1", move: "b2c2"))
    }

    func testWarnsWhenTheMoveAllowsMate() throws {
        // Black to move after 1.e4 e5 2.Qh5 Nc6 3.Bc4. ...Nf6 allows Qxf7#.
        let played = try game(["e4", "e5", "Qh5", "Nc6", "Bc4"])
        let warning = try XCTUnwrap(ComputerCoach.warning(fen: played.positions.last!, move: "g8f6"))

        XCTAssertEqual(warning.kind, .allowsMate)
        XCTAssertEqual(warning.message, "This move lets the computer checkmate you.")
    }

    func testBestMoveTakesTheQueenAndFindsMate() {
        XCTAssertEqual(ComputerCoach.bestMove(fen: "4k3/8/8/3q4/8/2N5/8/4K3 w - - 0 1"), "c3d5")
        XCTAssertEqual(ComputerCoach.bestMove(fen: "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1"), "a1a8")
        XCTAssertNil(ComputerCoach.bestMove(fen: "7k/6Q1/6K1/8/8/8/8/8 b - - 0 1"))
    }

    func testReviewFlagsTheMoveThatAllowedScholarsMate() throws {
        let played = try game(["e4", "e5", "Qh5", "Nc6", "Bc4", "Nf6", "Qxf7#"])
        let review = try XCTUnwrap(ComputerCoach.review(ply: 5, positions: played.positions, moves: played.moves))

        XCTAssertEqual(review.san, "Nf6")
        XCTAssertEqual(review.numberedSAN, "3... Nf6")
        XCTAssertEqual(review.quality, .blunder)
        XCTAssertEqual(review.reason, .allowedMate)
        XCTAssertNotNil(review.betterSAN)
        XCTAssertEqual(review.explanation, "This allowed checkmate. \(review.betterSAN!) would have stopped it.")
    }

    func testReviewPraisesAGoodOpeningMove() throws {
        let played = try game(["e4", "e5"])
        let review = try XCTUnwrap(ComputerCoach.review(ply: 0, positions: played.positions, moves: played.moves))

        XCTAssertEqual(review.numberedSAN, "1. e4")
        XCTAssertLessThanOrEqual(review.quality, .good)
        XCTAssertNil(review.explanation)
    }

    func testReviewExplainsAMissedCapture() throws {
        let fen = "4k3/8/8/3q4/8/2N5/1K6/8 w - - 0 1"
        let review = try XCTUnwrap(ComputerCoach.review(ply: 0, positions: [fen, fen], moves: ["b2c2"]))

        XCTAssertEqual(review.quality, .blunder)
        XCTAssertEqual(review.reason, .missedCapture(.queen, on: "d5"))
        XCTAssertEqual(review.explanation, "Nxd5 would have won the queen on d5.")
    }

    func testReviewExplainsAHungPiece() throws {
        let fen = "4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1"
        let review = try XCTUnwrap(ComputerCoach.review(ply: 0, positions: [fen, fen], moves: ["d1d5"]))

        XCTAssertEqual(review.quality, .blunder)
        XCTAssertEqual(review.reason, .hung(.queen, on: "d5"))
    }

    func testBeginnerStillTakesAFreeQueen() {
        for seed in UInt64(1)...12 {
            var generator = SeededGenerator(state: seed)
            XCTAssertEqual(
                ComputerOpponent.chooseMove(fen: "4k3/8/8/3q4/8/2N5/8/4K3 w - - 0 1", level: .beginner, using: &generator),
                "c3d5"
            )
        }
    }

    func testBeginnerVariesMoreThanFair() {
        func distinctOpenings(_ level: ComputerLevel) -> Int {
            Set((UInt64(1)...30).map { seed -> String? in
                var generator = SeededGenerator(state: seed)
                return ComputerOpponent.chooseMove(fen: ChessEngine.startingFen, level: level, using: &generator)
            }).count
        }

        XCTAssertGreaterThan(distinctOpenings(.beginner), distinctOpenings(.fair))
    }

    func testAnalysisIsQuickEnoughForEveryMove() {
        let start = Date()
        _ = ComputerCoach.warning(fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", move: "f3g5")
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }
}

/// SplitMix64, so random moves repeat from run to run.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
