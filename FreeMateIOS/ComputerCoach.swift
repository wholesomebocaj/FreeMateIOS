import Foundation

/// Judges the learner's moves for the blunder warning, the hint, and the post-game review.
///
/// It scores every legal move by the opponent's best reply, then plays out captures until the
/// position is quiet. That is a little stronger than Fair and sees hanging pieces, bad trades,
/// and mate in one, which are the mistakes beginners make most.
nonisolated enum ComputerCoach {
    static let mateScore = 100_000
    /// A move that loses this much more than the best move is a blunder: about a minor piece.
    static let blunderThreshold = 250
    /// A move that loses this much more than the best move is a mistake: about a pawn.
    static let mistakeThreshold = 90

    struct ScoredMove: Sendable {
        var uci: String
        /// Centipawns from the mover's side after the opponent's best reply.
        var score: Int
    }

    /// Every legal move, best first.
    static func scoreMoves(fen: String) -> [ScoredMove] {
        guard let engine = try? ChessEngine(fen: fen) else { return [] }
        return scoreMoves(engine)
    }

    /// The best move in UCI, for the hint.
    static func bestMove(fen: String) -> String? {
        scoreMoves(fen: fen).first?.uci
    }

    /// A warning when `uci` from `fen` hangs material or allows mate and a safer move exists.
    static func warning(fen: String, move uci: String) -> MoveWarning? {
        guard let engine = try? ChessEngine(fen: fen) else { return nil }
        let scored = scoreMoves(engine)
        guard let best = scored.first, let played = scored.first(where: { $0.uci == uci }) else { return nil }
        let threat = threat(after: uci, in: engine)
        if played.score <= -mateScore / 2 && best.score > -mateScore / 2 {
            return MoveWarning(kind: .allowsMate, betterMove: best.uci)
        }
        // Only warn when the move loses what the learner has now, not when it misses a chance
        // to win something.
        guard best.score - played.score >= blunderThreshold, played.score <= relativeEvaluation(engine) - blunderThreshold else {
            return nil
        }
        return MoveWarning(kind: threat.map { .losesPiece($0.piece, on: $0.square) } ?? .losesMaterial, betterMove: best.uci)
    }

    /// Grades each of the learner's moves in a finished game.
    ///
    /// - Parameters:
    ///   - positions: the start, then one FEN per move.
    ///   - moves: the moves in UCI, one per position after the first.
    static func review(ply: Int, positions: [String], moves: [String]) -> ReviewedMove? {
        guard ply < moves.count, let engine = try? ChessEngine(fen: positions[ply]) else { return nil }
        let scored = scoreMoves(engine)
        let uci = moves[ply]
        guard let best = scored.first, let played = scored.first(where: { $0.uci == uci }) else { return nil }
        let allowsMate = played.score <= -mateScore / 2 && best.score > -mateScore / 2
        let loss = best.score - played.score
        let quality: ReviewedMove.Quality
        if allowsMate || loss >= blunderThreshold {
            quality = .blunder
        } else if loss >= mistakeThreshold {
            quality = .mistake
        } else if loss <= 10 {
            quality = .best
        } else {
            quality = .good
        }
        let threat = threat(after: uci, in: engine)
        var reason: ReviewedMove.Reason?
        if allowsMate {
            reason = .allowedMate
        } else if quality >= .mistake, let threat, played.score < relativeEvaluation(engine) {
            reason = .hung(threat.piece, on: threat.square)
        } else if quality >= .mistake, let capture = capture(best.uci, in: engine) {
            reason = .missedCapture(capture.piece, on: capture.square)
        }
        return ReviewedMove(
            ply: ply,
            san: san(uci, in: engine),
            quality: quality,
            betterMove: quality >= .mistake ? best.uci : nil,
            betterSAN: quality >= .mistake ? san(best.uci, in: engine) : nil,
            reason: reason
        )
    }

    // MARK: - Search

    private static func scoreMoves(_ engine: ChessEngine) -> [ScoredMove] {
        ComputerOpponent.ordered(engine.searchMoves())
            .map { move in
                ScoredMove(uci: move.uci, score: -negamax(engine.playing(move), depth: 1, alpha: -.max, beta: .max))
            }
            .enumerated()
            .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
            .map(\.element)
    }

    private static func negamax(_ engine: ChessEngine, depth: Int, alpha: Int, beta: Int) -> Int {
        let moves = engine.searchMoves()
        if moves.isEmpty { return engine.isCheck() ? -(mateScore + depth) : 0 }
        if engine.isDrawByFiftyMoves() || engine.isInsufficientMaterial() { return 0 }
        if depth == 0 { return quiesce(engine, moves: moves, alpha: alpha, beta: beta, depth: 4) }
        var alpha = alpha
        var best = -Int.max
        for move in ComputerOpponent.ordered(moves) {
            let score = -negamax(engine.playing(move), depth: depth - 1, alpha: -beta, beta: -alpha)
            best = max(best, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }
        }
        return best
    }

    /// Plays out captures so a score never stops halfway through a trade. The side to move may
    /// also stop capturing, so the score is at least the position as it stands.
    private static func quiesce(_ engine: ChessEngine, moves: [SearchMove], alpha: Int, beta: Int, depth: Int) -> Int {
        let standPat = relativeEvaluation(engine)
        if standPat >= beta || depth == 0 { return standPat }
        var alpha = max(alpha, standPat)
        for move in ComputerOpponent.ordered(moves.filter { $0.captured != nil }) {
            let next = engine.playing(move)
            let score = -quiesce(next, moves: next.searchMoves(), alpha: -beta, beta: -alpha, depth: depth - 1)
            if score >= beta { return score }
            alpha = max(alpha, score)
        }
        return alpha
    }

    private static func relativeEvaluation(_ engine: ChessEngine) -> Int {
        let score = ComputerOpponent.evaluate(engine)
        return engine.sideToMove == .white ? score : -score
    }

    // MARK: - Explaining

    /// The opponent's best capture after `uci`, if it wins material.
    private static func threat(after uci: String, in engine: ChessEngine) -> (piece: PieceKind, square: String)? {
        guard let move = engine.searchMoves().first(where: { $0.uci == uci }) else { return nil }
        let next = engine.playing(move)
        let before = relativeEvaluation(next)
        var best: (piece: PieceKind, square: String, gain: Int)?
        for capture in next.searchMoves() where capture.captured != nil {
            let after = next.playing(capture)
            let gain = -quiesce(after, moves: after.searchMoves(), alpha: -.max, beta: .max, depth: 4) - before
            if gain >= 80, gain > (best?.gain ?? 0), let captured = capture.captured {
                best = (captured, String(capture.uci.dropFirst(2).prefix(2)), gain)
            }
        }
        return best.map { ($0.piece, $0.square) }
    }

    private static func capture(_ uci: String, in engine: ChessEngine) -> (piece: PieceKind, square: String)? {
        guard let move = engine.searchMoves().first(where: { $0.uci == uci }), let captured = move.captured else { return nil }
        return (captured, String(uci.dropFirst(2).prefix(2)))
    }

    static func san(_ uci: String, in engine: ChessEngine) -> String {
        let from = String(uci.prefix(2))
        let to = String(uci.dropFirst(2).prefix(2))
        let promotion = uci.count > 4 ? String(uci.suffix(1)) : nil
        return engine.legalMoves(from: from).first { $0.to == to && $0.promotion == promotion }?.san ?? uci
    }
}

extension PieceKind {
    /// "queen", for sentences.
    nonisolated var name: String { rawValue }
}

/// Why the learner's move is risky, shown before the computer replies.
nonisolated struct MoveWarning: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case losesPiece(PieceKind, on: String)
        case losesMaterial
        case allowsMate
    }

    var kind: Kind
    /// A safer move in UCI.
    var betterMove: String

    var message: String {
        switch kind {
        case .losesPiece(let piece, let square):
            return "After this move, the computer can win your \(piece.name) on \(square)."
        case .losesMaterial:
            return "This move lets the computer win material."
        case .allowsMate:
            return "This move lets the computer checkmate you."
        }
    }

    /// The square to mark as under attack.
    var square: String? {
        if case .losesPiece(_, let square) = kind { return square }
        return nil
    }
}

/// One of the learner's moves, graded after the game.
nonisolated struct ReviewedMove: Equatable, Sendable, Identifiable {
    enum Quality: Int, Comparable, Sendable {
        case best, good, mistake, blunder

        static func < (lhs: Quality, rhs: Quality) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String {
            switch self {
            case .best: return "Best"
            case .good: return "Good"
            case .mistake: return "Mistake"
            case .blunder: return "Blunder"
            }
        }
    }

    enum Reason: Equatable, Sendable {
        case hung(PieceKind, on: String)
        case missedCapture(PieceKind, on: String)
        case allowedMate
    }

    /// The move's index in the game, from 0.
    var ply: Int
    var san: String
    var quality: Quality
    var betterMove: String?
    var betterSAN: String?
    var reason: Reason?

    var id: Int { ply }

    /// The move as it appears in a score sheet: "12. Qxd5" or "12... Nf6".
    var numberedSAN: String {
        "\(ply / 2 + 1)\(ply % 2 == 0 ? "." : "...") \(san)"
    }

    var explanation: String? {
        guard let betterSAN else { return nil }
        switch reason {
        case .hung(let piece, let square):
            return "This left your \(piece.name) on \(square) to be taken. \(betterSAN) was safer."
        case .missedCapture(let piece, let square):
            return "\(betterSAN) would have won the \(piece.name) on \(square)."
        case .allowedMate:
            return "This allowed checkmate. \(betterSAN) would have stopped it."
        case nil:
            return "\(betterSAN) was stronger."
        }
    }
}
