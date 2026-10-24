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
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if session.isFinished {
                    completion
                } else {
                    if session.puzzleSet.puzzles.count > 1 {
                        progressDots
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(caption)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(session.step > 0 && !session.isSolved ? "Now checkmate." : trainer.puzzle.prompt)
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                    }
                    ModernBoardView(
                        board: trainer.board,
                        isInteractive: !session.isSolved && !trainer.isReplying,
                        shakeSquare: trainer.rejectedSquare,
                        shakeTrigger: trainer.rejectionCount
                    )
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    feedback
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle(session.puzzleSet.title)
        .navigationBarTitleDisplayMode(.inline)
        .focusedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !session.isFinished {
                action
                    .font(.headline)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(reduceMotion ? nil : DesignMotion.spring, value: session)
        .onChange(of: trainer.rejectionCount) { Haptics.error() }
        .onChange(of: session.isSolved) { _, solved in
            if solved { Haptics.success() }
        }
    }

    private var caption: String {
        let side = "\(trainer.puzzle.sideToMove.label) to move"
        if session.puzzleSet.isDaily {
            return "\(side) · \(Date().formatted(.dateTime.weekday(.wide).month().day()))"
        }
        return "\(side) · \(session.index + 1) of \(session.puzzleSet.puzzles.count)"
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(session.puzzleSet.puzzles.enumerated()), id: \.element.id) { index, puzzle in
                Capsule()
                    .fill(trainer.isSolved(puzzle) ? Theme.success : index == session.index ? Theme.accent : Theme.fill)
                    .frame(height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(session.puzzleSet.puzzles.filter(trainer.isSolved).count) of \(session.puzzleSet.puzzles.count) solved")
    }

    @ViewBuilder
    private var feedback: some View {
        if session.isSolved {
            message(trainer.puzzle.success, systemImage: "checkmark.circle.fill", tint: Theme.success)
        } else if session.step > 0 && session.mistakes == 0 && !session.hintShown {
            message(trainer.isReplying ? "Good. Now watch the reply." : "Good. Every reply loses now. Finish it.", systemImage: "checkmark.circle", tint: Theme.success)
        } else if session.mistakes > 0 {
            message("Not quite. \(trainer.puzzle.hint)", systemImage: "lightbulb.fill", tint: Theme.warning)
        } else if session.hintShown {
            message(trainer.puzzle.hint, systemImage: "lightbulb.fill", tint: Theme.warning)
        }
    }

    private func message(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(tint)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    @ViewBuilder
    private var action: some View {
        if session.isSolved {
            Button {
                trainer.next()
            } label: {
                Text(session.puzzleSet.isDaily ? "Done" : session.isLast ? "Finish" : "Next Puzzle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else if session.offersAnswer {
            Button {
                trainer.showAnswer()
            } label: {
                Label("Show Answer", systemImage: "eye")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.warning)
        } else {
            Button {
                trainer.showHint()
            } label: {
                Label("Hint", systemImage: "lightbulb")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.warning)
            .disabled(session.hintShown)
        }
    }

    private var completion: some View {
        VStack(spacing: Theme.Spacing.m) {
            if session.puzzleSet.isDaily {
                dailyCompletion
            } else {
                setCompletion
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    @ViewBuilder
    private var dailyCompletion: some View {
        let streak = DailyPuzzle.streak(solved: trainer.solved, today: Date())
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 64))
            .foregroundStyle(Theme.success)
            .symbolEffect(.bounce, value: session.isFinished)
        Text("Daily Puzzle Solved")
            .font(.title.weight(.bold))
        if streak > 1 {
            Label("\(streak) days in a row", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(Theme.warning)
        }
        Text("A new puzzle arrives tomorrow.")
            .foregroundStyle(.secondary)
        Button {
            dismiss()
        } label: {
            Text("Done").frame(maxWidth: .infinity)
        }
        .font(.headline)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.top, Theme.Spacing.s)
    }

    @ViewBuilder
    private var setCompletion: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.success)
                .symbolEffect(.bounce, value: session.isFinished)
            Text("Set Complete")
                .font(.title.weight(.bold))
            Text("\(session.firstTryCount) of \(session.puzzleSet.puzzles.count) solved on the first try.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: Theme.Spacing.xs) {
                Button {
                    dismiss()
                } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    trainer.restart()
                } label: {
                    Text("Practice Again").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.headline)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.top, Theme.Spacing.s)
        }
    }
}
