#if canImport(UIKit)
import XCTest
@testable import FreeMateIOS

/// Uses the bundled curriculum, so it runs in the app host (Xcode only).
@MainActor
final class GameStateTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "GameStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCompletingALessonSavesProgressSchedulesAReviewAndCountsToday() throws {
        let game = GameState(defaults: defaults)
        let lesson = try XCTUnwrap(game.allLessons.first)
        var changes = 0
        game.onProgressChange = { changes += 1 }

        game.markLessonComplete(lesson)

        XCTAssertTrue(game.completedLessons.contains(lesson.id))
        XCTAssertEqual(game.upcomingReviews().map(\.itemId), [lesson.id])
        XCTAssertTrue(game.reviewQueue().isEmpty, "The first check-in is tomorrow")
        XCTAssertEqual(game.streak, 1)
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(GameState(defaults: defaults).completedLessons.contains(lesson.id), "Saved")
    }

    func testAMissedStepIsDueNow() throws {
        let game = GameState(defaults: defaults)
        let lesson = try XCTUnwrap(game.allLessons.first)
        game.recordReviewFailure(ReviewSeed(kind: .lesson, itemId: lesson.id, branchId: nil, title: lesson.title, subtitle: "Missed"))

        XCTAssertEqual(game.reviewQueue().map(\.itemId), [lesson.id])
        XCTAssertEqual(game.reviewLabel(game.reviewQueue()[0]), "Missed recently")
    }

    func testWidgetLinksOpenTheRightScreen() throws {
        let game = GameState(defaults: defaults)
        let lesson = try XCTUnwrap(game.allLessons.dropFirst().first)

        game.open(URL(string: "freemate://review")!)
        XCTAssertEqual(game.selectedTab, .home)
        XCTAssertEqual(game.homePath, [.review])

        game.open(URL(string: "freemate://lesson/\(lesson.id)")!)
        XCTAssertEqual(game.selectedTab, .lessons)
        XCTAssertEqual(game.lessonPath, [.lesson(lesson.id)])

        game.open(URL(string: "freemate://lesson/not-a-lesson")!)
        XCTAssertEqual(game.selectedTab, .lessons)

        game.open(URL(string: "https://example.com")!)
        XCTAssertEqual(game.selectedTab, .lessons, "Other schemes are ignored")
    }

    func testWidgetSnapshotCountsDueReviewsAndStreakAtRenderTime() {
        // Whole seconds, because the snapshot saves dates to the second.
        let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let calendar = Calendar.current
        let today = ActivityStore.day(now, calendar: calendar)
        let yesterday = ActivityStore.day(calendar.date(byAdding: .day, value: -1, to: now)!, calendar: calendar)
        let snapshot = WidgetSnapshot(
            nextLessonId: "forks", nextLessonTitle: "Forks", courseTitle: "Tactics",
            lessonsDone: 3, lessonsTotal: 15,
            reviewDueDates: [now.addingTimeInterval(-60), now.addingTimeInterval(3600), now.addingTimeInterval(90_000)],
            activeDays: [yesterday, today], updatedAt: now
        )

        XCTAssertEqual(snapshot.dueReviews(at: now), 1)
        XCTAssertEqual(snapshot.dueReviews(at: now.addingTimeInterval(7200)), 2)
        XCTAssertEqual(snapshot.nextReviewDate(after: now), now.addingTimeInterval(3600))
        XCTAssertEqual(snapshot.streak(at: now), 2)

        snapshot.save(to: defaults)
        XCTAssertEqual(WidgetSnapshot.load(from: defaults), snapshot)
    }

    func testDashboardSummaryReadsEveryStore() throws {
        let game = GameState(defaults: defaults)
        game.markLessonComplete(try XCTUnwrap(game.allLessons.first))
        PuzzleProgressStore(defaults: defaults).markSolved("level/1/l1-free-rook", firstTry: true)
        defaults.set(try JSONEncoder().encode(ComputerGameRecord(wins: 2, draws: 1, losses: 0)), forKey: ComputerGame.recordKey)
        defaults.set(try JSONEncoder().encode(ComputerGameRecord(wins: 1, draws: 0, losses: 3)), forKey: CloudSync.otherDevicesComputerKey)

        let summary = ProgressSummary.load(game, defaults: defaults)

        XCTAssertEqual(summary.lessonsDone, 1)
        XCTAssertEqual(summary.lessonsTotal, game.allLessons.count)
        XCTAssertEqual(summary.puzzlesSolved, 1)
        XCTAssertEqual(summary.puzzlesTotal, 55, "Levels, collections, and drills")
        XCTAssertEqual(summary.openingsTotal, game.openingTutorials.count)
        XCTAssertEqual(summary.record, ComputerGameRecord(wins: 3, draws: 1, losses: 3), "This device plus the others")
        XCTAssertEqual(summary.streak, 1)
    }
}
#endif
