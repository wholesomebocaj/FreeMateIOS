import SwiftUI

/// The "Play Computer" side of the Practice tab: a game against the beginner computer.
struct ComputerPlayPanel: View {
    @ObservedObject var game: ComputerGame
    @State private var confirmsResign = false
    @State private var showsReview = false

    private var board: PracticeBoard { game.board }

    private var status: (text: String, symbol: String, tint: Color) {
        if let result = game.result {
            switch result {
            case .won: return (result.title, "crown.fill", Theme.success)
            case .lost, .resigned: return (result.title, "flag.fill", .secondary)
            case .drawn: return (result.title, "equal.circle.fill", .secondary)
            }
        }
        if game.warning != nil { return ("Careful!", "exclamationmark.triangle.fill", Theme.warning) }
        if game.isThinking { return ("The computer is thinking", "ellipsis", .secondary) }
        if board.isCheck && game.isLearnersTurn {
            return ("You're in check", "exclamationmark.triangle.fill", Theme.warning)
        }
        if game.isLearnersTurn { return ("Your move", "hand.tap.fill", Theme.accent) }
        return ("Computer to move", "desktopcomputer", .secondary)
    }

    var body: some View {
        VStack(spacing: 20) {
            statusRow
            ModernBoardView(board: board, isInteractive: game.canMove)
                .frame(maxWidth: 560)
            if let warning = game.warning {
                warningCard(warning)
            } else if let result = game.result {
                resultCard(result)
            } else {
                controls
            }
            levelCard
            MoveListCard(
                moves: MoveListFormatter.rows(board.history.map(\.san), startingFen: board.initialFen),
                emptyText: game.learner == .white ? "You play White. Make the first move." : "You play Black."
            )
        }
        .animation(DesignMotion.spring, value: game.result)
        .animation(DesignMotion.spring, value: game.warning)
        .onChange(of: board.history.count) { oldCount, newCount in
            // White plays the odd-numbered moves.
            guard newCount == oldCount + 1, let last = board.history.last,
                  (last.index % 2 == 1) != (game.learner == .white) else { return }
            announceComputerMove(last)
        }
        .onChange(of: game.result) { _, result in
            if result == .won { Haptics.success() }
        }
        .onAppear { game.reloadOtherDevices() }
        .onChange(of: game.warning) { _, warning in
            if warning != nil { Haptics.error() }
        }
        .sheet(isPresented: $showsReview) {
            ComputerGameReviewView(game: game)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.tint)
                .symbolEffect(.pulse, isActive: game.isThinking)
                .contentTransition(.symbolEffect(.replace))
            Text(status.text)
                .font(.headline)
                .contentTransition(.opacity)
            Spacer()
            StatusBadge(
                text: game.learner == .white ? "You: White" : "You: Black",
                systemImage: game.learner == .white ? "circle" : "circle.fill",
                tint: .secondary
            )
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    /// One row when the four buttons fit, two rows of two on narrower screens.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                newGameMenu
                hintButton
                undoButton
                resignButton
            }
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    newGameMenu
                    hintButton
                }
                HStack(spacing: 10) {
                    undoButton
                    resignButton
                }
            }
        }
    }

    private var newGameMenu: some View {
        Menu {
            Button("Play White", systemImage: "circle") { game.newGame(as: .white) }
            Button("Play Black", systemImage: "circle.fill") { game.newGame(as: .black) }
        } label: {
            Label("New", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var hintButton: some View {
        PracticeControlButton(title: "Hint", systemImage: game.isFindingHint ? "ellipsis" : "lightbulb") { game.showHint() }
            .disabled(!game.canHint)
    }

    private var undoButton: some View {
        PracticeControlButton(title: "Undo", systemImage: "arrow.uturn.backward") { game.undo() }
            .disabled(!game.canUndo)
    }

    private var resignButton: some View {
        PracticeControlButton(title: "Resign", systemImage: "flag") { confirmsResign = true }
            .disabled(board.history.isEmpty)
            .confirmationDialog("Resign this game?", isPresented: $confirmsResign, titleVisibility: .visible) {
                Button("Resign", role: .destructive) { game.resign() }
            } message: {
                Text("It counts as a loss.")
            }
    }

    private func warningCard(_ warning: MoveWarning) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Careful!", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(Theme.warning)
            Text(warning.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            ActionButtons(
                primaryTitle: "Take It Back",
                secondaryTitle: "Play Anyway",
                primary: { game.takeBackWarnedMove() },
                secondary: { game.ignoreWarning() }
            )
        }
        .cardStyle()
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func resultCard(_ result: ComputerGameResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Game over").eyebrowStyle()
            Text(result.title)
                .font(.title3.weight(.bold))
            if board.history.contains(where: { ($0.index % 2 == 1) == (game.learner == .white) }) {
                ActionButtons(
                    primaryTitle: "Review Game",
                    secondaryTitle: "Play Again",
                    primary: { showsReview = true },
                    secondary: { game.newGame(as: game.learner) }
                )
            } else {
                Button("Play Again") { game.newGame(as: game.learner) }
                    .font(.headline)
                    .controlSize(.large)
                    .primaryButtonStyle()
            }
            Button(game.learner == .white ? "Switch to Black" : "Switch to White") {
                game.newGame(as: game.learner.opposite)
            }
            .font(.subheadline.weight(.semibold))
        }
        .cardStyle()
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Computer")
                .font(.headline)
            Picker("Level", selection: $game.level) {
                ForEach(ComputerLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.segmented)
            Text(game.level.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Warn me before a blunder", isOn: $game.warnsAboutBlunders)
                .font(.subheadline)
                .tint(Theme.accent)
            if game.totalRecord.played > 0 {
                Text(recordText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var recordText: String {
        let record = game.totalRecord
        let games = record.played == 1 ? "1 game" : "\(record.played) games"
        let wins = record.wins == 1 ? "1 win" : "\(record.wins) wins"
        let draws = record.draws == 1 ? "1 draw" : "\(record.draws) draws"
        let losses = record.losses == 1 ? "1 loss" : "\(record.losses) losses"
        return "\(games) · \(wins) · \(draws) · \(losses)"
    }

    private func announceComputerMove(_ move: BoardMoveRecord) {
        let mover = game.learner.opposite.label
        AccessibilityNotification.Announcement("\(mover) plays \(move.san)").post()
        Haptics.light()
    }
}
