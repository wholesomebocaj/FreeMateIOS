import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Writes the widget's snapshot after progress changes and asks the widget to refresh.
@MainActor
enum WidgetSnapshotWriter {
    static func write(_ game: GameState) {
        let next = game.nextLesson()
        let course = next.flatMap { lesson in
            game.courses.first { CurriculumLoader.courseLessons($0).contains { $0.id == lesson.id } }
        }
        let lessons = game.allLessons
        let snapshot = WidgetSnapshot(
            nextLessonId: next?.id,
            nextLessonTitle: next?.title,
            courseTitle: course?.title,
            lessonsDone: lessons.filter { game.completedLessons.contains($0.id) }.count,
            lessonsTotal: lessons.count,
            reviewDueDates: game.progress.reviews.values.compactMap(\.dueAt).sorted(),
            activeDays: ActivityStore().days.sorted(),
            updatedAt: Date()
        )
        // Compared as saved, to the second, so an unchanged snapshot does not reload the widget.
        guard snapshot.withoutTimestamp.encoded() != WidgetSnapshot.load()?.withoutTimestamp.encoded() else { return }
        snapshot.save()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

private extension WidgetSnapshot {
    var withoutTimestamp: WidgetSnapshot {
        var copy = self
        copy.updatedAt = .distantPast
        return copy
    }
}
