import XCTest
@testable import FreeMateIOS

@MainActor
final class MoveListFormatterTests: XCTestCase {
    func testPairsMovesFromTheStart() async {
        let rows = MoveListFormatter.rows(["e4", "e5", "Nf3"], startingFen: ChessEngine.startingFen)

        XCTAssertEqual(rows, ["1. e4 e5", "2. Nf3"])
    }

    func testBlackToMoveStartsWithDots() async {
        let rows = MoveListFormatter.rows(["Nc6", "Bb5", "a6"], startingFen: "r1bqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2")

        XCTAssertEqual(rows, ["2... Nc6", "3. Bb5 a6"])
    }

    func testNoMoves() async {
        XCTAssertEqual(MoveListFormatter.rows([], startingFen: ChessEngine.startingFen), [])
    }
}
