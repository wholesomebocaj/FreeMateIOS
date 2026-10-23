import SwiftUI

/// Every guided tutorial, as large tappable cards with a preview of the opening's position.
struct OpeningTutorialListView: View {
    @EnvironmentObject private var game: GameState
    @State private var progress: [String: OpeningTutorialProgress] = [:]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Text("Learn each main line move by move, then test yourself against the replies opponents really play.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                ForEach(game.openingTutorials) { tutorial in
                    NavigationLink(value: OpeningRoute.tutorial(tutorial.id)) {
                        OpeningTutorialCard(
                            tutorial: tutorial,
                            status: (progress[tutorial.id] ?? OpeningTutorialProgress()).status(for: tutorial.opening)
                        )
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Opening Tutorials")
        .navigationBarTitleDisplayMode(.large)
        .tint(DesignTokens.accent)
        .onAppear(perform: reloadProgress)
    }

    private func reloadProgress() {
        let store = OpeningTutorialProgressStore()
        var map: [String: OpeningTutorialProgress] = [:]
        for tutorial in game.openingTutorials {
            map[tutorial.id] = store.progress(for: tutorial.id)
        }
        withAnimation(DesignMotion.spring) { progress = map }
    }
}

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

/// The way into the tutorials from the Openings tab.
struct OpeningTutorialsEntryCard: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        if !game.openingTutorials.isEmpty {
            NavigationLink(value: OpeningRoute.tutorials) {
                HStack(spacing: 14) {
                    ZStack {
                        ForEach(Array(game.openingTutorials.prefix(2).enumerated()), id: \.element.id) { index, tutorial in
                            BoardThumbnail(fen: tutorial.previewFen, isFlipped: tutorial.opening.userSide == .black)
                                .frame(width: 54, height: 54)
                                .rotationEffect(.degrees(index == 0 ? -7 : 6))
                                .offset(x: index == 0 ? -8 : 10, y: index == 0 ? 2 : -2)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                    }
                    .frame(width: 78, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opening Tutorials")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FreeMateTheme.text)
                        Text("Guided main lines, then \"what if?\" practice")
                            .font(.subheadline)
                            .foregroundStyle(FreeMateTheme.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(FreeMateTheme.muted)
                }
                .padding(16)
                .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows the guided opening tutorials")
        }
    }
}
