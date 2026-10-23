import SwiftUI

/// A full-screen celebration when the whole tutorial is done.
struct TutorialCompletionOverlay: View {
    let openingName: String
    let stats: TutorialCompletionStats
    var onDone: () -> Void
    var onPracticeAgain: () -> Void

    @State private var appeared = false
    @State private var ring: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay { Color.black.opacity(0.3) }
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
            if !reduceMotion {
                ConfettiBurst(isActive: appeared)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            VStack(spacing: 22) {
                SuccessRing(progress: ring, didFinish: appeared)
                VStack(spacing: 8) {
                    Text("Tutorial Complete")
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(openingName)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                    Text("You learned the main line and \(stats.variations) branching variations.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    StatTile(value: "\(stats.mainLineMoves)", label: "Moves")
                    StatTile(value: "\(stats.variations)", label: "Variations")
                    StatTile(value: "\(stats.accuracy)%", label: "Accuracy")
                }
                VStack(spacing: 6) {
                    Button(action: onDone) {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    Button("Practice Again", action: onPracticeAgain)
                        .font(.headline)
                        .padding(.vertical, 8)
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 40, y: 20)
            .padding(24)
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { appeared = true }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.2)) { ring = 1 }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct SuccessRing: View {
    var progress: CGFloat
    var didFinish: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.success.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.success.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "checkmark")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Theme.success)
                .symbolEffect(.bounce, value: didFinish)
        }
        .frame(width: 108, height: 108)
        .accessibilityHidden(true)
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A short, subtle burst of confetti from the top third of the screen.
private struct ConfettiBurst: View {
    var isActive: Bool
    @State private var particles = ConfettiParticle.burst(count: 46)
    @State private var start = Date()
    @State private var running = false
    private let duration: TimeInterval = 2.2
    private let colors: [Color] = [
        Theme.success, Theme.accent, Theme.highlight, Theme.topic("openings").color, Theme.warning,
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !running)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let particles = particles
            let colors = colors
            let duration = duration
            Canvas { context, size in
                guard elapsed < duration else { return }
                let t = CGFloat(elapsed)
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.32)
                let fade = max(0, 1 - elapsed / duration)
                for particle in particles {
                    let x = origin.x + particle.velocity.dx * t
                    let y = origin.y + particle.velocity.dy * t + 520 * t * t
                    var piece = context
                    piece.opacity = fade
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(particle.spin * elapsed))
                    let rect = CGRect(x: -particle.width / 2, y: -particle.height / 2, width: particle.width, height: particle.height)
                    piece.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(colors[particle.colorIndex % colors.count]))
                }
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active, !running else { return }
            start = .now
            running = true
            Task {
                try? await Task.sleep(for: .seconds(duration))
                running = false
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ConfettiParticle {
    var velocity: CGVector
    var spin: Double
    var width: CGFloat
    var height: CGFloat
    var colorIndex: Int

    static func burst(count: Int) -> [ConfettiParticle] {
        (0..<count).map { index in
            let angle = Double.random(in: (-Double.pi * 0.92)...(-Double.pi * 0.08))
            let speed = Double.random(in: 220...520)
            return ConfettiParticle(
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                spin: Double.random(in: -7...7),
                width: CGFloat.random(in: 5...8),
                height: CGFloat.random(in: 8...13),
                colorIndex: index
            )
        }
    }
}
