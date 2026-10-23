import SwiftUI

/// Everything the Home dashboard counts, read from each progress store.
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
        let catalog = try? PuzzleLibrary.loadCatalog()
        let drills = (try? PuzzleLibrary.loadDrills()) ?? []
        summary.puzzlesTotal = (catalog?.levels.reduce(0) { $0 + $1.puzzles.count } ?? 0) + drills.reduce(0) { $0 + $1.puzzles.count }
        summary.puzzlesSolved = PuzzleProgressStore(defaults: defaults).solved.count
        let decode = { (key: String) in
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(ComputerGameRecord.self, from: $0) } ?? ComputerGameRecord()
        }
        summary.record = decode(ComputerGame.recordKey) + decode(CloudSync.otherDevicesComputerKey)
        return summary
    }
}

/// The "Your Progress" section on Home.
struct ProgressDashboard: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.scenePhase) private var scenePhase
    @State private var summary = ProgressSummary()

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Your Progress")
            streakCard
            LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                tile(
                    "Lessons", value: "\(summary.lessonsDone)/\(summary.lessonsTotal)",
                    systemImage: "book.fill", color: Theme.accent,
                    fraction: fraction(summary.lessonsDone, summary.lessonsTotal)
                ) { game.selectedTab = .lessons }
                tile(
                    "Openings mastered", value: "\(summary.openingsMastered)/\(summary.openingsTotal)",
                    systemImage: "arrow.triangle.branch", color: Theme.topic("openings").color,
                    fraction: fraction(summary.openingsMastered, summary.openingsTotal)
                ) { game.selectedTab = .openings }
                tile(
                    "Puzzles solved", value: "\(summary.puzzlesSolved)/\(summary.puzzlesTotal)",
                    systemImage: "puzzlepiece.fill", color: Theme.warning,
                    fraction: fraction(summary.puzzlesSolved, summary.puzzlesTotal)
                ) { openPractice(.puzzles) }
                tile(
                    "vs Computer", value: "\(summary.record.wins)–\(summary.record.draws)–\(summary.record.losses)",
                    systemImage: "desktopcomputer", color: Theme.success,
                    caption: summary.record.played == 0 ? "No games yet" : "Wins, draws, losses"
                ) { openPractice(.computer) }
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: game.progress) { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }

    private var streakCard: some View {
        Button {
            game.selectedTab = .review
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                IconTile(systemImage: "flame.fill", color: summary.streak > 0 ? Theme.warning : .secondary, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.streak == 0 ? "Start a streak today" : "\(summary.streak)-day streak")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(reviewText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if summary.dueReviews > 0 {
                    StatusBadge(text: "\(summary.dueReviews) due", systemImage: "arrow.clockwise", tint: Theme.accent)
                }
            }
            .multilineTextAlignment(.leading)
            .cardStyle()
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityHint("Opens Review")
    }

    private var reviewText: String {
        switch summary.dueReviews {
        case 0: return summary.streak == 0 ? "Practice anything to begin." : "No reviews due. Keep it going with a lesson."
        case 1: return "1 review is due today."
        default: return "\(summary.dueReviews) reviews are due today."
        }
    }

    private func tile(
        _ title: String,
        value: String,
        systemImage: String,
        color: Color,
        fraction: Double? = nil,
        caption: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Image(systemName: systemImage).foregroundStyle(color)
                    Spacer(minLength: 0)
                }
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let fraction {
                    CapsuleProgressBar(fraction: fraction, tint: color)
                        .frame(height: 5)
                } else if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: Theme.Spacing.m)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .combine)
    }

    private func fraction(_ done: Int, _ total: Int) -> Double {
        total == 0 ? 0 : Double(done) / Double(total)
    }

    private func openPractice(_ mode: PracticeMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: PracticeMode.storageKey)
        game.selectedTab = .practice
    }

    private func refresh() {
        withAnimation(DesignMotion.spring) {
            summary = ProgressSummary.load(game)
        }
    }
}
