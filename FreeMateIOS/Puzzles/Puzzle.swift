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
    /// 2 for a mate in two: the learner's first move is listed in `solution`, the computer
    /// defends, and any checkmate finishes it. Nil for one-move puzzles.
    var mateIn: Int?

    var isMate: Bool { theme == .mate || mate == true }
    /// How many moves the learner plays.
    var moveCount: Int { max(mateIn ?? 1, 1) }

    init(
        id: String, prompt: String, fen: String, solution: [String], hint: String, success: String,
        theme: Theme? = nil, mate: Bool? = nil, mateIn: Int? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.fen = fen
        self.solution = solution
        self.hint = hint
        self.success = success
        self.theme = theme
        self.mate = mate
        self.mateIn = mateIn
    }

    var sideToMove: ChessColor {
        ChessColor.from(fen: String(fen.split(separator: " ").dropFirst().first ?? "w"))
    }

    /// Whether `uci` solves the puzzle. A move without a promotion piece matches a listed
    /// promotion, and any mate solves a mate puzzle.
    func accepts(_ uci: String) -> Bool {
        let move = uci.lowercased()
        if solution.contains(where: { $0 == move || (move.count == 4 && $0.hasPrefix(move)) }) { return true }
        // A mate in two only takes its listed first moves; any mate counts only on the last move.
        guard isMate, moveCount == 1 else { return false }
        return Self.mates(move, from: fen)
    }

    /// Whether `uci` checkmates from `fen`. With no piece named, a promotion is a queen.
    static func mates(_ uci: String, from fen: String) -> Bool {
        guard let after = play(uci, from: fen), let engine = try? ChessEngine(fen: after) else { return false }
        return engine.isCheckmate()
    }

    /// The position after `uci`, or nil when the move is not legal.
    static func play(_ uci: String, from fen: String) -> String? {
        let move = uci.lowercased()
        guard let engine = try? ChessEngine(fen: fen) else { return nil }
        let from = String(move.prefix(2))
        let to = String(move.dropFirst(2).prefix(2))
        // With no piece named, a promotion is a queen, as the trainer plays it.
        let promotes = engine.legalMoves(from: from).contains { $0.to == to && $0.promotion != nil }
        let promotion = move.count > 4 ? String(move.suffix(1)) : promotes ? "q" : nil
        guard engine.move(from: from, to: to, promotion: promotion) != nil else { return nil }
        return engine.fen()
    }

    /// A checkmating move from `fen`, for the answer on a mate in two's last move.
    static func matingMove(from fen: String) -> String? {
        guard let engine = try? ChessEngine(fen: fen) else { return nil }
        return engine.searchMoves().map(\.uci).first { mates($0, from: fen) }
    }

    /// The computer's defense in a mate in two. Every reply loses, so it takes the most natural
    /// one, a capture before a quiet move, the same way every time.
    static func defense(from fen: String) -> String? {
        guard let engine = try? ChessEngine(fen: fen) else { return nil }
        return ComputerOpponent.ordered(engine.searchMoves()).first?.uci
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

/// A themed set outside the level path, such as Endgames or Mate in Two.
nonisolated struct PuzzleCollection: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var summary: String
    var symbol: String
    var puzzles: [Puzzle]
}

nonisolated struct PuzzleCatalog: Codable, Equatable, Sendable {
    /// Puzzles to solve in a level before the next one opens.
    var unlockAfter: Int
    var levels: [PuzzleLevel]
    var collections: [PuzzleCollection]

    init(unlockAfter: Int, levels: [PuzzleLevel], collections: [PuzzleCollection] = []) {
        self.unlockAfter = unlockAfter
        self.levels = levels
        self.collections = collections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unlockAfter = try container.decode(Int.self, forKey: .unlockAfter)
        levels = try container.decode([PuzzleLevel].self, forKey: .levels)
        collections = try container.decodeIfPresent([PuzzleCollection].self, forKey: .collections) ?? []
    }

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

    init(collection: PuzzleCollection) {
        id = "collection/\(collection.id)"
        title = collection.title
        summary = collection.summary
        puzzles = collection.puzzles
    }

    /// The daily puzzle, keyed by its day so each day's solve is saved separately.
    init(day: String, puzzle: Puzzle) {
        id = "daily/\(day)"
        title = "Daily Puzzle"
        summary = "A new puzzle every day."
        puzzles = [puzzle]
    }

    var isDaily: Bool { id.hasPrefix("daily/") }

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
    static let storageKey = "freemate.puzzles.v1"

    struct Record: Codable, Equatable {
        /// Solved without a wrong move or the answer being shown.
        var firstTry: Bool
    }

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = storageKey) {
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
        /// Right so far. The computer answers with `reply`, then the learner moves again.
        case correct(reply: String)
        case wrong
        /// The puzzle is already solved, or the set is finished.
        case ignored
    }

    let puzzleSet: PuzzleSet
    private(set) var index = 0
    /// Which of the learner's moves comes next in the current puzzle, from 0.
    private(set) var step = 0
    /// The position the learner is solving from now.
    private(set) var fen: String
    private(set) var isSolved = false
    private(set) var mistakes = 0
    private(set) var hintShown = false
    private(set) var answerShown = false
    /// Puzzles solved first try in this session.
    private(set) var firstTryCount = 0
    private(set) var isFinished = false

    init(set: PuzzleSet, startingAt index: Int = 0) {
        puzzleSet = set
        let start = max(0, min(index, set.puzzles.count - 1))
        self.index = start
        fen = set.puzzles[start].fen
    }

    var puzzle: Puzzle { puzzleSet.puzzles[index] }
    var isLast: Bool { index == puzzleSet.puzzles.count - 1 }
    /// Wrong moves or the answer, so this solve does not count as first try.
    var isFirstTry: Bool { mistakes == 0 && !answerShown }
    /// After two wrong moves, offer the answer instead of more guessing.
    var offersAnswer: Bool { !isSolved && mistakes >= 2 && !answerShown }

    /// The move the hint and the answer point to.
    var answerMove: String? {
        step == 0 ? puzzle.solution.first : Puzzle.matingMove(from: fen)
    }

    mutating func submit(_ uci: String) -> Outcome {
        guard !isSolved, !isFinished else { return .ignored }
        let isLastMove = step == puzzle.moveCount - 1
        let accepted = step == 0 ? puzzle.accepts(uci) : isLastMove && Puzzle.mates(uci, from: fen)
        guard accepted, let after = Puzzle.play(uci, from: fen) else {
            mistakes += 1
            return .wrong
        }
        if isLastMove {
            fen = after
            isSolved = true
            if isFirstTry { firstTryCount += 1 }
            return .solved
        }
        guard let reply = Puzzle.defense(from: after), let answered = Puzzle.play(reply, from: after) else {
            fen = after
            isSolved = true
            return .solved
        }
        fen = answered
        step += 1
        hintShown = false
        return .correct(reply: reply)
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
        step = 0
        fen = puzzle.fen
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
