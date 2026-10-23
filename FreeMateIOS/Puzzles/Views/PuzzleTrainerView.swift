import SwiftUI

/// Solves a drill or a puzzle level one position at a time.
struct PuzzleTrainerView: View {
    @StateObject private var trainer: PuzzleTrainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(set: PuzzleSet) {
        _trainer = StateObject(wrappedValue: PuzzleTrainer(set: set))
    }

    private var session: PuzzleSession { trainer.session }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                progressDots
                if session.isFinished {
                    completionCard
                } else {
                    promptCard
                    ModernBoardView(
                        board: trainer.board,
                        isInteractive: !session.isSolved,
                        shakeSquare: trainer.rejectedSquare,
                        shakeTrigger: trainer.rejectionCount
                    )
                    .frame(maxWidth: 560)
                    feedbackCard
                    actions
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle(session.puzzleSet.title)
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : DesignMotion.spring, value: session)
        .onChange(of: trainer.rejectionCount) { Haptics.error() }
        .onChange(of: session.isSolved) { _, solved in
            if solved { Haptics.success() }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(session.puzzleSet.puzzles.enumerated()), id: \.element.id) { index, puzzle in
                Capsule()
                    .fill(trainer.isSolved(puzzle) ? Theme.success : Theme.fill)
                    .overlay {
                        if index == session.index && !session.isFinished {
                            Capsule().strokeBorder(Theme.accent, lineWidth: 2)
                        }
                    }
                    .frame(height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(session.puzzleSet.puzzles.filter(trainer.isSolved).count) of \(session.puzzleSet.puzzles.count) solved")
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Puzzle \(session.index + 1) of \(session.puzzleSet.puzzles.count)")
                    .eyebrowStyle()
                Spacer()
                StatusBadge(
                    text: "\(trainer.puzzle.sideToMove.label) to move",
                    systemImage: trainer.puzzle.sideToMove == .white ? "circle" : "circle.fill",
                    tint: .secondary
                )
            }
            Text(trainer.puzzle.prompt)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    @ViewBuilder
    private var feedbackCard: some View {
        if session.isSolved {
            feedback(trainer.puzzle.success, systemImage: "checkmark.circle.fill", tint: Theme.success)
        } else if session.mistakes > 0 {
            feedback("Not quite. \(trainer.puzzle.hint)", systemImage: "lightbulb.fill", tint: Theme.warning)
        } else if session.hintShown {
            feedback(trainer.puzzle.hint, systemImage: "lightbulb.fill", tint: Theme.warning)
        }
    }

    private func feedback(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .transition(.opacity)
    }

    @ViewBuilder
    private var actions: some View {
        if session.isSolved {
            Button {
                trainer.next()
            } label: {
                Text(session.isLast ? "Finish" : "Next Puzzle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .primaryButtonStyle()
        } else if session.offersAnswer {
            Button {
                trainer.showAnswer()
            } label: {
                Label("Show Answer", systemImage: "eye")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .secondaryButtonStyle(tint: Theme.warning)
        } else {
            Button {
                trainer.showHint()
            } label: {
                Label("Hint", systemImage: "lightbulb")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .secondaryButtonStyle(tint: Theme.warning)
            .disabled(session.hintShown)
        }
    }

    private var completionCard: some View {
        let total = session.puzzleSet.puzzles.count
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.success)
            Text("Set complete")
                .font(.title.weight(.bold))
            Text("\(session.firstTryCount) of \(total) solved on the first try.")
                .font(.body)
                .foregroundStyle(.secondary)
            Text(session.puzzleSet.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ActionButtons(
                primaryTitle: "Done",
                secondaryTitle: "Practice Again",
                primary: { dismiss() },
                secondary: { trainer.restart() }
            )
            .padding(.top, Theme.Spacing.xs)
        }
        .cardStyle(padding: Theme.Spacing.l)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}
