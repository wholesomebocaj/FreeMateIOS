import Foundation

/// One position with a single winning move, used by both the drills and the curated puzzles.
nonisolated struct Puzzle: Codable, Identifiable, Equatable, Sendable {
    enum Theme: String, Codable, Sendable {
        /// Any checkmating move counts, not only the listed ones.
        case mate
        /// Win material. Only the listed moves count; `tools/check_puzzles.py` makes sure every
        /// other move is clearly worse.
        case material
    }

    var id: String
    var prompt: String
    var fen: String
    /// Accepted moves in UCI.
    var solution: [String]
    var hint: String
    var success: String
    var theme: Theme?
    /// The drills mark mate puzzles this way, as the web app does.
    var mate: Bool?

    var isMate: Bool { theme == .mate || mate == true }

    var sideToMove: ChessColor {
        ChessColor.from(fen: String(fen.split(separator: " ").dropFirst().first ?? "w"))
    }

    /// Whether `uci` solves the puzzle. A move without a promotion piece matches a listed
    /// promotion, and any mate solves a mate puzzle.
    func accepts(_ uci: String) -> Bool {
        let move = uci.lowercased()
        if solution.contains(where: { $0 == move || (move.count == 4 && $0.hasPrefix(move)) }) { return true }
        guard isMate, let engine = try? ChessEngine(fen: fen) else { return false }
        let from = String(move.prefix(2))
        let to = String(move.dropFirst(2).prefix(2))
        // With no piece named, a promotion is a queen, as the trainer plays it.
        let promotes = engine.legalMoves(from: from).contains { $0.to == to && $0.promotion != nil }
        let promotion = move.count > 4 ? String(move.suffix(1)) : promotes ? "q" : nil
        guard engine.move(from: from, to: to, promotion: promotion) != nil else {
            return false
        }
        return engine.isCheckmate()
    }
}

/// A short set of puzzles on one idea, ported from the web app's drills.
nonisolated struct Drill: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var summary: String
    var puzzles: [Puzzle]
}

nonisolated struct PuzzleLevel: Codable, Identifiable, Equatable, Sendable {
    var level: Int
    var title: String
    var summary: String
    var puzzles: [Puzzle]

    var id: Int { level }
}

nonisolated struct PuzzleCatalog: Codable, Equatable, Sendable {
    /// Puzzles to solve in a level before the next one opens.
    var unlockAfter: Int
    var levels: [PuzzleLevel]

    func isUnlocked(_ level: PuzzleLevel, solved: Set<String>) -> Bool {
        guard let index = levels.firstIndex(where: { $0.level == level.level }), index > 0 else { return true }
        let previous = levels[index - 1]
        return previous.puzzles.filter { solved.contains(PuzzleSet.key(level: previous, puzzle: $0)) }.count >= unlockAfter
    }
}

/// The puzzles one trainer session works through: a drill or a level.
nonisolated struct PuzzleSet: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var summary: String
    var puzzles: [Puzzle]

    init(drill: Drill) {
        id = "drill/\(drill.id)"
        title = drill.title
        summary = drill.summary
        puzzles = drill.puzzles
    }

    init(level: PuzzleLevel) {
        id = "level/\(level.level)"
        title = "Level \(level.level): \(level.title)"
        summary = level.summary
        puzzles = level.puzzles
    }

    /// The progress key for a puzzle in this set. Drill puzzle ids are only unique per drill.
    func key(for puzzle: Puzzle) -> String { "\(id)/\(puzzle.id)" }

    static func key(level: PuzzleLevel, puzzle: Puzzle) -> String {
        PuzzleSet(level: level).key(for: puzzle)
    }
}

enum PuzzleLibraryError: Error {
    case missingResource(String)
}

nonisolated enum PuzzleLibrary {
    static func decodeDrills(_ data: Data) throws -> [Drill] {
        try JSONDecoder().decode([Drill].self, from: data)
    }

    static func decodeCatalog(_ data: Data) throws -> PuzzleCatalog {
        try JSONDecoder().decode(PuzzleCatalog.self, from: data)
    }

    static func loadDrills(from bundle: Bundle = .main) throws -> [Drill] {
        try decodeDrills(resource("drills", in: bundle))
    }

    static func loadCatalog(from bundle: Bundle = .main) throws -> PuzzleCatalog {
        try decodeCatalog(resource("puzzles", in: bundle))
    }

    private static func resource(_ name: String, in bundle: Bundle) throws -> Data {
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources")
        guard let url else { throw PuzzleLibraryError.missingResource(name) }
        return try Data(contentsOf: url)
    }
}

/// Which puzzles the learner has solved, saved on the device.
nonisolated struct PuzzleProgressStore {
    struct Record: Codable, Equatable {
        /// Solved without a wrong move or the answer being shown.
        var firstTry: Bool
    }

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "freemate.puzzles.v1") {
        self.defaults = defaults
        self.key = key
    }

    var solved: Set<String> { Set(all().keys) }

    func record(for puzzleKey: String) -> Record? { all()[puzzleKey] }

    /// Keeps the best result: a first-try solve is never downgraded by a later retry.
    func markSolved(_ puzzleKey: String, firstTry: Bool) {
        var map = all()
        map[puzzleKey] = Record(firstTry: firstTry || (map[puzzleKey]?.firstTry ?? false))
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: key)
        }
    }

    private func all() -> [String: Record] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: Record].self, from: data)) ?? [:]
    }
}

/// Works through a `PuzzleSet` one puzzle at a time. UI-free.
nonisolated struct PuzzleSession: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case solved
        case wrong
        /// The puzzle is already solved, or the set is finished.
        case ignored
    }

    let puzzleSet: PuzzleSet
    private(set) var index = 0
    private(set) var isSolved = false
    private(set) var mistakes = 0
    private(set) var hintShown = false
    private(set) var answerShown = false
    /// Puzzles solved first try in this session.
    private(set) var firstTryCount = 0
    private(set) var isFinished = false

    init(set: PuzzleSet, startingAt index: Int = 0) {
        puzzleSet = set
        self.index = max(0, min(index, set.puzzles.count - 1))
    }

    var puzzle: Puzzle { puzzleSet.puzzles[index] }
    var isLast: Bool { index == puzzleSet.puzzles.count - 1 }
    /// Wrong moves or the answer, so this solve does not count as first try.
    var isFirstTry: Bool { mistakes == 0 && !answerShown }
    /// After two wrong moves, offer the answer instead of more guessing.
    var offersAnswer: Bool { !isSolved && mistakes >= 2 && !answerShown }

    mutating func submit(_ uci: String) -> Outcome {
        guard !isSolved, !isFinished else { return .ignored }
        if puzzle.accepts(uci) {
            isSolved = true
            if isFirstTry { firstTryCount += 1 }
            return .solved
        }
        mistakes += 1
        return .wrong
    }

    mutating func showHint() { hintShown = true }

    mutating func showAnswer() {
        hintShown = true
        answerShown = true
    }

    /// Moves to the next puzzle, or finishes the set after the last one.
    mutating func advance() {
        guard isSolved else { return }
        if isLast {
            isFinished = true
            return
        }
        index += 1
        isSolved = false
        mistakes = 0
        hintShown = false
        answerShown = false
    }

    /// Starts the set over from the first puzzle.
    mutating func restart() {
        self = PuzzleSession(set: puzzleSet)
    }
}
