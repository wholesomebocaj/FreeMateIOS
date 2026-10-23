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
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    summary
                    ModernBoardView(board: review.board, isInteractive: false)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    moveDetail
                    moveList
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
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
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { review.step(-1) } label: { Label("Previous Move", systemImage: "chevron.backward") }
                        .disabled(review.selectedPly == nil)
                    Spacer()
                    Button { review.selectNextMistake() } label: { Label("Next Mistake", systemImage: "exclamationmark.triangle") }
                        .disabled(review.count(.mistake) + review.count(.blunder) == 0)
                    Spacer()
                    Button { review.step(1) } label: { Label("Next Move", systemImage: "chevron.forward") }
                        .disabled(review.selectedPly == review.moves.count - 1)
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
            HStack(spacing: 0) {
                ForEach([ReviewedMove.Quality.best, .good, .mistake, .blunder], id: \.self) { quality in
                    VStack(spacing: 2) {
                        Text("\(review.count(quality))")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(review.count(quality) > 0 ? Self.tint(quality) : .secondary)
                        Text(quality.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Reviewing your moves…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: review.progress)
                    .tint(Theme.accent)
            }
        }
    }

    private var moveDetail: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let ply = review.selectedPly {
                HStack(alignment: .firstTextBaseline) {
                    Text(numbered(ply))
                        .font(.title3.weight(.bold).monospaced())
                    Spacer()
                    if let graded = review.reviewed[ply] {
                        Label(graded.quality.label, systemImage: Self.symbol(graded.quality))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Self.tint(graded.quality))
                    } else if !isLearners(ply) {
                        Text("Computer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                if let graded = review.reviewed[ply], let explanation = graded.explanation {
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        review.toggleBetterMove()
                    } label: {
                        Text(review.showsBetterMove ? "Show Your Move" : "Show \(graded.betterSAN ?? "Better Move")")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.warning)
                    .padding(.top, 2)
                }
            } else {
                Text("Starting position")
                    .font(.title3.weight(.bold))
                Text("Step through the game to see how each move did.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moveList: some View {
        VStack(spacing: 0) {
            ForEach(Array(review.learnerPlies.enumerated()), id: \.element) { index, ply in
                Button {
                    review.select(ply)
                } label: {
                    HStack {
                        Text(numbered(ply))
                            .font(.body.monospaced())
                            .foregroundStyle(.primary)
                        Spacer()
                        if let graded = review.reviewed[ply] {
                            Image(systemName: Self.symbol(graded.quality))
                                .foregroundStyle(Self.tint(graded.quality))
                                .accessibilityLabel(graded.quality.label)
                        } else {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 11)
                    .background(review.selectedPly == ply ? Theme.fill : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < review.learnerPlies.count - 1 {
                    Divider().padding(.leading, Theme.Spacing.m)
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func isLearners(_ ply: Int) -> Bool {
        (ply % 2 == 0) == (review.learner == .white)
    }

    private func numbered(_ ply: Int) -> String {
        "\(ply / 2 + 1)\(ply % 2 == 0 ? "." : "…") \(review.sans[ply])"
    }

    static func symbol(_ quality: ReviewedMove.Quality) -> String {
        switch quality {
        case .best: return "star.fill"
        case .good: return "checkmark.circle.fill"
        case .mistake: return "questionmark.circle.fill"
        case .blunder: return "exclamationmark.triangle.fill"
        }
    }

    static func tint(_ quality: ReviewedMove.Quality) -> Color {
        switch quality {
        case .best: return Theme.success
        case .good: return Theme.accent
        case .mistake, .blunder: return Theme.warning
        }
    }
}
