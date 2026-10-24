import Foundation

// MARK: - Daily puzzle

/// One puzzle a day, the same for everyone, picked from every bundled puzzle in a fixed order.
nonisolated enum DailyPuzzle {
    /// Every puzzle, sorted by id so the order never depends on the file layout.
    static func pool(catalog: PuzzleCatalog?, drills: [Drill]) -> [Puzzle] {
        let all = (catalog?.levels.flatMap(\.puzzles) ?? [])
            + (catalog?.collections.flatMap(\.puzzles) ?? [])
            + drills.flatMap(\.puzzles)
        var seen = Set<String>()
        return all.filter { seen.insert($0.id).inserted }.sorted { $0.id < $1.id }
    }

    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        ActivityStore.day(date, calendar: calendar)
    }

    /// Steps through the pool one day at a time, with a stride that visits every puzzle before
    /// any repeats, so neighbors in the file are not neighbors in time.
    static func puzzle(on date: Date, pool: [Puzzle], calendar: Calendar = .current) -> Puzzle? {
        guard !pool.isEmpty else { return nil }
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .distantPast
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        let stride = coprimeStride(for: pool.count)
        let index = ((days * stride) % pool.count + pool.count) % pool.count
        return pool[index]
    }

    static func set(on date: Date, pool: [Puzzle], calendar: Calendar = .current) -> PuzzleSet? {
        puzzle(on: date, pool: pool, calendar: calendar).map { PuzzleSet(day: day(date, calendar: calendar), puzzle: $0) }
    }

    /// Days in a row the daily puzzle was solved, from the saved puzzle keys.
    static func streak(solved: Set<String>, today: Date, calendar: Calendar = .current) -> Int {
        let days = Set(solved.compactMap { key -> String? in
            let parts = key.split(separator: "/")
            return parts.count >= 2 && parts[0] == "daily" ? String(parts[1]) : nil
        })
        return ActivityStore.streak(days: days, today: today, calendar: calendar)
    }

    private static func coprimeStride(for count: Int) -> Int {
        var stride = 7
        while gcd(stride, count) != 1 { stride += 1 }
        return stride
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}

// MARK: - Puzzle Rush

/// As many one-move puzzles as possible before time runs out or three are missed.
nonisolated struct RushSession: Equatable, Sendable {
    static let duration: TimeInterval = 180
    static let strikesAllowed = 3

    let puzzles: [Puzzle]
    private(set) var index = 0
    private(set) var score = 0
    private(set) var strikes = 0
    private(set) var isOver = false

    /// One-move puzzles only, shuffled.
    init(pool: [Puzzle], using generator: inout some RandomNumberGenerator) {
        puzzles = pool.filter { $0.moveCount == 1 }.shuffled(using: &generator)
        isOver = puzzles.isEmpty
    }

    init(pool: [Puzzle]) {
        var generator = SystemRandomNumberGenerator()
        self.init(pool: pool, using: &generator)
    }

    var puzzle: Puzzle? { isOver || index >= puzzles.count ? nil : puzzles[index] }

    /// Scores the move and moves on either way. Returns whether it was right.
    @discardableResult
    mutating func submit(_ uci: String) -> Bool {
        guard let puzzle else { return false }
        let correct = puzzle.accepts(uci)
        if correct { score += 1 } else { strikes += 1 }
        index += 1
        if strikes >= Self.strikesAllowed || index >= puzzles.count { isOver = true }
        return correct
    }

    mutating func timeUp() { isOver = true }
}

/// The best Puzzle Rush score, saved on the device and synced.
nonisolated struct RushStore {
    static let storageKey = "freemate.rush.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var best: Int {
        defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(Int.self, from: $0) } ?? 0
    }

    /// Saves `score` if it beats the best. Returns whether it did.
    @discardableResult
    func record(_ score: Int) -> Bool {
        guard score > best, let data = try? JSONEncoder().encode(score) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        return true
    }
}

// MARK: - Blunder Check

/// "Is this move safe?" The learner answers Safe or Blunder, then sees why.
nonisolated struct BlunderCheck: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var fen: String
    /// The move in question, in UCI.
    var move: String
    var isBlunder: Bool
    /// The reply that punishes a blunder.
    var refutation: String?
    var explanation: String

    var sideToMove: ChessColor {
        ChessColor.from(fen: String(fen.split(separator: " ").dropFirst().first ?? "w"))
    }

    /// The move in SAN, such as "Nf6", for the question.
    var san: String {
        guard let engine = try? ChessEngine(fen: fen) else { return move }
        return ComputerCoach.san(move, in: engine)
    }

    var refutationSAN: String? {
        guard let refutation, let after = Puzzle.play(move, from: fen), let engine = try? ChessEngine(fen: after) else { return nil }
        return ComputerCoach.san(refutation, in: engine)
    }
}

nonisolated enum BlunderCheckLibrary {
    static func decode(_ data: Data) throws -> [BlunderCheck] {
        try JSONDecoder().decode([BlunderCheck].self, from: data)
    }

    static func loadBundled(from bundle: Bundle = .main) throws -> [BlunderCheck] {
        let url = bundle.url(forResource: "blunders", withExtension: "json")
            ?? bundle.url(forResource: "blunders", withExtension: "json", subdirectory: "Resources")
        guard let url else { throw PuzzleLibraryError.missingResource("blunders") }
        return try decode(Data(contentsOf: url))
    }
}

nonisolated struct BlunderCheckSession: Equatable, Sendable {
    let checks: [BlunderCheck]
    private(set) var index = 0
    /// The learner's answer to the current check, once given.
    private(set) var answer: Bool?
    private(set) var correctCount = 0
    private(set) var isFinished = false

    init(checks: [BlunderCheck]) {
        self.checks = checks
        isFinished = checks.isEmpty
    }

    var check: BlunderCheck? { isFinished ? nil : checks[index] }
    var isAnswered: Bool { answer != nil }
    var wasCorrect: Bool { answer != nil && answer == check?.isBlunder }

    /// Answers the current check. Returns whether the answer was right.
    @discardableResult
    mutating func answer(isBlunder: Bool) -> Bool {
        guard let check, answer == nil else { return false }
        answer = isBlunder
        let correct = isBlunder == check.isBlunder
        if correct { correctCount += 1 }
        return correct
    }

    mutating func next() {
        guard answer != nil else { return }
        answer = nil
        if index >= checks.count - 1 {
            isFinished = true
        } else {
            index += 1
        }
    }

    mutating func restart() {
        self = BlunderCheckSession(checks: checks)
    }
}

/// Which blunder checks were answered correctly, saved on the device and synced.
nonisolated struct BlunderProgressStore {
    static let storageKey = "freemate.blunders.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var correct: Set<String> {
        defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode([String].self, from: $0) }.map(Set.init) ?? []
    }

    func markCorrect(_ id: String) {
        var ids = correct
        guard ids.insert(id).inserted, let data = try? JSONEncoder().encode(ids.sorted()) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
