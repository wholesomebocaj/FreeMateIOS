import SwiftUI

struct OpeningTutorialCard: View {
    let tutorial: OpeningTutorial
    let status: TutorialMasteryStatus

    var body: some View {
        let opening = tutorial.opening
        HStack(alignment: .center, spacing: 16) {
            BoardThumbnail(fen: tutorial.previewFen, isFlipped: opening.userSide == .black)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(opening.eco ?? "Opening") · \(opening.userSide.label) · \(opening.variations.count) variations")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(opening.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(opening.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                TutorialStatusBadge(status: status)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the tutorial")
    }
}

struct TutorialStatusBadge: View {
    let status: TutorialMasteryStatus

    private var tint: Color {
        switch status {
        case .notStarted: return .secondary
        case .inProgress: return DesignTokens.accent
        case .mastered: return DesignTokens.success
        }
    }

    var body: some View {
        Label(status.label, systemImage: status.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
            .contentTransition(.opacity)
    }
}
