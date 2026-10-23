import Foundation

// Native port of the beginner computer in web/engine.js (`evaluate` and `chooseComputerMove`).

nonisolated enum ComputerLevel: String, CaseIterable, Identifiable, Sendable {
    case easy
    case fair

    var id: String { rawValue }
    var label: String { self == .easy ? "Easy" : "Fair" }

    var summary: String {
        self == .easy ? "Misses some tactics." : "Looks one move deeper."
    }

    /// How many half-moves the search looks ahead.
    var depth: Int { self == .easy ? 1 : 2 }
    /// The spread of random centipawns added to each root move, so games vary.
    var noise: Double { self == .easy ? 160 : 35 }
}

nonisolated enum ComputerOpponent {
    /// The computer's move in UCI, or nil when the game is over or the FEN is invalid.
    static func chooseMove(fen: String, level: ComputerLevel) -> String? {
        var generator = SystemRandomNumberGenerator()
        return chooseMove(fen: fen, level: level, using: &generator)
    }

    static func chooseMove(fen: String, level: ComputerLevel, using generator: inout some RandomNumberGenerator) -> String? {
        guard let engine = try? ChessEngine(fen: fen) else { return nil }
        var best: SearchMove?
        var bestScore = -Double.infinity
        for move in ordered(engine.searchMoves()) {
            let reply = -negamax(engine.playing(move), depth: level.depth - 1, alpha: -.infinity, beta: .infinity)
            let score = reply + Double.random(in: 0..<1, using: &generator) * level.noise - level.noise / 2
            if score > bestScore {
                bestScore = score
                best = move
            }
        }
        return best?.uci
    }

    /// Material plus piece-square bonuses in centipawns, from White's side.
    static func evaluate(_ engine: ChessEngine) -> Int {
        var score = 0
        for (index, piece) in engine.squares.enumerated() {
            guard let piece else { continue }
            let rank = ChessSquare.rank(index)
            let file = ChessSquare.file(index)
            let mirrored = piece.color == .white ? index : (7 - rank) * 8 + file
            let value = value(of: piece.kind) + table(for: piece.kind)[mirrored]
            score += piece.color == .white ? value : -value
        }
        return score
    }

    private static func negamax(_ engine: ChessEngine, depth: Int, alpha: Double, beta: Double) -> Double {
        let moves = engine.searchMoves()
        if moves.isEmpty { return engine.isCheck() ? Double(-100_000 - depth) : 0 }
        if engine.isDrawByFiftyMoves() || engine.isInsufficientMaterial() { return 0 }
        if depth == 0 {
            let score = Double(evaluate(engine))
            return engine.sideToMove == .white ? score : -score
        }
        var alpha = alpha
        var best = -Double.infinity
        for move in ordered(moves) {
            let score = -negamax(engine.playing(move), depth: depth - 1, alpha: -beta, beta: -alpha)
            best = max(best, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }
        }
        return best
    }

    /// Captures first, best trade first, so alpha-beta cuts more.
    private static func ordered(_ moves: [SearchMove]) -> [SearchMove] {
        func priority(_ move: SearchMove) -> Int {
            guard let captured = move.captured else { return 0 }
            return value(of: captured) * 10 - value(of: move.piece)
        }
        return moves.enumerated()
            .sorted { lhs, rhs in
                let left = priority(lhs.element)
                let right = priority(rhs.element)
                return left != right ? left > right : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func value(of kind: PieceKind) -> Int {
        switch kind {
        case .pawn: return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook: return 500
        case .queen: return 900
        case .king: return 0
        }
    }

    private static func table(for kind: PieceKind) -> [Int] {
        switch kind {
        case .pawn: return pawnTable
        case .knight: return knightTable
        case .bishop: return bishopTable
        case .rook: return rookTable
        case .queen: return queenTable
        case .king: return kingTable
        }
    }

    // Each table starts at a1 from White's side. Black reads it mirrored.
    private static let pawnTable = [
        0, 0, 0, 0, 0, 0, 0, 0,
        5, 10, 10, -20, -20, 10, 10, 5,
        5, -5, -10, 0, 0, -10, -5, 5,
        0, 0, 0, 20, 20, 0, 0, 0,
        5, 5, 10, 25, 25, 10, 5, 5,
        10, 10, 20, 30, 30, 20, 10, 10,
        50, 50, 50, 50, 50, 50, 50, 50,
        0, 0, 0, 0, 0, 0, 0, 0,
    ]

    private static let knightTable = [
        -50, -40, -30, -30, -30, -30, -40, -50,
        -40, -20, 0, 0, 0, 0, -20, -40,
        -30, 0, 10, 15, 15, 10, 0, -30,
        -30, 5, 15, 20, 20, 15, 5, -30,
        -30, 0, 15, 20, 20, 15, 0, -30,
        -30, 5, 10, 15, 15, 10, 5, -30,
        -40, -20, 0, 5, 5, 0, -20, -40,
        -50, -40, -30, -30, -30, -30, -40, -50,
    ]

    private static let bishopTable = [
        -20, -10, -10, -10, -10, -10, -10, -20,
        -10, 0, 0, 0, 0, 0, 0, -10,
        -10, 0, 5, 10, 10, 5, 0, -10,
        -10, 5, 5, 10, 10, 5, 5, -10,
        -10, 0, 10, 10, 10, 10, 0, -10,
        -10, 10, 10, 10, 10, 10, 10, -10,
        -10, 5, 0, 0, 0, 0, 5, -10,
        -20, -10, -10, -10, -10, -10, -10, -20,
    ]

    private static let rookTable = [
        0, 0, 0, 0, 0, 0, 0, 0,
        5, 10, 10, 10, 10, 10, 10, 5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        0, 0, 0, 5, 5, 0, 0, 0,
    ]

    private static let queenTable = [
        -20, -10, -10, -5, -5, -10, -10, -20,
        -10, 0, 0, 0, 0, 0, 0, -10,
        -10, 0, 5, 5, 5, 5, 0, -10,
        -5, 0, 5, 5, 5, 5, 0, -5,
        0, 0, 5, 5, 5, 5, 0, -5,
        -10, 5, 5, 5, 5, 5, 0, -10,
        -10, 0, 5, 0, 0, 0, 0, -10,
        -20, -10, -10, -5, -5, -10, -10, -20,
    ]

    private static let kingTable = [
        20, 30, 10, 0, 0, 10, 30, 20,
        20, 20, 0, 0, 0, 0, 20, 20,
        -10, -20, -20, -20, -20, -20, -20, -10,
        -20, -30, -30, -40, -40, -30, -30, -20,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
    ]
}

/// How a game against the computer ended, from the learner's side.
nonisolated enum ComputerGameResult: Equatable, Sendable {
    case won
    case lost
    case resigned
    case drawn(DrawReason)

    nonisolated enum DrawReason: Equatable, Sendable {
        case stalemate, fiftyMoves, insufficientMaterial, repetition
    }

    /// The result after a game's positions (the start, then one FEN per move), or nil while
    /// the game is still going.
    static func of(positions: [String], learner: ChessColor) -> ComputerGameResult? {
        guard let fen = positions.last, let engine = try? ChessEngine(fen: fen) else { return nil }
        if engine.isCheckmate() { return engine.sideToMove == learner ? .lost : .won }
        if engine.isStalemate() { return .drawn(.stalemate) }
        if engine.isInsufficientMaterial() { return .drawn(.insufficientMaterial) }
        if engine.isDrawByFiftyMoves() { return .drawn(.fiftyMoves) }
        // Placement, side to move, castling, and en passant identify a repeated position.
        let key = { (fen: String) in fen.split(separator: " ").prefix(4).joined(separator: " ") }
        let current = key(fen)
        if positions.filter({ key($0) == current }).count >= 3 { return .drawn(.repetition) }
        return nil
    }

    var title: String {
        switch self {
        case .won: return "Checkmate. You won!"
        case .lost: return "Checkmate. The computer won."
        case .resigned: return "You resigned."
        case .drawn(.stalemate): return "Stalemate. It's a draw."
        case .drawn(.fiftyMoves): return "Draw by the fifty-move rule."
        case .drawn(.insufficientMaterial): return "Draw. Neither side can checkmate."
        case .drawn(.repetition): return "Draw by repetition."
        }
    }
}

/// Wins, draws, and losses against the computer, saved on the device.
nonisolated struct ComputerGameRecord: Codable, Equatable, Sendable {
    var wins = 0
    var draws = 0
    var losses = 0

    var played: Int { wins + draws + losses }

    mutating func add(_ result: ComputerGameResult) {
        switch result {
        case .won: wins += 1
        case .lost, .resigned: losses += 1
        case .drawn: draws += 1
        }
    }
}
