import SwiftUI

/// The Lessons tab: search and filter chips on top, then a progress card, courses, and brackets.
struct CourseLibraryView: View {
    @EnvironmentObject private var game: GameState

    private var hasActiveFilters: Bool {
        var cleared = CourseLibraryState.reset
        cleared.query = game.library.query
        return game.library != cleared
    }

    private var isBrowsing: Bool {
        !hasActiveFilters && game.library.query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        let entries = game.libraryEntries()
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                filterBar
                VStack(alignment: .leading, spacing: 28) {
                    if isBrowsing, let next = game.nextLesson() {
                        ContinueLearningCard(
                            percent: game.progressPercent(),
                            completed: game.allLessons.filter { game.completedLessons.contains($0.id) }.count,
                            total: game.allLessons.count,
                            next: next
                        ) {
                            game.openLesson(next.id)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    courses(entries)
                    if isBrowsing {
                        brackets
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
        .navigationTitle("Lessons")
        .searchable(text: $game.library.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search courses and topics")
        .settingsToolbar()
        .animation(DesignMotion.spring, value: game.library)
    }

    private var filterBar: some View {
        FilterChipBar {
            FilterChipMenu(
                title: "Level",
                selection: $game.library.bracket,
                options: [FilterOption(value: "all", label: "All Levels")]
                    + game.brackets.map { FilterOption(value: $0.id, label: $0.title) }
            )
            FilterChipMenu(title: "Topic", selection: $game.library.topic, options: [
                FilterOption(value: "all", label: "All Topics"),
                FilterOption(value: "fundamentals", label: "Fundamentals"),
                FilterOption(value: "openings", label: "Openings"),
                FilterOption(value: "tactics", label: "Tactics"),
                FilterOption(value: "endgame", label: "Endgame"),
                FilterOption(value: "strategy", label: "Strategy"),
            ])
            FilterChipMenu(title: "Status", selection: $game.library.status, options: [
                FilterOption(value: "all", label: "Any Status"),
                FilterOption(value: "not-started", label: "Not Started"),
                FilterOption(value: "in-progress", label: "In Progress"),
                FilterOption(value: "completed", label: "Completed"),
            ])
            FilterChipMenu(title: "Color", selection: $game.library.color, options: [
                FilterOption(value: "all", label: "Any Color"),
                FilterOption(value: "white", label: "White"),
                FilterOption(value: "black", label: "Black"),
                FilterOption(value: "both", label: "Both"),
            ])
            FilterChipMenu(title: "Type", selection: $game.library.type, options: [
                FilterOption(value: "all", label: "Any Type"),
                FilterOption(value: "interactive lesson", label: "Interactive Lesson"),
                FilterOption(value: "opening course", label: "Opening Course"),
                FilterOption(value: "drill", label: "Drill"),
                FilterOption(value: "quiz", label: "Quiz"),
                FilterOption(value: "practice", label: "Practice"),
            ])
            if hasActiveFilters {
                ClearFiltersChip {
                    var cleared = CourseLibraryState.reset
                    cleared.query = game.library.query
                    game.library = cleared
                }
            }
        }
    }

    @ViewBuilder
    private func courses(_ entries: [CourseLibraryMeta]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Courses", subtitle: "\(entries.count) course\(entries.count == 1 ? "" : "s")") {
                Menu {
                    Picker("Sort By", selection: $game.library.sort) {
                        ForEach(CourseLibrarySort.allCases) { sort in
                            Text(sort.label).tag(sort)
                        }
                    }
                } label: {
                    Label(game.library.sort.label, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel("Sort courses")
                .accessibilityValue(game.library.sort.label)
            }
            if entries.isEmpty {
                emptyState
            } else {
                ForEach(entries) { meta in
                    Button {
                        game.openCourse(meta.course.id)
                    } label: {
                        LibraryCourseCard(meta: meta)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let query = game.library.query.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ContentUnavailableView {
                Label("No Courses", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("No courses match these filters.")
            } actions: {
                Button("Clear Filters") { game.resetLibrary() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
        }
    }

    private var brackets: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Skill Brackets", subtitle: "Follow a path from your current level")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(game.brackets) { bracket in
                        Button {
                            game.openBracket(bracket.slug)
                        } label: {
                            BracketCard(bracket: bracket, progress: game.bracketProgress(bracket))
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -20)
        }
    }
}

struct ContinueLearningCard: View {
    let percent: Int
    let completed: Int
    let total: Int
    let next: Lesson
    var onContinue: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            ProgressRing(fraction: Double(percent) / 100, tint: Theme.success)
                .frame(width: 64, height: 64)
                .overlay {
                    Text("\(percent)%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(completed) of \(total) lessons complete")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(next.title)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                Button(completed == 0 ? "Start Learning" : "Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

struct LibraryCourseCard: View {
    let meta: CourseLibraryMeta

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TopicTile(topic: meta.topic)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(meta.bracketLabel) · \(meta.lessonCount) lessons · \(meta.estimatedMinutes) min")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(meta.course.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(meta.course.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    CapsuleProgressBar(fraction: Double(meta.progress) / 100, tint: meta.status == "completed" ? Theme.success : Theme.accent)
                    Text(meta.status == "not-started" ? "New" : "\(meta.progress)%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue(meta.statusLabel)
    }
}

/// A rounded tile with the symbol and color of the course topic.
struct TopicTile: View {
    let topic: String

    var body: some View {
        let style = Theme.topic(topic)
        IconTile(systemImage: style.symbol, color: style.color)
    }
}

struct BracketCard: View {
    let bracket: SkillBracket
    let progress: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bracket.range)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(bracket.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(bracket.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxHeight: .infinity, alignment: .top)
            HStack(spacing: 8) {
                CapsuleProgressBar(fraction: Double(progress) / 100, tint: progress >= 100 ? Theme.success : Theme.accent)
                Text("\(progress)%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 250, height: 190, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A circular progress indicator.
struct ProgressRing: View {
    var fraction: Double
    var tint: Color
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.fill, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(DesignMotion.spring, value: fraction)
        .accessibilityHidden(true)
    }
}
