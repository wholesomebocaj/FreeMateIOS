import XCTest
@testable import FreeMateIOS

final class LearnerProgressTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private let lessonSeed = ReviewSeed(kind: .lesson, itemId: "forks", branchId: nil, title: "Forks", subtitle: "Tactics")
    private let openingSeed = ReviewSeed(kind: .opening, itemId: "italian-game", branchId: "main", title: "Italian", subtitle: "")

    private func days(_ count: Int, after date: Date) -> Date {
        calendar.date(byAdding: .day, value: count, to: date)!
    }

    private func makeDefaults() throws -> (UserDefaults, () -> Void) {
        let suite = "LearnerProgressTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return (defaults, { defaults.removePersistentDomain(forName: suite) })
    }

    // MARK: - Schedule

    func testItemsClimbTheOneThreeSevenFourteenDayLadder() {
        var item = ReviewSchedule.success(nil, seed: lessonSeed, now: start, calendar: calendar)
        XCTAssertEqual(item.state, .learning)
        XCTAssertEqual(item.stage, 1)
        XCTAssertEqual(item.dueAt, days(1, after: start))

        var now = start
        for (stage, wait) in [(2, 3), (3, 7), (4, 14)] {
            now = item.dueAt!
            item = ReviewSchedule.success(item, seed: lessonSeed, now: now, calendar: calendar)
            XCTAssertEqual(item.stage, stage)
            XCTAssertEqual(item.dueAt, days(wait, after: now))
        }

        item = ReviewSchedule.success(item, seed: lessonSeed, now: item.dueAt!, calendar: calendar)
        XCTAssertEqual(item.state, .mastered)
        XCTAssertNil(item.dueAt)
        XCTAssertEqual(item.successStreak, 5)
    }

    func testPracticingEarlyDoesNotSkipTheWait() {
        let first = ReviewSchedule.success(nil, seed: lessonSeed, now: start, calendar: calendar)
        let early = ReviewSchedule.success(first, seed: lessonSeed, now: start.addingTimeInterval(3600), calendar: calendar)

        XCTAssertEqual(early.stage, 1)
        XCTAssertEqual(early.dueAt, first.dueAt)
        XCTAssertEqual(early.successes, 2)
    }

    func testAMissStartsTheLadderOverAndIsDueNow() {
        var item = ReviewSchedule.success(nil, seed: lessonSeed, now: start, calendar: calendar)
        item = ReviewSchedule.success(item, seed: lessonSeed, now: item.dueAt!, calendar: calendar)
        let missedAt = days(2, after: start)
        item = ReviewSchedule.failure(item, seed: lessonSeed, now: missedAt)

        XCTAssertEqual(item.state, .shaky)
        XCTAssertEqual(item.stage, 0)
        XCTAssertEqual(item.dueAt, missedAt)
        XCTAssertEqual(item.successStreak, 0)
        XCTAssertEqual(item.failures, 1)

        item = ReviewSchedule.success(item, seed: lessonSeed, now: missedAt, calendar: calendar)
        XCTAssertEqual(item.stage, 1, "Fixing a miss restarts at the 1-day rung")
    }

    func testQueueShowsMissedItemsFirstAndHidesFutureOnes() {
        var progress = LearnerProgress()
        progress.recordSuccess(lessonSeed, now: start)
        progress.recordFailure(openingSeed, now: start)
        let tomorrow = days(1, after: start).addingTimeInterval(60)

        XCTAssertEqual(progress.reviewQueue(now: start).map(\.itemId), ["italian-game"])
        XCTAssertEqual(progress.upcomingReviews(now: start).map(\.itemId), ["forks"])
        XCTAssertEqual(progress.reviewQueue(now: tomorrow).map(\.itemId), ["italian-game", "forks"])
    }

    func testCompletingALessonSchedulesItsFirstReview() {
        var progress = LearnerProgress()
        progress.noteStep(3, lesson: "forks")
        progress.completeLesson("forks", seed: lessonSeed, now: start)

        XCTAssertTrue(progress.completedLessons.contains("forks"))
        XCTAssertNil(progress.lessonSteps["forks"])
        XCTAssertEqual(progress.reviews["lesson:forks"]?.stage, 1)
    }

    // MARK: - Storage

    func testProgressRoundTripsThroughTheStore() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        let store = LearnerProgressStore(defaults: defaults)
        var progress = store.load()
        progress.completeLesson("forks", seed: lessonSeed, now: start)
        progress.saveLine(openingId: "italian-game", lineId: "main", progress: OpeningLineProgress(
            moveIndex: 4, playedMoves: ["e2e4"], currentFen: nil, completed: false, updatedAt: start
        ))
        store.save(progress)

        XCTAssertEqual(LearnerProgressStore(defaults: defaults).load(), progress)
    }

    func testMigratesLegacyKeysAndDeletesAccounts() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        defaults.set(["board-basics"], forKey: "freemate.completedLessons")
        defaults.set(try JSONSerialization.data(withJSONObject: ["piece-movement": 2]), forKey: "freemate.lessonSteps")
        defaults.set(try JSONSerialization.data(withJSONObject: [
            "lesson:forks": [
                "type": "lesson", "id": "forks", "title": "Forks", "subtitle": "Tactics", "state": "mastered",
                "failures": 1, "attempts": 3, "successes": 2, "successStreak": 2,
                "lastSucceededAt": "2026-09-01T10:00:00.000Z", "updatedAt": "2026-09-01T10:00:00.000Z",
            ],
            "opening:scotch-game:main": [
                "type": "opening", "id": "scotch-game", "branchId": "main", "title": "Scotch", "state": "shaky",
                "failures": 2, "attempts": 2, "successes": 0, "successStreak": 0, "dueAt": "2026-09-02T10:00:00Z",
            ],
        ]), forKey: "freemate.reviewQueue")
        defaults.set(try JSONSerialization.data(withJSONObject: [
            "activeLineId": "main",
            "lines": ["main": ["moveIndex": 3, "playedMoves": ["e2e4", "e7e5", "g1f3"], "completed": false]],
        ]), forKey: "freemate-opening-progress:italian-game")
        defaults.set(try JSONSerialization.data(withJSONObject: [
            "main": ["completed": true, "completedAt": "2026-09-03T10:00:00Z"],
        ]), forKey: "freemate-opening-completions:italian-game")
        defaults.set(try JSONSerialization.data(withJSONObject: [
            ["lessonId": "center-control", "status": "mastered", "completed": true, "masteryScore": 100, "updatedAt": "x"],
        ]), forKey: "freemate.progress.lessons")
        defaults.set(Data("[{\"passwordHash\":\"pbkdf2_sha256$240000$salt$hash\"}]".utf8), forKey: "freemate.users")
        defaults.set("cookie", forKey: "freemate_auth")

        let progress = LearnerProgressStore(defaults: defaults).load()

        XCTAssertEqual(progress.completedLessons, ["board-basics", "center-control"])
        XCTAssertEqual(progress.lessonSteps, ["piece-movement": 2])
        let forks = try XCTUnwrap(progress.reviews["lesson:forks"])
        XCTAssertEqual(forks.state, .learning, "Old 'mastered forever' items start the new ladder")
        XCTAssertEqual(forks.stage, 1)
        XCTAssertEqual(forks.dueAt, LegacyProgressMigration.date("2026-09-02T10:00:00Z"))
        XCTAssertEqual(progress.reviews["opening:scotch-game:main"]?.state, .shaky)
        XCTAssertEqual(progress.openings["italian-game"]?.lines["main"]?.moveIndex, 3)
        XCTAssertEqual(progress.openings["italian-game"]?.completions["main"]?.completed, true)

        for key in ["freemate.users", "freemate_auth", "freemate.completedLessons", "freemate.reviewQueue",
                    "freemate-opening-progress:italian-game", "freemate.progress.lessons"] {
            XCTAssertNil(defaults.object(forKey: key), "\(key) should be removed")
        }
        XCTAssertNotNil(defaults.data(forKey: LearnerProgress.storageKey))
        XCTAssertEqual(LearnerProgressStore(defaults: defaults).load(), progress, "Migration runs once")
    }

    // MARK: - iCloud merge

    func testMergeKeepsWorkFromBothDevices() {
        var phone = LearnerProgress()
        phone.completeLesson("forks", seed: lessonSeed, now: start)
        phone.noteStep(2, lesson: "pins")
        phone.completeBranch(openingId: "italian-game", lineId: "main", seed: openingSeed, now: start)

        var tablet = LearnerProgress()
        tablet.completeLesson("board-basics", seed: ReviewSeed(kind: .lesson, itemId: "board-basics", branchId: nil, title: "Board", subtitle: ""), now: start)
        tablet.noteStep(5, lesson: "pins")
        tablet.noteStep(1, lesson: "forks")
        tablet.recordFailure(lessonSeed, now: days(1, after: start))

        let merged = LearnerProgress.merged(phone, tablet)

        XCTAssertEqual(merged.completedLessons, ["forks", "board-basics"])
        XCTAssertEqual(merged.lessonSteps, ["pins": 5], "Furthest step wins; completed lessons drop their step")
        XCTAssertEqual(merged.reviews["lesson:forks"]?.state, .shaky, "The newer review wins")
        XCTAssertEqual(merged.openings["italian-game"]?.completions["main"]?.completed, true)
        XCTAssertEqual(LearnerProgress.merged(tablet, phone), merged, "Order does not matter")
        XCTAssertEqual(LearnerProgress.merged(merged, merged), merged, "Merging twice changes nothing")
    }

    func testSyncMergeRules() throws {
        let progressKey = try XCTUnwrap(SyncMerge.keys.first { $0.key == LearnerProgress.storageKey })
        let data = Data("x".utf8)
        XCTAssertNil(SyncMerge.merge(progressKey, local: nil, cloud: nil))
        XCTAssertEqual(SyncMerge.merge(progressKey, local: data, cloud: nil), data)
        XCTAssertEqual(SyncMerge.merge(progressKey, local: nil, cloud: data), data)
        XCTAssertEqual(SyncMerge.merge(progressKey, local: data, cloud: Data("y".utf8)), data, "Unreadable cloud data keeps the local copy")

        let puzzles = try XCTUnwrap(SyncMerge.puzzles(
            JSONEncoder().encode(["a": PuzzleProgressStore.Record(firstTry: false), "b": PuzzleProgressStore.Record(firstTry: true)]),
            JSONEncoder().encode(["a": PuzzleProgressStore.Record(firstTry: true), "c": PuzzleProgressStore.Record(firstTry: false)])
        ))
        let puzzleMap = try JSONDecoder().decode([String: PuzzleProgressStore.Record].self, from: puzzles)
        XCTAssertEqual(puzzleMap.mapValues(\.firstTry), ["a": true, "b": true, "c": false])

        var mine = OpeningTutorialProgress()
        mine.completedVariationIds = ["x"]
        mine.fewestMistakes = 3
        mine.bestPercent = 40
        var theirs = OpeningTutorialProgress()
        theirs.mainLineCompleted = true
        theirs.completedVariationIds = ["y"]
        theirs.fewestMistakes = 1
        theirs.bestPercent = 90
        let tutorials = try XCTUnwrap(SyncMerge.tutorials(JSONEncoder().encode(["ruy": mine]), JSONEncoder().encode(["ruy": theirs])))
        let tutorial = try XCTUnwrap(try JSONDecoder().decode([String: OpeningTutorialProgress].self, from: tutorials)["ruy"])
        XCTAssertTrue(tutorial.mainLineCompleted)
        XCTAssertEqual(tutorial.completedVariationIds, ["x", "y"])
        XCTAssertEqual(tutorial.fewestMistakes, 1)
        XCTAssertEqual(tutorial.bestPercent, 90)

        let activity = try XCTUnwrap(SyncMerge.activity(JSONEncoder().encode(["2026-10-01", "2026-10-03"]), JSONEncoder().encode(["2026-10-02", "2026-10-03"])))
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: activity), ["2026-10-01", "2026-10-02", "2026-10-03"])
    }

    func testComputerGamesAreCountedPerDevice() {
        let own = ComputerGameRecord(wins: 2, draws: 0, losses: 1)
        let cloud = ["tablet": ComputerGameRecord(wins: 1, draws: 1, losses: 0), "phone": ComputerGameRecord(wins: 1, draws: 0, losses: 0)]

        let result = SyncMerge.deviceRecords(own: own, cloud: cloud, deviceId: "phone")

        XCTAssertEqual(result.cloud["phone"], own, "This device's own count replaces its old cloud copy")
        XCTAssertEqual(result.others, ComputerGameRecord(wins: 1, draws: 1, losses: 0))
        XCTAssertEqual(own + result.others, ComputerGameRecord(wins: 3, draws: 1, losses: 1))
    }

    // MARK: - Streak

    func testStreakCountsDaysInARowAndSurvivesUntilTheNextDayEnds() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        let store = ActivityStore(defaults: defaults, calendar: calendar)
        let today = start

        XCTAssertEqual(store.streak(today: today), 0)
        store.record(days(-2, after: today))
        store.record(days(-1, after: today))
        XCTAssertEqual(store.streak(today: today), 2, "Not practicing yet today keeps yesterday's streak")
        store.record(today)
        store.record(today)
        XCTAssertEqual(store.streak(today: today), 3)
        XCTAssertEqual(store.streak(today: days(2, after: today)), 0, "A missed day ends it")
        store.record(days(-5, after: today))
        XCTAssertEqual(store.streak(today: today), 3, "Older days do not join a broken run")
    }
}
