import Foundation

/// The tutorial state machine. It owns the position; the board only reflects it.
///
/// Step 1 walks the main line with the expected squares highlighted. Step 2 ("What if?")
/// replays each variation: the opponent leaves the main line and the learner must answer.
struct OpeningTutorialSession: Equatable {
    enum Phase: Equatable {
        case mainLine
        case mainLineComplete
        case whatIf
        case completed
    }

    struct Mistake: Equatable {
        enum Kind: Equatable {
            /// A legal move that is not the one the tutorial teaches.
            case wrongMove
            /// A move the rules do not allow.
            case illegalMove
        }

        var kind: Kind
        var phase: Phase
        var variationId: String?
        var ply: Int
        /// SAN when the move is legal, otherwise the squares, e.g. "e2e5".
        var attempted: String
        var expected: TutorialMove
        var hint: String
    }

    enum MoveResult: Equatable {
        case correct(TutorialMove)
        case incorrect(Mistake)
        /// Not the learner's turn, or no line is active.
        case ignored
    }

    enum Feedback: Equatable {
        case none
        case correct(TutorialMove)
        case opponentMoved(TutorialMove)
        case incorrect(Mistake)
        case mainLineComplete
        case variationComplete(OpeningVariation)
        case tutorialComplete
    }

    let opening: ChessOpening
    private let plan: OpeningTutorialPlan

    private(set) var phase: Phase = .mainLine
    private(set) var variationIndex = 0
    /// Index of the next move in the current line.
    private(set) var cursor = 0
    private(set) var fen: String
    private(set) var lastMove: TutorialMove?
    private(set) var feedback: Feedback = .none
    private(set) var mistakes: [Mistake] = []
    private(set) var hintRevealed = false
    private(set) var completedVariationIds: [String] = []

    init(tutorial: OpeningTutorial) {
        opening = tutorial.opening
        plan = tutorial.plan
        fen = ChessEngine.startingFen
    }

    init(opening: ChessOpening) throws {
        self.init(tutorial: try OpeningTutorial(opening: opening))
    }

    var mainLineMoves: [TutorialMove] { plan.mainLine }

    var currentVariation: OpeningVariation? {
        guard phase == .whatIf, opening.variations.indices.contains(variationIndex) else { return nil }
        return opening.variations[variationIndex]
    }

    var currentLine: [TutorialMove] {
        switch phase {
        case .mainLine, .mainLineComplete:
            return plan.mainLine
        case .whatIf:
            return currentVariation.flatMap { plan.variations[$0.id] } ?? []
        case .completed:
            return []
        }
    }

    /// Moves already played in the current line.
    var playedMoves: [TutorialMove] { Array(currentLine.prefix(cursor)) }

    var nextMove: TutorialMove? {
        guard phase == .mainLine || phase == .whatIf, currentLine.indices.contains(cursor) else { return nil }
        return currentLine[cursor]
    }

    var isUserTurn: Bool { nextMove.map { opening.isUserPly($0.ply) } ?? false }
    var isAwaitingOpponent: Bool { nextMove.map { !opening.isUserPly($0.ply) } ?? false }
    var expectedUserMove: TutorialMove? { isUserTurn ? nextMove : nil }
    var isCurrentLineComplete: Bool { (phase == .mainLine || phase == .whatIf) && cursor >= currentLine.count }
    var hasMoreVariations: Bool { variationIndex + 1 < opening.variations.count }

    /// Squares to light up: always in the main line, only after a hint in "What if?" practice.
    var highlightedSquares: (from: String, to: String)? {
        guard let move = expectedUserMove else { return nil }
        guard phase == .mainLine || hintRevealed else { return nil }
        return (move.from, move.to)
    }

    var mainLineUserMoveCount: Int { plan.mainLine.filter { opening.isUserPly($0.ply) }.count }

    var mainLineUserMovesPlayed: Int {
        switch phase {
        case .mainLine:
            return playedMoves.filter { opening.isUserPly($0.ply) }.count
        case .mainLineComplete, .whatIf, .completed:
            return mainLineUserMoveCount
        }
    }

    var currentHint: String? {
        guard let move = expectedUserMove else { return nil }
        return Self.hint(for: move)
    }

    @discardableResult
    mutating func submitMove(from: String, to: String, promotion: String? = nil) -> MoveResult {
        guard let expected = expectedUserMove else { return .ignored }
        let promotionMatches = expected.promotion == nil || expected.promotion == (promotion ?? "q")
        if from == expected.from && to == expected.to && promotionMatches {
            advance(with: expected)
            feedback = .correct(expected)
            finishLineIfNeeded()
            return .correct(expected)
        }
        let legal = (try? ChessEngine(fen: fen))?.legalMoves(from: from).first { $0.to == to }
        let mistake = Mistake(
            kind: legal == nil ? .illegalMove : .wrongMove,
            phase: phase,
            variationId: currentVariation?.id,
            ply: expected.ply,
            attempted: legal?.san ?? "\(from)\(to)",
            expected: expected,
            hint: Self.hint(for: expected)
        )
        mistakes.append(mistake)
        hintRevealed = true
        feedback = .incorrect(mistake)
        return .incorrect(mistake)
    }

    @discardableResult
    mutating func playOpponentMove() -> TutorialMove? {
        guard isAwaitingOpponent, let move = nextMove else { return nil }
        advance(with: move)
        feedback = .opponentMoved(move)
        finishLineIfNeeded()
        return move
    }

    mutating func revealHint() {
        guard expectedUserMove != nil else { return }
        hintRevealed = true
    }

    /// Step 2. Valid once the main line is done; with no variations the tutorial simply completes.
    mutating func startWhatIfPractice() {
        guard phase == .mainLineComplete else { return }
        guard !opening.variations.isEmpty else {
            phase = .completed
            feedback = .tutorialComplete
            return
        }
        loadVariation(0)
    }

    mutating func nextVariation() {
        guard phase == .whatIf, isCurrentLineComplete else { return }
        if hasMoreVariations {
            loadVariation(variationIndex + 1)
        } else {
            phase = .completed
            feedback = .tutorialComplete
        }
    }

    /// Restarts the current stage. From the summary, starts the whole tutorial again.
    mutating func restart() {
        switch phase {
        case .whatIf:
            loadVariation(variationIndex)
        case .mainLine, .mainLineComplete, .completed:
            phase = .mainLine
            cursor = 0
            fen = ChessEngine.startingFen
            lastMove = nil
            hintRevealed = false
            feedback = .none
            mistakes = []
            completedVariationIds = []
        }
    }

    static func hint(for move: TutorialMove) -> String {
        let squares = "Move the \(move.piece.rawValue) from \(move.from) to \(move.to)."
        guard let hint = move.step.hint, !hint.isEmpty else { return squares }
        return "\(hint) \(squares)"
    }

    private mutating func advance(with move: TutorialMove) {
        fen = move.fenAfter
        lastMove = move
        cursor += 1
        hintRevealed = false
    }

    private mutating func finishLineIfNeeded() {
        guard isCurrentLineComplete else { return }
        switch phase {
        case .mainLine:
            phase = .mainLineComplete
            feedback = .mainLineComplete
        case .whatIf:
            if let variation = currentVariation {
                if !completedVariationIds.contains(variation.id) { completedVariationIds.append(variation.id) }
                feedback = .variationComplete(variation)
            }
        case .mainLineComplete, .completed:
            break
        }
    }

    private mutating func loadVariation(_ index: Int) {
        let branchPly = opening.variations[index].branchPly
        phase = .whatIf
        variationIndex = index
        cursor = 0
        fen = plan.mainLine[branchPly].fenBefore
        lastMove = branchPly > 0 ? plan.mainLine[branchPly - 1] : nil
        hintRevealed = false
        feedback = .none
    }
}
