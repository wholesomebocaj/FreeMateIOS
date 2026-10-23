import XCTest
@testable import FreeMateIOS

@MainActor
final class ChessEngineTests: XCTestCase {
    func testFenWithAvailableEnPassantCapture() async throws {
        let engine = try ChessEngine(fen: "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3")

        XCTAssertEqual(engine.fen(), "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3")
        XCTAssertTrue(engine.legalMoves(from: "e5").contains { $0.san == "exf6" })
    }

    func testLegalMovesWhenTheOpponentCouldAllowEnPassant() async throws {
        // Berlin Defense after 7.dxe5. Black's ...f5 would let the e5 pawn capture en passant.
        let engine = try ChessEngine(fen: "r1bqkb1r/ppp2ppp/2pn4/4P3/8/5N2/PPP2PPP/RNBQ1RK1 b kq - 0 7")

        XCTAssertTrue(engine.legalMoves().contains { $0.san == "Nf5" })
        XCTAssertEqual(engine.move(from: "f7", to: "f5")?.san, "f5")
        XCTAssertEqual(engine.fen(), "r1bqkb1r/ppp3pp/2pn4/4Pp2/8/5N2/PPP2PPP/RNBQ1RK1 w kq f6 0 8")
        XCTAssertEqual(engine.move(from: "e5", to: "f6")?.san, "exf6")
        XCTAssertNil(engine.piece(at: "f5"))
    }
}
