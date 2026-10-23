import SwiftUI

/// The FreeMate design system: one palette, type scale, spacing scale, and set of shapes
/// for every screen. See DESIGN.md at the repository root for how to use it.
///
/// Colors take their cue from the board: warm cream and sage squares, with one calm blue
/// accent for anything the learner can act on. Every color adapts to light and dark mode.
enum Theme {
    // MARK: Brand and status

    /// Buttons, links, selection, progress, and the board's guide glow.
    static let accent = Color(light: 0x2F7CD3, dark: 0x4895EF)
    /// Correct moves, finished lessons, and mastery.
    static let success = Color(light: 0x2E8B57, dark: 0x4CC38A)
    /// Hints and gentle nudges after a mistake. Never used for hard errors.
    static let warning = Color(light: 0xB86E00, dark: 0xF5A623)
    /// Checkmate, failed sign-in, and other real problems.
    static let danger = Color(light: 0xC9372C, dark: 0xFF6961)
    /// The warm butter used for the last move on the board.
    static let highlight = Color(light: 0xE8C35A, dark: 0xF5D67A)

    // MARK: Surfaces

    /// The screen background.
    static let background = Color(.systemGroupedBackground)
    /// Cards and grouped rows.
    static let surface = Color(.secondarySystemGroupedBackground)
    /// Tiles and stats that sit on a card.
    static let surfaceRaised = Color(.tertiarySystemGroupedBackground)
    /// Tracks, chip backgrounds, and input fields.
    static let fill = Color(.tertiarySystemFill)
    static let separator = Color(.separator)

    // MARK: Board

    static let boardLight = Color(hex: 0xEEE9DD)
    static let boardDark = Color(hex: 0x8FA68C)

    // MARK: Topics

    /// One hue per curriculum topic, used for tiles and icons.
    static func topic(_ topic: String) -> (symbol: String, color: Color) {
        switch topic.lowercased() {
        case "openings": return ("arrow.triangle.branch", Color(light: 0x5856D6, dark: 0x8A86FF))
        case "tactics": return ("bolt.fill", warning)
        case "endgame": return ("flag.checkered", success)
        case "strategy": return ("brain.head.profile", Color(light: 0x9A4FCB, dark: 0xC17BEA))
        default: return ("square.grid.3x3.fill", accent)
        }
    }

    // MARK: Shape and spacing

    enum Radius {
        /// Small tiles, inputs, and thumbnails.
        static let small: CGFloat = 12
        /// Icon tiles inside cards.
        static let tile: CGFloat = 14
        /// The board.
        static let board: CGFloat = 16
        /// Every card.
        static let card: CGFloat = 22
        /// Floating cards and sheets over content.
        static let floating: CGFloat = 28
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        /// Between sections on a screen.
        static let xl: CGFloat = 28
    }
}

extension Color {
    /// A color from a 24-bit hex value, such as `0x2F7CD3`.
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A color that switches between two hex values with the appearance.
    nonisolated init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
        #else
        self.init(hex: dark)
        #endif
    }
}

// MARK: - Shared styles

extension View {
    /// The standard card: surface fill, continuous corners, and comfortable padding.
    func cardStyle(padding: CGFloat = Theme.Spacing.m) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    /// Filled capsule button for the one main action in a group.
    func primaryButtonStyle(tint: Color = Theme.accent) -> some View {
        self
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(tint)
    }

    /// Tinted capsule button for secondary actions.
    func secondaryButtonStyle(tint: Color = Theme.accent) -> some View {
        self
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(tint)
    }

    /// Small, quiet label above a title, such as "Your move" or "C92 · White".
    func eyebrowStyle() -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    /// The screen background, edge to edge.
    func themeBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

/// A capsule label for a state, such as "Mastered" or "Due".
struct StatusBadge: View {
    var text: String
    var systemImage: String?
    var tint: Color

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
        .contentTransition(.opacity)
    }
}

/// A main and a secondary action side by side, stacked full width when they do not fit.
struct ActionButtons: View {
    var primaryTitle: String
    var secondaryTitle: String
    var primary: () -> Void
    var secondary: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.s) {
                buttons(fillWidth: false)
            }
            VStack(spacing: Theme.Spacing.xs) {
                buttons(fillWidth: true)
            }
        }
        .font(.headline)
        .controlSize(.large)
    }

    @ViewBuilder
    private func buttons(fillWidth: Bool) -> some View {
        Button(action: primary) {
            Text(primaryTitle)
                .lineLimit(1)
                .frame(maxWidth: fillWidth ? .infinity : nil)
        }
        .primaryButtonStyle()
        Button(action: secondary) {
            Text(secondaryTitle)
                .lineLimit(1)
                .frame(maxWidth: fillWidth ? .infinity : nil)
        }
        .secondaryButtonStyle()
    }
}

/// A rounded tile with a symbol, for list rows and cards.
struct IconTile: View {
    var systemImage: String
    var color: Color
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: systemImage)
            .font(size > 44 ? .title3.weight(.semibold) : .body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            .accessibilityHidden(true)
    }
}
