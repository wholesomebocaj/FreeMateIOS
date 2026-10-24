import SwiftUI

/// The Learn tab: courses grouped by level, with search.
struct CourseLibraryView: View {
    @EnvironmentObject private var game: GameState

    /// Courses in recommended order, grouped by level and keeping that order.
    private var groups: [(level: String, entries: [CourseLibraryMeta])] {
        var result: [(level: String, entries: [CourseLibraryMeta])] = []
        for entry in game.libraryEntries() {
            if let index = result.firstIndex(where: { $0.level == entry.bracketLabel }) {
                result[index].entries.append(entry)
            } else {
                result.append((entry.bracketLabel, [entry]))
            }
        }
        return result
    }

    var body: some View {
        let groups = groups
        List {
            ForEach(groups, id: \.level) { group in
                Section(group.level) {
                    ForEach(group.entries) { meta in
                        NavigationLink(value: LessonRoute.course(meta.course.id)) {
                            CourseRow(meta: meta)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView.search(text: game.library.query)
            }
        }
        .navigationTitle("Learn")
        .searchable(text: $game.library.query, prompt: "Courses and topics")
    }
}

struct CourseRow: View {
    let meta: CourseLibraryMeta

    var body: some View {
        let topic = Theme.topic(meta.topic)
        let done = Int((Double(meta.progress) / 100 * Double(meta.lessonCount)).rounded())
        IconRow(
            title: meta.course.title,
            subtitle: "\(meta.lessonCount) lessons · \(meta.estimatedMinutes) min",
            systemImage: topic.symbol,
            color: topic.color
        ) {
            if meta.status == "completed" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
                    .accessibilityLabel("Completed")
            } else if meta.status == "in-progress" {
                Text("\(done)/\(meta.lessonCount)")
            }
        }
    }
}

/// A small circular progress indicator.
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
