import Combine
import Foundation

/// Connects an `OpeningTutorialSession` to the shared `PracticeBoard`.
///
/// The board forwards every move attempt here instead of playing it. Correct moves are synced
/// back to the board; wrong ones never land, so the piece stays on its square while the
/// attempted squares flash and a hint appears.
@MainActor
final class OpeningTutorialController: ObservableObject {
    @Published private(set) var session: OpeningTutorialSession
    @Published private(set) var progress: OpeningTutorialProgress
    /// Increments on every rejected move so the view can play a short shake.
    @Published private(set) var rejectionCount = 0

    let board: PracticeBoard
    private let store: OpeningTutorialProgressStore
    private var opponentTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?

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
            syncBoard()
            saveProgress()
            scheduleOpponentReply()
        case .incorrect:
            rejectionCount += 1
            flashRejected(from: from, to: to)
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

    func restart() {
        opponentTask?.cancel()
        flashTask?.cancel()
        session.restart()
        syncBoard()
        scheduleOpponentReply()
    }

    private func scheduleOpponentReply() {
        opponentTask?.cancel()
        guard session.isAwaitingOpponent else { return }
        opponentTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard let self, !Task.isCancelled else { return }
            self.session.playOpponentMove()
            self.syncBoard()
            self.saveProgress()
            self.scheduleOpponentReply()
        }
    }

    private func flashRejected(from: String, to: String) {
        flashTask?.cancel()
        board.setConfig(highlightSquares: [
            HighlightMark(square: from, className: "danger"),
            HighlightMark(square: to, className: "danger"),
        ])
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled else { return }
            self.syncBoard()
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
            if session.phase == .completed {
                progress.fewestMistakes = min(progress.fewestMistakes ?? .max, session.mistakes.count)
            }
        }
        progress = store.progress(for: opening.id)
    }
}
