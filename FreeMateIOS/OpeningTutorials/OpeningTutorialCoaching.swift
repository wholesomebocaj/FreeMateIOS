import Foundation

struct TutorialMessage: Equatable {
    enum Tone: Equatable {
        case neutral
        case success
        /// A gentle nudge after a mistake, never an alarm.
        case hint
    }

    var title: String
    var body: String
    var tone: Tone = .neutral
}

extension OpeningTutorialSession {
    var stageLabel: String {
        switch phase {
        case .mainLine: return "Step 1 · Main line"
        case .mainLineComplete: return "Step 1 complete"
        case .whatIf: return "Step 2 · What if?"
        case .completed: return "Tutorial complete"
        }
    }

    /// Progress through the whole tutorial, from 0 to 100.
    var progressPercent: Int {
        let total = mainLineUserMoveCount + opening.variations.count
        guard total > 0 else { return 0 }
        let done = mainLineUserMovesPlayed + completedVariationIds.count
        return Int((Double(done) / Double(total) * 100).rounded())
    }

    /// What the coach says about the position on the board right now.
    var coachMessage: TutorialMessage {
        let opponent = opening.opponentSide.label
        switch phase {
        case .mainLine:
            if let move = expectedUserMove {
                return TutorialMessage(title: "Play \(move.moveNumberLabel): \(move.step.title)", body: move.step.explanation)
            }
            return TutorialMessage(title: "\(opponent) to move", body: "Watch the reply, then it is your turn again.")
        case .mainLineComplete:
            return TutorialMessage(
                title: "You know the main line",
                body: "Next, \(opponent) will try other moves. Answer each one without the highlighted squares.",
                tone: .success
            )
        case .whatIf:
            guard let variation = currentVariation else { return TutorialMessage(title: "", body: "") }
            let heading = "What if: \(variation.name)"
            if isCurrentLineComplete {
                return TutorialMessage(title: heading, body: lastMove?.step.explanation ?? variation.summary, tone: .success)
            }
            if expectedUserMove != nil, let last = lastMove {
                return TutorialMessage(title: heading, body: "\(opponent) played \(last.moveNumberLabel). \(last.step.explanation) How do you answer?")
            }
            return TutorialMessage(title: heading, body: variation.summary)
        case .completed:
            let count = mistakes.count
            let summary = count == 0 ? "No mistakes. Great memory." : "\(count) mistake\(count == 1 ? "" : "s") along the way. Replay any time to tidy them up."
            return TutorialMessage(title: "\(opening.name) complete", body: summary, tone: .success)
        }
    }

    /// Short feedback on the last thing that happened, or nil when there is nothing new to say.
    var feedbackMessage: TutorialMessage? {
        switch feedback {
        case .none, .opponentMoved, .mainLineComplete, .tutorialComplete:
            return nil
        case .correct(let move):
            let body = phase == .whatIf ? move.step.explanation : "Correct."
            return TutorialMessage(title: "\(move.san) is right", body: body, tone: .success)
        case .incorrect(let mistake):
            let title = mistake.kind == .illegalMove
                ? "That move is not legal here"
                : "\(mistake.attempted) is not the move in this line"
            return TutorialMessage(title: title, body: mistake.hint, tone: .hint)
        case .variationComplete(let variation):
            let next = hasMoreVariations ? "Ready for the next one?" : "That was the last one."
            return TutorialMessage(title: "You handled the \(variation.name)", body: next, tone: .success)
        }
    }
}
