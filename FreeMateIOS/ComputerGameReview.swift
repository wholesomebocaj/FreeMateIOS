import Combine
import Foundation

/// Grades the learner's moves in a finished game, one move at a time off the main thread, and
/// steps a read-only board through the game.
@MainActor
final class ComputerGameReview: ObservableObject {
    let positions: [String]
    let moves: [String]
    let sans: [String]
    let learner: ChessColor
    let board: PracticeBoard

    @Published private(set) var reviewed: [Int: ReviewedMove] = [:]
    @Published private(set) var isFinished = false
    /// The move on the board, as an index into `moves`, or nil for the starting position.
    @Published private(set) var selectedPly: Int?
    /// Shows the position before the selected move, with the better move marked.
    @Published private(set) var showsBetterMove = false

    private var task: Task<Void, Never>?

    /// The learner's moves as indexes into `moves`.
    var learnerPlies: [Int] {
        moves.indices.filter { ($0 % 2 == 0) == (learner == .white) }
    }

    var progress: Double {
        learnerPlies.isEmpty ? 1 : Double(reviewed.count) / Double(learnerPlies.count)
    }

    var selectedReview: ReviewedMove? { selectedPly.flatMap { reviewed[$0] } }

    func count(_ quality: ReviewedMove.Quality) -> Int {
        reviewed.values.filter { $0.quality == quality }.count
    }

    init(game: ComputerGame) {
        positions = game.positions
        moves = game.board.history.map(\.move)
        sans = game.board.history.map(\.san)
        learner = game.learner
        board = PracticeBoard(fen: game.board.initialFen, orientation: game.learner.rawValue)
        select(moves.isEmpty ? nil : moves.count - 1)
    }

    func start() {
        guard task == nil else { return }
        let positions = positions
        let moves = moves
        let plies = learnerPlies
        task = Task { [weak self] in
            for ply in plies {
                let review = await Task.detached(priority: .userInitiated) {
                    ComputerCoach.review(ply: ply, positions: positions, moves: moves)
                }.value
                guard let self, !Task.isCancelled else { return }
                if let review { self.reviewed[ply] = review }
                if ply == self.selectedPly { self.select(ply) }
            }
            self?.isFinished = true
        }
    }

    func stop() {
        task?.cancel()
    }

    func select(_ ply: Int?) {
        selectedPly = ply.map { max(0, min($0, moves.count - 1)) }
        showsBetterMove = false
        showPosition()
    }

    func step(_ offset: Int) {
        let next = (selectedPly ?? -1) + offset
        select(next < 0 ? nil : next)
    }

    /// The next of the learner's moves graded a mistake or a blunder, wrapping around.
    func selectNextMistake() {
        let mistakes = learnerPlies.filter { (reviewed[$0]?.quality ?? .best) >= .mistake }
        guard !mistakes.isEmpty else { return }
        select(mistakes.first { $0 > (selectedPly ?? -1) } ?? mistakes[0])
    }

    func toggleBetterMove() {
        guard selectedReview?.betterMove != nil else { return }
        showsBetterMove.toggle()
        showPosition()
    }

    private func showPosition() {
        guard let ply = selectedPly else {
            try? board.syncFen(positions[0])
            board.setConfig(highlightSquares: [])
            return
        }
        if showsBetterMove, let better = selectedReview?.betterMove {
            try? board.syncFen(positions[ply])
            board.setConfig(highlightSquares: [
                HighlightMark(square: String(better.prefix(2)), className: "focus"),
                HighlightMark(square: String(better.dropFirst(2).prefix(2)), className: "target"),
            ])
        } else {
            let move = moves[ply]
            try? board.syncFen(positions[ply + 1], lastMove: [String(move.prefix(2)), String(move.dropFirst(2).prefix(2))])
            board.setConfig(highlightSquares: [])
        }
    }
}
