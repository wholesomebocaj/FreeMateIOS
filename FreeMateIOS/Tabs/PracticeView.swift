import SwiftUI

/// The Practice tab: a free board for both sides, on the same board as the tutorials.
struct PracticeView: View {
    @StateObject private var board = PracticeBoard()
    @State private var showsPositionLoader = false

    private var turnText: String { board.turn == "white" ? "White" : "Black" }

    private var status: (text: String, symbol: String, tint: Color) {
        if board.isCheckmate { return ("Checkmate", "crown.fill", Color(.systemRed)) }
        if board.isStalemate { return ("Stalemate", "equal.circle.fill", Color(.systemOrange)) }
        if board.isCheck { return ("\(turnText) is in check", "exclamationmark.triangle.fill", Color(.systemOrange)) }
        return ("\(turnText) to move", board.turn == "white" ? "circle" : "circle.fill", .secondary)
    }

    var body: some View {
        let moves = MoveListFormatter.rows(board.history.map(\.san), startingFen: board.initialFen)
        ScrollView {
            VStack(spacing: 20) {
                statusRow
                ModernBoardView(board: board)
                    .frame(maxWidth: 560)
                controls
                if !board.feedback.isEmpty {
                    Text(board.feedback)
                        .font(.footnote)
                        .foregroundStyle(board.feedbackKind == "error" ? Color(.systemOrange) : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                }
                movesCard(moves)
                positionCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.immediately)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Practice")
        .accountToolbar()
        .tint(DesignTokens.accent)
        .animation(DesignMotion.spring, value: board.history.count)
        .animation(DesignMotion.spring, value: board.feedback)
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
            controlButton("Reset", systemImage: "arrow.counterclockwise") { board.reset() }
            controlButton("Flip", systemImage: "arrow.up.arrow.down") { board.flip() }
            controlButton("Clear", systemImage: "xmark.square") { board.clear() }
        }
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    private func movesCard(_ moves: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Moves")
                .font(.headline)
            if moves.isEmpty {
                Text("Moves you play appear here.")
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
                                    .background(Color(.tertiarySystemFill), in: Capsule())
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
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
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    .foregroundStyle(failed ? Color(.systemOrange) : .secondary)
            }
        }
        .onChange(of: board.fen) { _, newValue in
            text = newValue
        }
    }
}
