import Combine
import Foundation

/// A game against `ComputerOpponent` on the shared `PracticeBoard`.
///
/// The learner's moves play on the board as usual. After each one, the computer searches off
/// the main thread and its reply is played back onto the board.
@MainActor
final class ComputerGame: ObservableObject {
    static let levelKey = "freemate.computerLevel"
    static let recordKey = "freemate.computerGames"

    @Published private(set) var learner: ChessColor = .white
    @Published private(set) var isThinking = false
    @Published private(set) var result: ComputerGameResult?
    @Published private(set) var record: ComputerGameRecord
    @Published var level: ComputerLevel {
        didSet { defaults.set(level.rawValue, forKey: Self.levelKey) }
    }

    let board = PracticeBoard()
    /// Pause before the reply so the learner sees their own move land first.
    var thinkingDelay = Duration.milliseconds(350)
    private let defaults: UserDefaults
    private var thinkTask: Task<Void, Never>?
    private var boardChanges: AnyCancellable?

    var isLearnersTurn: Bool { board.turn == learner.rawValue }
    var canMove: Bool { result == nil && !isThinking && isLearnersTurn }
    var canUndo: Bool { result == nil && !isThinking && board.history.contains { $0.index % 2 == learnerParity } }
    /// History index parity of the learner's moves. White plays moves 1, 3, 5, and so on.
    private var learnerParity: Int { learner == .white ? 1 : 0 }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        level = defaults.string(forKey: Self.levelKey).flatMap(ComputerLevel.init(rawValue:)) ?? .easy
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

    func newGame(as color: ChessColor) {
        thinkTask?.cancel()
        isThinking = false
        result = nil
        learner = color
        try? board.loadFen(ChessEngine.startingFen, setInitial: true, clearHistory: true)
        board.orientation = color.rawValue
        board.feedback = ""
        scheduleReply()
    }

    /// Takes back the learner's last move and the computer's reply to it.
    func undo() {
        guard canUndo else { return }
        thinkTask?.cancel()
        var moves = board.history.map(\.move)
        if let last = board.history.last, last.index % 2 != learnerParity { moves.removeLast() }
        moves.removeLast()
        let start = board.initialFen
        try? board.loadFen(start, clearHistory: true)
        for move in moves {
            board.playMove(move, suppressCallbacks: true, promptPromotion: false)
        }
        board.feedback = ""
        result = nil
    }

    func resign() {
        guard result == nil, !board.history.isEmpty else { return }
        thinkTask?.cancel()
        isThinking = false
        finish(.resigned)
    }

    private func learnerMoved() {
        board.feedback = ""
        if !checkForResult() { scheduleReply() }
    }

    private func scheduleReply() {
        guard result == nil, !isLearnersTurn else { return }
        let fen = board.fen
        let level = level
        let delay = thinkingDelay
        isThinking = true
        thinkTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
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

    @discardableResult
    private func checkForResult() -> Bool {
        let positions = [board.initialFen] + board.history.map(\.fen)
        guard let result = ComputerGameResult.of(positions: positions, learner: learner) else { return false }
        finish(result)
        return true
    }

    private func finish(_ result: ComputerGameResult) {
        self.result = result
        board.selectedSquare = nil
        board.legalDestinations = []
        record.add(result)
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Self.recordKey)
        }
    }
}
