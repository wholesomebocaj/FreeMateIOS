import SwiftUI

/// The standard screen: themed background, a native navigation title, and the account button.
struct FreeMateScreen<Content: View>: View {
    var title: String
    var largeTitle = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .themeBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(largeTitle ? .large : .inline)
            .accountToolbar()
    }
}

/// A slim progress bar with its percentage beside it.
struct ProgressMeter: View {
    var value: Int
    var tint: Color?

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            CapsuleProgressBar(
                fraction: Double(min(max(value, 0), 100)) / 100,
                tint: tint ?? (value >= 100 ? Theme.success : Theme.accent)
            )
            Text("\(value)%")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(value) percent")
    }
}
