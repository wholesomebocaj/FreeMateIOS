import SwiftUI

/// The top section: which stage the learner is in, and how far through it they are.
struct TutorialProgressHeader: View {
    let summary: TutorialProgressSummary
    var isComplete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.opacity)
                Spacer()
                Text(summary.detail)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            CapsuleProgressBar(fraction: summary.fraction, tint: isComplete ? DesignTokens.success : DesignTokens.accent)
            if let caption = summary.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
        }
        .animation(DesignMotion.spring, value: summary)
        .accessibilityElement(children: .combine)
    }
}
