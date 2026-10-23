import SwiftUI

/// A small, static board for previews. Drawn in a single `Canvas` pass so lists stay smooth.
struct BoardThumbnail: View {
    var fen: String
    var isFlipped = false
    var palette = BoardPalette.sage

    var body: some View {
        let placements = Self.placements(fen: fen, isFlipped: isFlipped)
        let palette = palette
        Canvas { context, size in
            let side = min(size.width, size.height)
            let square = side / 8
            for row in 0..<8 {
                for column in 0..<8 {
                    let rect = CGRect(x: CGFloat(column) * square, y: CGFloat(row) * square, width: square, height: square)
                    let isLight = (row + column) % 2 == 0
                    context.fill(Path(rect), with: .color(isLight ? palette.light : palette.dark))
                }
            }
            let line = square * 0.03
            for placement in placements {
                let rect = CGRect(x: CGFloat(placement.column) * square, y: CGFloat(placement.row) * square, width: square, height: square)
                    .insetBy(dx: square * 0.04, dy: square * 0.04)
                let body = ChessPieceShape(glyph: placement.glyph).path(in: rect)
                let details = ChessPieceShape(glyph: placement.glyph, layer: .details).path(in: rect)
                context.fill(body, with: .color(PieceInk.fill(isWhite: placement.isWhite)))
                context.stroke(body, with: .color(PieceInk.outline(isWhite: placement.isWhite)), style: StrokeStyle(lineWidth: line, lineJoin: .round))
                context.stroke(details, with: .color(PieceInk.detail(isWhite: placement.isWhite)), style: StrokeStyle(lineWidth: line, lineCap: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private struct Placement {
        var row: Int
        var column: Int
        var glyph: PieceGlyph
        var isWhite: Bool
    }

    private static func placements(fen: String, isFlipped: Bool) -> [Placement] {
        let map = (try? ChessEngine.parsePieceMap(fen)) ?? [:]
        return map.compactMap { square, code in
            guard let coordinates = BoardPieceLayout.coordinates(square),
                  let letter = code.last,
                  let glyph = PieceGlyph(letter: letter) else { return nil }
            let column = isFlipped ? 7 - coordinates.file : coordinates.file
            let row = isFlipped ? coordinates.rank : 7 - coordinates.rank
            return Placement(row: row, column: column, glyph: glyph, isWhite: code.hasPrefix("w"))
        }
    }
}
