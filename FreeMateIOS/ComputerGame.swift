import Combine
import Foundation

/// A game against `ComputerOpponent` on the shared `PracticeBoard`.
///
/// The learner's moves play on the board as usual. After each one, `ComputerCoach` checks it
/// for a blunder (when warnings are on), then the computer searches off the main thread and
/// its reply is played back onto the board.
@MainActor
final class ComputerGame: ObservableObject {
    static let levelKey = "freemate.computerLevel"
    static let recordKey = "freemate.computerGames"
    static let warningsKey = "freemate.blunderWarnings"

    @Published private(set) var learner: ChessColor = .white
    @Published private(set) var isThinking = false
    @Published private(set) var isFindingHint = false
    @Published private(set) var result: ComputerGameResult?
    @Published private(set) var record: ComputerGameRecord
    /// The learner's last move looks like a blunder. The computer waits until they take it
    /// back or play on.
    @Published private(set) var warning: MoveWarning?
    @Published var level: ComputerLevel {
        didSet { defaults.set(level.rawValue, forKey: Self.levelKey) }
    }
    @Published var warnsAboutBlunders: Bool {
        didSet { defaults.set(warnsAboutBlunders, forKey: Self.warningsKey) }
    }

    let board = PracticeBoard()
    /// Pause before the reply so the learner sees their own move land first.
    var thinkingDelay = Duration.milliseconds(350)
    private let defaults: UserDefaults
    private var thinkTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    private var boardChanges: AnyCancellable?

    var isLearnersTurn: Bool { board.turn == learner.rawValue }
    var canMove: Bool { result == nil && !isThinking && warning == nil && isLearnersTurn }
    var canUndo: Bool {
        result == nil && !isThinking && warning == nil && board.history.contains { $0.index % 2 == learnerParity }
    }
    var canHint: Bool { canMove && !isFindingHint }
    /// History index parity of the learner's moves. White plays moves 1, 3, 5, and so on.
    private var learnerParity: Int { learner == .white ? 1 : 0 }

    /// The start, then one FEN per move, for `ComputerGameResult` and the review.
    var positions: [String] { [board.initialFen] + board.history.map(\.fen) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        level = defaults.string(forKey: Self.levelKey).flatMap(ComputerLevel.init(rawValue:)) ?? .easy
        warnsAboutBlunders = defaults.object(forKey: Self.warningsKey) as? Bool ?? true
        if let data = defaults.data(forKey: Self.recordKey),
           let saved = try? JSONDecoder().decode(ComputerGameRecord.self, from: data) {
            record = saved
        } else {
            record = ComputerGameRecord()
        }
        board.onMoveSuccess = { [weak self] _ in self?.learnerMoved() }
        // Turn and history live on the board, so views of the game refresh with it.
        boardChanges = board.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
    }

    /// Starts a game. A custom `fen` must have White to move, since move parity follows White.
    func newGame(as color: ChessColor, from fen: String = ChessEngine.startingFen) {
        cancelTasks()
        result = nil
        warning = nil
        learner = color
        try? board.loadFen(fen, setInitial: true, clearHistory: true)
        board.orientation = color.rawValue
        board.feedback = ""
        clearMarks()
        scheduleReply(checkingLearnersMove: false)
    }

    /// Takes back the learner's last move and the computer's reply to it.
    func undo() {
        guard canUndo else { return }
        cancelTasks()
        let last = board.history.last
        rewind(last.map { $0.index % 2 != learnerParity } == true ? 2 : 1)
    }

    /// Takes back the move the warning is about.
    func takeBackWarnedMove() {
        guard warning != nil else { return }
        warning = nil
        rewind(1)
    }

    /// Plays on after a warning.
    func ignoreWarning() {
        guard warning != nil else { return }
        warning = nil
        clearMarks()
        scheduleReply(checkingLearnersMove: false)
    }

    func resign() {
        guard result == nil, !board.history.isEmpty else { return }
        cancelTasks()
        warning = nil
        finish(.resigned)
    }

    /// Marks the coach's best move on the board.
    func showHint() {
        guard canHint else { return }
        let fen = board.fen
        isFindingHint = true
        hintTask = Task { [weak self] in
            let move = await Task.detached(priority: .userInitiated) {
                ComputerCoach.bestMove(fen: fen)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.isFindingHint = false
            guard let move, self.board.fen == fen else { return }
            self.board.setConfig(highlightSquares: [
                HighlightMark(square: String(move.prefix(2)), className: "focus"),
                HighlightMark(square: String(move.dropFirst(2).prefix(2)), className: "target"),
            ])
        }
    }

    private func learnerMoved() {
        board.feedback = ""
        clearMarks()
        if !checkForResult() { scheduleReply(checkingLearnersMove: warnsAboutBlunders) }
    }

    private func scheduleReply(checkingLearnersMove: Bool) {
        guard result == nil, !isLearnersTurn else { return }
        let fen = board.fen
        let previous = board.history.dropLast().last?.fen ?? board.initialFen
        let learnersMove = board.history.last?.move
        let level = level
        let delay = thinkingDelay
        isThinking = true
        thinkTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            if checkingLearnersMove, let learnersMove {
                let warning = await Task.detached(priority: .userInitiated) {
                    ComputerCoach.warning(fen: previous, move: learnersMove)
                }.value
                guard let self, !Task.isCancelled, self.board.fen == fen else { return }
                if let warning {
                    self.isThinking = false
                    self.warning = warning
                    if let square = warning.square {
                        self.board.setConfig(highlightSquares: [HighlightMark(square: square, className: "danger")])
                    }
                    return
                }
            }
            let move = await Task.detached(priority: .userInitiated) {
                ComputerOpponent.chooseMove(fen: fen, level: level)
            }.value
            guard let self, !Task.isCancelled, self.board.fen == fen else { return }
            self.isThinking = false
            guard let move else { return }
            self.board.playMove(move, suppressCallbacks: true, promptPromotion: false)
            self.checkForResult()
        }
    }

    private func rewind(_ count: Int) {
        let moves = board.history.map(\.move).dropLast(count)
        try? board.loadFen(board.initialFen, clearHistory: true)
        for move in moves {
            board.playMove(move, suppressCallbacks: true, promptPromotion: false)
        }
        board.feedback = ""
        clearMarks()
        result = nil
    }

    private func cancelTasks() {
        thinkTask?.cancel()
        hintTask?.cancel()
        isThinking = false
        isFindingHint = false
    }

    private func clearMarks() {
        board.setConfig(highlightSquares: [])
    }

    @discardableResult
    private func checkForResult() -> Bool {
        guard let result = ComputerGameResult.of(positions: positions, learner: learner) else { return false }
        finish(result)
        return true
    }

    private func finish(_ result: ComputerGameResult) {
        self.result = result
        board.selectedSquare = nil
        board.legalDestinations = []
        clearMarks()
        record.add(result)
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Self.recordKey)
        }
    }
}
