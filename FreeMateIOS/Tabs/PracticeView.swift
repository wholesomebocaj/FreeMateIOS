import SwiftUI

/// Whether the Practice tab shows a game against the computer or a free board.
enum PracticeMode: String, CaseIterable, Identifiable {
    case computer
    case freeBoard

    var id: String { rawValue }
    var label: String { self == .computer ? "Play Computer" : "Free Board" }
}

/// The Practice tab: a game against the computer, or a free board for both sides, on the same
/// board as the tutorials.
struct PracticeView: View {
    @StateObject private var board = PracticeBoard()
    @StateObject private var computer = ComputerGame()
    @AppStorage("freemate.practiceMode") private var mode = PracticeMode.computer
    @State private var showsPositionLoader = false

    private var turnText: String { board.turn == "white" ? "White" : "Black" }

    private var status: (text: String, symbol: String, tint: Color) {
        if board.isCheckmate { return ("Checkmate", "crown.fill", Theme.danger) }
        if board.isStalemate { return ("Stalemate", "equal.circle.fill", Theme.warning) }
        if board.isCheck { return ("\(turnText) is in check", "exclamationmark.triangle.fill", Theme.warning) }
        return ("\(turnText) to move", board.turn == "white" ? "circle" : "circle.fill", .secondary)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Mode", selection: $mode.animation(DesignMotion.spring)) {
                    ForEach(PracticeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                switch mode {
                case .computer:
                    ComputerPlayPanel(game: computer)
                case .freeBoard:
                    freeBoard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.immediately)
        .themeBackground()
        .navigationTitle("Practice")
        .accountToolbar()
        .animation(DesignMotion.spring, value: board.history.count)
        .animation(DesignMotion.spring, value: board.feedback)
    }

    @ViewBuilder
    private var freeBoard: some View {
        statusRow
        ModernBoardView(board: board)
            .frame(maxWidth: 560)
        controls
        if !board.feedback.isEmpty {
            Text(board.feedback)
                .font(.footnote)
                .foregroundStyle(board.feedbackKind == "error" ? Theme.warning : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
        }
        MoveListCard(
            moves: MoveListFormatter.rows(board.history.map(\.san), startingFen: board.initialFen),
            emptyText: "Moves you play appear here."
        )
        positionCard
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.tint)
                .contentTransition(.symbolEffect(.replace))
            Text(status.text)
                .font(.headline)
                .contentTransition(.opacity)
            Spacer()
            Text(board.history.isEmpty ? "No moves yet" : "Last: \(board.history.last?.san ?? "")")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            PracticeControlButton(title: "Reset", systemImage: "arrow.counterclockwise") { board.reset() }
            PracticeControlButton(title: "Flip", systemImage: "arrow.up.arrow.down") { board.flip() }
            PracticeControlButton(title: "Clear", systemImage: "xmark.square") { board.clear() }
        }
    }

    private var positionCard: some View {
        DisclosureGroup(isExpanded: $showsPositionLoader) {
            FenForm(board: board)
                .padding(.top, 10)
        } label: {
            Label("Load a Position", systemImage: "square.and.arrow.down")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

/// A full-width capsule button for the row of board controls.
struct PracticeControlButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}

/// The moves played so far, scrolled to the latest.
struct MoveListCard: View {
    var moves: [String]
    var emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Moves")
                .font(.headline)
            if moves.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(moves.enumerated()), id: \.offset) { index, move in
                                Text(move)
                                    .font(.subheadline.monospaced())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.fill, in: Capsule())
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: moves.count) { _, count in
                        withAnimation(DesignMotion.spring) { proxy.scrollTo(count - 1, anchor: .trailing) }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

struct FenForm: View {
    @ObservedObject var board: PracticeBoard
    @State private var text = ChessEngine.startingFen
    @State private var message = ""
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("FEN", text: $text, axis: .vertical)
                .font(.footnote.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button {
                do {
                    try board.loadFen(text, setInitial: true, clearHistory: true)
                    message = "Position loaded."
                    failed = false
                } catch {
                    message = error.localizedDescription
                    failed = true
                }
            } label: {
                Text("Load Position")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(failed ? Theme.warning : .secondary)
            }
        }
        .onChange(of: board.fen) { _, newValue in
            text = newValue
        }
    }
}
