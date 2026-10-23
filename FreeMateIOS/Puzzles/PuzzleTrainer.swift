import Combine
import Foundation

/// Connects a `PuzzleSession` to the shared `PracticeBoard`.
///
/// The board forwards every move attempt here. A solving move lands on the board; a wrong one
/// never does, so the piece springs back while the card shows the hint.
@MainActor
final class PuzzleTrainer: ObservableObject {
    @Published private(set) var session: PuzzleSession
    /// Increments on every wrong move so the view can shake and play an error haptic.
    @Published private(set) var rejectionCount = 0
    @Published private(set) var rejectedSquare: String?
    /// Puzzle keys solved at any time, for the progress dots.
    @Published private(set) var solved: Set<String>

    let board = PracticeBoard()
    private let store: PuzzleProgressStore
    private let activity: ActivityStore

    init(set: PuzzleSet, store: PuzzleProgressStore = PuzzleProgressStore(), activity: ActivityStore = ActivityStore()) {
        self.store = store
        self.activity = activity
        let solved = store.solved
        self.solved = solved
        // Pick up at the first puzzle not solved yet.
        let start = set.puzzles.firstIndex { !solved.contains(set.key(for: $0)) } ?? 0
        session = PuzzleSession(set: set, startingAt: start)
        board.onMoveAttempt = { [weak self] from, to, promotion in
            self?.attempt(from + to + (promotion ?? ""))
        }
        loadPuzzle()
    }

    var puzzle: Puzzle { session.puzzle }

    func isSolved(_ puzzle: Puzzle) -> Bool { solved.contains(session.puzzleSet.key(for: puzzle)) }

    func attempt(_ uci: String) {
        switch session.submit(uci) {
        case .solved:
            rejectedSquare = nil
            // The board sends no promotion piece, so take the listed one, or a queen.
            let move = uci.count == 4 ? (puzzle.solution.first { $0.hasPrefix(uci) } ?? uci) : uci
            let from = String(move.prefix(2))
            let to = String(move.dropFirst(2).prefix(2))
            if let engine = try? ChessEngine(fen: board.fen) {
                let promotes = engine.legalMoves(from: from).contains { $0.to == to && $0.promotion != nil }
                let promotion = move.count > 4 ? String(move.suffix(1)) : promotes ? "q" : nil
                if engine.move(from: from, to: to, promotion: promotion) != nil {
                    try? board.syncFen(engine.fen(), lastMove: [from, to])
                }
            }
            board.setConfig(highlightSquares: [])
            let key = session.puzzleSet.key(for: puzzle)
            store.markSolved(key, firstTry: session.isFirstTry)
            solved.insert(key)
            activity.record()
        case .wrong:
            rejectedSquare = String(uci.prefix(2))
            rejectionCount += 1
        case .ignored:
            break
        }
    }

    /// Marks the piece to move.
    func showHint() {
        session.showHint()
        guard let move = puzzle.solution.first else { return }
        board.setConfig(highlightSquares: [HighlightMark(square: String(move.prefix(2)), className: "focus")])
    }

    /// Marks the whole move. The puzzle no longer counts as solved first try.
    func showAnswer() {
        session.showAnswer()
        guard let move = puzzle.solution.first else { return }
        board.setConfig(highlightSquares: [
            HighlightMark(square: String(move.prefix(2)), className: "focus"),
            HighlightMark(square: String(move.dropFirst(2).prefix(2)), className: "target"),
        ])
    }

    func next() {
        session.advance()
        if !session.isFinished { loadPuzzle() }
    }

    func restart() {
        session.restart()
        loadPuzzle()
    }

    private func loadPuzzle() {
        rejectedSquare = nil
        try? board.loadFen(puzzle.fen, setInitial: true, clearHistory: true)
        board.orientation = puzzle.sideToMove.rawValue
        board.setConfig(highlightSquares: [])
    }
}
