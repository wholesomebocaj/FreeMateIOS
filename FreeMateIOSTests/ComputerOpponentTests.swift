import XCTest
@testable import FreeMateIOS

/// A repeatable stand-in for the system generator, so noisy moves are the same every run.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class ComputerOpponentTests: XCTestCase {
    private func moves(_ fen: String, _ level: ComputerLevel, seeds: ClosedRange<UInt64> = 1...12) -> Set<String?> {
        Set(seeds.map { seed in
            var generator = SplitMix64(state: seed)
            return ComputerOpponent.chooseMove(fen: fen, level: level, using: &generator)
        })
    }

    func testStartingPositionIsLevel() throws {
        XCTAssertEqual(ComputerOpponent.evaluate(try ChessEngine(fen: ChessEngine.startingFen)), 0)
    }

    func testEvaluationFavorsTheSideWithMoreMaterial() throws {
        let whiteUpAQueen = try ChessEngine(fen: "4k3/8/8/8/8/8/8/3QK3 w - - 0 1")
        let blackUpAQueen = try ChessEngine(fen: "3qk3/8/8/8/8/8/8/4K3 w - - 0 1")

        XCTAssertGreaterThan(ComputerOpponent.evaluate(whiteUpAQueen), 800)
        XCTAssertEqual(ComputerOpponent.evaluate(whiteUpAQueen), -ComputerOpponent.evaluate(blackUpAQueen))
    }

    func testBothLevelsTakeAHangingQueen() {
        let fen = "4k3/8/8/3q4/8/2N5/8/4K3 w - - 0 1"

        XCTAssertEqual(moves(fen, .easy), ["c3d5"])
        XCTAssertEqual(moves(fen, .fair), ["c3d5"])
    }

    func testBothLevelsFindABackRankMate() {
        let fen = "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1"

        XCTAssertEqual(moves(fen, .easy), ["a1a8"])
        XCTAssertEqual(moves(fen, .fair), ["a1a8"])
    }

    func testFairSeesTheRecaptureThatEasyMisses() {
        // Qxd5 wins a pawn, but c6xd5 takes the queen back.
        let fen = "4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1"

        XCTAssertTrue(moves(fen, .easy).contains("d1d5"))
        XCTAssertFalse(moves(fen, .fair).contains("d1d5"))
    }

    func testBlackPlaysForBlack() {
        // The black knight can take an undefended white queen.
        let fen = "4k3/8/2n5/8/3Q4/8/8/4K3 b - - 0 1"

        XCTAssertEqual(moves(fen, .fair), ["c6d4"])
    }

    func testPromotesToAQueen() {
        XCTAssertEqual(moves("8/P7/8/8/8/8/8/k6K w - - 0 1", .fair), ["a7a8q"])
    }

    func testNoMoveWhenTheGameIsOver() {
        XCTAssertEqual(moves("7k/6Q1/6K1/8/8/8/8/8 b - - 0 1", .fair), [nil])
        XCTAssertNil(ComputerOpponent.chooseMove(fen: "not a fen", level: .easy))
    }

    func testFairRepliesQuicklyFromTheStart() {
        let start = Date()
        XCTAssertNotNil(ComputerOpponent.chooseMove(fen: ChessEngine.startingFen, level: .fair))
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testCheckmateResultDependsOnTheLearnersSide() {
        let blackIsMated = ["7k/6Q1/6K1/8/8/8/8/8 b - - 0 1"]

        XCTAssertEqual(ComputerGameResult.of(positions: blackIsMated, learner: .white), .won)
        XCTAssertEqual(ComputerGameResult.of(positions: blackIsMated, learner: .black), .lost)
    }

    func testDrawResults() {
        XCTAssertEqual(ComputerGameResult.of(positions: ["7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"], learner: .white), .drawn(.stalemate))
        XCTAssertEqual(ComputerGameResult.of(positions: ["7k/8/6K1/8/8/8/8/8 w - - 0 1"], learner: .white), .drawn(.insufficientMaterial))
        XCTAssertEqual(ComputerGameResult.of(positions: ["7k/8/6K1/8/8/8/8/R7 w - - 100 80"], learner: .white), .drawn(.fiftyMoves))
    }

    func testThreefoldRepetitionIsADraw() {
        let a = "4k3/8/8/8/8/8/8/R3K3 w - - 0 1"
        let b = "4k3/8/8/8/8/8/8/R2K4 b - - 1 1"
        let c = "3k4/8/8/8/8/8/8/R2K4 w - - 2 2"
        let d = "3k4/8/8/8/8/8/8/R3K3 b - - 3 2"
        let twice = [a, b, c, d, a, b, c, d]

        XCTAssertNil(ComputerGameResult.of(positions: twice, learner: .white))
        XCTAssertEqual(ComputerGameResult.of(positions: twice + [a], learner: .white), .drawn(.repetition))
    }

    func testGameInProgressHasNoResult() {
        XCTAssertNil(ComputerGameResult.of(positions: [ChessEngine.startingFen], learner: .white))
    }

    func testRecordCountsResignationAsALoss() {
        var record = ComputerGameRecord()
        record.add(.won)
        record.add(.resigned)
        record.add(.drawn(.stalemate))

        XCTAssertEqual(record, ComputerGameRecord(wins: 1, draws: 1, losses: 1))
        XCTAssertEqual(record.played, 3)
    }
}
