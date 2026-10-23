import SwiftUI

enum DesignMotion {
    /// The shared spring for state changes: phase switches, cards, and progress.
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    /// Slightly quicker, for pieces gliding between squares.
    static let piece = Animation.spring(response: 0.34, dampingFraction: 0.84)
    static let shake = Animation.easeOut(duration: 0.5)
}

enum DesignTokens {
    static let accent = Color(.systemBlue)
    static let success = Color(.systemGreen)
    static let cardRadius: CGFloat = 22
}

/// A gentle side-to-side shake that fades out. Each increment of `animatableData` plays once.
nonisolated struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = animatableData - animatableData.rounded(.down)
        let offset = travel * sin(progress * .pi * 6) * (1 - progress)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

/// A soft glow that breathes on the square the learner should move to.
struct PulsingGlow: View {
    var color: Color
    var size: CGFloat
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: size * 0.065)
            .background { Circle().fill(color.opacity(0.16)) }
            .shadow(color: color.opacity(0.8), radius: size * 0.14)
            .padding(size * 0.12)
            .scaleEffect(breathing ? 1 : 0.86)
            .opacity(breathing ? 1 : 0.55)
            .onAppear {
                guard !reduceMotion else {
                    breathing = true
                    return
                }
                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
            .allowsHitTesting(false)
    }
}

/// Cards that sink slightly while pressed, then spring back.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(DesignMotion.spring, value: configuration.isPressed)
    }
}

/// A slim capsule progress bar.
struct CapsuleProgressBar: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(proxy.size.height, proxy.size.width * clamped))
                    .opacity(clamped > 0 ? 1 : 0)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((min(max(fraction, 0), 1) * 100).rounded())) percent")
    }
}
