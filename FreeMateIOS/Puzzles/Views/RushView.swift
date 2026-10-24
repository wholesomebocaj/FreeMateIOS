import Combine
import SwiftUI

/// Runs a Puzzle Rush on the shared board: one try per puzzle, a three-minute clock, and three
/// strikes.
@MainActor
final class RushController: ObservableObject {
    enum Phase: Equatable { case ready, playing, over }

    @Published private(set) var phase = Phase.ready
    @Published private(set) var session: RushSession
    @Published private(set) var endsAt: Date?
    /// Flashes after each answer: true for right, false for wrong.
    @Published private(set) var lastAnswer: Bool?
    @Published private(set) var answerCount = 0
    @Published private(set) var isNewBest = false
    /// Showing the result of the last answer before the next puzzle loads.
    @Published private(set) var isAdvancing = false

    let board = PracticeBoard()
    private let pool: [Puzzle]
    private let store: RushStore
    private let activity: ActivityStore
    private var clock: Task<Void, Never>?
    private var advance: Task<Void, Never>?

    init(pool: [Puzzle] = PuzzleContent.allPuzzles, store: RushStore = RushStore(), activity: ActivityStore = ActivityStore()) {
        self.pool = pool
        self.store = store
        self.activity = activity
        session = RushSession(pool: pool)
        board.onMoveAttempt = { [weak self] from, to, promotion in
            self?.attempt(from + to + (promotion ?? ""))
        }
    }

    var best: Int { store.best }

    func start() {
        session = RushSession(pool: pool)
        advance?.cancel()
        isAdvancing = false
        lastAnswer = nil
        isNewBest = false
        phase = .playing
        let end = Date().addingTimeInterval(RushSession.duration)
        endsAt = end
        loadPuzzle()
        clock?.cancel()
        clock = Task { [weak self] in
            try? await Task.sleep(for: .seconds(RushSession.duration))
            guard let self, !Task.isCancelled else { return }
            self.session.timeUp()
            self.finish()
        }
    }

    func stop() {
        clock?.cancel()
        advance?.cancel()
    }

    private func attempt(_ uci: String) {
        guard phase == .playing, session.puzzle != nil, !isAdvancing else { return }
        let fen = board.fen
        let correct = session.submit(uci)
        lastAnswer = correct
        answerCount += 1
        if correct, let after = Puzzle.play(uci, from: fen) {
            try? board.syncFen(after, lastMove: [String(uci.prefix(2)), String(uci.dropFirst(2).prefix(2))])
        }
        isAdvancing = true
        advance = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(correct ? 350 : 600))
            guard let self, !Task.isCancelled else { return }
            self.isAdvancing = false
            if self.session.isOver {
                self.finish()
            } else {
                self.loadPuzzle()
            }
        }
    }

    private func loadPuzzle() {
        guard let puzzle = session.puzzle else { return }
        try? board.loadFen(puzzle.fen, setInitial: true, clearHistory: true)
        board.orientation = puzzle.sideToMove.rawValue
        board.setConfig(highlightSquares: [])
    }

    private func finish() {
        guard phase == .playing else { return }
        clock?.cancel()
        phase = .over
        endsAt = nil
        if session.score > 0 { activity.record() }
        isNewBest = store.record(session.score)
    }
}

struct RushView: View {
    @StateObject private var rush = RushController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch rush.phase {
            case .ready: intro
            case .playing: playing
            case .over: results
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themeBackground()
        .navigationTitle("Puzzle Rush")
        .navigationBarTitleDisplayMode(.inline)
        .focusedScreen()
        .animation(reduceMotion ? nil : DesignMotion.spring, value: rush.phase)
        .onChange(of: rush.answerCount) {
            if rush.lastAnswer == true { Haptics.light() } else { Haptics.error() }
        }
        .onDisappear { rush.stop() }
    }

    private var intro: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.warning)
            Text("Puzzle Rush")
                .font(.largeTitle.weight(.bold))
            Text("Solve as many as you can in 3 minutes. Three misses and it's over.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if rush.best > 0 {
                Text("Best: \(rush.best)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                rush.start()
            } label: {
                Text("Start").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    private var playing: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    if let endsAt = rush.endsAt {
                        Text(timerInterval: Date()...endsAt, countsDown: true)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                    }
                    Spacer()
                    Text("\(rush.session.score)")
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(rush.lastAnswer == false ? Theme.warning : .primary)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<RushSession.strikesAllowed, id: \.self) { index in
                            Image(systemName: index < rush.session.strikes ? "xmark.circle.fill" : "circle")
                                .foregroundStyle(index < rush.session.strikes ? Theme.danger : Color.secondary.opacity(0.5))
                        }
                    }
                    .frame(width: 70, alignment: .trailing)
                    .accessibilityElement()
                    .accessibilityLabel("\(rush.session.strikes) of \(RushSession.strikesAllowed) misses")
                }
                .frame(maxWidth: 560)
                if let puzzle = rush.session.puzzle {
                    Text("\(puzzle.sideToMove.label) to move · \(puzzle.prompt)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 560, alignment: .leading)
                }
                ModernBoardView(board: rush.board, isInteractive: !rush.isAdvancing)
                    .frame(maxWidth: 560)
                    .overlay {
                        if let answer = rush.lastAnswer {
                            RoundedRectangle(cornerRadius: Theme.Radius.board, style: .continuous)
                                .strokeBorder(answer ? Theme.success : Theme.warning, lineWidth: 4)
                                .opacity(0.9)
                                .id(rush.answerCount)
                                .transition(.opacity)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .frame(maxWidth: .infinity)
        }
    }

    private var results: some View {
        VStack(spacing: Theme.Spacing.s) {
            Spacer()
            Text("\(rush.session.score)")
                .font(.system(size: 88, weight: .bold, design: .rounded).monospacedDigit())
            Text(rush.session.score == 1 ? "puzzle solved" : "puzzles solved")
                .font(.title3)
                .foregroundStyle(.secondary)
            if rush.isNewBest {
                Label("New best", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.highlight)
                    .padding(.top, Theme.Spacing.xs)
            } else if rush.best > 0 {
                Text("Best: \(rush.best)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.top, Theme.Spacing.xs)
            }
            Spacer()
            VStack(spacing: Theme.Spacing.xs) {
                Button {
                    rush.start()
                } label: {
                    Text("Play Again").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    dismiss()
                } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.headline)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(.horizontal, Theme.Spacing.l)
    }
}
