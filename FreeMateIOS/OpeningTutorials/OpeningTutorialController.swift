import Combine
import Foundation

/// Connects an `OpeningTutorialSession` to the shared `PracticeBoard`.
///
/// The board forwards every move attempt here instead of playing it. Correct moves are synced
/// back to the board; wrong ones never land, so the piece springs back to its square while
/// the card shows a hint.
@MainActor
final class OpeningTutorialController: ObservableObject {
    @Published private(set) var session: OpeningTutorialSession
    @Published private(set) var progress: OpeningTutorialProgress
    /// Increments on every rejected move so the view can shake and play an error haptic.
    @Published private(set) var rejectionCount = 0
    /// The square the rejected piece started from.
    @Published private(set) var rejectedSquare: String?

    let board: PracticeBoard
    private let store: OpeningTutorialProgressStore
    private var opponentTask: Task<Void, Never>?

    var opening: ChessOpening { session.opening }

    init(tutorial: OpeningTutorial, store: OpeningTutorialProgressStore? = nil) {
        let store = store ?? OpeningTutorialProgressStore()
        session = OpeningTutorialSession(tutorial: tutorial)
        self.store = store
        progress = store.progress(for: tutorial.id)
        board = PracticeBoard(
            fen: ChessEngine.startingFen,
            mode: "free",
            orientation: tutorial.opening.userSide == .white ? "white" : "black"
        )
        board.onMoveAttempt = { [weak self] from, to, promotion in
            self?.attempt(from: from, to: to, promotion: promotion)
        }
        syncBoard()
        scheduleOpponentReply()
    }

    func attempt(from: String, to: String, promotion: String?) {
        switch session.submitMove(from: from, to: to, promotion: promotion) {
        case .correct:
            rejectedSquare = nil
            syncBoard()
            saveProgress()
            scheduleOpponentReply()
        case .incorrect:
            rejectedSquare = from
            rejectionCount += 1
            syncBoard()
        case .ignored:
            syncBoard()
        }
    }

    func showHint() {
        session.revealHint()
        syncBoard()
    }

    func startWhatIfPractice() {
        session.startWhatIfPractice()
        saveProgress()
        syncBoard()
        scheduleOpponentReply()
    }

    func nextVariation() {
        session.nextVariation()
        saveProgress()
        syncBoard()
        scheduleOpponentReply()
    }

    /// Restarts the current line, or the whole tutorial from the main line or summary.
    func restart() {
        opponentTask?.cancel()
        rejectedSquare = nil
        session.restart()
        syncBoard()
        scheduleOpponentReply()
    }

    func restartTutorial() {
        opponentTask?.cancel()
        rejectedSquare = nil
        session.restartTutorial()
        syncBoard()
        scheduleOpponentReply()
    }

    /// Long enough to read the explanation of the move just played before the reply lands.
    private var replyDelay: Duration {
        switch session.phase {
        case .whatIf: return session.cursor == 0 ? .milliseconds(900) : .milliseconds(1100)
        case .mainLine, .mainLineComplete, .completed: return .milliseconds(650)
        }
    }

    private func scheduleOpponentReply() {
        opponentTask?.cancel()
        guard session.isAwaitingOpponent else { return }
        let delay = replyDelay
        opponentTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.session.playOpponentMove()
            self.syncBoard()
            self.saveProgress()
            self.scheduleOpponentReply()
        }
    }

    private func syncBoard() {
        let last = session.lastMove.map { [$0.from, $0.to] } ?? []
        try? board.syncFen(session.fen, lastMove: last)
        var marks: [HighlightMark] = []
        if let squares = session.highlightedSquares {
            marks = [
                HighlightMark(square: squares.from, className: "focus"),
                HighlightMark(square: squares.to, className: "target"),
            ]
        }
        board.setConfig(highlightSquares: marks)
    }

    private func saveProgress() {
        let session = session
        let reachedWhatIf = session.phase != .mainLine
        store.update(opening.id) { progress in
            if reachedWhatIf { progress.mainLineCompleted = true }
            progress.completedVariationIds.formUnion(session.completedVariationIds)
            progress.bestPercent = max(progress.bestPercent ?? 0, session.progressPercent)
            if session.phase == .completed {
                progress.fewestMistakes = min(progress.fewestMistakes ?? .max, session.mistakes.count)
            }
        }
        progress = store.progress(for: opening.id)
    }
}
