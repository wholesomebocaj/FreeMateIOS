import SwiftUI

/// The floating card under the board. Text cross-fades as moves are played; a new scene
/// (such as branching out) slides the whole card up.
struct TutorialInstructionCard: View {
    let content: TutorialCardContent
    var shakeTrigger = 0
    var onAction: () -> Void
    var onHint: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        switch content.style {
        case .guide, .branching: return Theme.accent
        case .waiting: return .secondary
        case .hint: return Theme.warning
        case .success: return Theme.success
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: content.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.16), in: Circle())
                    .contentTransition(.symbolEffect(.replace))
                Text(content.eyebrow)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                if content.showsHintButton {
                    Button(action: onHint) {
                        Label("Hint", systemImage: "lightbulb")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            Text(content.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            if !content.message.isEmpty {
                Text(content.message)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            if let detail = content.detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            if let title = content.actionTitle {
                Button(action: onAction) {
                    Text(title)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(content.style == .success ? Theme.success : Theme.accent)
                .padding(.top, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(tint.opacity(content.style == .hint ? 0.45 : 0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
        .modifier(ShakeEffect(travel: reduceMotion ? 0 : 10, animatableData: CGFloat(shakeTrigger)))
        .animation(DesignMotion.shake, value: shakeTrigger)
        .animation(reduceMotion ? nil : DesignMotion.spring, value: content)
        .accessibilityElement(children: .contain)
    }
}
