import XCTest
@testable import FreeMateIOS

final class PuzzleTests: XCTestCase {
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

    private func allPuzzles() throws -> [Puzzle] {
        try catalog().levels.flatMap(\.puzzles) + drills().flatMap(\.puzzles)
    }

    private func set(_ puzzles: [Puzzle]) -> PuzzleSet {
        PuzzleSet(drill: Drill(id: "test", title: "Test", summary: "", puzzles: puzzles))
    }

    // MARK: - Bundled content

    func testBundledContentLoads() throws {
        let catalog = try catalog()
        XCTAssertEqual(catalog.levels.map(\.level), [1, 2, 3, 4])
        XCTAssertTrue(catalog.levels.allSatisfy { $0.puzzles.count == 6 })
        XCTAssertEqual(try drills().map(\.id), ["mate-in-one", "forks", "pins", "hanging", "out-of-check"])
        XCTAssertEqual(Set(catalog.levels.flatMap(\.puzzles).map(\.id)).count, 24)
    }

    func testEverySolutionIsLegalAndAccepted() throws {
        for puzzle in try allPuzzles() {
            let engine = try ChessEngine(fen: puzzle.fen)
            for uci in puzzle.solution {
                let legal = engine.legalMoves(from: String(uci.prefix(2))).contains { $0.uci == uci }
                XCTAssertTrue(legal, "\(puzzle.id): \(uci) is not legal")
                XCTAssertTrue(puzzle.accepts(uci), "\(puzzle.id): \(uci)")
            }
        }
    }

    func testEveryMateSolutionMates() throws {
        for puzzle in try allPuzzles() where puzzle.isMate {
            for uci in puzzle.solution {
                let engine = try ChessEngine(fen: puzzle.fen)
                engine.move(from: String(uci.prefix(2)), to: String(uci.dropFirst(2).prefix(2)))
                XCTAssertTrue(engine.isCheckmate(), "\(puzzle.id): \(uci) is not mate")
            }
        }
    }

    func testTheCoachAgreesWithEveryMaterialSolution() throws {
        for puzzle in try catalog().levels.flatMap(\.puzzles) where puzzle.theme == .material {
            let best = try XCTUnwrap(ComputerCoach.bestMove(fen: puzzle.fen))
            XCTAssertTrue(puzzle.solution.contains(best), "\(puzzle.id): the coach prefers \(best)")
        }
    }

    // MARK: - Accepting moves

    func testAnyMateSolvesAMatePuzzle() throws {
        let puzzle = Puzzle(
            id: "two-mates", prompt: "", fen: "6k1/8/6K1/8/8/8/8/Q7 w - - 0 1",
            solution: ["a1a8"], hint: "", success: "", theme: .mate
        )

        XCTAssertTrue(puzzle.accepts("a1a8"))
        XCTAssertTrue(puzzle.accepts("a1g7"), "Qg7 is also mate")
        XCTAssertFalse(puzzle.accepts("a1a7"))
        XCTAssertFalse(puzzle.accepts("a1h1"), "Not a legal move")
    }

    func testMaterialPuzzlesOnlyAcceptListedMoves() {
        let puzzle = Puzzle(
            id: "fork", prompt: "", fen: "r3k3/8/8/1N6/8/8/8/4K3 w - - 0 1",
            solution: ["b5c7"], hint: "", success: "", theme: .material
        )

        XCTAssertTrue(puzzle.accepts("b5c7"))
        XCTAssertTrue(puzzle.accepts("B5C7"))
        XCTAssertFalse(puzzle.accepts("b5d6"))
    }

    func testAMoveWithoutAPieceMatchesAListedPromotion() {
        let puzzle = Puzzle(
            id: "promote", prompt: "", fen: "8/P7/8/8/8/8/8/k6K w - - 0 1",
            solution: ["a7a8q"], hint: "", success: "", theme: .material
        )

        XCTAssertTrue(puzzle.accepts("a7a8"))
        XCTAssertTrue(puzzle.accepts("a7a8q"))
        XCTAssertFalse(puzzle.accepts("a7a8n"))
    }

    func testSideToMove() throws {
        let levels = try catalog().levels
        XCTAssertEqual(levels[0].puzzles.first { $0.id == "l1-black-back-rank" }?.sideToMove, .black)
        XCTAssertEqual(levels[0].puzzles.first?.sideToMove, .white)
    }

    // MARK: - Unlocking

    func testLevelsUnlockAfterEnoughSolves() throws {
        let catalog = try catalog()
        let first = catalog.levels[0]
        let second = catalog.levels[1]
        let keys = first.puzzles.map { PuzzleSet.key(level: first, puzzle: $0) }

        XCTAssertTrue(catalog.isUnlocked(first, solved: []))
        XCTAssertFalse(catalog.isUnlocked(second, solved: Set(keys.prefix(3))))
        XCTAssertTrue(catalog.isUnlocked(second, solved: Set(keys.prefix(4))))
        XCTAssertFalse(catalog.isUnlocked(catalog.levels[2], solved: Set(keys)), "Level 3 needs Level 2 solves")
    }

    func testDrillKeysDoNotCollideAcrossSets() throws {
        let drills = try drills()
        let keys = drills.flatMap { drill in drill.puzzles.map { PuzzleSet(drill: drill).key(for: $0) } }
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(keys.first, "drill/mate-in-one/back-rank")
    }

    // MARK: - Session

    func testSessionSolvesAndAdvances() throws {
        let level = try catalog().levels[0]
        var session = PuzzleSession(set: PuzzleSet(level: level))

        XCTAssertEqual(session.submit("e1e2"), .wrong)
        XCTAssertFalse(session.isFirstTry)
        XCTAssertEqual(session.submit(level.puzzles[0].solution[0]), .solved)
        XCTAssertEqual(session.submit(level.puzzles[0].solution[0]), .ignored)
        XCTAssertEqual(session.firstTryCount, 0)

        session.advance()
        XCTAssertEqual(session.index, 1)
        XCTAssertFalse(session.isSolved)
        XCTAssertEqual(session.mistakes, 0)
        XCTAssertEqual(session.submit(level.puzzles[1].solution[0]), .solved)
        XCTAssertEqual(session.firstTryCount, 1)
    }

    func testAdvanceWaitsForASolve() throws {
        var session = PuzzleSession(set: PuzzleSet(level: try catalog().levels[0]))
        session.advance()
        XCTAssertEqual(session.index, 0)
    }

    func testAnswerIsOfferedAfterTwoMistakesAndCostsFirstTry() throws {
        let puzzle = try catalog().levels[0].puzzles[0]
        var session = PuzzleSession(set: set([puzzle]))

        _ = session.submit("e1e2")
        XCTAssertFalse(session.offersAnswer)
        _ = session.submit("e1f2")
        XCTAssertTrue(session.offersAnswer)

        var fresh = PuzzleSession(set: set([puzzle]))
        fresh.showAnswer()
        XCTAssertFalse(fresh.isFirstTry)
        XCTAssertEqual(fresh.submit(puzzle.solution[0]), .solved)
        XCTAssertEqual(fresh.firstTryCount, 0)
    }

    func testFinishingTheLastPuzzleEndsTheSet() throws {
        let puzzle = try catalog().levels[0].puzzles[0]
        var session = PuzzleSession(set: set([puzzle]))
        _ = session.submit(puzzle.solution[0])
        session.advance()

        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.submit(puzzle.solution[0]), .ignored)

        session.restart()
        XCTAssertFalse(session.isFinished)
        XCTAssertFalse(session.isSolved)
        XCTAssertEqual(session.firstTryCount, 0)
    }

    // MARK: - Progress

    func testStoreKeepsTheBestResult() throws {
        let suite = "PuzzleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PuzzleProgressStore(defaults: defaults)

        store.markSolved("level/1/a", firstTry: true)
        store.markSolved("level/1/a", firstTry: false)
        store.markSolved("level/1/b", firstTry: false)

        XCTAssertEqual(store.solved, ["level/1/a", "level/1/b"])
        XCTAssertEqual(store.record(for: "level/1/a")?.firstTry, true)
        XCTAssertEqual(PuzzleProgressStore(defaults: defaults).record(for: "level/1/b")?.firstTry, false)
    }
}
