import SwiftUI

/// The Play tab: a game against the computer, or a free board.
struct PracticeView: View {
    @EnvironmentObject private var game: GameState
    @StateObject private var computer = ComputerGame()
    @StateObject private var freeBoard = PracticeBoard()

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
                } footer: {
                    Text("The computer can warn you before a blunder and review your game when it ends.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Play")
            .navigationDestination(for: PracticeRoute.self) { route in
                switch route {
                case .computer: ComputerGameView(game: computer)
                case .freeBoard: FreeBoardView(board: freeBoard)
                }
            }
            .onAppear { computer.reloadOtherDevices() }
        }
    }

    private var computerSubtitle: String {
        let record = computer.totalRecord
        guard record.played > 0 else { return "\(computer.level.label) · Beginner friendly" }
        return "\(computer.level.label) · \(record.wins) won, \(record.losses) lost"
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
