import SwiftUI

/// A game against the beginner computer, with the whole screen for the board.
struct ComputerGameView: View {
    @ObservedObject var game: ComputerGame
    @State private var confirmsResign = false
    @State private var showsReview = false

    private var board: PracticeBoard { game.board }

    private var status: (text: String, tint: Color) {
        if let result = game.result {
            return (result.title, result == .won ? Theme.success : .secondary)
        }
        if game.warning != nil { return ("Careful", Theme.warning) }
        if game.isThinking { return ("Thinking…", .secondary) }
        if board.isCheck && game.isLearnersTurn { return ("You're in check", Theme.warning) }
        if game.isLearnersTurn { return ("Your move", .primary) }
        return ("Computer to move", .secondary)
    }

    private var learnerHasMoved: Bool {
        board.history.contains { ($0.index % 2 == 1) == (game.learner == .white) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                statusRow
                ModernBoardView(board: board, isInteractive: game.canMove)
                    .frame(maxWidth: 560)
                MoveStrip(moves: MoveListFormatter.rows(board.history.map(\.san), startingFen: board.initialFen))
                if let warning = game.warning {
                    warningCard(warning)
                } else if let result = game.result {
                    resultCard(result)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle("Computer")
        .navigationBarTitleDisplayMode(.inline)
        .focusedScreen()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { settingsMenu }
            ToolbarItemGroup(placement: .bottomBar) {
                newGameMenu
                Spacer()
                Button {
                    game.showHint()
                } label: {
                    Label("Hint", systemImage: game.isFindingHint ? "ellipsis" : "lightbulb")
                }
                .disabled(!game.canHint)
                Spacer()
                Button {
                    game.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!game.canUndo)
                Spacer()
                Button {
                    confirmsResign = true
                } label: {
                    Label("Resign", systemImage: "flag")
                }
                .disabled(board.history.isEmpty || game.result != nil)
            }
        }
        .confirmationDialog("Resign this game?", isPresented: $confirmsResign, titleVisibility: .visible) {
            Button("Resign", role: .destructive) { game.resign() }
        } message: {
            Text("It counts as a loss.")
        }
        .sheet(isPresented: $showsReview) {
            ComputerGameReviewView(game: game)
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
        .onChange(of: game.warning) { _, warning in
            if warning != nil { Haptics.error() }
        }
        .onAppear { game.reloadOtherDevices() }
    }

    private var statusRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if game.isThinking {
                ProgressView()
                    .controlSize(.small)
            }
            Text(status.text)
                .font(.headline)
                .foregroundStyle(status.tint)
                .contentTransition(.opacity)
            Spacer()
            Text("\(game.level.label) · You play \(game.learner.label)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 560)
        .accessibilityElement(children: .combine)
    }

    private var newGameMenu: some View {
        Menu {
            Button("Play as White", systemImage: "circle") { game.newGame(as: .white) }
            Button("Play as Black", systemImage: "circle.fill") { game.newGame(as: .black) }
        } label: {
            Label("New Game", systemImage: "plus")
        }
    }

    private var settingsMenu: some View {
        Menu {
            Picker("Level", selection: $game.level) {
                ForEach(ComputerLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.inline)
            Toggle("Warn Before Blunders", systemImage: "exclamationmark.shield", isOn: $game.warnsAboutBlunders)
            if game.totalRecord.played > 0 {
                Section(recordText) {}
            }
        } label: {
            Label("Game Settings", systemImage: "slider.horizontal.3")
        }
    }

    private func warningCard(_ warning: MoveWarning) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Careful", systemImage: "lightbulb.fill")
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
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func resultCard(_ result: ComputerGameResult) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: result == .won ? "crown.fill" : result == .lost || result == .resigned ? "flag.fill" : "equal.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(result == .won ? Theme.highlight : .secondary)
            Text(result.title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            if learnerHasMoved {
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
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Theme.Spacing.l)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var recordText: String {
        let record = game.totalRecord
        return "\(record.wins) won · \(record.draws) drawn · \(record.losses) lost"
    }

    private func announceComputerMove(_ move: BoardMoveRecord) {
        let mover = game.learner.opposite.label
        AccessibilityNotification.Announcement("\(mover) plays \(move.san)").post()
        Haptics.light()
    }
}
