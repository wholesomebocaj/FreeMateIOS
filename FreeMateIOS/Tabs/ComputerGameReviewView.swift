import SwiftUI

/// Steps through a finished game against the computer, with each of the learner's moves graded.
struct ComputerGameReviewView: View {
    @StateObject private var review: ComputerGameReview
    @Environment(\.dismiss) private var dismiss

    init(game: ComputerGame) {
        _review = StateObject(wrappedValue: ComputerGameReview(game: game))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summary
                    ModernBoardView(board: review.board, isInteractive: false)
                        .frame(maxWidth: 560)
                    moveCard
                    stepper
                    moveList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .themeBackground()
            .navigationTitle("Game Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .animation(DesignMotion.spring, value: review.reviewed.count)
            .animation(DesignMotion.spring, value: review.selectedPly)
            .animation(DesignMotion.spring, value: review.showsBetterMove)
        }
        .onAppear { review.start() }
        .onDisappear { review.stop() }
    }

    @ViewBuilder
    private var summary: some View {
        if review.isFinished {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach([ReviewedMove.Quality.best, .good, .mistake, .blunder], id: \.self) { quality in
                    StatusBadge(
                        text: "\(review.count(quality)) \(quality.label)",
                        systemImage: Self.symbol(quality),
                        tint: Self.tint(quality)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Reviewing your moves").eyebrowStyle()
                ProgressView(value: review.progress)
                    .tint(Theme.accent)
            }
        }
    }

    private var moveCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let ply = review.selectedPly {
                HStack {
                    Text(numbered(ply))
                        .font(.title3.weight(.bold).monospaced())
                    Spacer()
                    if let graded = review.reviewed[ply] {
                        StatusBadge(text: graded.quality.label, systemImage: Self.symbol(graded.quality), tint: Self.tint(graded.quality))
                    } else if isLearners(ply) {
                        ProgressView().controlSize(.small)
                    } else {
                        StatusBadge(text: "Computer", systemImage: "desktopcomputer", tint: .secondary)
                    }
                }
                if let graded = review.reviewed[ply], let explanation = graded.explanation {
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        review.toggleBetterMove()
                    } label: {
                        Label(
                            review.showsBetterMove ? "Show your move" : "Show \(graded.betterSAN ?? "better move")",
                            systemImage: review.showsBetterMove ? "arrow.uturn.backward" : "lightbulb"
                        )
                        .font(.subheadline.weight(.semibold))
                    }
                    .secondaryButtonStyle(tint: Theme.warning)
                } else if let graded = review.reviewed[ply] {
                    Text(graded.quality == .best ? "The best move here." : "A solid move.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Starting position")
                    .font(.title3.weight(.bold))
                Text("Step through the game to see how each of your moves did.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            PracticeControlButton(title: "Back", systemImage: "chevron.left") { review.step(-1) }
                .disabled(review.selectedPly == nil)
            PracticeControlButton(title: "Next", systemImage: "chevron.right") { review.step(1) }
                .disabled(review.selectedPly == review.moves.count - 1)
            PracticeControlButton(title: "Errors", systemImage: "exclamationmark.triangle") { review.selectNextMistake() }
                .accessibilityLabel("Next mistake")
                .disabled(review.count(.mistake) + review.count(.blunder) == 0)
        }
    }

    private var moveList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your moves")
                .font(.headline)
                .padding(.bottom, 6)
            ForEach(review.learnerPlies, id: \.self) { ply in
                Button {
                    review.select(ply)
                } label: {
                    HStack {
                        Text(numbered(ply))
                            .font(.subheadline.monospaced())
                        Spacer()
                        if let graded = review.reviewed[ply] {
                            Image(systemName: Self.symbol(graded.quality))
                                .foregroundStyle(Self.tint(graded.quality))
                                .accessibilityLabel(graded.quality.label)
                        } else {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        review.selectedPly == ply ? Theme.fill : .clear,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }

    private func isLearners(_ ply: Int) -> Bool {
        (ply % 2 == 0) == (review.learner == .white)
    }

    private func numbered(_ ply: Int) -> String {
        "\(ply / 2 + 1)\(ply % 2 == 0 ? "." : "...") \(review.sans[ply])"
    }

    static func symbol(_ quality: ReviewedMove.Quality) -> String {
        switch quality {
        case .best: return "star.fill"
        case .good: return "checkmark"
        case .mistake: return "questionmark"
        case .blunder: return "exclamationmark.triangle.fill"
        }
    }

    static func tint(_ quality: ReviewedMove.Quality) -> Color {
        switch quality {
        case .best: return Theme.success
        case .good: return .secondary
        case .mistake, .blunder: return Theme.warning
        }
    }
}
