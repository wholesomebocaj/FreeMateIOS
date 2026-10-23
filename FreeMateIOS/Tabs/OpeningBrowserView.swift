import SwiftUI

/// The Openings tab: search and filter chips on top, guided tutorials, then repertoire courses.
struct OpeningBrowserView: View {
    @EnvironmentObject private var game: GameState
    @State private var query = ""
    /// "all", "White", or "Black", matching `OpeningCourse.side`.
    @State private var side = "all"
    @State private var difficulty = "all"
    @State private var tutorialProgress: [String: OpeningTutorialProgress] = [:]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var tutorials: [OpeningTutorial] {
        game.openingTutorials.filter { tutorial in
            let opening = tutorial.opening
            guard side == "all" || opening.userSide.label == side else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            let haystack = ([opening.name, opening.eco ?? "", opening.ecoName ?? "", opening.summary]
                + opening.variations.map(\.name)).joined(separator: " ").lowercased()
            return haystack.contains(trimmedQuery)
        }
    }

    private var courses: [OpeningCourse] {
        game.openings.filter { opening in
            guard side == "all" || opening.side == side else { return false }
            guard difficulty == "all" || opening.difficulty == difficulty else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            return "\(opening.name) \(opening.eco) \(opening.description)".lowercased().contains(trimmedQuery)
        }
    }

    private var levels: [String] {
        Array(Set(game.openings.map(\.difficulty))).sorted()
    }

    var body: some View {
        let tutorials = tutorials
        let courses = courses
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                filterBar
                VStack(alignment: .leading, spacing: 28) {
                    if !tutorials.isEmpty {
                        tutorialSection(tutorials)
                    }
                    if !courses.isEmpty {
                        courseSection(courses)
                    }
                    if tutorials.isEmpty && courses.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 4)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
        .themeBackground()
        .navigationTitle("Openings")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search openings or ECO codes")
        .settingsToolbar()
        .animation(DesignMotion.spring, value: side)
        .animation(DesignMotion.spring, value: difficulty)
        .onAppear(perform: reloadTutorialProgress)
    }

    private var filterBar: some View {
        FilterChipBar {
            FilterChipToggle(text: "All", isSelected: side == "all") { side = "all" }
            FilterChipToggle(text: "White", systemImage: "circle", isSelected: side == "White") { side = "White" }
            FilterChipToggle(text: "Black", systemImage: "circle.fill", isSelected: side == "Black") { side = "Black" }
            Divider()
                .frame(height: 22)
                .padding(.horizontal, 2)
            FilterChipMenu(
                title: "Course Level",
                selection: $difficulty,
                options: [FilterOption(value: "all", label: "All Levels")] + levels.map { FilterOption(value: $0, label: $0) }
            )
            if side != "all" || difficulty != "all" {
                ClearFiltersChip {
                    side = "all"
                    difficulty = "all"
                }
            }
        }
    }

    private func tutorialSection(_ tutorials: [OpeningTutorial]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Guided Tutorials", subtitle: "Learn the main line, then branch out")
            ForEach(tutorials) { tutorial in
                NavigationLink(value: OpeningRoute.tutorial(tutorial.id)) {
                    OpeningTutorialCard(
                        tutorial: tutorial,
                        status: (tutorialProgress[tutorial.id] ?? OpeningTutorialProgress()).status(for: tutorial.opening)
                    )
                }
                .buttonStyle(PressableCardStyle())
            }
        }
    }

    private func courseSection(_ courses: [OpeningCourse]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Repertoire Courses", subtitle: "\(courses.count) course\(courses.count == 1 ? "" : "s") with branching lines")
            ForEach(courses) { opening in
                OpeningCourseCard(
                    opening: opening,
                    onTrain: { game.openTrainer(id: opening.id, line: nil) },
                    onOverview: { game.openOpening(opening.id) }
                )
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if trimmedQuery.isEmpty {
            ContentUnavailableView {
                Label("No Openings", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("No openings match these filters.")
            } actions: {
                Button("Clear Filters") {
                    side = "all"
                    difficulty = "all"
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        } else {
            ContentUnavailableView.search(text: query)
        }
    }

    private func reloadTutorialProgress() {
        let store = OpeningTutorialProgressStore()
        var map: [String: OpeningTutorialProgress] = [:]
        for tutorial in game.openingTutorials {
            map[tutorial.id] = store.progress(for: tutorial.id)
        }
        withAnimation(DesignMotion.spring) { tutorialProgress = map }
    }
}

struct OpeningCourseCard: View {
    let opening: OpeningCourse
    var onTrain: () -> Void
    var onOverview: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SideTile(isWhite: opening.side == "White")
            VStack(alignment: .leading, spacing: 6) {
                Text("\(opening.eco) · \(opening.difficulty) · \(opening.side)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(opening.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(opening.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(opening.sectionCount) sections · \(opening.moveCount) moves")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 10) {
                    Button(action: onTrain) {
                        Label("Train", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: onOverview) {
                        Text("Overview")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// A small board square with a knight in the side the course is played from.
struct SideTile: View {
    let isWhite: Bool

    var body: some View {
        ChessPieceView(glyph: .knight, isWhite: isWhite)
            .padding(7)
            .frame(width: 52, height: 52)
            .background(
                isWhite ? BoardPalette.sage.dark : BoardPalette.sage.light,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
