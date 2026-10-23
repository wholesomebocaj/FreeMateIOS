import SwiftUI

/// The six chess piece shapes, independent of `PieceKind` so they can be drawn off the main actor.
nonisolated enum PieceGlyph: CaseIterable, Sendable {
    case pawn, knight, bishop, rook, queen, king

    init?(letter: Character) {
        switch letter.lowercased() {
        case "p": self = .pawn
        case "n": self = .knight
        case "b": self = .bishop
        case "r": self = .rook
        case "q": self = .queen
        case "k": self = .king
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .pawn: return "pawn"
        case .knight: return "knight"
        case .bishop: return "bishop"
        case .rook: return "rook"
        case .queen: return "queen"
        case .king: return "king"
        }
    }
}

/// A minimal Staunton-style piece, drawn on a 100 × 100 grid so it stays crisp at any size.
/// `.body` is the filled silhouette; `.details` holds the small marks drawn over it.
nonisolated struct ChessPieceShape: Shape {
    enum Layer: Sendable {
        case body
        case details
    }

    var glyph: PieceGlyph
    var layer: Layer = .body

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        let originX = rect.midX - 50 * scale
        let originY = rect.midY - 50 * scale
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + x * scale, y: originY + y * scale)
        }
        func r(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: originX + x * scale, y: originY + y * scale, width: width * scale, height: height * scale)
        }
        func c(_ radius: CGFloat) -> CGSize {
            CGSize(width: radius * scale, height: radius * scale)
        }

        var path = Path()
        switch (glyph, layer) {
        case (.pawn, .body):
            path.addEllipse(in: r(37.5, 18.5, 25, 25))
            path.addRoundedRect(in: r(37, 44.5, 26, 8), cornerSize: c(3.5), style: .continuous)
            path.move(to: p(41, 52.5))
            path.addCurve(to: p(33, 80), control1: p(41, 63), control2: p(35, 71))
            path.addLine(to: p(67, 80))
            path.addCurve(to: p(59, 52.5), control1: p(65, 71), control2: p(59, 63))
            path.closeSubpath()
            path.addRoundedRect(in: r(27, 79, 46, 10), cornerSize: c(4), style: .continuous)
        case (.pawn, .details):
            break
        case (.rook, .body):
            path.move(to: p(29, 17))
            path.addLine(to: p(38, 17))
            path.addLine(to: p(38, 24))
            path.addLine(to: p(45, 24))
            path.addLine(to: p(45, 17))
            path.addLine(to: p(55, 17))
            path.addLine(to: p(55, 24))
            path.addLine(to: p(62, 24))
            path.addLine(to: p(62, 17))
            path.addLine(to: p(71, 17))
            path.addLine(to: p(71, 37))
            path.addLine(to: p(29, 37))
            path.closeSubpath()
            path.move(to: p(34, 37))
            path.addLine(to: p(66, 37))
            path.addLine(to: p(64, 76))
            path.addLine(to: p(36, 76))
            path.closeSubpath()
            path.addRoundedRect(in: r(30, 73, 40, 7), cornerSize: c(2.5), style: .continuous)
            path.addRoundedRect(in: r(25, 79, 50, 10), cornerSize: c(4), style: .continuous)
        case (.rook, .details):
            path.move(to: p(35, 44))
            path.addLine(to: p(65, 44))
        case (.bishop, .body):
            path.addEllipse(in: r(44.5, 8, 11, 11))
            path.move(to: p(50, 19))
            path.addCurve(to: p(61, 50), control1: p(61, 27), control2: p(66, 39))
            path.addCurve(to: p(56, 59), control1: p(59, 54), control2: p(57, 57))
            path.addLine(to: p(44, 59))
            path.addCurve(to: p(39, 50), control1: p(43, 57), control2: p(41, 54))
            path.addCurve(to: p(50, 19), control1: p(34, 39), control2: p(39, 27))
            path.closeSubpath()
            path.addRoundedRect(in: r(37, 58, 26, 7), cornerSize: c(3), style: .continuous)
            path.move(to: p(43, 65))
            path.addLine(to: p(57, 65))
            path.addCurve(to: p(66, 80), control1: p(58, 70), control2: p(63, 74))
            path.addLine(to: p(34, 80))
            path.addCurve(to: p(43, 65), control1: p(37, 74), control2: p(42, 70))
            path.closeSubpath()
            path.addRoundedRect(in: r(27, 79, 46, 10), cornerSize: c(4), style: .continuous)
        case (.bishop, .details):
            path.move(to: p(55, 31))
            path.addLine(to: p(47, 43))
        case (.knight, .body):
            path.move(to: p(68, 80))
            path.addCurve(to: p(64, 30), control1: p(72, 64), control2: p(72, 44))
            path.addCurve(to: p(52, 18), control1: p(60, 23), control2: p(56, 20))
            path.addLine(to: p(51, 10))
            path.addLine(to: p(44, 18))
            path.addCurve(to: p(27, 34), control1: p(37, 20), control2: p(31, 26))
            path.addCurve(to: p(20, 53), control1: p(23, 41), control2: p(19, 47))
            path.addCurve(to: p(31, 58), control1: p(21, 58), control2: p(26, 60))
            path.addCurve(to: p(47, 52), control1: p(36, 56), control2: p(41, 53))
            path.addCurve(to: p(34, 80), control1: p(45, 60), control2: p(38, 68))
            path.closeSubpath()
            path.addRoundedRect(in: r(27, 79, 46, 10), cornerSize: c(4), style: .continuous)
        case (.knight, .details):
            path.addEllipse(in: r(36.4, 30.4, 5.2, 5.2))
            path.move(to: p(25, 50))
            path.addCurve(to: p(28, 46), control1: p(27, 49), control2: p(28, 48))
        case (.queen, .body):
            path.move(to: p(37, 53))
            path.addLine(to: p(27, 27))
            path.addLine(to: p(37, 39))
            path.addLine(to: p(40, 21))
            path.addLine(to: p(46, 35))
            path.addLine(to: p(50, 17))
            path.addLine(to: p(54, 35))
            path.addLine(to: p(60, 21))
            path.addLine(to: p(63, 39))
            path.addLine(to: p(73, 27))
            path.addLine(to: p(63, 53))
            path.closeSubpath()
            path.addEllipse(in: r(23.2, 21.2, 7.6, 7.6))
            path.addEllipse(in: r(36.2, 15.2, 7.6, 7.6))
            path.addEllipse(in: r(46.2, 11.2, 7.6, 7.6))
            path.addEllipse(in: r(56.2, 15.2, 7.6, 7.6))
            path.addEllipse(in: r(69.2, 21.2, 7.6, 7.6))
            path.addRoundedRect(in: r(35, 52, 30, 7), cornerSize: c(3), style: .continuous)
            path.move(to: p(39, 59))
            path.addLine(to: p(61, 59))
            path.addCurve(to: p(69, 80), control1: p(62, 67), control2: p(66, 73))
            path.addLine(to: p(31, 80))
            path.addCurve(to: p(39, 59), control1: p(34, 73), control2: p(38, 67))
            path.closeSubpath()
            path.addRoundedRect(in: r(25, 79, 50, 10), cornerSize: c(4), style: .continuous)
        case (.queen, .details):
            break
        case (.king, .body):
            path.addRoundedRect(in: r(46.5, 6, 7, 22), cornerSize: c(2), style: .continuous)
            path.addRoundedRect(in: r(41, 11, 18, 7), cornerSize: c(2), style: .continuous)
            path.move(to: p(35, 53))
            path.addCurve(to: p(39, 30), control1: p(26, 45), control2: p(27, 31))
            path.addCurve(to: p(50, 38), control1: p(44, 30), control2: p(48, 33))
            path.addCurve(to: p(61, 30), control1: p(52, 33), control2: p(56, 30))
            path.addCurve(to: p(65, 53), control1: p(73, 31), control2: p(74, 45))
            path.closeSubpath()
            path.addRoundedRect(in: r(34, 52, 32, 7), cornerSize: c(3), style: .continuous)
            path.move(to: p(38, 59))
            path.addLine(to: p(62, 59))
            path.addCurve(to: p(70, 80), control1: p(63, 67), control2: p(67, 73))
            path.addLine(to: p(30, 80))
            path.addCurve(to: p(38, 59), control1: p(33, 73), control2: p(37, 67))
            path.closeSubpath()
            path.addRoundedRect(in: r(25, 79, 50, 10), cornerSize: c(4), style: .continuous)
        case (.king, .details):
            break
        }
        return path
    }
}

/// One piece, with a light outline for white and a soft rim light for black.
struct ChessPieceView: View {
    var glyph: PieceGlyph
    var isWhite: Bool

    init(glyph: PieceGlyph, isWhite: Bool) {
        self.glyph = glyph
        self.isWhite = isWhite
    }

    /// `code` uses the board's notation, such as "wN" or "bP".
    init?(code: String) {
        guard code.count == 2, let letter = code.last, let glyph = PieceGlyph(letter: letter) else { return nil }
        self.init(glyph: glyph, isWhite: code.hasPrefix("w"))
    }

    var body: some View {
        GeometryReader { proxy in
            let line = min(proxy.size.width, proxy.size.height) * 0.026
            ZStack {
                ChessPieceShape(glyph: glyph).fill(PieceInk.fill(isWhite: isWhite))
                ChessPieceShape(glyph: glyph)
                    .stroke(PieceInk.outline(isWhite: isWhite), style: StrokeStyle(lineWidth: line, lineJoin: .round))
                ChessPieceShape(glyph: glyph, layer: .details).fill(PieceInk.detail(isWhite: isWhite))
                ChessPieceShape(glyph: glyph, layer: .details)
                    .stroke(PieceInk.detail(isWhite: isWhite), style: StrokeStyle(lineWidth: line, lineCap: .round))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.28), radius: line * 0.6, y: line * 0.6)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

nonisolated enum PieceInk {
    static func fill(isWhite: Bool) -> Color {
        isWhite ? Color(red: 0.973, green: 0.965, blue: 0.945) : Color(red: 0.169, green: 0.169, blue: 0.188)
    }

    static func outline(isWhite: Bool) -> Color {
        isWhite ? Color(red: 0.149, green: 0.149, blue: 0.169) : Color.white.opacity(0.22)
    }

    static func detail(isWhite: Bool) -> Color {
        isWhite ? Color(red: 0.149, green: 0.149, blue: 0.169) : Color.white.opacity(0.55)
    }
}
