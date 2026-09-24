import SwiftUI

struct ChessboardView: View {
    @ObservedObject var board: PracticeBoard

    var body: some View {
        VStack(spacing: 8) {
            boardGrid
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .center) {
                    if let prompt = board.promotion {
                        promotionChooser(prompt)
                    }
                }
            if !board.feedback.isEmpty {
                Text(board.feedback)
                    .font(.footnote)
                    .foregroundStyle(board.feedbackKind == "error" ? FreeMateTheme.red : FreeMateTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var boardGrid: some View {
        let ranks: [Int] = board.orientation == "white" ? Array(stride(from: 8, through: 1, by: -1)) : Array(1...8)
        let files: [Character] = board.orientation == "white" ? Array("abcdefgh") : Array(Array("abcdefgh").reversed())
        return GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let square = side / 8
            VStack(spacing: 0) {
                ForEach(ranks, id: \.self) { rank in
                    HStack(spacing: 0) {
                        ForEach(files, id: \.self) { file in
                            squareCell(file: file, rank: rank, size: square)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(FreeMateTheme.panelDeep)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func squareCell(file: Character, rank: Int, size: CGFloat) -> some View {
        let name = "\(file)\(rank)"
        let fileIndex = Array("abcdefgh").firstIndex(of: file) ?? 0
        let light = (rank + fileIndex) % 2 == 0
        let piece = board.position[name]
        let highlight = board.highlightSquares.first { $0.square == name }
        return Button {
            board.select(name)
        } label: {
            ZStack {
                Rectangle().fill(light ? FreeMateTheme.lightSquare : FreeMateTheme.darkSquare)
                if board.lastMove.contains(name) {
                    Rectangle().fill(FreeMateTheme.gold.opacity(0.35))
                }
                if let highlight {
                    Rectangle().fill(highlightColor(highlight.className))
                }
                if board.selectedSquare == name {
                    Rectangle().strokeBorder(FreeMateTheme.accent, lineWidth: 3)
                }
                if board.legalDestinations.contains(name) {
                    Circle()
                        .fill(piece == nil ? Color.black.opacity(0.28) : Color.clear)
                        .frame(width: piece == nil ? size * 0.28 : size * 0.86)
                        .overlay {
                            if piece != nil {
                                Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: size * 0.08)
                            }
                        }
                }
                if let piece, let symbol = ChessPiece.from(code: piece)?.symbol {
                    Text(symbol)
                        .font(.system(size: size * 0.72))
                }
                if rank == (board.orientation == "white" ? 1 : 8) && file == (board.orientation == "white" ? "a" : "h") {
                    Text(String(file))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(light ? FreeMateTheme.darkSquare : FreeMateTheme.lightSquare)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(2)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .accessibilityLabel(name)
    }

    private func highlightColor(_ name: String) -> Color {
        switch name {
        case "target": return FreeMateTheme.accent.opacity(0.45)
        case "danger": return FreeMateTheme.red.opacity(0.4)
        case "correct": return FreeMateTheme.green.opacity(0.45)
        default: return FreeMateTheme.gold.opacity(0.35)
        }
    }

    private func promotionChooser(_ prompt: PromotionPrompt) -> some View {
        VStack(spacing: 10) {
            Text("Promote to")
                .font(.headline)
            HStack {
                ForEach(prompt.choices, id: \.self) { choice in
                    Button(PromotionLabel.name(choice)) { board.choosePromotion(choice) }
                        .buttonStyle(.borderedProminent)
                        .tint(FreeMateTheme.green)
                }
            }
            Button("Cancel") { board.cancelPromotion() }
                .foregroundStyle(FreeMateTheme.muted)
        }
        .padding()
        .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 16))
    }
}

extension ChessPiece {
    static func from(code: String) -> ChessPiece? {
        guard code.count == 2 else { return nil }
        let color: ChessColor = code.hasPrefix("w") ? .white : .black
        guard let kind = PieceKind.from(fen: code.last!) else { return nil }
        return ChessPiece(color: color, kind: kind)
    }
}

enum FreeMateTheme {
    static let bg = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let panel = Color(red: 0.122, green: 0.161, blue: 0.216)
    static let panelSoft = Color(red: 0.149, green: 0.196, blue: 0.267)
    static let panelDeep = Color(red: 0.043, green: 0.071, blue: 0.125)
    static let accent = Color(red: 0.525, green: 0.937, blue: 0.675)
    static let text = Color(red: 0.976, green: 0.980, blue: 0.984)
    static let muted = Color(red: 0.612, green: 0.639, blue: 0.686)
    static let green = Color(red: 0.133, green: 0.773, blue: 0.369)
    static let gold = Color(red: 0.980, green: 0.800, blue: 0.082)
    static let red = Color(red: 0.973, green: 0.443, blue: 0.443)
    static let lightSquare = Color(red: 0.941, green: 0.851, blue: 0.710)
    static let darkSquare = Color(red: 0.710, green: 0.533, blue: 0.388)
}

struct FreeMateScreen<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    @EnvironmentObject private var game: GameState
    @State private var showAuth = false

    var body: some View {
        ZStack {
            FreeMateTheme.bg.ignoresSafeArea()
            content()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(game.currentUser?.displayName ?? "Sign in") { showAuth = true }
                    .foregroundStyle(FreeMateTheme.accent)
            }
        }
        .sheet(isPresented: $showAuth) { AuthView().environmentObject(game) }
        .toolbarBackground(FreeMateTheme.panel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct ProgressMeter: View {
    var value: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FreeMateTheme.muted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FreeMateTheme.panelDeep)
                    Capsule().fill(FreeMateTheme.green).frame(width: geo.size.width * CGFloat(min(max(value, 0), 100)) / 100)
                }
            }
            .frame(height: 8)
        }
    }
}
