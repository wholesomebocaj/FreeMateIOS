import XCTest
@testable import FreeMateIOS

@MainActor
final class BoardPieceLayoutTests: XCTestCase {
    private func position(_ fen: String) throws -> [String: String] {
        try ChessEngine.parsePieceMap(fen)
    }

    private func id(of square: String, in pieces: [PlacedPiece]) -> Int? {
        pieces.first { $0.square == square }?.id
    }

    func testAMoveKeepsThePieceIdentity() async throws {
        let start = BoardPieceLayout.initial(try position(ChessEngine.startingFen))
        let pawn = try XCTUnwrap(id(of: "e2", in: start))

        let after = BoardPieceLayout.reconcile(start, with: try position("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"), lastMove: ["e2", "e4"])

        XCTAssertEqual(id(of: "e4", in: after), pawn)
        XCTAssertEqual(after.count, 32)
        XCTAssertEqual(Set(after.map(\.id)), Set(start.map(\.id)))
    }

    func testACaptureRemovesOnlyTheCapturedPiece() async throws {
        let before = BoardPieceLayout.initial(try position("4k3/8/8/3q4/8/8/8/3R2K1 w - - 0 1"))
        let rook = try XCTUnwrap(id(of: "d1", in: before))
        let queen = try XCTUnwrap(id(of: "d5", in: before))

        let after = BoardPieceLayout.reconcile(before, with: try position("4k3/8/8/3R4/8/8/8/6K1 b - - 0 1"), lastMove: ["d1", "d5"])

        XCTAssertEqual(id(of: "d5", in: after), rook)
        XCTAssertFalse(after.contains { $0.id == queen })
        XCTAssertEqual(after.count, 3)
    }

    func testCastlingMovesKingAndRook() async throws {
        let before = BoardPieceLayout.initial(try position("4k3/8/8/8/8/8/8/4K2R w K - 0 1"))
        let king = try XCTUnwrap(id(of: "e1", in: before))
        let rook = try XCTUnwrap(id(of: "h1", in: before))

        let after = BoardPieceLayout.reconcile(before, with: try position("4k3/8/8/8/8/8/8/5RK1 b - - 1 1"), lastMove: ["e1", "g1"])

        XCTAssertEqual(id(of: "g1", in: after), king)
        XCTAssertEqual(id(of: "f1", in: after), rook)
    }

    func testPromotionKeepsThePawnIdentity() async throws {
        let before = BoardPieceLayout.initial(try position("8/P7/8/8/8/8/8/k1K5 w - - 0 1"))
        let pawn = try XCTUnwrap(id(of: "a7", in: before))

        let after = BoardPieceLayout.reconcile(before, with: try position("Q7/8/8/8/8/8/8/k1K5 b - - 0 1"), lastMove: ["a7", "a8"])

        XCTAssertEqual(id(of: "a8", in: after), pawn)
        XCTAssertEqual(after.first { $0.id == pawn }?.code, "wQ")
    }

    func testJumpingToAnotherPositionReusesNearbyPieces() async throws {
        let before = BoardPieceLayout.initial(try position("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1"))
        let pawn = try XCTUnwrap(id(of: "e2", in: before))

        let after = BoardPieceLayout.reconcile(before, with: try position("4k3/8/8/8/4P3/8/8/4K3 w - - 0 1"))

        XCTAssertEqual(id(of: "e4", in: after), pawn)
        XCTAssertEqual(after.map(\.id).sorted(), before.map(\.id).sorted())
    }

    func testANewPieceGetsAFreshIdentity() async throws {
        let before = BoardPieceLayout.initial(try position("4k3/8/8/8/8/8/8/4K3 w - - 0 1"))

        let after = BoardPieceLayout.reconcile(before, with: try position("4k3/8/8/8/8/8/3N4/4K3 w - - 0 1"))

        let knight = try XCTUnwrap(after.first { $0.code == "wN" })
        XCTAssertFalse(before.contains { $0.id == knight.id })
    }
}
