import XCTest
@testable import FreeMateIOS

final class PuzzleModesTests: XCTestCase {
    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FreeMateIOS/Resources")

    private func catalog() throws -> PuzzleCatalog {
        if let bundled = try? PuzzleLibrary.loadCatalog() { return bundled }
        return try PuzzleLibrary.decodeCatalog(Data(contentsOf: Self.resources.appendingPathComponent("puzzles.json")))
    }

    private func drills() throws -> [Drill] {
        if let bundled = try? PuzzleLibrary.loadDrills() { return bundled }
        return try PuzzleLibrary.decodeDrills(Data(contentsOf: Self.resources.appendingPathComponent("drills.json")))
    }

    private func blunders() throws -> [BlunderCheck] {
        if let bundled = try? BlunderCheckLibrary.loadBundled() { return bundled }
        return try BlunderCheckLibrary.decode(Data(contentsOf: Self.resources.appendingPathComponent("blunders.json")))
    }

    private func defaults() throws -> (UserDefaults, () -> Void) {
        let suite = "PuzzleModesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return (defaults, { defaults.removePersistentDomain(forName: suite) })
    }

    private let smothered = Puzzle(
        id: "m2", prompt: "Mate in two.", fen: "r6k/6pp/7N/8/8/1Q6/8/7K w - - 0 1",
        solution: ["b3g8"], hint: "", success: "", theme: .mate, mateIn: 2
    )

    private func session(_ puzzles: [Puzzle]) -> PuzzleSession {
        PuzzleSession(set: PuzzleSet(drill: Drill(id: "t", title: "T", summary: "", puzzles: puzzles)))
    }

    // MARK: - Content

    func testCollectionsLoad() throws {
        let catalog = try catalog()
        XCTAssertEqual(catalog.collections.map(\.id), ["endgames", "mate-in-two", "skewers", "discovered-attacks"])
        XCTAssertEqual(PuzzleSet(collection: catalog.collections[0]).id, "collection/endgames")
        XCTAssertTrue(catalog.collections.first { $0.id == "mate-in-two" }!.puzzles.allSatisfy { $0.moveCount == 2 })
    }

    func testEveryCollectionSolutionIsLegal() throws {
        for puzzle in try catalog().collections.flatMap(\.puzzles) {
            for uci in puzzle.solution {
                XCTAssertNotNil(Puzzle.play(uci, from: puzzle.fen), "\(puzzle.id): \(uci)")
                XCTAssertTrue(puzzle.accepts(uci), "\(puzzle.id): \(uci)")
            }
        }
    }

    func testEveryMateInTwoEndsInMateAfterTheComputersDefense() throws {
        for puzzle in try catalog().collections.flatMap(\.puzzles) where puzzle.moveCount == 2 {
            for key in puzzle.solution {
                let afterKey = try XCTUnwrap(Puzzle.play(key, from: puzzle.fen))
                let defense = try XCTUnwrap(Puzzle.defense(from: afterKey), puzzle.id)
                let afterDefense = try XCTUnwrap(Puzzle.play(defense, from: afterKey))
                XCTAssertNotNil(Puzzle.matingMove(from: afterDefense), "\(puzzle.id): no mate after \(key) \(defense)")
            }
        }
    }

    func testBlunderChecksAreConsistent() throws {
        let checks = try blunders()
        XCTAssertEqual(checks.count, 10)
        XCTAssertEqual(Set(checks.map(\.id)).count, checks.count)
        for check in checks {
            XCTAssertNotNil(Puzzle.play(check.move, from: check.fen), check.id)
            if check.isBlunder {
                let after = try XCTUnwrap(Puzzle.play(check.move, from: check.fen))
                XCTAssertNotNil(Puzzle.play(try XCTUnwrap(check.refutation), from: after), check.id)
            }
        }
        let scholars = try XCTUnwrap(checks.first { $0.id == "scholars-trap" })
        XCTAssertEqual(scholars.san, "Nf6")
        XCTAssertEqual(scholars.sideToMove, .black)
        XCTAssertEqual(scholars.refutationSAN, "Qxf7#")
    }

    // MARK: - Mate in two

    func testMateInTwoPlaysTheDefenseThenTakesAnyMate() {
        var session = session([smothered])

        XCTAssertEqual(session.submit("h6f7"), .wrong, "Nf7+ is not the key move")
        XCTAssertEqual(session.answerMove, "b3g8")
        XCTAssertEqual(session.submit("b3g8"), .correct(reply: "a8g8"))
        XCTAssertEqual(session.step, 1)
        XCTAssertEqual(session.answerMove, "h6f7")
        XCTAssertEqual(session.submit("h1g1"), .wrong)
        XCTAssertEqual(session.submit("h6f7"), .solved)
        XCTAssertTrue(session.isSolved)
        XCTAssertEqual(session.firstTryCount, 0, "Two misses along the way")
    }

    func testAMateInTwoKeyIsNotAcceptedAsAnyMate() {
        XCTAssertTrue(smothered.accepts("b3g8"))
        XCTAssertFalse(smothered.accepts("h6f7"))
    }

    func testAdvanceResetsTheStep() {
        var session = session([smothered, smothered])
        _ = session.submit("b3g8")
        _ = session.submit("h6f7")
        session.advance()

        XCTAssertEqual(session.index, 1)
        XCTAssertEqual(session.step, 0)
        XCTAssertEqual(session.fen, smothered.fen)
    }

    // MARK: - Daily

    func testDailyPuzzleIsStableAndVisitsEveryPuzzleBeforeRepeating() throws {
        let pool = DailyPuzzle.pool(catalog: try catalog(), drills: try drills())
        XCTAssertEqual(pool.count, 55)
        XCTAssertEqual(Set(pool.map(\.id)).count, pool.count)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 9))!
        let later = calendar.date(byAdding: .hour, value: 10, to: start)!

        XCTAssertEqual(DailyPuzzle.puzzle(on: start, pool: pool, calendar: calendar), DailyPuzzle.puzzle(on: later, pool: pool, calendar: calendar))
        let days = (0..<pool.count).map { calendar.date(byAdding: .day, value: $0, to: start)! }
        let picked = days.compactMap { DailyPuzzle.puzzle(on: $0, pool: pool, calendar: calendar)?.id }
        XCTAssertEqual(Set(picked).count, pool.count)
        XCTAssertEqual(DailyPuzzle.set(on: start, pool: pool, calendar: calendar)?.id, "daily/2026-10-24")
    }

    func testDailyStreakCountsSolvedDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 9))!
        let solved: Set<String> = ["daily/2026-10-23/a", "daily/2026-10-24/b", "daily/2026-10-20/c", "level/1/x"]

        XCTAssertEqual(DailyPuzzle.streak(solved: solved, today: today, calendar: calendar), 2)
    }

    // MARK: - Rush

    func testRushScoresStrikesAndSkipsTwoMovePuzzles() throws {
        let pool = DailyPuzzle.pool(catalog: try catalog(), drills: try drills())
        var generator = SeededGenerator(state: 7)
        var rush = RushSession(pool: pool, using: &generator)
        XCTAssertTrue(rush.puzzles.allSatisfy { $0.moveCount == 1 })
        XCTAssertEqual(rush.puzzles.count, pool.count - 5)

        XCTAssertTrue(rush.submit(rush.puzzle!.solution[0]))
        XCTAssertEqual(rush.score, 1)
        for _ in 0..<3 { rush.submit("a1a1") }
        XCTAssertEqual(rush.strikes, 3)
        XCTAssertTrue(rush.isOver)
        XCTAssertNil(rush.puzzle)
        XCTAssertFalse(rush.submit("a1a1"))
    }

    func testRushStoreKeepsTheBest() throws {
        let (defaults, cleanUp) = try defaults()
        defer { cleanUp() }
        let store = RushStore(defaults: defaults)

        XCTAssertTrue(store.record(5))
        XCTAssertFalse(store.record(3))
        XCTAssertEqual(store.best, 5)
        XCTAssertEqual(try XCTUnwrap(SyncMerge.rushBest(JSONEncoder().encode(5), JSONEncoder().encode(9))), try JSONEncoder().encode(9))
    }

    // MARK: - Blunder check

    func testBlunderCheckSessionScoresAnswers() throws {
        let checks = Array(try blunders().prefix(2))
        var session = BlunderCheckSession(checks: checks)

        XCTAssertTrue(session.answer(isBlunder: true), "Qxd5 loses the queen")
        XCTAssertFalse(session.answer(isBlunder: false), "Already answered")
        XCTAssertTrue(session.wasCorrect)
        session.next()
        XCTAssertFalse(session.answer(isBlunder: true), "exd5 is safe")
        XCTAssertFalse(session.wasCorrect)
        session.next()
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.correctCount, 1)
    }

    func testBlunderProgressIsSaved() throws {
        let (defaults, cleanUp) = try defaults()
        defer { cleanUp() }
        BlunderProgressStore(defaults: defaults).markCorrect("a")
        BlunderProgressStore(defaults: defaults).markCorrect("a")

        XCTAssertEqual(BlunderProgressStore(defaults: defaults).correct, ["a"])
    }
}
