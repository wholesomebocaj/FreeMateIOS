import Foundation

/// A piece with a stable identity, so the board can slide it between squares instead of
/// redrawing it in place.
struct PlacedPiece: Identifiable, Hashable {
    let id: Int
    /// Board notation such as "wN" or "bP".
    var code: String
    var square: String

    var isWhite: Bool { code.hasPrefix("w") }
}

enum BoardPieceLayout {
    static func initial(_ position: [String: String]) -> [PlacedPiece] {
        position.keys.sorted().enumerated().map { index, square in
            PlacedPiece(id: index, code: position[square] ?? "", square: square)
        }
    }

    /// Carries identities from `previous` into `position`.
    ///
    /// Pieces that stayed put keep their identity. A piece that appears on a new square takes
    /// the identity of the piece that left `lastMove`'s origin (covering promotion), otherwise
    /// the nearest vanished piece of the same kind. Whatever is left over was captured.
    static func reconcile(_ previous: [PlacedPiece], with position: [String: String], lastMove: [String] = []) -> [PlacedPiece] {
        var vanished = previous
        var kept: [PlacedPiece] = []
        var arrivals: [(square: String, code: String)] = []

        for square in position.keys.sorted() {
            let code = position[square] ?? ""
            if let index = vanished.firstIndex(where: { $0.square == square && $0.code == code }) {
                kept.append(vanished.remove(at: index))
            } else {
                arrivals.append((square, code))
            }
        }

        let moveFrom = lastMove.count == 2 ? lastMove[0] : nil
        let moveTo = lastMove.count == 2 ? lastMove[1] : nil
        var nextID = (previous.map(\.id).max() ?? -1) + 1
        let ordered = arrivals.sorted {
            ($0.square == moveTo ? 0 : 1, $0.square) < ($1.square == moveTo ? 0 : 1, $1.square)
        }

        for arrival in ordered {
            let fromLastMove = arrival.square == moveTo
                ? vanished.firstIndex { $0.square == moveFrom && $0.isWhite == arrival.code.hasPrefix("w") }
                : nil
            let sameKind = vanished.indices
                .filter { vanished[$0].code == arrival.code }
                .min { distance(vanished[$0].square, arrival.square) < distance(vanished[$1].square, arrival.square) }
            if let index = fromLastMove ?? sameKind {
                var piece = vanished.remove(at: index)
                piece.square = arrival.square
                piece.code = arrival.code
                kept.append(piece)
            } else {
                kept.append(PlacedPiece(id: nextID, code: arrival.code, square: arrival.square))
                nextID += 1
            }
        }
        return kept.sorted { $0.id < $1.id }
    }

    static func distance(_ lhs: String, _ rhs: String) -> Int {
        guard let a = coordinates(lhs), let b = coordinates(rhs) else { return .max }
        return max(abs(a.file - b.file), abs(a.rank - b.rank))
    }

    static func coordinates(_ square: String) -> (file: Int, rank: Int)? {
        let chars = Array(square)
        guard chars.count == 2,
              let file = "abcdefgh".firstIndex(of: chars[0]).map({ "abcdefgh".distance(from: "abcdefgh".startIndex, to: $0) }),
              let rank = Int(String(chars[1])), (1...8).contains(rank) else { return nil }
        return (file, rank - 1)
    }
}
