import SwiftUI

/// Everything the Today screen counts, read from each progress store.
struct ProgressSummary: Equatable {
    var streak = 0
    var dueReviews = 0
    var lessonsDone = 0
    var lessonsTotal = 0
    var openingsMastered = 0
    var openingsTotal = 0
    var puzzlesSolved = 0
    var puzzlesTotal = 0
    var record = ComputerGameRecord()

    @MainActor
    static func load(_ game: GameState, defaults: UserDefaults = .standard) -> ProgressSummary {
        var summary = ProgressSummary()
        summary.streak = ActivityStore(defaults: defaults).streak()
        summary.dueReviews = game.reviewQueue().count
        let lessons = game.allLessons
        summary.lessonsTotal = lessons.count
        summary.lessonsDone = lessons.filter { game.completedLessons.contains($0.id) }.count
        let tutorials = OpeningTutorialProgressStore(defaults: defaults)
        summary.openingsTotal = game.openingTutorials.count
        summary.openingsMastered = game.openingTutorials.filter {
            tutorials.progress(for: $0.id).status(for: $0.opening) == .mastered
        }.count
        summary.puzzlesTotal = PuzzleContent.allPuzzles.count
        summary.puzzlesSolved = PuzzleProgressStore(defaults: defaults).solved.count
        let decode = { (key: String) in
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(ComputerGameRecord.self, from: $0) } ?? ComputerGameRecord()
        }
        summary.record = decode(ComputerGame.recordKey) + decode(CloudSync.otherDevicesComputerKey)
        return summary
    }
}

/// The Today tab: what to do next, what is due, and how it is going.
struct HomeView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.scenePhase) private var scenePhase
    @State private var summary = ProgressSummary()
    @State private var showsSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                continueCard
                if summary.dueReviews > 0 {
                    reviewCard
                }
                statsCard
                practiceRow
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .onAppear(perform: refresh)
        .onChange(of: game.progress) { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }

    // MARK: - Continue

    @ViewBuilder
    private var continueCard: some View {
        if summary.lessonsTotal > 0 && summary.lessonsDone == summary.lessonsTotal {
            allDoneCard
        } else if let lesson = game.nextLesson() {
            let course = game.courses.first { CurriculumLoader.courseLessons($0).contains { $0.id == lesson.id } }
            let meta = course.map { CourseLibrary.meta(for: $0, brackets: game.brackets, completed: game.completedLessons) }
            let topic = Theme.topic(meta?.topic ?? "fundamentals")
            let step = game.savedStep(for: lesson.id) ?? 0
            let fen = lesson.steps.compactMap(\.fen).first
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(course?.title ?? "Lesson", systemImage: topic.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(topic.color)
                            .lineLimit(1)
                        Text(lesson.title)
                            .font(.title.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(lesson.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if let fen {
                        BoardThumbnail(fen: fen)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                            .accessibilityHidden(true)
                    }
                }
                HStack(spacing: Theme.Spacing.s) {
                    Text("\(lesson.timeMinutes) min")
                    if step > 0 {
                        Text("·")
                        Text("Step \(step + 1) of \(lesson.steps.count)")
                    }
                }
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                Button {
                    game.openLesson(lesson.id)
                } label: {
                    Text(step > 0 ? "Continue" : summary.lessonsDone == 0 ? "Start Learning" : "Start Lesson")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
            .padding(Theme.Spacing.l)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.floating, style: .continuous))
        }
    }

    private var allDoneCard: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.success)
            Text("Every lesson complete")
                .font(.title2.weight(.bold))
            Text("Keep your skills sharp with reviews and puzzles.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.floating, style: .continuous))
    }

    // MARK: - Review

    private var reviewCard: some View {
        Button {
            game.openReview()
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                IconTile(systemImage: "clock.arrow.circlepath", color: Theme.accent, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.dueReviews == 1 ? "1 review due" : "\(summary.dueReviews) reviews due")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("A few minutes keeps them fresh.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.m)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat(
                value: "\(summary.streak)",
                label: "Day streak",
                systemImage: "flame.fill",
                color: summary.streak > 0 ? Theme.warning : .secondary
            )
            Divider().frame(height: 40)
            stat(value: "\(summary.lessonsDone)/\(summary.lessonsTotal)", label: "Lessons", systemImage: "book.fill", color: Theme.accent)
            Divider().frame(height: 40)
            stat(value: "\(summary.puzzlesSolved)", label: "Puzzles", systemImage: "puzzlepiece.fill", color: Theme.success)
        }
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func stat(value: String, label: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Practice

    private var practiceRow: some View {
        HStack(spacing: Theme.Spacing.s) {
            shortcut("Play", detail: "vs Computer", systemImage: "desktopcomputer", color: Theme.success) {
                game.openPractice(.computer)
            }
            shortcut("Daily Puzzle", detail: dailyDetail, systemImage: "calendar", color: Theme.warning) {
                if let daily = PuzzleContent.dailySet(on: Date()) {
                    game.openPuzzles(.set(daily.id))
                } else {
                    game.openPuzzles()
                }
            }
        }
    }

    private var dailyDetail: String {
        guard let daily = PuzzleContent.dailySet(on: Date()) else { return "One move wins" }
        let key = daily.key(for: daily.puzzles[0])
        return PuzzleProgressStore().solved.contains(key) ? "Solved today" : "A new one every day"
    }

    private func shortcut(_ title: String, detail: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                IconTile(systemImage: systemImage, color: color, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    private func refresh() {
        withAnimation(DesignMotion.spring) {
            summary = ProgressSummary.load(game)
        }
    }
}
