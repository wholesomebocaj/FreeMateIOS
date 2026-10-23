import SwiftUI

/// The bundled puzzles and drills, loaded once.
enum PuzzleContent {
    static let catalog = try? PuzzleLibrary.loadCatalog()
    static let drills = (try? PuzzleLibrary.loadDrills()) ?? []
    static var levels: [PuzzleLevel] { catalog?.levels ?? [] }

    static func set(id: String) -> PuzzleSet? {
        if let level = levels.first(where: { PuzzleSet(level: $0).id == id }) { return PuzzleSet(level: level) }
        if let drill = drills.first(where: { PuzzleSet(drill: $0).id == id }) { return PuzzleSet(drill: drill) }
        return nil
    }
}

/// The Practice tab: the computer, a free board, puzzles by level, and drills.
struct PracticeView: View {
    @EnvironmentObject private var game: GameState
    @StateObject private var computer = ComputerGame()
    @StateObject private var freeBoard = PracticeBoard()
    @State private var solved: Set<String> = []

    var body: some View {
        NavigationStack(path: $game.practicePath) {
            List {
                Section {
                    NavigationLink(value: PracticeRoute.computer) {
                        IconRow(
                            title: "Play the Computer",
                            subtitle: computerSubtitle,
                            systemImage: "desktopcomputer",
                            color: Theme.success
                        )
                    }
                    NavigationLink(value: PracticeRoute.freeBoard) {
                        IconRow(
                            title: "Free Board",
                            subtitle: "Move both sides or set up a position",
                            systemImage: "square.grid.3x3.fill",
                            color: Theme.accent
                        )
                    }
                }
                if let catalog = PuzzleContent.catalog {
                    Section {
                        ForEach(catalog.levels) { level in
                            levelRow(level, in: catalog)
                        }
                    } header: {
                        Text("Puzzles")
                    } footer: {
                        Text("Solve \(catalog.unlockAfter) in a level to unlock the next.")
                    }
                }
                if !PuzzleContent.drills.isEmpty {
                    Section("Drills") {
                        ForEach(PuzzleContent.drills) { drill in
                            drillRow(drill)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Practice")
            .navigationDestination(for: PracticeRoute.self) { route in
                switch route {
                case .computer:
                    ComputerGameView(game: computer)
                case .freeBoard:
                    FreeBoardView(board: freeBoard)
                case .puzzles(let id):
                    if let set = PuzzleContent.set(id: id) {
                        PuzzleTrainerView(set: set)
                    } else {
                        ContentUnavailableView("Puzzles Not Found", systemImage: "puzzlepiece")
                    }
                }
            }
            .onAppear {
                solved = PuzzleProgressStore().solved
                computer.reloadOtherDevices()
            }
        }
    }

    private var computerSubtitle: String {
        let record = computer.totalRecord
        guard record.played > 0 else { return "\(computer.level.label) · Beginner friendly" }
        return "\(computer.level.label) · \(record.wins) won, \(record.losses) lost"
    }

    private static let levelStyles: [(symbol: String, color: Color)] = [
        ("shoeprints.fill", Theme.accent),
        ("arrow.up.left.and.arrow.down.right", Theme.success),
        ("line.diagonal.arrow", Theme.warning),
        ("eye.fill", .purple),
    ]

    @ViewBuilder
    private func levelRow(_ level: PuzzleLevel, in catalog: PuzzleCatalog) -> some View {
        let set = PuzzleSet(level: level)
        let done = level.puzzles.filter { solved.contains(set.key(for: $0)) }.count
        let style = Self.levelStyles[(level.level - 1) % Self.levelStyles.count]
        if catalog.isUnlocked(level, solved: solved) {
            NavigationLink(value: PracticeRoute.puzzles(set.id)) {
                IconRow(title: level.title, subtitle: "Level \(level.level)", systemImage: style.symbol, color: style.color) {
                    progress(done: done, total: level.puzzles.count)
                }
            }
        } else {
            IconRow(title: level.title, subtitle: "Level \(level.level)", systemImage: "lock.fill", color: Color(.systemGray3)) {
                Image(systemName: "lock")
                    .accessibilityLabel("Locked")
            }
            .opacity(0.6)
        }
    }

    private func drillRow(_ drill: Drill) -> some View {
        let set = PuzzleSet(drill: drill)
        let done = drill.puzzles.filter { solved.contains(set.key(for: $0)) }.count
        let style = Self.drillStyle(drill.id)
        return NavigationLink(value: PracticeRoute.puzzles(set.id)) {
            IconRow(title: drill.title, subtitle: drill.summary, systemImage: style.symbol, color: style.color) {
                progress(done: done, total: drill.puzzles.count)
            }
        }
    }

    @ViewBuilder
    private func progress(done: Int, total: Int) -> some View {
        if done == total && total > 0 {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.success)
                .accessibilityLabel("Complete")
        } else if done > 0 {
            Text("\(done)/\(total)")
        }
    }

    static func drillStyle(_ id: String) -> (symbol: String, color: Color) {
        switch id {
        case "mate-in-one": return ("crown.fill", Theme.highlight)
        case "forks": return ("arrow.triangle.branch", Theme.warning)
        case "pins": return ("pin.fill", .purple)
        case "hanging": return ("hand.raised.fill", Theme.success)
        case "out-of-check": return ("shield.lefthalf.filled", Theme.accent)
        default: return ("target", .gray)
        }
    }
}

/// A board for both sides, for trying ideas or loading a position.
struct FreeBoardView: View {
    @ObservedObject var board: PracticeBoard
    @State private var showsLoader = false

    private var turnText: String { board.turn == "white" ? "White" : "Black" }

    private var status: (text: String, tint: Color) {
        if board.isCheckmate { return ("Checkmate", Theme.danger) }
        if board.isStalemate { return ("Stalemate", Theme.warning) }
        if board.isCheck { return ("\(turnText) is in check", Theme.warning) }
        return ("\(turnText) to move", .primary)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                HStack {
                    Text(status.text)
                        .font(.headline)
                        .foregroundStyle(status.tint)
                        .contentTransition(.opacity)
                    Spacer()
                }
                .frame(maxWidth: 560)
                ModernBoardView(board: board)
                    .frame(maxWidth: 560)
                MoveStrip(moves: MoveListFormatter.rows(board.history.map(\.san), startingFen: board.initialFen))
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle("Free Board")
        .navigationBarTitleDisplayMode(.inline)
        .focusedScreen()
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { board.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                Spacer()
                Button { board.flip() } label: { Label("Flip Board", systemImage: "arrow.up.arrow.down") }
                Spacer()
                Button { board.clear() } label: { Label("Clear Board", systemImage: "eraser") }
                Spacer()
                Button { showsLoader = true } label: { Label("Load Position", systemImage: "square.and.arrow.down") }
            }
        }
        .sheet(isPresented: $showsLoader) {
            NavigationStack {
                FenForm(board: board) { showsLoader = false }
                    .navigationTitle("Load Position")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showsLoader = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .onAppear { board.feedback = "" }
    }
}

/// The moves so far on one line, scrolled to the latest.
struct MoveStrip: View {
    var moves: [String]

    var body: some View {
        if !moves.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(moves.enumerated()), id: \.offset) { index, move in
                            Text(move)
                                .font(.subheadline.monospaced())
                                .foregroundStyle(index == moves.count - 1 ? .primary : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.fill, in: Capsule())
                                .id(index)
                        }
                    }
                }
                .scrollClipDisabled()
                .frame(maxWidth: 560)
                .onChange(of: moves.count) { _, count in
                    withAnimation(DesignMotion.spring) { proxy.scrollTo(count - 1, anchor: .trailing) }
                }
                .onAppear { proxy.scrollTo(moves.count - 1, anchor: .trailing) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Moves")
        }
    }
}

struct FenForm: View {
    @ObservedObject var board: PracticeBoard
    var onLoad: () -> Void = {}
    @State private var text = ""
    @State private var message = ""

    var body: some View {
        Form {
            Section {
                TextField("FEN", text: $text, axis: .vertical)
                    .font(.footnote.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(2...4)
            } footer: {
                Text(message.isEmpty ? "Paste a position in FEN notation." : message)
                    .foregroundStyle(message.isEmpty ? Color.secondary : Theme.warning)
            }
            Section {
                Button("Load Position") {
                    do {
                        try board.loadFen(text, setInitial: true, clearHistory: true)
                        onLoad()
                    } catch {
                        message = error.localizedDescription
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { text = board.fen }
    }
}
