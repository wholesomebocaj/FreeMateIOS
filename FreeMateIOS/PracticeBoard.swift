import Combine
import Foundation

struct BoardMoveRecord: Equatable, Identifiable {
    var index: Int
    var move: String
    var san: String
    var fen: String
    var captured: Bool
    var id: Int { index }
}

struct MovePayload: Equatable {
    var move: String
    var san: String
    var fen: String
    var captured: Bool
    var message: String
}

struct PromotionPrompt: Equatable, Identifiable {
    var from: String
    var to: String
    var choices: [String]
    var id: String { from + to }
}

@MainActor
final class PracticeBoard: ObservableObject {
    @Published var fen: String
    @Published var initialFen: String
    @Published var orientation: String
    @Published var turn: String
    @Published var position: [String: String]
    @Published var history: [BoardMoveRecord] = []
    @Published var lastMove: [String] = []
    @Published var selectedSquare: String?
    @Published var legalDestinations: [String] = []
    @Published var highlightSquares: [HighlightMark] = []
    @Published var isCheck = false
    @Published var isCheckmate = false
    @Published var isStalemate = false
    @Published var isGameOver = false
    @Published var feedback = ""
    @Published var feedbackKind = ""
    @Published var promotion: PromotionPrompt?

    var mode: String
    var objective: String
    var allowedMoves: [String]
    var lockToAllowedMoves: Bool
    var highlightLegalMoves: Bool
    var solutionMoves: [String]
    var successMessage: String
    var errorMessage: String
    var onMoveSuccess: ((MovePayload) -> Void)?
    var onMoveError: ((String, String) -> Void)?
    var onComplete: ((MovePayload) -> Void)?
    var onSquareSelect: ((String) -> Void)?

    private var engine: ChessEngine?

    init(fen: String = ChessEngine.startingFen, mode: String = "free", orientation: String = "white") {
        let normalized = (try? ChessEngine.normalize(fen).joined(separator: " ")) ?? ChessEngine.startingFen
        self.fen = normalized
        initialFen = normalized
        self.mode = mode
        self.orientation = orientation
        objective = ""
        allowedMoves = []
        lockToAllowedMoves = false
        highlightLegalMoves = true
        solutionMoves = []
        successMessage = ""
        errorMessage = ""
        engine = try? ChessEngine(fen: normalized)
        position = (try? ChessEngine.parsePieceMap(normalized)) ?? [:]
        turn = normalized.split(separator: " ").dropFirst().first.map(String.init) == "b" ? "black" : "white"
        refreshFlags()
    }

    func setConfig(
        mode: String? = nil,
        objective: String? = nil,
        allowedMoves: [String]? = nil,
        solutionMoves: [String]? = nil,
        lockToAllowedMoves: Bool? = nil,
        highlightLegalMoves: Bool? = nil,
        successMessage: String? = nil,
        errorMessage: String? = nil,
        highlightSquares: [HighlightMark]? = nil
    ) {
        if let mode { self.mode = mode }
        if let objective { self.objective = objective }
        if let allowedMoves { self.allowedMoves = allowedMoves }
        if let solutionMoves { self.solutionMoves = solutionMoves }
        if let lockToAllowedMoves { self.lockToAllowedMoves = lockToAllowedMoves }
        if let highlightLegalMoves { self.highlightLegalMoves = highlightLegalMoves }
        if let successMessage { self.successMessage = successMessage }
        if let errorMessage { self.errorMessage = errorMessage }
        if let highlightSquares { self.highlightSquares = highlightSquares }
        if let selectedSquare { refreshDestinations(for: selectedSquare) }
    }

    func loadFen(_ fen: String, setInitial: Bool = false, clearHistory: Bool = true) throws {
        promotion = nil
        let parts = try ChessEngine.normalize(fen)
        let normalized = parts.joined(separator: " ")
        _ = try ChessEngine.parsePieceMap(normalized)
        self.fen = normalized
        engine = try? ChessEngine(fen: normalized)
        position = (try? ChessEngine.parsePieceMap(normalized)) ?? [:]
        turn = parts[1] == "b" ? "black" : "white"
        lastMove = []
        selectedSquare = nil
        legalDestinations = []
        if setInitial { initialFen = normalized }
        if clearHistory { history = [] }
        refreshFlags()
    }

    func syncFen(_ fen: String, lastMove: [String] = [], clearSelection: Bool = true) throws {
        promotion = nil
        let parts = try ChessEngine.normalize(fen)
        let normalized = parts.joined(separator: " ")
        self.fen = normalized
        engine = try? ChessEngine(fen: normalized)
        position = (try? ChessEngine.parsePieceMap(normalized)) ?? [:]
        turn = parts[1] == "b" ? "black" : "white"
        self.lastMove = lastMove
        if clearSelection {
            selectedSquare = nil
            legalDestinations = []
        }
        refreshFlags()
    }

    func reset() {
        try? loadFen(ChessEngine.startingFen, setInitial: true, clearHistory: true)
        feedback = "Board reset to the starting position."
        feedbackKind = "success"
    }

    func clear() {
        try? loadFen(ChessEngine.emptyFen, setInitial: true, clearHistory: true)
        feedback = "Board cleared."
        feedbackKind = "success"
    }

    func flip() {
        promotion = nil
        orientation = orientation == "white" ? "black" : "white"
        selectedSquare = nil
        legalDestinations = []
        feedback = "Board flipped to \(orientation)'s perspective."
        feedbackKind = "success"
    }

    func select(_ square: String) {
        onSquareSelect?(square)
        guard position[square] != nil else {
            if let selectedSquare, legalDestinations.contains(square) {
                tryMove(from: selectedSquare, to: square)
            }
            return
        }
        if legalDestinations.contains(square), let selectedSquare, selectedSquare != square {
            tryMove(from: selectedSquare, to: square)
            return
        }
        if selectedSquare == square {
            selectedSquare = nil
            legalDestinations = []
            return
        }
        selectedSquare = square
        refreshDestinations(for: square)
    }

    func tryMove(from: String, to: String, promotionPiece: String? = nil) {
        guard from != to else {
            selectedSquare = nil
            legalDestinations = []
            return
        }
        let requested = buildMove(from: from, to: to)
        if !isConfiguredMoveAllowed(requested) {
            reject(requested, "That move is not part of this exercise.")
            return
        }
        let local = validateLocalMove(from: from, to: to, promotion: promotionPiece)
        if local.promotionRequired {
            promotion = PromotionPrompt(from: from, to: to, choices: local.promotionChoices)
            return
        }
        guard local.isValid, let move = local.move, let san = local.san, let resulting = local.resultingFen else {
            reject(requested, local.message)
            return
        }
        applyValidatedMove(from: from, to: to, move: move, san: san, resultingFen: resulting, captured: local.captured)
    }

    @discardableResult
    func playMove(_ move: String, suppressCallbacks: Bool = false, suppressComplete: Bool = false, promptPromotion: Bool = true) -> EngineMoveResult {
        let clean = move.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let from = String(clean.prefix(2))
        let to = String(clean.dropFirst(2).prefix(2))
        let promotionPiece = clean.count > 4 ? String(clean.dropFirst(4).prefix(1)) : nil
        let local = validateLocalMove(from: from, to: to, promotion: promotionPiece)
        if local.promotionRequired {
            if !promptPromotion {
                return playMove(String(clean.prefix(4)) + "q", suppressCallbacks: suppressCallbacks, suppressComplete: suppressComplete, promptPromotion: false)
            }
            promotion = PromotionPrompt(from: from, to: to, choices: local.promotionChoices)
            return EngineMoveResult(isValid: false, message: "Choose a promotion piece.", san: nil, resultingFen: nil, move: clean, promotionRequired: true, promotionChoices: local.promotionChoices)
        }
        guard local.isValid, let played = local.move, let san = local.san, let resulting = local.resultingFen else {
            reject(clean, local.message)
            return EngineMoveResult(isValid: false, message: local.message, san: nil, resultingFen: nil, move: clean)
        }
        applyValidatedMove(
            from: from,
            to: to,
            move: played,
            san: san,
            resultingFen: resulting,
            captured: local.captured,
            suppressCallbacks: suppressCallbacks,
            suppressComplete: suppressComplete
        )
        return EngineMoveResult(isValid: true, message: san, san: san, resultingFen: resulting, move: played, captured: local.captured)
    }

    func choosePromotion(_ piece: String) {
        guard let prompt = promotion else { return }
        promotion = nil
        tryMove(from: prompt.from, to: prompt.to, promotionPiece: piece)
    }

    func cancelPromotion() { promotion = nil }

    private func buildMove(from: String, to: String) -> String {
        let piece = position[from]
        let promotionRank = piece == "wP" ? "8" : piece == "bP" ? "1" : nil
        if let promotionRank, to.hasSuffix(promotionRank) { return "\(from)\(to)q" }
        return "\(from)\(to)"
    }

    private func isConfiguredMoveAllowed(_ move: String) -> Bool {
        let base = String(move.prefix(4))
        if mode == "free" { return true }
        if lockToAllowedMoves && !allowedMoves.isEmpty {
            return allowedMoves.contains(move) || allowedMoves.contains(base)
        }
        if mode == "puzzle" && !solutionMoves.isEmpty {
            return solutionMoves[0] == move || solutionMoves[0] == base
        }
        return true
    }

    private func validateLocalMove(from: String, to: String, promotion: String?) -> EngineMoveResult {
        guard let engine else {
            return EngineMoveResult(isValid: false, message: "This board position cannot be validated locally.", san: nil, resultingFen: nil, move: nil)
        }
        let legal = engine.legalMoves(from: from)
        let matching = legal.filter { $0.to == to }
        guard let moveInfo = matching.first else {
            return EngineMoveResult(isValid: false, message: "That move is not legal.", san: nil, resultingFen: nil, move: nil)
        }
        let choices = unique(matching.compactMap(\.promotion))
        let chosen = promotion ?? moveInfo.promotion
        if choices.count > 1 && (chosen == nil || chosen?.isEmpty == true) {
            return EngineMoveResult(
                isValid: false,
                message: "Choose a promotion piece.",
                san: nil,
                resultingFen: nil,
                move: nil,
                promotionRequired: true,
                promotionChoices: choices
            )
        }
        let uci = "\(from)\(to)\(chosen ?? "")"
        if !isConfiguredMoveAllowed(uci) {
            return EngineMoveResult(isValid: false, message: "That move is not part of this exercise.", san: nil, resultingFen: nil, move: uci)
        }
        let scratch = engine.copy()
        guard let played = scratch.move(from: from, to: to, promotion: chosen) else {
            return EngineMoveResult(isValid: false, message: "That move is not legal.", san: nil, resultingFen: nil, move: uci)
        }
        return EngineMoveResult(
            isValid: true,
            message: "",
            san: played.san,
            resultingFen: scratch.fen(),
            move: uci,
            captured: played.captured
        )
    }

    private func applyValidatedMove(
        from: String,
        to: String,
        move: String,
        san: String,
        resultingFen: String,
        captured: Bool,
        suppressCallbacks: Bool = false,
        suppressComplete: Bool = false
    ) {
        fen = ((try? ChessEngine.normalize(resultingFen)) ?? [resultingFen]).joined(separator: " ")
        engine = try? ChessEngine(fen: fen)
        position = (try? ChessEngine.parsePieceMap(fen)) ?? [:]
        let parts = fen.split(separator: " ")
        turn = parts.count > 1 && parts[1] == "b" ? "black" : "white"
        lastMove = [from, to]
        history.append(BoardMoveRecord(index: history.count + 1, move: move, san: san, fen: fen, captured: captured))
        selectedSquare = nil
        legalDestinations = []
        let message = successMessage.isEmpty ? "Correct. Nice move." : successMessage
        let payload = MovePayload(move: move, san: san, fen: fen, captured: captured, message: message)
        refreshFlags()
        if !suppressCallbacks {
            feedback = message
            feedbackKind = "success"
            onMoveSuccess?(payload)
        }
        if !suppressComplete && (mode == "lesson" || mode == "puzzle") {
            onComplete?(payload)
        }
    }

    private func reject(_ move: String, _ message: String) {
        let text = errorMessage.isEmpty ? message : errorMessage
        selectedSquare = nil
        legalDestinations = []
        promotion = nil
        feedback = text
        feedbackKind = "error"
        onMoveError?(move, text)
    }

    private func refreshDestinations(for square: String) {
        guard highlightLegalMoves, position[square] != nil, let engine else {
            legalDestinations = []
            return
        }
        legalDestinations = unique(engine.legalMoves(from: square).map(\.to).filter { destination in
            isConfiguredMoveAllowed(buildMove(from: square, to: destination))
        })
    }

    private func refreshFlags() {
        isCheck = engine?.isCheck() ?? false
        isCheckmate = engine?.isCheckmate() ?? false
        isStalemate = engine?.isStalemate() ?? false
        isGameOver = engine?.isGameOver() ?? false
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

enum PromotionLabel {
    static func name(_ choice: String) -> String {
        switch choice {
        case "q": return "Queen"
        case "r": return "Rook"
        case "b": return "Bishop"
        case "n": return "Knight"
        default: return choice.uppercased()
        }
    }
}
