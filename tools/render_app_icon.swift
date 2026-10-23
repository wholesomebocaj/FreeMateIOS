// Renders the app icon from the app's own vector knight, so the icon matches the board.
//
//     tools/render_app_icon.sh
//
// The script compiles this file together with FreeMateIOS/DesignSystem/ChessPieceShape.swift.

import AppKit
import SwiftUI

struct AppIconView: View {
    var dark: Bool

    private let sageLight = Color(red: 0.561, green: 0.651, blue: 0.549)
    private let sageDeep = Color(red: 0.388, green: 0.482, blue: 0.376)
    private let cream = Color(red: 0.933, green: 0.914, blue: 0.867)
    private let night = Color(red: 0.102, green: 0.125, blue: 0.106)
    private let nightSage = Color(red: 0.196, green: 0.247, blue: 0.192)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: dark ? [nightSage, night] : [sageLight, sageDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            // A quiet corner of the board behind the knight.
            Canvas { context, size in
                let square = size.width / 8
                for row in 0..<8 {
                    for column in 0..<8 where (row + column) % 2 == 0 {
                        let rect = CGRect(x: CGFloat(column) * square, y: CGFloat(row) * square, width: square, height: square)
                        context.fill(Path(rect), with: .color(.white.opacity(dark ? 0.025 : 0.05)))
                    }
                }
            }
            ZStack {
                ChessPieceShape(glyph: .knight, layer: .body)
                    .fill(dark ? cream : Color(red: 0.973, green: 0.965, blue: 0.945))
                ChessPieceShape(glyph: .knight, layer: .body)
                    .stroke(Color(red: 0.149, green: 0.149, blue: 0.169).opacity(0.85), lineWidth: 14)
                ChessPieceShape(glyph: .knight, layer: .details)
                    .fill(Color(red: 0.149, green: 0.149, blue: 0.169))
            }
            .frame(width: 700, height: 700)
            .shadow(color: .black.opacity(dark ? 0.5 : 0.28), radius: 28, y: 18)
            .offset(y: 8)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
func render(dark: Bool, to path: String) throws {
    let renderer = ImageRenderer(content: AppIconView(dark: dark))
    renderer.scale = 1
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: URL(fileURLWithPath: path))
}

let directory = CommandLine.arguments.dropFirst().first ?? "."
try MainActor.assumeIsolated {
    try render(dark: false, to: "\(directory)/AppIcon.png")
    try render(dark: true, to: "\(directory)/AppIcon-Dark.png")
}
print("Wrote AppIcon.png and AppIcon-Dark.png to \(directory)")
