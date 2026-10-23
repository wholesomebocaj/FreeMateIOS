import SwiftUI

nonisolated struct BoardPalette: Equatable, Sendable {
    var light: Color
    var dark: Color
    var lastMove: Color
    /// Guidance color for hint squares, selection, and the breathing target glow.
    var guide: Color

    static let sage = BoardPalette(
        light: Color(red: 0.933, green: 0.914, blue: 0.867),
        dark: Color(red: 0.561, green: 0.651, blue: 0.549),
        lastMove: Color(red: 0.980, green: 0.859, blue: 0.471).opacity(0.42),
        guide: Color(red: 0.243, green: 0.557, blue: 0.871)
    )
}

/// A modern, animated board that renders a `PracticeBoard`.
///
/// Tap a piece and then a square, or drag the piece. Moves go through `PracticeBoard`, so an
/// owner that rejects a move (such as a tutorial) leaves the piece to spring back home.
struct ModernBoardView: View {
    @ObservedObject var board: PracticeBoard
    var isInteractive = true
    /// The square whose piece shakes when `shakeTrigger` changes.
    var shakeSquare: String?
    var shakeTrigger = 0
    var palette = BoardPalette.sage

    @State private var pieces: [PlacedPiece] = []
    /// Resets with a spring when the finger lifts or the gesture is cancelled, so a rejected
    /// piece glides home.
    @GestureState(resetTransaction: Transaction(animation: DesignMotion.piece)) private var drag: PieceDrag?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct PieceDrag: Equatable {
        var origin: String
        var pieceID: Int?
        var translation: CGSize = .zero
        var isLifted = false
    }

    private var isFlipped: Bool { board.orientation == "black" }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let square = side / 8
            ZStack(alignment: .topLeading) {
                squaresLayer(square)
                piecesLayer(square)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.dark)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            }
            .overlay {
                if let prompt = board.promotion {
                    promotionPicker(prompt, square: square)
                }
            }
            .contentShape(Rectangle())
            .gesture(boardGesture(square: square))
            .allowsHitTesting(isInteractive)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { pieces = BoardPieceLayout.initial(board.position) }
        .onChange(of: board.position) { _, position in
            let next = BoardPieceLayout.reconcile(pieces, with: position, lastMove: board.lastMove)
            withAnimation(reduceMotion ? nil : DesignMotion.piece) { pieces = next }
        }
        .onChange(of: board.selectedSquare) { _, square in
            if square != nil { Haptics.light() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chessboard, \(board.turn) to move")
    }

    // MARK: Squares

    private func squaresLayer(_ size: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { column in
                        squareView(squareName(row: row, column: column), row: row, column: column, size: size)
                    }
                }
            }
        }
    }

    private func squareView(_ name: String, row: Int, column: Int, size: CGFloat) -> some View {
        let isLight = isLightSquare(name)
        let guideClass = board.highlightSquares.first { $0.square == name }?.className
        let isDestination = board.legalDestinations.contains(name)
        let hasPiece = board.position[name] != nil
        return ZStack {
            Rectangle().fill(isLight ? palette.light : palette.dark)
            if board.lastMove.contains(name) {
                Rectangle().fill(palette.lastMove)
            }
            if board.selectedSquare == name || guideClass == "focus" {
                Rectangle().fill(palette.guide.opacity(0.26))
            }
            if board.isCheck, board.position[name] == (board.turn == "white" ? "wK" : "bK") {
                RadialGradient(colors: [Color.red.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: size * 0.62)
            }
            coordinates(row: row, column: column, isLight: isLight, size: size)
            if guideClass == "target" {
                PulsingGlow(color: palette.guide, size: size)
            }
            if isDestination {
                if hasPiece {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.18), lineWidth: size * 0.07)
                        .padding(size * 0.04)
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.17))
                        .frame(width: size * 0.3, height: size * 0.3)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: name, guide: guideClass))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { board.select(name) }
    }

    @ViewBuilder
    private func coordinates(row: Int, column: Int, isLight: Bool, size: CGFloat) -> some View {
        let ink = isLight ? palette.dark : palette.light
        let font = Font.system(size: max(8, size * 0.19), weight: .semibold, design: .rounded)
        if column == 0 {
            Text(String(rankNumber(row: row)))
                .font(font)
                .foregroundStyle(ink)
                .padding(.leading, size * 0.07)
                .padding(.top, size * 0.04)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityHidden(true)
        }
        if row == 7 {
            Text(String(fileLetter(column: column)))
                .font(font)
                .foregroundStyle(ink)
                .padding(.trailing, size * 0.07)
                .padding(.bottom, size * 0.03)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .accessibilityHidden(true)
        }
    }

    // MARK: Pieces

    private func piecesLayer(_ size: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(pieces) { piece in
                let isDragged = drag?.pieceID == piece.id
                let isShaking = shakeSquare == piece.square && !reduceMotion
                if let pieceView = ChessPieceView(code: piece.code) {
                    pieceView
                        .frame(width: size * 0.92, height: size * 0.92)
                        .scaleEffect(isDragged && drag?.isLifted == true ? 1.16 : 1)
                        .modifier(ShakeEffect(travel: isShaking ? size * 0.09 : 0, animatableData: CGFloat(shakeTrigger)))
                        .position(center(of: piece.square, size: size))
                        .offset(isDragged ? drag?.translation ?? .zero : .zero)
                        .zIndex(isDragged ? 1 : 0)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
        .frame(width: size * 8, height: size * 8, alignment: .topLeading)
        .animation(DesignMotion.shake, value: shakeTrigger)
        .drawingGroup()
        .allowsHitTesting(false)
    }

    // MARK: Gestures

    private func boardGesture(square size: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($drag) { value, state, _ in
                state = pieceDrag(for: value, size: size)
            }
            .onChanged { value in
                guard let current = pieceDrag(for: value, size: size), current.isLifted else { return }
                if board.selectedSquare != current.origin { board.select(current.origin) }
            }
            .onEnded { value in
                guard let target = squareName(at: value.location, size: size) else { return }
                if let finished = pieceDrag(for: value, size: size), finished.isLifted {
                    if target != finished.origin, board.legalDestinations.contains(target) {
                        board.tryMove(from: finished.origin, to: target)
                    }
                } else {
                    board.select(target)
                }
            }
    }

    /// The drag in progress, lifted once the finger travels a little way from a piece the
    /// side to move owns.
    private func pieceDrag(for value: DragGesture.Value, size: CGFloat) -> PieceDrag? {
        guard let origin = squareName(at: value.startLocation, size: size) else { return nil }
        let piece = pieces.first { $0.square == origin && $0.isWhite == (board.turn == "white") }
        let distance = hypot(value.translation.width, value.translation.height)
        return PieceDrag(
            origin: origin,
            pieceID: piece?.id,
            translation: value.translation,
            isLifted: piece != nil && distance > size * 0.15
        )
    }

    // MARK: Promotion

    private func promotionPicker(_ prompt: PromotionPrompt, square size: CGFloat) -> some View {
        let isWhite = board.turn == "white"
        return VStack(spacing: 14) {
            Text("Promote to")
                .font(.headline)
            HStack(spacing: 10) {
                ForEach(prompt.choices, id: \.self) { choice in
                    Button {
                        board.choosePromotion(choice)
                    } label: {
                        if let glyph = PieceGlyph(letter: Character(choice)) {
                            ChessPieceView(glyph: glyph, isWhite: isWhite)
                                .frame(width: size * 0.95, height: size * 0.95)
                                .padding(6)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel(PromotionLabel.name(choice))
                }
            }
            Button("Cancel") { board.cancelPromotion() }
                .font(.subheadline)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: Geometry

    private func squareName(row: Int, column: Int) -> String {
        "\(fileLetter(column: column))\(rankNumber(row: row))"
    }

    private func fileLetter(column: Int) -> Character {
        Array("abcdefgh")[isFlipped ? 7 - column : column]
    }

    private func rankNumber(row: Int) -> Int {
        isFlipped ? row + 1 : 8 - row
    }

    private func squareName(at point: CGPoint, size: CGFloat) -> String? {
        let column = Int((point.x / size).rounded(.down))
        let row = Int((point.y / size).rounded(.down))
        guard (0..<8).contains(column), (0..<8).contains(row) else { return nil }
        return squareName(row: row, column: column)
    }

    private func center(of square: String, size: CGFloat) -> CGPoint {
        guard let coordinates = BoardPieceLayout.coordinates(square) else { return .zero }
        let column = isFlipped ? 7 - coordinates.file : coordinates.file
        let row = isFlipped ? coordinates.rank : 7 - coordinates.rank
        return CGPoint(x: (CGFloat(column) + 0.5) * size, y: (CGFloat(row) + 0.5) * size)
    }

    private func isLightSquare(_ square: String) -> Bool {
        guard let coordinates = BoardPieceLayout.coordinates(square) else { return false }
        return (coordinates.file + coordinates.rank) % 2 == 1
    }

    private func accessibilityLabel(for square: String, guide: String?) -> String {
        var parts = [square]
        if let code = board.position[square], let glyph = code.last.flatMap(PieceGlyph.init(letter:)) {
            parts.append("\(code.hasPrefix("w") ? "white" : "black") \(glyph.name)")
        } else {
            parts.append("empty")
        }
        if board.selectedSquare == square { parts.append("selected") }
        if guide == "focus" { parts.append("move this piece") }
        if guide == "target" { parts.append("move here") }
        return parts.joined(separator: ", ")
    }
}
