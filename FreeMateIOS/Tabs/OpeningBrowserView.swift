import SwiftUI

/// The Openings tab: guided tutorials, then repertoire courses by side, with search.
struct OpeningBrowserView: View {
    @EnvironmentObject private var game: GameState
    @State private var query = ""
    @State private var tutorialProgress: [String: OpeningTutorialProgress] = [:]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var tutorials: [OpeningTutorial] {
        game.openingTutorials.filter { tutorial in
            guard !trimmedQuery.isEmpty else { return true }
            let opening = tutorial.opening
            return ([opening.name, opening.eco ?? "", opening.ecoName ?? ""] + opening.variations.map(\.name))
                .joined(separator: " ").lowercased().contains(trimmedQuery)
        }
    }

    private func courses(side: String) -> [OpeningCourse] {
        game.openings.filter { opening in
            guard opening.side == side else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            return "\(opening.name) \(opening.eco)".lowercased().contains(trimmedQuery)
        }
    }

    var body: some View {
        let tutorials = tutorials
        let white = courses(side: "White")
        let black = courses(side: "Black")
        List {
            if !tutorials.isEmpty {
                Section {
                    ForEach(tutorials) { tutorial in
                        NavigationLink(value: OpeningRoute.tutorial(tutorial.id)) {
                            TutorialRow(
                                tutorial: tutorial,
                                status: (tutorialProgress[tutorial.id] ?? OpeningTutorialProgress()).status(for: tutorial.opening)
                            )
                        }
                    }
                } header: {
                    Text("Guided Tutorials")
                } footer: {
                    Text("Play the main line, then answer the common replies from memory.")
                }
            }
            courseSection("Play as White", white)
            courseSection("Play as Black", black)
        }
        .listStyle(.insetGrouped)
        .overlay {
            if tutorials.isEmpty && white.isEmpty && black.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Openings")
        .searchable(text: $query, prompt: "Openings or ECO codes")
        .onAppear(perform: reloadTutorialProgress)
    }

    @ViewBuilder
    private func courseSection(_ title: String, _ courses: [OpeningCourse]) -> some View {
        if !courses.isEmpty {
            Section(title) {
                ForEach(courses) { opening in
                    NavigationLink(value: OpeningRoute.overview(opening.id)) {
                        HStack(spacing: Theme.Spacing.s) {
                            SideTile(isWhite: opening.side == "White", size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(opening.name)
                                Text("\(opening.eco) · \(opening.difficulty)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func reloadTutorialProgress() {
        let store = OpeningTutorialProgressStore()
        var map: [String: OpeningTutorialProgress] = [:]
        for tutorial in game.openingTutorials {
            map[tutorial.id] = store.progress(for: tutorial.id)
        }
        tutorialProgress = map
    }
}

struct TutorialRow: View {
    let tutorial: OpeningTutorial
    let status: TutorialMasteryStatus

    var body: some View {
        let opening = tutorial.opening
        HStack(spacing: Theme.Spacing.m) {
            BoardThumbnail(fen: tutorial.previewFen, isFlipped: opening.userSide == .black)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(opening.name)
                    .font(.headline)
                Text("\(opening.userSide.label) · \(opening.variations.count) variations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.xs)
            switch status {
            case .mastered:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.success)
            case .inProgress(let percent):
                Text("\(percent)%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            case .notStarted:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(status.label)
    }
}

/// A board square with a knight of the side the course is played from.
struct SideTile: View {
    let isWhite: Bool
    var size: CGFloat = 52

    var body: some View {
        ChessPieceView(glyph: .knight, isWhite: isWhite)
            .padding(size * 0.14)
            .frame(width: size, height: size)
            .background(
                isWhite ? BoardPalette.sage.dark : BoardPalette.sage.light,
                in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
