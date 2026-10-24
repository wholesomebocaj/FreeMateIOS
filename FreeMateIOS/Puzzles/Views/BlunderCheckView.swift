import Combine
import SwiftUI

/// Shows each blunder check on a read-only board, then plays the move, and the punishment for
/// a blunder, once the learner answers.
@MainActor
final class BlunderCheckController: ObservableObject {
    @Published private(set) var session: BlunderCheckSession
    let board = PracticeBoard()
    private let store: BlunderProgressStore
    private let activity: ActivityStore
    private var reveal: Task<Void, Never>?

    init(checks: [BlunderCheck], store: BlunderProgressStore = BlunderProgressStore(), activity: ActivityStore = ActivityStore()) {
        self.store = store
        self.activity = activity
        session = BlunderCheckSession(checks: checks)
        load()
    }

    func answer(isBlunder: Bool) {
        guard let check = session.check, !session.isAnswered else { return }
        if session.answer(isBlunder: isBlunder) {
            store.markCorrect(check.id)
            Haptics.success()
        } else {
            Haptics.error()
        }
        activity.record()
        play(check)
    }

    func next() {
        reveal?.cancel()
        session.next()
        load()
    }

    func restart() {
        reveal?.cancel()
        session.restart()
        load()
    }

    private func play(_ check: BlunderCheck) {
        guard let after = Puzzle.play(check.move, from: check.fen) else { return }
        try? board.syncFen(after, lastMove: squares(check.move))
        board.setConfig(highlightSquares: [])
        guard check.isBlunder, let refutation = check.refutation, let punished = Puzzle.play(refutation, from: after) else { return }
        reveal = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled else { return }
            try? self.board.syncFen(punished, lastMove: self.squares(refutation))
            self.board.setConfig(highlightSquares: [HighlightMark(square: String(refutation.dropFirst(2).prefix(2)), className: "danger")])
        }
    }

    private func load() {
        guard let check = session.check else { return }
        try? board.loadFen(check.fen, setInitial: true, clearHistory: true)
        board.orientation = check.sideToMove.rawValue
        let squares = squares(check.move)
        board.setConfig(highlightSquares: [
            HighlightMark(square: squares[0], className: "focus"),
            HighlightMark(square: squares[1], className: "target"),
        ])
    }

    private func squares(_ uci: String) -> [String] {
        [String(uci.prefix(2)), String(uci.dropFirst(2).prefix(2))]
    }
}

struct BlunderCheckView: View {
    @StateObject private var controller: BlunderCheckController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(checks: [BlunderCheck]) {
        _controller = StateObject(wrappedValue: BlunderCheckController(checks: checks))
    }

    private var session: BlunderCheckSession { controller.session }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if session.isFinished {
                    completion
                } else if let check = session.check {
                    progressDots
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(check.sideToMove.label) to move · \(session.index + 1) of \(session.checks.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Is \(check.san) safe?")
                            .font(.title2.weight(.bold))
                    }
                    ModernBoardView(board: controller.board, isInteractive: false)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    if session.isAnswered {
                        verdict(check)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle("Blunder Check")
        .navigationBarTitleDisplayMode(.inline)
        .focusedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !session.isFinished {
                actions
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
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(session.checks.indices, id: \.self) { index in
                Capsule()
                    .fill(index < session.index || (index == session.index && session.isAnswered) ? Theme.success.opacity(0.8) : index == session.index ? Theme.accent : Theme.fill)
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func verdict(_ check: BlunderCheck) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                session.wasCorrect ? "Right. \(check.isBlunder ? "It's a blunder." : "It's safe.")" : "Not quite. \(check.isBlunder ? "It's a blunder." : "It's safe.")",
                systemImage: session.wasCorrect ? "checkmark.circle.fill" : "lightbulb.fill"
            )
            .font(.headline)
            .foregroundStyle(session.wasCorrect ? Theme.success : Theme.warning)
            Text(check.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    @ViewBuilder
    private var actions: some View {
        if session.isAnswered {
            Button {
                controller.next()
            } label: {
                Text(session.index == session.checks.count - 1 ? "Finish" : "Next").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else {
            HStack(spacing: Theme.Spacing.s) {
                Button {
                    controller.answer(isBlunder: false)
                } label: {
                    Label("Safe", systemImage: "checkmark.shield").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.success)
                Button {
                    controller.answer(isBlunder: true)
                } label: {
                    Label("Blunder", systemImage: "xmark.shield").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.danger)
            }
        }
    }

    private var completion: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.success)
            Text("\(session.correctCount) of \(session.checks.count) right")
                .font(.title.weight(.bold))
            Text("Before every move, ask what your opponent can take.")
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
                    controller.restart()
                } label: {
                    Text("Try Again").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.headline)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.top, Theme.Spacing.s)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
