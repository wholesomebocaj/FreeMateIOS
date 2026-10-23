import Foundation

/// What the floating instruction card shows.
struct TutorialCardContent: Equatable {
    enum Style: Equatable {
        case guide
        case waiting
        case branching
        /// A gentle nudge after a mistake, never an alarm.
        case hint
        case success
    }

    enum Action: Equatable {
        case startBranching
        case nextVariation
        case finish
    }

    /// Changes when the card should slide in fresh (new phase or variation). Within a scene,
    /// only the text cross-fades.
    var sceneID: String
    var style: Style
    var symbol: String
    var eyebrow: String
    var title: String
    var message: String
    var detail: String?
    var action: Action?
    var showsHintButton = false

    var actionTitle: String? {
        switch action {
        case .startBranching: return "Branch Out"
        case .nextVariation: return "Next Variation"
        case .finish: return "Finish Tutorial"
        case nil: return nil
        }
    }
}

struct TutorialProgressSummary: Equatable {
    var title: String
    var detail: String
    var fraction: Double
    /// A quiet line under the bar, such as the variation being practised.
    var caption: String?
}

struct TutorialCompletionStats: Equatable {
    var mainLineMoves: Int
    var variations: Int
    var mistakes: Int
    /// Correct moves as a share of all attempts, from 0 to 100.
    var accuracy: Int
}

enum TutorialMasteryStatus: Equatable {
    case notStarted
    case inProgress(percent: Int)
    case mastered

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress(let percent): return "In Progress · \(percent)%"
        case .mastered: return "Mastered"
        }
    }

    var symbol: String {
        switch self {
        case .notStarted: return "circle.dashed"
        case .inProgress: return "circle.lefthalf.filled"
        case .mastered: return "checkmark.seal.fill"
        }
    }
}

extension OpeningTutorialProgress {
    func status(for opening: ChessOpening) -> TutorialMasteryStatus {
        let variationIds = Set(opening.variations.map(\.id))
        let doneVariations = completedVariationIds.intersection(variationIds).count
        if mainLineCompleted && doneVariations == variationIds.count { return .mastered }
        let total = opening.userMoveCountInMainLine + variationIds.count
        let saved = (mainLineCompleted ? opening.userMoveCountInMainLine : 0) + doneVariations
        let percent = max(bestPercent ?? 0, total == 0 ? 0 : Int((Double(saved) / Double(total) * 100).rounded()))
        return percent > 0 ? .inProgress(percent: min(percent, 99)) : .notStarted
    }
}

extension ChessOpening {
    var userMoveCountInMainLine: Int { mainLine.indices.filter(isUserPly).count }
}

extension OpeningTutorialSession {
    /// Progress through the whole tutorial, from 0 to 100.
    var progressPercent: Int {
        let total = mainLineUserMoveCount + opening.variations.count
        guard total > 0 else { return 0 }
        let done = mainLineUserMovesPlayed + completedVariationIds.count
        return Int((Double(done) / Double(total) * 100).rounded())
    }

    var progressSummary: TutorialProgressSummary {
        let total = mainLineUserMoveCount
        switch phase {
        case .mainLine:
            let played = mainLineUserMovesPlayed
            return TutorialProgressSummary(title: "Main Line", detail: "\(played) of \(total) moves", fraction: Double(played) / Double(max(total, 1)), caption: ecoCaption)
        case .mainLineComplete:
            return TutorialProgressSummary(title: "Main Line", detail: "All \(total) moves", fraction: 1, caption: ecoCaption)
        case .whatIf:
            let count = opening.variations.count
            let line = currentLine.filter { opening.isUserPly($0.ply) }.count
            let played = playedMoves.filter { opening.isUserPly($0.ply) }.count
            let within = line == 0 ? 0 : Double(played) / Double(line)
            let fraction = (Double(completedVariationIds.count) + (isCurrentLineComplete ? 0 : within)) / Double(max(count, 1))
            let variation = currentVariation
            return TutorialProgressSummary(
                title: "Branching Variations",
                detail: "\(variationIndex + 1) of \(count)",
                fraction: min(fraction, 1),
                caption: variation.map { [$0.eco, $0.name].compactMap { $0 }.joined(separator: " · ") }
            )
        case .completed:
            return TutorialProgressSummary(title: "Complete", detail: "Main line and \(opening.variations.count) variations", fraction: 1)
        }
    }

    private var ecoCaption: String? {
        guard let eco = opening.eco, let name = opening.ecoName else { return nil }
        return "\(eco) · \(name)"
    }

    var completionStats: TutorialCompletionStats {
        let variationAnswers = completedVariationIds.reduce(0) { sum, id in
            sum + (variationMoves(id)?.filter { opening.isUserPly($0.ply) }.count ?? 0)
        }
        let correct = mainLineUserMovesPlayed + variationAnswers
        let attempts = correct + mistakes.count
        return TutorialCompletionStats(
            mainLineMoves: mainLineUserMoveCount,
            variations: completedVariationIds.count,
            mistakes: mistakes.count,
            accuracy: attempts == 0 ? 100 : Int((Double(correct) / Double(attempts) * 100).rounded())
        )
    }

    var card: TutorialCardContent {
        let opponent = opening.opponentSide.label
        switch phase {
        case .mainLine:
            return mainLineCard(opponent: opponent)
        case .mainLineComplete:
            return TutorialCardContent(
                sceneID: "main-complete",
                style: .success,
                symbol: "checkmark.seal.fill",
                eyebrow: "Main line complete",
                title: "You know the \(opening.name)",
                message: "Now let's branch out. \(opponent) will try other moves. Can you respond?",
                action: .startBranching
            )
        case .whatIf:
            return branchingCard(opponent: opponent)
        case .completed:
            return TutorialCardContent(
                sceneID: "complete",
                style: .success,
                symbol: "trophy.fill",
                eyebrow: "Tutorial complete",
                title: "\(opening.name) mastered",
                message: "You played the main line and every branching variation."
            )
        }
    }

    private func mainLineCard(opponent: String) -> TutorialCardContent {
        let scene = "main"
        if case .incorrect(let mistake) = feedback, let expected = expectedUserMove {
            return TutorialCardContent(
                sceneID: scene,
                style: .hint,
                symbol: "arrow.uturn.backward",
                eyebrow: "Not quite",
                title: "Try \(expected.moveNumberLabel)",
                message: mistake.hint
            )
        }
        if let move = expectedUserMove {
            return TutorialCardContent(
                sceneID: scene,
                style: .guide,
                symbol: "hand.point.up.left.fill",
                eyebrow: "Your move",
                title: "Play \(move.moveNumberLabel)",
                message: move.step.title,
                detail: move.step.explanation
            )
        }
        let reply = lastMove.map { "\($0.san) is right. " } ?? ""
        return TutorialCardContent(
            sceneID: scene,
            style: .waiting,
            symbol: "ellipsis",
            eyebrow: "\(opponent) to move",
            title: reply.isEmpty ? "Watch \(opponent)'s move" : "Nice",
            message: "\(reply)\(opponent) is replying…"
        )
    }

    private func branchingCard(opponent: String) -> TutorialCardContent {
        guard let variation = currentVariation else {
            return TutorialCardContent(sceneID: "branch", style: .branching, symbol: "lightbulb.max.fill", eyebrow: "Branching out", title: "", message: "")
        }
        let scene = "branch-\(variation.id)"
        if isCurrentLineComplete {
            return TutorialCardContent(
                sceneID: scene,
                style: .success,
                symbol: "checkmark.circle.fill",
                eyebrow: "Variation complete",
                title: "You handled the \(variation.name)",
                message: lastMove?.step.explanation ?? variation.summary,
                action: hasMoreVariations ? .nextVariation : .finish
            )
        }
        if case .incorrect(let mistake) = feedback, let expected = expectedUserMove {
            let title = mistake.kind == .illegalMove ? "That move isn't legal here" : "\(mistake.attempted) doesn't fit this line"
            return TutorialCardContent(
                sceneID: scene,
                style: .hint,
                symbol: "lightbulb.max.fill",
                eyebrow: "Not quite",
                title: title,
                message: expected.step.hint ?? mistake.hint,
                detail: hintRevealed ? "The squares to use are now highlighted." : nil
            )
        }
        if let expected = expectedUserMove, let last = lastMove {
            let title = cursor == 1
                ? "What if \(opponent) plays \(last.moveNumberLabel) instead?"
                : "\(opponent) plays \(last.moveNumberLabel)"
            return TutorialCardContent(
                sceneID: scene,
                style: .branching,
                symbol: "lightbulb.max.fill",
                eyebrow: "Branching out",
                title: title,
                message: "Try to respond.",
                detail: hintRevealed ? Self.hint(for: expected) : last.step.explanation,
                showsHintButton: !hintRevealed
            )
        }
        if cursor == 0 {
            return TutorialCardContent(
                sceneID: scene,
                style: .branching,
                symbol: "lightbulb.max.fill",
                eyebrow: "Branching out",
                title: "What if \(opponent) tries something else?",
                message: variation.summary
            )
        }
        let reply = lastMove.map { "\($0.san) is right. \($0.step.explanation)" } ?? ""
        return TutorialCardContent(
            sceneID: scene,
            style: .waiting,
            symbol: "checkmark",
            eyebrow: "\(opponent) to move",
            title: "Nice",
            message: reply
        )
    }
}
