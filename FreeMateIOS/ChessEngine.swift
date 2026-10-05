import Foundation

// Native port of the chess.js engine used by PracticeBoard, plus the
// python-chess checks in /api/validate-move, /api/legal-moves, /api/rook-move,
// and /api/openings/validate-move.

enum ChessColor: String, Codable, Equatable {
    case white
    case black

    var opposite: ChessColor { self == .white ? .black : .white }
    var fen: String { self == .white ? "w" : "b" }
    var label: String { self == .white ? "White" : "Black" }

    static func from(fen: String) -> ChessColor {
        fen == "b" ? .black : .white
    }
}

enum PieceKind: String, Equatable {
    case pawn, knight, bishop, rook, queen, king

    var fen: Character {
        switch self {
        case .pawn: return "p"
        case .knight: return "n"
        case .bishop: return "b"
        case .rook: return "r"
        case .queen: return "q"
        case .king: return "k"
        }
    }

    var sanLetter: String {
        switch self {
        case .pawn: return ""
        case .knight: return "N"
        case .bishop: return "B"
        case .rook: return "R"
        case .queen: return "Q"
        case .king: return "K"
        }
    }

    static func from(fen: Character) -> PieceKind? {
        switch String(fen).lowercased() {
        case "p": return .pawn
        case "n": return .knight
        case "b": return .bishop
        case "r": return .rook
        case "q": return .queen
        case "k": return .king
        default: return nil
        }
    }
}

struct ChessPiece: Equatable {
    var color: ChessColor
    var kind: PieceKind

    var code: String {
        "\(color == .white ? "w" : "b")\(kind.fen.uppercased())"
    }

    var fen: Character {
        if color == .black { return kind.fen }
        return String(kind.fen).uppercased().first ?? kind.fen
    }

    var symbol: String {
        switch (color, kind) {
        case (.white, .king): return "♔"
        case (.white, .queen): return "♕"
        case (.white, .rook): return "♖"
        case (.white, .bishop): return "♗"
        case (.white, .knight): return "♘"
        case (.white, .pawn): return "♙"
        case (.black, .king): return "♚"
        case (.black, .queen): return "♛"
        case (.black, .rook): return "♜"
        case (.black, .bishop): return "♝"
        case (.black, .knight): return "♞"
        case (.black, .pawn): return "♟"
        }
    }

    static func from(fen: Character) -> ChessPiece? {
        guard let kind = PieceKind.from(fen: fen) else { return nil }
        let color: ChessColor = fen.isUppercase ? .white : .black
        return ChessPiece(color: color, kind: kind)
    }
}

struct VerboseMove: Equatable {
    var from: String
    var to: String
    var promotion: String?
    var san: String
    var captured: Bool
    var piece: String

    var uci: String { "\(from)\(to)\(promotion ?? "")" }
}

struct EngineMoveResult: Equatable {
    var isValid: Bool
    var message: String
    var san: String?
    var resultingFen: String?
    var move: String?
    var captured: Bool = false
    var promotionRequired: Bool = false
    var promotionChoices: [String] = []
}

enum FenError: LocalizedError {
    case empty
    case rankCount
    case rankWidth
    case piece(Character)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a FEN string to load a position."
        case .rankCount:
            return "FEN must contain 8 ranks."
        case .rankWidth:
            return "Each FEN rank must contain 8 files."
        case .piece(let char):
            return "Unsupported FEN piece: \(char)"
        }
    }
}

enum ChessSquare {
    static let files = Array("abcdefgh")

    static func index(file: Int, rank: Int) -> Int { rank * 8 + file }
    static func file(_ index: Int) -> Int { index % 8 }
    static func rank(_ index: Int) -> Int { index / 8 }

    static func name(_ index: Int) -> String {
        "\(files[file(index)])\(rank(index) + 1)"
    }

    static func index(_ name: String) -> Int? {
        let chars = Array(name.lowercased())
        guard chars.count == 2, let file = files.firstIndex(of: chars[0]),
              let rankDigit = chars[1].wholeNumberValue, (1...8).contains(rankDigit) else {
            return nil
        }
        return index(file: file, rank: rankDigit - 1)
    }

    static func onBoard(file: Int, rank: Int) -> Bool {
        (0..<8).contains(file) && (0..<8).contains(rank)
    }
}

final class ChessEngine {
    static let startingFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    static let emptyFen = "8/8/8/8/8/8/8/8 w - - 0 1"

    private var board: [ChessPiece?]
    private var turn: ChessColor
    private var castling: Set<String>
    private var epTarget: Int?
    private var halfmove: Int
    private var fullmove: Int
    private var positionCounts: [String: Int]

    init(fen: String) throws {
        let parts = ChessEngine.normalize(fen)
        let parsed = try ChessEngine.parsePlacement(parts[0])
        board = parsed
        turn = ChessColor.from(fen: parts[1])
        castling = Set(parts[2].filter { "KQkq".contains($0) }.map(String.init))
        if parts[3] == "-" {
            epTarget = nil
        } else {
            epTarget = ChessSquare.index(parts[3])
        }
        halfmove = Int(parts[4]) ?? 0
        fullmove = max(1, Int(parts[5]) ?? 1)
        positionCounts = [:]
        sanitizeCastling()
        sanitizeEnPassant()
        recordPosition()
    }

    func copy() -> ChessEngine {
        let clone = try! ChessEngine(fen: fen())
        clone.positionCounts = positionCounts
        return clone
    }

    var sideToMove: ChessColor { turn }

    func fen() -> String {
        var ranks: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = ""
            var empty = 0
            for file in 0..<8 {
                if let piece = board[ChessSquare.index(file: file, rank: rank)] {
                    if empty > 0 {
                        row += "\(empty)"
                        empty = 0
                    }
                    row.append(piece.fen)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += "\(empty)" }
            ranks.append(row)
        }
        let castle = castlingString()
        let ep = printableEnPassant()
        return "\(ranks.joined(separator: "/")) \(turn.fen) \(castle) \(ep) \(halfmove) \(fullmove)"
    }

    func piece(at square: String) -> ChessPiece? {
        guard let index = ChessSquare.index(square) else { return nil }
        return board[index]
    }

    func pieceCode(at square: String) -> String? {
        piece(at: square)?.code
    }

    func placement() -> [String: String] {
        var map: [String: String] = [:]
        for index in 0..<64 {
            if let piece = board[index] {
                map[ChessSquare.name(index)] = piece.code
            }
        }
        return map
    }

    func isCheck() -> Bool { isKingInCheck(turn) }
    func isCheckmate() -> Bool { isCheck() && legalMoves().isEmpty }
    func isStalemate() -> Bool { !isCheck() && legalMoves().isEmpty }
    func isDrawByFiftyMoves() -> Bool { halfmove >= 100 }
    func isThreefoldRepetition() -> Bool { (positionCounts[positionKey()] ?? 0) >= 3 }

    func isInsufficientMaterial() -> Bool {
        var bishops: [Int] = []
        var counts: [PieceKind: Int] = [:]
        var numPieces = 0
        for index in 0..<64 {
            guard let piece = board[index] else { continue }
            counts[piece.kind, default: 0] += 1
            numPieces += 1
            if piece.kind == .bishop {
                let color = (ChessSquare.file(index) + ChessSquare.rank(index)) % 2
                bishops.append(color)
            }
        }
        if numPieces == 2 { return true }
        if numPieces == 3 && ((counts[.bishop] ?? 0) == 1 || (counts[.knight] ?? 0) == 1) {
            return true
        }
        if numPieces == (counts[.bishop] ?? 0) + 2, !bishops.isEmpty {
            let sum = bishops.reduce(0, +)
            if sum == 0 || sum == bishops.count { return true }
        }
        return false
    }

    func isDraw() -> Bool {
        isDrawByFiftyMoves() || isStalemate() || isInsufficientMaterial() || isThreefoldRepetition()
    }

    func isGameOver() -> Bool { isCheckmate() || isDraw() }

    func legalMoves(from square: String? = nil) -> [VerboseMove] {
        let raws = pseudoLegalMoves(from: square).filter { isLegal($0) }
        return raws.map { verbose($0, among: raws.filter { isLegal($0) }) }
    }

    @discardableResult
    func move(from: String, to: String, promotion: String? = nil) -> VerboseMove? {
        let matches = legalMoves(from: from).filter { $0.to == to }
        guard !matches.isEmpty else { return nil }
        let chosen: VerboseMove
        if let promotion {
            guard let match = matches.first(where: { $0.promotion == promotion.lowercased() }) else {
                return nil
            }
            chosen = match
        } else if matches.count == 1 {
            chosen = matches[0]
        } else if let queen = matches.first(where: { $0.promotion == nil }) {
            chosen = queen
        } else {
            // chess.js lists promotions as knight, bishop, rook, queen.
            // moves({square})[0].promotion is therefore the knight when the
            // caller does not pass a promotion piece.
            chosen = matches[0]
        }
        apply(raw(from: chosen))
        return chosen
    }

    static func normalize(_ fen: String) throws -> [String] {
        let trimmed = fen.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw FenError.empty }
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if parts.count == 1 { return [parts[0], "w", "-", "-", "0", "1"] }
        return [
            parts[0],
            parts.count > 1 && !parts[1].isEmpty ? parts[1] : "w",
            parts.count > 2 && !parts[2].isEmpty ? parts[2] : "-",
            parts.count > 3 && !parts[3].isEmpty ? parts[3] : "-",
            parts.count > 4 && !parts[4].isEmpty ? parts[4] : "0",
            parts.count > 5 && !parts[5].isEmpty ? parts[5] : "1",
        ]
    }

    static func parsePlacement(_ placement: String) throws -> [ChessPiece?] {
        let ranks = placement.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if ranks.count != 8 { throw FenError.rankCount }
        var board = [ChessPiece?](repeating: nil, count: 64)
        for (rankIndex, rankText) in ranks.enumerated() {
            var fileIndex = 0
            let rank = 7 - rankIndex
            for char in rankText {
                if let skip = char.wholeNumberValue {
                    fileIndex += skip
                    continue
                }
                guard let piece = ChessPiece.from(fen: char) else { throw FenError.piece(char) }
                if fileIndex > 7 { throw FenError.rankWidth }
                board[ChessSquare.index(file: fileIndex, rank: rank)] = piece
                fileIndex += 1
            }
            if fileIndex != 8 { throw FenError.rankWidth }
        }
        return board
    }

    static func parsePieceMap(_ fen: String) throws -> [String: String] {
        let parts = try normalize(fen)
        let board = try parsePlacement(parts[0])
        var map: [String: String] = [:]
        for index in 0..<64 {
            if let piece = board[index] {
                map[ChessSquare.name(index)] = piece.code
            }
        }
        return map
    }

    static func validateUCI(fen: String?, move: String) -> EngineMoveResult {
        let source = (fen?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? fen! : startingFen
        let engine: ChessEngine
        do {
            engine = try ChessEngine(fen: source)
        } catch {
            return EngineMoveResult(
                isValid: false,
                message: "That board position is not a valid FEN string.",
                san: nil,
                resultingFen: nil,
                move: move
            )
        }
        let clean = move.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count == 4 || clean.count == 5,
              ChessSquare.index(String(clean.prefix(2))) != nil,
              ChessSquare.index(String(clean.dropFirst(2).prefix(2))) != nil,
              clean.count == 4 || "qrbn".contains(clean.suffix(1)) else {
            return EngineMoveResult(
                isValid: false,
                message: "Enter a move in UCI format, like e2e4 or g1f3.",
                san: nil,
                resultingFen: nil,
                move: move
            )
        }
        let from = String(clean.prefix(2))
        let to = String(clean.dropFirst(2).prefix(2))
        let promotion = clean.count == 5 ? String(clean.suffix(1)) : nil
        guard let played = engine.move(from: from, to: to, promotion: promotion) else {
            return EngineMoveResult(
                isValid: false,
                message: "That move is not legal in the current position.",
                san: nil,
                resultingFen: nil,
                move: move
            )
        }
        return EngineMoveResult(
            isValid: true,
            message: "Nice move. That is legal from this position.",
            san: played.san,
            resultingFen: engine.fen(),
            move: move,
            captured: played.captured
        )
    }

    static func legalSquares(fen: String, fromSquare: String) -> (squares: [String], message: String) {
        let from = fromSquare.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ChessSquare.index(from) != nil, let engine = try? ChessEngine(fen: fen) else {
            return ([], "That board position or square is not valid.")
        }
        let squares = engine.legalMoves(from: from).map(\.to)
        return (squares, "Found \(squares.count) legal moves.")
    }

    static func validateRookMove(fromSquare: String, toSquare: String) -> (correct: Bool, message: String, from: String, to: String) {
        let from = fromSquare.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let to = toSquare.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let start = ChessSquare.index(from), let target = ChessSquare.index(to) else {
            return (false, "Choose a real square on the board.", from, to)
        }
        var board = [ChessPiece?](repeating: nil, count: 64)
        board[ChessSquare.index("h1")!] = ChessPiece(color: .white, kind: .king)
        board[ChessSquare.index("h8")!] = ChessPiece(color: .black, kind: .king)
        board[start] = ChessPiece(color: .white, kind: .rook)
        let engine = ChessEngine(board: board, turn: .white, castling: [], epTarget: nil, halfmove: 0, fullmove: 1)
        let legal = engine.legalMoves(from: from).contains { $0.to == to && $0.promotion == nil && ChessSquare.index($0.to) == target }
        if legal {
            return (true, "Correct. A rook moves in a straight line across ranks or files.", from, to)
        }
        return (false, "Incorrect. Rooks move horizontally or vertically, not diagonally.", from, to)
    }

    static func validateOpeningMove(
        startingFen: String,
        line: [OpeningLineMove],
        move: String,
        moveIndex: Int,
        playedMoves: [String]?
    ) -> EngineMoveResult {
        if moveIndex >= line.count {
            return EngineMoveResult(
                isValid: false,
                message: "This opening line is already complete.",
                san: nil,
                resultingFen: nil,
                move: move
            )
        }
        let fen = startingFen == "startpos" ? ChessEngine.startingFen : startingFen
        guard let engine = try? ChessEngine(fen: fen) else {
            return EngineMoveResult(
                isValid: false,
                message: "Opening has an invalid starting FEN.",
                san: nil,
                resultingFen: nil,
                move: move
            )
        }
        let previous = playedMoves ?? line.prefix(moveIndex).map(\.uci)
        for previousMove in previous {
            guard let parsed = parseUCI(previousMove),
                  engine.move(from: parsed.from, to: parsed.to, promotion: parsed.promotion) != nil else {
                return EngineMoveResult(
                    isValid: false,
                    message: "The training position is out of sync. Reset the line and try again.",
                    san: nil,
                    resultingFen: engine.fen(),
                    move: move
                )
            }
        }
        guard let attempted = parseUCI(move) else {
            return EngineMoveResult(
                isValid: false,
                message: "Move must be UCI, like e2e4.",
                san: nil,
                resultingFen: engine.fen(),
                move: move
            )
        }
        let expected = line[moveIndex].uci.lowercased()
        let attemptText = move.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let baseAttempt = String(attemptText.prefix(4))
        let candidates = engine.legalMoves(from: attempted.from).filter { $0.to == attempted.to }
        let legalMatch = attempted.promotion == nil
            ? candidates.first { $0.promotion == nil }
            : candidates.first { $0.promotion == attempted.promotion }
        if legalMatch == nil {
            return EngineMoveResult(
                isValid: false,
                message: "That move is legal in some positions, but not here. Try the highlighted opening move.",
                san: nil,
                resultingFen: engine.fen(),
                move: move
            )
        }
        let matchesExpected = attemptText == expected || attemptText == String(expected.prefix(4)) || baseAttempt == String(expected.prefix(4))
        if !matchesExpected {
            return EngineMoveResult(
                isValid: false,
                message: "Good legal move, but this trainer is practicing \(line[moveIndex].san).",
                san: nil,
                resultingFen: engine.fen(),
                move: move
            )
        }
        guard let played = engine.move(from: attempted.from, to: attempted.to, promotion: attempted.promotion) else {
            return EngineMoveResult(
                isValid: false,
                message: "That move is legal in some positions, but not here. Try the highlighted opening move.",
                san: nil,
                resultingFen: engine.fen(),
                move: move
            )
        }
        return EngineMoveResult(
            isValid: true,
            message: line[moveIndex].explanation.isEmpty ? "Correct move." : line[moveIndex].explanation,
            san: played.san,
            resultingFen: engine.fen(),
            move: move,
            captured: played.captured
        )
    }

    private init(board: [ChessPiece?], turn: ChessColor, castling: Set<String>, epTarget: Int?, halfmove: Int, fullmove: Int) {
        self.board = board
        self.turn = turn
        self.castling = castling
        self.epTarget = epTarget
        self.halfmove = halfmove
        self.fullmove = fullmove
        self.positionCounts = [:]
        recordPosition()
    }

    private struct RawMove {
        var from: Int
        var to: Int
        var promotion: PieceKind?
        var captured: Bool
        var enPassant: Bool
        var castle: Bool
    }

    private func pseudoLegalMoves(from square: String?) -> [RawMove] {
        let only = square.flatMap { ChessSquare.index($0.lowercased()) }
        var moves: [RawMove] = []
        let squares = only.map { [$0] } ?? Array(0..<64)
        for from in squares {
            guard let piece = board[from], piece.color == turn else { continue }
            switch piece.kind {
            case .pawn:
                moves.append(contentsOf: pawnMoves(from: from, color: piece.color))
            case .knight:
                moves.append(contentsOf: leapMoves(from: from, deltas: [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]))
            case .bishop:
                moves.append(contentsOf: slideMoves(from: from, deltas: [(1, 1), (1, -1), (-1, 1), (-1, -1)]))
            case .rook:
                moves.append(contentsOf: slideMoves(from: from, deltas: [(1, 0), (-1, 0), (0, 1), (0, -1)]))
            case .queen:
                moves.append(contentsOf: slideMoves(from: from, deltas: [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]))
            case .king:
                moves.append(contentsOf: leapMoves(from: from, deltas: [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]))
                moves.append(contentsOf: castleMoves(from: from, color: piece.color))
            }
        }
        return moves
    }

    private func pawnMoves(from: Int, color: ChessColor) -> [RawMove] {
        let file = ChessSquare.file(from)
        let rank = ChessSquare.rank(from)
        let direction = color == .white ? 1 : -1
        let startRank = color == .white ? 1 : 6
        let promoteRank = color == .white ? 7 : 0
        var moves: [RawMove] = []
        let oneRank = rank + direction
        if ChessSquare.onBoard(file: file, rank: oneRank) {
            let one = ChessSquare.index(file: file, rank: oneRank)
            if board[one] == nil {
                if oneRank == promoteRank {
                    moves.append(contentsOf: promotions(from: from, to: one, captured: false, enPassant: false))
                } else {
                    moves.append(RawMove(from: from, to: one, promotion: nil, captured: false, enPassant: false, castle: false))
                    if rank == startRank {
                        let twoRank = rank + direction * 2
                        let two = ChessSquare.index(file: file, rank: twoRank)
                        if board[two] == nil {
                            moves.append(RawMove(from: from, to: two, promotion: nil, captured: false, enPassant: false, castle: false))
                        }
                    }
                }
            }
        }
        for fileDelta in [-1, 1] {
            let targetFile = file + fileDelta
            guard ChessSquare.onBoard(file: targetFile, rank: oneRank) else { continue }
            let target = ChessSquare.index(file: targetFile, rank: oneRank)
            if let occupant = board[target], occupant.color != color {
                if oneRank == promoteRank {
                    moves.append(contentsOf: promotions(from: from, to: target, captured: true, enPassant: false))
                } else {
                    moves.append(RawMove(from: from, to: target, promotion: nil, captured: true, enPassant: false, castle: false))
                }
            } else if epTarget == target {
                moves.append(RawMove(from: from, to: target, promotion: nil, captured: true, enPassant: true, castle: false))
            }
        }
        return moves
    }

    private func promotions(from: Int, to: Int, captured: Bool, enPassant: Bool) -> [RawMove] {
        [PieceKind.knight, .bishop, .rook, .queen].map {
            RawMove(from: from, to: to, promotion: $0, captured: captured, enPassant: enPassant, castle: false)
        }
    }

    private func leapMoves(from: Int, deltas: [(Int, Int)]) -> [RawMove] {
        let file = ChessSquare.file(from)
        let rank = ChessSquare.rank(from)
        let color = board[from]!.color
        var moves: [RawMove] = []
        for (df, dr) in deltas {
            let nextFile = file + df
            let nextRank = rank + dr
            guard ChessSquare.onBoard(file: nextFile, rank: nextRank) else { continue }
            let target = ChessSquare.index(file: nextFile, rank: nextRank)
            if let occupant = board[target] {
                if occupant.color != color {
                    moves.append(RawMove(from: from, to: target, promotion: nil, captured: true, enPassant: false, castle: false))
                }
            } else {
                moves.append(RawMove(from: from, to: target, promotion: nil, captured: false, enPassant: false, castle: false))
            }
        }
        return moves
    }

    private func slideMoves(from: Int, deltas: [(Int, Int)]) -> [RawMove] {
        let color = board[from]!.color
        var moves: [RawMove] = []
        for (df, dr) in deltas {
            var file = ChessSquare.file(from) + df
            var rank = ChessSquare.rank(from) + dr
            while ChessSquare.onBoard(file: file, rank: rank) {
                let target = ChessSquare.index(file: file, rank: rank)
                if let occupant = board[target] {
                    if occupant.color != color {
                        moves.append(RawMove(from: from, to: target, promotion: nil, captured: true, enPassant: false, castle: false))
                    }
                    break
                }
                moves.append(RawMove(from: from, to: target, promotion: nil, captured: false, enPassant: false, castle: false))
                file += df
                rank += dr
            }
        }
        return moves
    }

    private func castleMoves(from: Int, color: ChessColor) -> [RawMove] {
        guard board[from]?.kind == .king, !isKingInCheck(color) else { return [] }
        var moves: [RawMove] = []
        if color == .white && from == ChessSquare.index("e1") {
            if castling.contains("K"),
               board[ChessSquare.index("f1")!] == nil,
               board[ChessSquare.index("g1")!] == nil,
               board[ChessSquare.index("h1")!]?.kind == .rook,
               board[ChessSquare.index("h1")!]?.color == .white,
               !isAttacked(ChessSquare.index("f1")!, by: .black),
               !isAttacked(ChessSquare.index("g1")!, by: .black) {
                moves.append(RawMove(from: from, to: ChessSquare.index("g1")!, promotion: nil, captured: false, enPassant: false, castle: true))
            }
            if castling.contains("Q"),
               board[ChessSquare.index("d1")!] == nil,
               board[ChessSquare.index("c1")!] == nil,
               board[ChessSquare.index("b1")!] == nil,
               board[ChessSquare.index("a1")!]?.kind == .rook,
               board[ChessSquare.index("a1")!]?.color == .white,
               !isAttacked(ChessSquare.index("d1")!, by: .black),
               !isAttacked(ChessSquare.index("c1")!, by: .black) {
                moves.append(RawMove(from: from, to: ChessSquare.index("c1")!, promotion: nil, captured: false, enPassant: false, castle: true))
            }
        }
        if color == .black && from == ChessSquare.index("e8") {
            if castling.contains("k"),
               board[ChessSquare.index("f8")!] == nil,
               board[ChessSquare.index("g8")!] == nil,
               board[ChessSquare.index("h8")!]?.kind == .rook,
               board[ChessSquare.index("h8")!]?.color == .black,
               !isAttacked(ChessSquare.index("f8")!, by: .white),
               !isAttacked(ChessSquare.index("g8")!, by: .white) {
                moves.append(RawMove(from: from, to: ChessSquare.index("g8")!, promotion: nil, captured: false, enPassant: false, castle: true))
            }
            if castling.contains("q"),
               board[ChessSquare.index("d8")!] == nil,
               board[ChessSquare.index("c8")!] == nil,
               board[ChessSquare.index("b8")!] == nil,
               board[ChessSquare.index("a8")!]?.kind == .rook,
               board[ChessSquare.index("a8")!]?.color == .black,
               !isAttacked(ChessSquare.index("d8")!, by: .white),
               !isAttacked(ChessSquare.index("c8")!, by: .white) {
                moves.append(RawMove(from: from, to: ChessSquare.index("c8")!, promotion: nil, captured: false, enPassant: false, castle: true))
            }
        }
        return moves
    }

    private func isLegal(_ move: RawMove) -> Bool {
        let mover = turn
        let next = snapshot()
        next.apply(move)
        return !next.isKingInCheck(mover)
    }

    private func snapshot() -> ChessEngine {
        ChessEngine(board: board, turn: turn, castling: castling, epTarget: epTarget, halfmove: halfmove, fullmove: fullmove)
    }

    private func apply(_ move: RawMove) {
        let mover = board[move.from]!
        let opponent = mover.color.opposite
        var nextCastling = castling
        var nextEP: Int? = nil
        var nextHalf = halfmove + 1

        if move.enPassant {
            let capturedRank = ChessSquare.rank(move.to) + (mover.color == .white ? -1 : 1)
            board[ChessSquare.index(file: ChessSquare.file(move.to), rank: capturedRank)] = nil
        }
        if move.castle {
            if move.to == ChessSquare.index("g1") {
                board[ChessSquare.index("h1")!] = nil
                board[ChessSquare.index("f1")!] = ChessPiece(color: .white, kind: .rook)
            } else if move.to == ChessSquare.index("c1") {
                board[ChessSquare.index("a1")!] = nil
                board[ChessSquare.index("d1")!] = ChessPiece(color: .white, kind: .rook)
            } else if move.to == ChessSquare.index("g8") {
                board[ChessSquare.index("h8")!] = nil
                board[ChessSquare.index("f8")!] = ChessPiece(color: .black, kind: .rook)
            } else if move.to == ChessSquare.index("c8") {
                board[ChessSquare.index("a8")!] = nil
                board[ChessSquare.index("d8")!] = ChessPiece(color: .black, kind: .rook)
            }
        }

        if mover.kind == .king {
            if mover.color == .white { nextCastling.subtract(["K", "Q"]) }
            else { nextCastling.subtract(["k", "q"]) }
        }
        if mover.kind == .rook {
            if move.from == ChessSquare.index("h1") { nextCastling.remove("K") }
            if move.from == ChessSquare.index("a1") { nextCastling.remove("Q") }
            if move.from == ChessSquare.index("h8") { nextCastling.remove("k") }
            if move.from == ChessSquare.index("a8") { nextCastling.remove("q") }
        }
        if move.to == ChessSquare.index("h1") { nextCastling.remove("K") }
        if move.to == ChessSquare.index("a1") { nextCastling.remove("Q") }
        if move.to == ChessSquare.index("h8") { nextCastling.remove("k") }
        if move.to == ChessSquare.index("a8") { nextCastling.remove("q") }

        if mover.kind == .pawn || move.captured { nextHalf = 0 }
        if mover.kind == .pawn && abs(ChessSquare.rank(move.to) - ChessSquare.rank(move.from)) == 2 {
            nextEP = ChessSquare.index(file: ChessSquare.file(move.from), rank: (ChessSquare.rank(move.from) + ChessSquare.rank(move.to)) / 2)
        }

        board[move.to] = ChessPiece(color: mover.color, kind: move.promotion ?? mover.kind)
        board[move.from] = nil
        castling = nextCastling
        epTarget = nextEP
        halfmove = nextHalf
        if mover.color == .black { fullmove += 1 }
        turn = opponent
        sanitizeCastling()
        sanitizeEnPassant()
        recordPosition()
    }

    private func isKingInCheck(_ color: ChessColor) -> Bool {
        guard let king = kingSquare(color) else { return false }
        return isAttacked(king, by: color.opposite)
    }

    private func kingSquare(_ color: ChessColor) -> Int? {
        board.firstIndex { $0?.color == color && $0?.kind == .king }
    }

    private func isAttacked(_ target: Int, by color: ChessColor) -> Bool {
        let file = ChessSquare.file(target)
        let rank = ChessSquare.rank(target)
        let pawnRank = rank + (color == .white ? -1 : 1)
        for df in [-1, 1] {
            if ChessSquare.onBoard(file: file + df, rank: pawnRank) {
                let index = ChessSquare.index(file: file + df, rank: pawnRank)
                if board[index]?.color == color && board[index]?.kind == .pawn { return true }
            }
        }
        for (df, dr) in [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)] {
            if ChessSquare.onBoard(file: file + df, rank: rank + dr) {
                let index = ChessSquare.index(file: file + df, rank: rank + dr)
                if board[index]?.color == color && board[index]?.kind == .knight { return true }
            }
        }
        for (df, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)] {
            var nextFile = file + df
            var nextRank = rank + dr
            while ChessSquare.onBoard(file: nextFile, rank: nextRank) {
                let index = ChessSquare.index(file: nextFile, rank: nextRank)
                if let piece = board[index] {
                    if piece.color == color {
                        let diagonal = df != 0 && dr != 0
                        if piece.kind == .queen || piece.kind == .king && abs(nextFile - file) <= 1 && abs(nextRank - rank) <= 1 {
                            return true
                        }
                        if diagonal && piece.kind == .bishop { return true }
                        if !diagonal && piece.kind == .rook { return true }
                        if piece.kind == .king && (abs(nextFile - file) > 1 || abs(nextRank - rank) > 1) {
                            break
                        }
                    }
                    break
                }
                nextFile += df
                nextRank += dr
            }
        }
        return false
    }

    private func verbose(_ move: RawMove, among legal: [RawMove]) -> VerboseMove {
        let piece = board[move.from]!
        let san = sanString(move, piece: piece, legal: legal)
        return VerboseMove(
            from: ChessSquare.name(move.from),
            to: ChessSquare.name(move.to),
            promotion: move.promotion?.fen.description,
            san: san,
            captured: move.captured,
            piece: piece.code
        )
    }

    private func sanString(_ move: RawMove, piece: ChessPiece, legal: [RawMove]) -> String {
        let next = snapshot()
        next.apply(move)
        let suffix = next.isCheckmate() ? "#" : (next.isKingInCheck(next.turn) ? "+" : "")
        if move.castle {
            return (ChessSquare.file(move.to) == 6 ? "O-O" : "O-O-O") + suffix
        }
        let destination = ChessSquare.name(move.to)
        let promotion = move.promotion.map { "=\($0.fen.uppercased())" } ?? ""
        if piece.kind == .pawn {
            if move.captured {
                let file = String(ChessSquare.files[ChessSquare.file(move.from)])
                return "\(file)x\(destination)\(promotion)\(suffix)"
            }
            return "\(destination)\(promotion)\(suffix)"
        }
        let same = legal.filter {
            $0.from != move.from && $0.to == move.to && board[$0.from]?.kind == piece.kind && board[$0.from]?.color == piece.color && $0.promotion == move.promotion
        }
        var disambiguation = ""
        if !same.isEmpty {
            let file = ChessSquare.file(move.from)
            let rank = ChessSquare.rank(move.from)
            let fileClash = same.contains { ChessSquare.file($0.from) == file }
            let rankClash = same.contains { ChessSquare.rank($0.from) == rank }
            if !fileClash {
                disambiguation = String(ChessSquare.files[file])
            } else if !rankClash {
                disambiguation = "\(rank + 1)"
            } else {
                disambiguation = "\(ChessSquare.files[file])\(rank + 1)"
            }
        }
        let capture = move.captured ? "x" : ""
        return "\(piece.kind.sanLetter)\(disambiguation)\(capture)\(destination)\(suffix)"
    }

    private func raw(from move: VerboseMove) -> RawMove {
        RawMove(
            from: ChessSquare.index(move.from)!,
            to: ChessSquare.index(move.to)!,
            promotion: move.promotion.flatMap { token in token.first.flatMap { PieceKind.from(fen: $0) } },
            captured: move.captured,
            enPassant: epTarget == ChessSquare.index(move.to) && board[ChessSquare.index(move.from)!]?.kind == .pawn && ChessSquare.file(ChessSquare.index(move.from)!) != ChessSquare.file(ChessSquare.index(move.to)!),
            castle: board[ChessSquare.index(move.from)!]?.kind == .king && abs(ChessSquare.file(ChessSquare.index(move.from)!) - ChessSquare.file(ChessSquare.index(move.to)!)) == 2
        )
    }

    private func castlingString() -> String {
        let ordered = ["K", "Q", "k", "q"]
        let text = ordered.filter { castling.contains($0) }.joined()
        return text.isEmpty ? "-" : text
    }

    private func printableEnPassant() -> String {
        guard let epTarget else { return "-" }
        let color = turn
        let file = ChessSquare.file(epTarget)
        let rank = ChessSquare.rank(epTarget)
        let pawnRank = rank + (color == .white ? -1 : 1)
        for df in [-1, 1] {
            guard ChessSquare.onBoard(file: file + df, rank: pawnRank) else { continue }
            let from = ChessSquare.index(file: file + df, rank: pawnRank)
            guard board[from]?.color == color, board[from]?.kind == .pawn else { continue }
            let capture = RawMove(from: from, to: epTarget, promotion: nil, captured: true, enPassant: true, castle: false)
            if isLegal(capture) { return ChessSquare.name(epTarget) }
        }
        return "-"
    }

    private func sanitizeCastling() {
        func home(_ square: String, kind: PieceKind, color: ChessColor) -> Bool {
            guard let index = ChessSquare.index(square) else { return false }
            return board[index]?.kind == kind && board[index]?.color == color
        }
        if !home("e1", .king, .white) || !home("h1", .rook, .white) { castling.remove("K") }
        if !home("e1", .king, .white) || !home("a1", .rook, .white) { castling.remove("Q") }
        if !home("e8", .king, .black) || !home("h8", .rook, .black) { castling.remove("k") }
        if !home("e8", .king, .black) || !home("a8", .rook, .black) { castling.remove("q") }
    }

    private func sanitizeEnPassant() {
        guard let epTarget else { return }
        let file = ChessSquare.file(epTarget)
        let rank = ChessSquare.rank(epTarget)
        let pawnRank = rank + (turn == .white ? -1 : 1)
        let startRank = rank + (turn == .white ? 1 : -1)
        guard ChessSquare.onBoard(file: file, rank: pawnRank),
              board[epTarget] == nil,
              board[ChessSquare.index(file: file, rank: startRank)] == nil,
              board[ChessSquare.index(file: file, rank: pawnRank)]?.kind == .pawn,
              board[ChessSquare.index(file: file, rank: pawnRank)]?.color == turn.opposite else {
            self.epTarget = nil
            return
        }
        let canCapture = [-1, 1].contains { df in
            ChessSquare.onBoard(file: file + df, rank: pawnRank)
                && board[ChessSquare.index(file: file + df, rank: pawnRank)]?.kind == .pawn
                && board[ChessSquare.index(file: file + df, rank: pawnRank)]?.color == turn
        }
        if !canCapture { self.epTarget = nil }
    }

    private func positionKey() -> String {
        let placement = fen().split(separator: " ").prefix(4).joined(separator: " ")
        return placement
    }

    private func recordPosition() {
        let key = positionKey()
        positionCounts[key, default: 0] += 1
    }

    private static func parseUCI(_ text: String) -> (from: String, to: String, promotion: String?)? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count == 4 || clean.count == 5 else { return nil }
        let from = String(clean.prefix(2))
        let to = String(clean.dropFirst(2).prefix(2))
        guard ChessSquare.index(from) != nil, ChessSquare.index(to) != nil else { return nil }
        if clean.count == 5 {
            let promotion = String(clean.suffix(1))
            guard "qrbn".contains(promotion) else { return nil }
            return (from, to, promotion)
        }
        return (from, to, nil)
    }
}

struct OpeningLineMove: Equatable {
    var uci: String
    var san: String
    var title: String
    var explanation: String
}
