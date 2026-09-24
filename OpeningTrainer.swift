import Combine
import Foundation

private struct LineSnapshot {
    var moveIndex: Int
    var fen: String
    var playedMoves: [String]
    var lastMove: [String]
}

@MainActor
final class OpeningTrainer: ObservableObject {
    let opening: OpeningCourse
    private let game: GameState
    let lines: [TrainingLine]
    @Published var board: PracticeBoard
    @Published var activeLine: TrainingLine
    @Published var moveIndex = 0
    @Published var playedMoves: [String] = []
    @Published var prompt = ""
    @Published var kicker = ""
    @Published var status = "Loading"
    @Published var statusDone = false
    @Published var feedback = ""
    @Published var feedbackKind = ""
    @Published var noteTitle = ""
    @Published var explanation = ""
    @Published var completions: [String: BranchCompletion] = [:]
    @Published private(set) var progress: OpeningProgressRecord
    private var currentFen: String
    private var currentLastMove: [String] = []
    private var cache: [String: [LineSnapshot]] = [:]
    private var generation = 0
    private let trainSide: String

    init(opening: OpeningCourse, game: GameState, requestedLineId: String?) {
        self.opening = opening
        self.game = game
        lines = opening.lines
        trainSide = opening.training.sideToTrain
        let stored = game.openingProgressRecord(for: opening.id)
        progress = stored
        completions = game.branchCompletionMap(for: opening.id)
        let starting = opening.training.startingFen == "startpos" ? ChessEngine.startingFen : opening.training.startingFen
        currentFen = starting
        let initial = lines.first { $0.id == requestedLineId }
            ?? lines.first { $0.id == stored.activeLineId }
            ?? lines[0]
        activeLine = initial
        board = PracticeBoard(fen: starting, mode: "lesson", orientation: trainSide == "black" ? "black" : "white")
        board.lockToAllowedMoves = true
        restore(initial)
        fastForwardToUserTurn()
        render(syncBoard: true)
        wireBoard()
        for line in lines where cache[line.id] == nil {
            cache[line.id] = buildCache(line)
        }
    }

    func loadBranch(_ line: TrainingLine) {
        guard line.id != activeLine.id else { return }
        generation += 1
        activeLine = line
        progress.activeLineId = line.id
        game.setActiveOpeningLine(openingId: opening.id, lineId: line.id)
        progress = game.openingProgressRecord(for: opening.id)
        restore(line)
        fastForwardToUserTurn()
        status = "Loading"
        statusDone = false
        noteTitle = line.title
        explanation = line.description.isEmpty ? "Follow the branch one move at a time." : line.description
        feedback = moveIndex >= line.moves.count
            ? "Branch complete. The final position has been restored."
            : "Branch loaded. Follow the coach prompts."
        feedbackKind = ""
        render(syncBoard: true)
    }

    func jump(to nextIndex: Int) {
        let bounded = max(0, min(nextIndex, activeLine.moves.count))
        guard bounded != moveIndex else { return }
        generation += 1
        applyCached(activeLine, targetIndex: bounded)
        game.saveOpeningLine(
            openingId: opening.id,
            line: activeLine,
            moveIndex: moveIndex,
            playedMoves: playedMoves,
            currentFen: currentFen,
            completed: moveIndex >= activeLine.moves.count
        )
        render(syncBoard: true)
        if bounded <= 0 { feedback = "Back to the start." }
        else if bounded >= activeLine.moves.count { feedback = "At the end of the line." }
        else { feedback = "Moved to a previous step." }
        feedbackKind = ""
    }

    func lineProgress(_ line: TrainingLine) -> Int {
        let total = line.moves.count
        if total == 0 { return 0 }
        let saved = progress.lines[line.id]?.moveIndex
        let active = line.id == activeLine.id ? moveIndex : 0
        let done = completions[line.id]?.completed == true
            ? total
            : max(0, min(saved ?? active, total))
        return Int((Double(done) / Double(total) * 100).rounded())
    }

    func moveState(line: TrainingLine, index: Int) -> String {
        let complete = completions[line.id]?.completed == true
        if line.id == activeLine.id {
            if index == moveIndex { return "active" }
            if complete || index < moveIndex { return "done" }
            return "upcoming"
        }
        return complete ? "done" : "upcoming"
    }

    func moveLabel(_ move: OpeningMove, index: Int) -> String {
        let number = index / 2 + 1
        let prefix = index % 2 == 0 ? "\(number)." : "\(number)..."
        return "\(prefix) \(move.san)"
    }

    private var userSettle: UInt64 { 250_000_000 }
    private var opponentSettle: UInt64 { 220_000_000 }

    private func wireBoard() {
        board.onMoveSuccess = { [weak self] payload in
            self?.handleUserMove(payload)
        }
        board.onMoveError = { [weak self] _, _ in
            guard let self else { return }
            self.feedback = "Try the highlighted move."
            self.feedbackKind = "error"
            self.queueReview()
        }
    }

    private func handleUserMove(_ payload: MovePayload) {
        let validation = ChessEngine.validateOpeningMove(
            startingFen: opening.training.startingFen,
            line: activeLine.moves.map(\.asLineMove),
            move: payload.move,
            moveIndex: moveIndex,
            playedMoves: playedMoves
        )
        if !validation.isValid {
            feedback = "Incorrect move."
            feedbackKind = "error"
            queueReview()
            try? board.syncFen(currentFen, lastMove: currentLastMove)
            return
        }
        if moveIndex < activeLine.moves.count {
            playedMoves.append(activeLine.moves[moveIndex].uci)
        }
        currentFen = validation.resultingFen ?? payload.fen
        currentLastMove = [String(payload.move.prefix(2)), String(payload.move.dropFirst(2).prefix(2))]
        feedback = "Correct."
        feedbackKind = "success"
        moveIndex += 1
        if moveIndex >= activeLine.moves.count {
            markComplete()
        }
        game.saveOpeningLine(
            openingId: opening.id,
            line: activeLine,
            moveIndex: moveIndex,
            playedMoves: playedMoves,
            currentFen: currentFen,
            completed: moveIndex >= activeLine.moves.count
        )
        render(syncBoard: false)
        let token = generation
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: self.userSettle)
            guard token == self.generation else { return }
            await self.autoPlay(token: token)
        }
    }

    private func autoPlay(token: Int) async {
        while moveIndex < activeLine.moves.count && !isUserMove(moveIndex) {
            guard token == generation else { return }
            let reply = activeLine.moves[moveIndex]
            status = "Coach move"
            statusDone = false
            prompt = "\(reply.san) is the reply"
            noteTitle = "Opponent plays \(reply.san)"
            explanation = reply.explanation
            board.setConfig(allowedMoves: [], lockToAllowedMoves: true, highlightSquares: moveHighlights(reply.uci))
            try? await Task.sleep(nanoseconds: userSettle)
            guard token == generation else { return }
            let data = board.playMove(reply.uci, suppressCallbacks: true, suppressComplete: true, promptPromotion: false)
            if !data.isValid {
                feedback = "Line paused."
                feedbackKind = "error"
                return
            }
            playedMoves.append(reply.uci)
            currentFen = data.resultingFen ?? currentFen
            currentLastMove = [String(reply.uci.prefix(2)), String(reply.uci.dropFirst(2).prefix(2))]
            moveIndex += 1
            if moveIndex >= activeLine.moves.count { markComplete() }
            game.saveOpeningLine(
                openingId: opening.id,
                line: activeLine,
                moveIndex: moveIndex,
                playedMoves: playedMoves,
                currentFen: currentFen,
                completed: moveIndex >= activeLine.moves.count
            )
            render(syncBoard: false)
            try? await Task.sleep(nanoseconds: opponentSettle)
        }
        guard token == generation else { return }
        render(syncBoard: false)
    }

    private func render(syncBoard: Bool) {
        if moveIndex >= activeLine.moves.count {
            prompt = "Line complete."
            kicker = "\(activeLine.title) · \(playedMoves.count)/\(activeLine.moves.count)"
            noteTitle = "Training complete"
            explanation = activeLine.completionMessage
                ?? "Great work. You handled this real-game branch. Pick another branch in the roadmap when you are ready."
            feedback = "Branch complete."
            feedbackKind = "success"
            status = "Complete"
            statusDone = true
            board.setConfig(allowedMoves: [], lockToAllowedMoves: true, highlightSquares: [])
            if syncBoard { try? board.syncFen(currentFen, lastMove: currentLastMove) }
            return
        }
        let expected = activeLine.moves[moveIndex]
        let userTurn = isUserMove(moveIndex)
        kicker = "\(activeLine.title) · move \(moveIndex + 1) of \(activeLine.moves.count)"
        if syncBoard { try? board.syncFen(currentFen, lastMove: currentLastMove) }
        if !userTurn {
            prompt = "Review \(expected.san)"
            noteTitle = "Opponent plays \(expected.san)"
            explanation = expected.explanation.isEmpty ? (activeLine.description.isEmpty ? "Step through the line with the sidebar or arrow keys." : activeLine.description) : expected.explanation
            status = "Preview"
            statusDone = false
            board.setConfig(mode: "lesson", allowedMoves: [], lockToAllowedMoves: true, highlightSquares: moveHighlights(expected.uci))
            return
        }
        prompt = "Play \(expected.san)"
        noteTitle = "Why \(expected.san)?"
        explanation = expected.explanation.isEmpty ? (activeLine.description.isEmpty ? "Make the recommended beginner move." : activeLine.description) : expected.explanation
        status = "Your move"
        statusDone = false
        board.setConfig(
            mode: "lesson",
            allowedMoves: [expected.uci],
            lockToAllowedMoves: true,
            successMessage: expected.explanation,
            errorMessage: "This line wants \(expected.san). Try the highlighted move.",
            highlightSquares: moveHighlights(expected.uci)
        )
    }

    private func markComplete() {
        var map = completions
        map[activeLine.id] = BranchCompletion(completed: true, completedAt: GameState.isoNow())
        completions = map
        game.markBranchComplete(opening: opening, line: activeLine)
        progress = game.openingProgressRecord(for: opening.id)
    }

    private func queueReview() {
        _ = game.recordReviewFailure(ReviewSeed(
            type: "opening",
            id: opening.id,
            branchId: activeLine.id,
            title: "\(opening.name): \(activeLine.title)",
            subtitle: activeLine.description.isEmpty ? opening.name : activeLine.description,
            href: "/openings/\(opening.id)/train?line=\(activeLine.id)"
        ))
    }

    private func restore(_ line: TrainingLine) {
        let states = ensureCache(line)
        if let saved = game.normalizedLineState(saved: progress.lines[line.id], line: line) {
            applyCached(line, targetIndex: saved.moveIndex, states: states)
            playedMoves = saved.playedMoves
            return
        }
        if completions[line.id]?.completed == true {
            applyCached(line, targetIndex: line.moves.count, states: states)
            game.saveOpeningLine(openingId: opening.id, line: line, moveIndex: moveIndex, playedMoves: playedMoves, currentFen: currentFen, completed: true)
            return
        }
        applyCached(line, targetIndex: 0, states: states)
    }

    private func fastForwardToUserTurn() {
        var target = moveIndex
        while target < activeLine.moves.count && !isUserMove(target) { target += 1 }
        if target != moveIndex { applyCached(activeLine, targetIndex: target) }
    }

    private func ensureCache(_ line: TrainingLine) -> [LineSnapshot] {
        if let existing = cache[line.id] { return existing }
        let built = buildCache(line)
        cache[line.id] = built
        return built
    }

    private func buildCache(_ line: TrainingLine) -> [LineSnapshot] {
        let start = opening.training.startingFen == "startpos" ? ChessEngine.startingFen : opening.training.startingFen
        guard let engine = try? ChessEngine(fen: start) else { return [] }
        var states = [LineSnapshot(moveIndex: 0, fen: start, playedMoves: [], lastMove: [])]
        var played: [String] = []
        for move in line.moves {
            let promotion = move.uci.count > 4 ? String(move.uci.dropFirst(4).prefix(1)) : nil
            guard engine.move(from: String(move.uci.prefix(2)), to: String(move.uci.dropFirst(2).prefix(2)), promotion: promotion) != nil else {
                feedback = "Could not precompute \(line.title)."
                feedbackKind = "error"
                break
            }
            played.append(move.uci)
            states.append(LineSnapshot(
                moveIndex: played.count,
                fen: engine.fen(),
                playedMoves: played,
                lastMove: [String(move.uci.prefix(2)), String(move.uci.dropFirst(2).prefix(2))]
            ))
        }
        return states
    }

    private func applyCached(_ line: TrainingLine, targetIndex: Int, states: [LineSnapshot]? = nil) {
        let bounded = max(0, min(targetIndex, line.moves.count))
        let states = states ?? cache[line.id] ?? ensureCache(line)
        guard states.indices.contains(bounded) else {
            moveIndex = 0
            playedMoves = []
            currentFen = opening.training.startingFen == "startpos" ? ChessEngine.startingFen : opening.training.startingFen
            currentLastMove = []
            return
        }
        let state = states[bounded]
        moveIndex = state.moveIndex
        playedMoves = state.playedMoves
        currentFen = state.fen
        currentLastMove = state.lastMove
    }

    private func isUserMove(_ index: Int) -> Bool {
        trainSide == "black" ? index % 2 == 1 : index % 2 == 0
    }

    private func moveHighlights(_ uci: String) -> [HighlightMark] {
        [
            HighlightMark(square: String(uci.prefix(2)), className: "focus"),
            HighlightMark(square: String(uci.dropFirst(2).prefix(2)), className: "target"),
        ]
    }
}
