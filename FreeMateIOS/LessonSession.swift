import Combine
import Foundation

@MainActor
final class LessonSession: ObservableObject {
    let lesson: Lesson
    private let game: GameState
    @Published var index = 0
    @Published var completedSteps = Set<Int>()
    @Published var feedback = ""
    @Published var feedbackKind = ""
    @Published var foundSquares = Set<String>()
    @Published var board: PracticeBoard?
    @Published var finished = false
    @Published var scaffold = false
    private var autoTask: Task<Void, Never>?

    init(lesson: Lesson, game: GameState) {
        self.lesson = lesson
        self.game = game
        start()
    }

    var step: LessonStep? {
        lesson.steps.indices.contains(index) ? lesson.steps[index] : nil
    }

    var nextTitle: String {
        index == lesson.steps.count - 1 ? "Finish" : "Next"
    }

    var canAdvance: Bool { completedSteps.contains(index) }

    func start() {
        if lesson.steps.isEmpty {
            scaffold = true
            finished = true
            return
        }
        showCurrentStep()
    }

    func goBack() {
        guard index > 0 else { return }
        index -= 1
        showCurrentStep()
    }

    func goForward() {
        guard completedSteps.contains(index) else { return }
        index += 1
        if index >= lesson.steps.count {
            finished = true
            board = nil
            game.markLessonComplete(lesson)
            return
        }
        showCurrentStep()
    }

    func choose(_ choice: LessonChoice) {
        guard let step else { return }
        let correct = step.correctChoice
        let isCorrect = choice.value == correct
        if isCorrect {
            showFeedback(step.successText ?? "Correct.", kind: "success")
            markComplete(step)
        } else {
            showFeedback(step.errorText ?? "Not quite. Try again.", kind: "error")
            recordFailure(step)
        }
    }

    func clickSquare(_ square: String) {
        guard let step else { return }
        if step.type == "click-all-squares" {
            handleClickAll(square, step: step)
            return
        }
        guard let target = step.targetSquare else { return }
        if square == target {
            showFeedback(step.successText ?? "Correct. \(square.uppercased()) is the target square.", kind: "success")
            markComplete(step)
        } else {
            showFeedback(step.errorText ?? "Try again. Click \(target.uppercased()).", kind: "error")
            recordFailure(step)
        }
    }

    private func showCurrentStep() {
        autoTask?.cancel()
        feedback = ""
        feedbackKind = ""
        foundSquares = []
        guard let step else { return }
        let config = boardConfig(step)
        let needsBoard = config != nil && (step.type != "multiple-choice" || step.board || step.type == "explain" || step.type == "checklist")
        if needsBoard, let config {
            let practice = PracticeBoard(fen: config.fen, mode: "lesson", orientation: config.orientation)
            practice.setConfig(
                mode: "lesson",
                objective: config.objective,
                allowedMoves: config.allowedMoves,
                solutionMoves: config.solutionMoves,
                lockToAllowedMoves: config.lockToAllowedMoves,
                highlightLegalMoves: true,
                successMessage: step.successText ?? config.successMessage,
                errorMessage: config.errorMessage,
                highlightSquares: config.highlights
            )
            practice.onSquareSelect = { [weak self] square in
                guard let self, let current = self.step, ["square-click", "click-all-squares"].contains(current.type) else { return }
                self.clickSquare(square)
            }
            practice.onMoveSuccess = { [weak self] payload in
                self?.showFeedback(payload.message, kind: "success")
                if let current = self?.step { self?.markComplete(current) }
            }
            practice.onMoveError = { [weak self] _, message in
                self?.showFeedback(message, kind: "error")
                if let current = self?.step { self?.recordFailure(current) }
            }
            practice.onComplete = { [weak self] _ in
                guard let self, let current = self.step else { return }
                if current.type != "square-click" && current.type != "click-all-squares" {
                    self.markComplete(current)
                }
            }
            board = practice
        } else {
            board = nil
        }
        if shouldAutoComplete(step) {
            let stepIndex = index
            autoTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard !Task.isCancelled, self.index == stepIndex, !self.completedSteps.contains(stepIndex) else { return }
                self.markComplete(step)
            }
        }
    }

    private func handleClickAll(_ square: String, step: LessonStep) {
        let targets = Set(step.targetSquares)
        guard !targets.isEmpty else { return }
        if targets.contains(square) {
            foundSquares.insert(square)
            let updated = step.highlightSquares.map {
                HighlightMark(square: $0.square, className: foundSquares.contains($0.square) ? "correct" : $0.className)
            }
            board?.setConfig(highlightSquares: updated)
            if foundSquares.count == targets.count {
                showFeedback(step.successText ?? "Great job. You found them all.", kind: "success")
                markComplete(step)
            } else {
                showFeedback("Good. \(foundSquares.count) of \(targets.count) squares found.", kind: "success")
            }
            return
        }
        showFeedback(step.errorText ?? "Not quite. Try another highlighted square.", kind: "error")
        recordFailure(step)
    }

    private func markComplete(_ step: LessonStep) {
        if step.completeOnSuccess == false { return }
        completedSteps.insert(index)
        objectWillChange.send()
    }

    private func recordFailure(_ step: LessonStep) {
        _ = game.recordReviewFailure(ReviewSeed(
            type: "lesson",
            id: lesson.id,
            branchId: nil,
            title: lesson.title,
            subtitle: step.title.isEmpty ? "Lesson practice" : "Missed: \(step.title)",
            href: "/lessons/\(lesson.id)"
        ))
    }

    private func showFeedback(_ message: String, kind: String) {
        feedback = message
        feedbackKind = kind
    }

    private func shouldAutoComplete(_ step: LessonStep) -> Bool {
        ["explain", "board-demo", "highlight-demo"].contains(step.type) && step.completeOnSuccess != false
    }

    private struct BoardSetup {
        var fen: String
        var objective: String
        var highlights: [HighlightMark]
        var allowedMoves: [String]
        var lockToAllowedMoves: Bool
        var successMessage: String
        var errorMessage: String
        var orientation: String
        var solutionMoves: [String]
    }

    private func boardConfig(_ step: LessonStep) -> BoardSetup? {
        let interactive = [
            "explain", "checklist", "board-demo", "highlight-demo", "move-task", "capture-task",
            "tactic-task", "board-task", "attack-visualization", "guided-puzzle", "rook-practice",
            "rook-challenge", "click-all-squares", "square-click", "move-validation", "multiple-choice",
        ].contains(step.type)
        if !interactive { return nil }
        if step.type == "multiple-choice" && !step.board && step.fen == nil { return nil }
        if step.type == "explain" || step.type == "checklist" {
            if step.fen == nil && lessonBase(lesson.id) == nil && step.highlightSquares.isEmpty { return nil }
        }
        let base = lessonBase(lesson.id)
        let highlights = step.highlightSquares.isEmpty ? (base?.highlights ?? []) : step.highlightSquares
        let allowed = resolvedAllowedMoves(step, base: base, highlights: highlights)
        return BoardSetup(
            fen: step.fen ?? base?.fen ?? ChessEngine.startingFen,
            objective: step.objective ?? (step.title.isEmpty ? nil : step.title) ?? base?.objective ?? lesson.title,
            highlights: highlights,
            allowedMoves: allowed,
            lockToAllowedMoves: step.lockToAllowedMoves ?? base?.lock ?? !allowed.isEmpty,
            successMessage: step.successText ?? base?.success ?? "Correct.",
            errorMessage: step.errorText ?? base?.error ?? "Try another legal move from this position.",
            orientation: step.orientation ?? "white",
            solutionMoves: step.solutionMoves
        )
    }

    private func resolvedAllowedMoves(_ step: LessonStep, base: LessonBase?, highlights: [HighlightMark]) -> [String] {
        if !step.allowedMoves.isEmpty { return step.allowedMoves }
        if let allowed = base?.allowed, !allowed.isEmpty { return allowed }
        if let start = step.startSquare, let target = step.targetSquare { return ["\(start)\(target)"] }
        if let start = step.startSquare, !highlights.isEmpty {
            return highlights.map { "\(start)\($0.square)" }
        }
        return []
    }

    private struct LessonBase {
        var fen: String?
        var objective: String?
        var allowed: [String]?
        var highlights: [HighlightMark]?
        var success: String?
        var error: String?
        var lock: Bool?
    }

    private func lessonBase(_ id: String) -> LessonBase? {
        switch id {
        case "naming-squares":
            return LessonBase(fen: ChessEngine.emptyFen, objective: "Find the target square on the board.")
        case "rook-from-d4":
            let squares = rookSquares("d4")
            return LessonBase(
                fen: "7k/8/8/8/3R4/8/8/7K w - - 0 1",
                objective: "Move the rook along a rank or file.",
                allowed: squares.map { "d4\($0)" },
                highlights: squares.map { HighlightMark(square: $0, className: "focus") },
                success: "Correct! Rooks move in straight lines.",
                error: "Try again. Rooks can only move horizontally or vertically."
            )
        case "bishop-movement":
            let squares = bishopSquares("d4")
            return LessonBase(fen: "k7/8/8/8/3B4/8/8/7K w - - 0 1", objective: "Move the bishop along a diagonal.", allowed: squares.map { "d4\($0)" }, highlights: squares.map { HighlightMark(square: $0, className: "focus") }, success: "Correct! Bishops move diagonally.", error: "Try again. Bishops stay on diagonals.")
        case "knight-movement":
            let squares = knightSquares("d4")
            return LessonBase(fen: "k7/8/8/8/3N4/8/8/7K w - - 0 1", objective: "Move the knight in an L shape.", allowed: squares.map { "d4\($0)" }, highlights: squares.map { HighlightMark(square: $0, className: "target") }, success: "Correct! Knights jump in an L shape.", error: "Try again. Knights move two squares and then one.")
        case "queen-movement":
            let squares = queenSquares("d4")
            return LessonBase(fen: "k7/8/8/8/3Q4/8/8/7K w - - 0 1", objective: "Move the queen on a straight or diagonal line.", allowed: squares.map { "d4\($0)" }, highlights: squares.map { HighlightMark(square: $0, className: "focus") }, success: "Correct! Queens combine rook and bishop movement.", error: "Try again. Queens move on ranks, files, or diagonals.")
        case "first-opening-move":
            return LessonBase(
                fen: ChessEngine.startingFen,
                objective: "Choose a principled legal first move.",
                allowed: ["e2e4", "d2d4", "c2c4", "g1f3"],
                highlights: ["d4", "e4", "d5", "e5"].map { HighlightMark(square: $0, className: "target") },
                success: "Good first move. You are fighting for the center or developing a piece.",
                error: "Try e2e4, d2d4, c2c4, or g1f3."
            )
        case "checkmate-vs-stalemate":
            return LessonBase(fen: "7k/6Q1/5K2/8/8/8/8/8 b - - 0 1", objective: "Identify the type of ending.", success: "Correct.", error: "Try again.")
        case "checks-captures-threats":
            return LessonBase(fen: "k7/8/8/3q4/8/8/4K3/8 w - - 0 1", objective: "Spot the opponent's forcing move.", highlights: [HighlightMark(square: "d5", className: "danger"), HighlightMark(square: "e2", className: "focus")], success: "Good. You found the forcing idea.", error: "Not quite. Try again.")
        case "find-the-fork-idea":
            return LessonBase(fen: "8/6k1/8/8/3N4/4q3/8/K7 w - - 0 1", objective: "Notice how one piece can attack two targets at once.", allowed: ["d4f5"], highlights: [HighlightMark(square: "f5", className: "target"), HighlightMark(square: "g7", className: "danger"), HighlightMark(square: "e3", className: "danger")], success: "Nice. That's the kind of move that creates a fork.", error: "Try again. Look for the move that attacks both targets.")
        default:
            return nil
        }
    }
}

private let lessonFiles = Array("abcdefgh")

private func rookSquares(_ from: String) -> [String] {
    let file = from.first!
    let rank = Int(String(from.dropFirst())) ?? 0
    let ranks = (1...8).map { "\(file)\($0)" }
    let files = lessonFiles.map { "\($0)\(rank)" }
    return (files + ranks).filter { $0 != from }
}

private func bishopSquares(_ from: String) -> [String] {
    raySquares(from, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)])
}

private func queenSquares(_ from: String) -> [String] {
    rookSquares(from) + bishopSquares(from)
}

private func knightSquares(_ from: String) -> [String] {
    guard let fileIndex = lessonFiles.firstIndex(of: from.first!), let rank = Int(String(from.dropFirst())) else { return [] }
    return [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)].compactMap { delta in
        let file = fileIndex + delta.0
        let nextRank = rank + delta.1
        guard lessonFiles.indices.contains(file), (1...8).contains(nextRank) else { return nil }
        return "\(lessonFiles[file])\(nextRank)"
    }
}

private func raySquares(_ from: String, directions: [(Int, Int)]) -> [String] {
    guard let startFile = lessonFiles.firstIndex(of: from.first!), let startRank = Int(String(from.dropFirst())) else { return [] }
    var squares: [String] = []
    for (fileDelta, rankDelta) in directions {
        var file = startFile + fileDelta
        var rank = startRank + rankDelta
        while lessonFiles.indices.contains(file), (1...8).contains(rank) {
            squares.append("\(lessonFiles[file])\(rank)")
            file += fileDelta
            rank += rankDelta
        }
    }
    return squares
}
