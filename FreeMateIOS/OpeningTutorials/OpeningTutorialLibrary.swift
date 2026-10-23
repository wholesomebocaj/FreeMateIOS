import Foundation

/// A tutorial step resolved against `ChessEngine`, so the board knows exactly which squares move.
struct TutorialMove: Equatable {
    var step: OpeningStep
    var ply: Int
    /// SAN as produced by `ChessEngine`, including check marks.
    var san: String
    var from: String
    var to: String
    var promotion: String?
    var piece: PieceKind
    var fenBefore: String
    var fenAfter: String

    var uci: String { from + to + (promotion ?? "") }

    var moveNumberLabel: String { Self.label(san: san, ply: ply) }

    static func label(san: String, ply: Int) -> String {
        let number = ply / 2 + 1
        return ply % 2 == 0 ? "\(number). \(san)" : "\(number)... \(san)"
    }
}

enum OpeningTutorialError: Error, Equatable, LocalizedError {
    case missingResource
    case emptyMainLine(openingId: String)
    case illegalMove(openingId: String, line: String, ply: Int, san: String)
    case invalidVariation(openingId: String, variationId: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "The opening tutorials file is missing from the app bundle."
        case .emptyMainLine(let openingId):
            return "\(openingId) has no main line moves."
        case .illegalMove(let openingId, let line, let ply, let san):
            return "\(openingId) \(line): \(san) at ply \(ply) is not a legal move."
        case .invalidVariation(let openingId, let variationId, let reason):
            return "\(openingId) \(variationId): \(reason)"
        }
    }
}

/// The main line and every variation of an opening, resolved into concrete board moves.
struct OpeningTutorialPlan: Equatable {
    var mainLine: [TutorialMove]
    var variations: [String: [TutorialMove]]

    init(opening: ChessOpening) throws {
        guard !opening.mainLine.isEmpty else { throw OpeningTutorialError.emptyMainLine(openingId: opening.id) }
        mainLine = try Self.resolve(opening.mainLine, from: ChessEngine.startingFen, startingPly: 0, openingId: opening.id, line: "main line")
        guard opening.isUserPly(mainLine.count - 1) else {
            throw OpeningTutorialError.invalidVariation(openingId: opening.id, variationId: "main line", reason: "The main line must end with the learner's move.")
        }
        var resolved: [String: [TutorialMove]] = [:]
        for variation in opening.variations {
            let ply = variation.branchPly
            func fail(_ reason: String) -> OpeningTutorialError {
                .invalidVariation(openingId: opening.id, variationId: variation.id, reason: reason)
            }
            guard mainLine.indices.contains(ply) else { throw fail("branchPly \(ply) is outside the main line.") }
            guard !opening.isUserPly(ply) else { throw fail("The opponent must be the one leaving the main line.") }
            guard let first = variation.moves.first else { throw fail("The variation has no moves.") }
            guard !SANText.matches(mainLine[ply].step.san, first.san) else { throw fail("\(first.san) is already the main line move.") }
            guard opening.isUserPly(ply + variation.moves.count - 1) else { throw fail("The variation must end with the learner's move.") }
            guard resolved[variation.id] == nil else { throw fail("Duplicate variation id.") }
            resolved[variation.id] = try Self.resolve(variation.moves, from: mainLine[ply].fenBefore, startingPly: ply, openingId: opening.id, line: variation.id)
        }
        variations = resolved
    }

    static func resolve(_ steps: [OpeningStep], from fen: String, startingPly: Int, openingId: String, line: String) throws -> [TutorialMove] {
        guard let engine = try? ChessEngine(fen: fen) else {
            throw OpeningTutorialError.illegalMove(openingId: openingId, line: line, ply: startingPly, san: steps.first?.san ?? "")
        }
        var moves: [TutorialMove] = []
        for (offset, step) in steps.enumerated() {
            let ply = startingPly + offset
            let before = engine.fen()
            let candidates = candidateSquares(for: step.san, in: engine).flatMap { engine.legalMoves(from: $0) }
            guard let legal = candidates.first(where: { SANText.matches($0.san, step.san) }),
                  let played = engine.move(from: legal.from, to: legal.to, promotion: legal.promotion),
                  let letter = played.piece.last,
                  let kind = PieceKind.from(fen: letter) else {
                throw OpeningTutorialError.illegalMove(openingId: openingId, line: line, ply: ply, san: step.san)
            }
            moves.append(TutorialMove(
                step: step,
                ply: ply,
                san: played.san,
                from: played.from,
                to: played.to,
                promotion: played.promotion,
                piece: kind,
                fenBefore: before,
                fenAfter: engine.fen()
            ))
        }
        return moves
    }

    /// Squares holding a piece of the side to move that could match the SAN's piece letter.
    /// Generating SAN is costly, so only these pieces are asked for their legal moves.
    private static func candidateSquares(for san: String, in engine: ChessEngine) -> [String] {
        let normalized = SANText.normalized(san)
        let kind: PieceKind
        if normalized.hasPrefix("O") {
            kind = .king
        } else if let first = normalized.first, first.isUppercase, let piece = PieceKind.from(fen: first) {
            kind = piece
        } else {
            kind = .pawn
        }
        let code = ChessPiece(color: engine.sideToMove, kind: kind).code
        return engine.placement().filter { $0.value == code }.map(\.key).sorted()
    }
}

/// An opening whose lines have all been checked against the engine.
struct OpeningTutorial: Equatable, Identifiable {
    let opening: ChessOpening
    let plan: OpeningTutorialPlan

    var id: String { opening.id }

    /// The position to show in previews: after `previewPly` plies, or the end of the main line.
    var previewFen: String {
        let plies = min(max(opening.previewPly ?? plan.mainLine.count, 1), plan.mainLine.count)
        return plan.mainLine[plies - 1].fenAfter
    }

    init(opening: ChessOpening) throws {
        self.opening = opening
        plan = try OpeningTutorialPlan(opening: opening)
    }
}

struct OpeningTutorialCatalog: Codable, Equatable {
    var version: Int
    var source: String?
    var openings: [ChessOpening]
}

enum OpeningTutorialLibrary {
    static let resourceName = "opening-tutorials"

    /// Decodes and validates every opening. Throws on the first line that does not resolve.
    static func decode(_ data: Data) throws -> [OpeningTutorial] {
        let catalog = try JSONDecoder().decode(OpeningTutorialCatalog.self, from: data)
        return try catalog.openings.map { try OpeningTutorial(opening: $0) }
    }

    static func loadBundled(from bundle: Bundle = .main) throws -> [OpeningTutorial] {
        let url = bundle.url(forResource: resourceName, withExtension: "json")
            ?? bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "OpeningTutorials")
        guard let url else { throw OpeningTutorialError.missingResource }
        return try decode(Data(contentsOf: url))
    }
}

nonisolated struct OpeningTutorialProgress: Codable, Equatable {
    var mainLineCompleted = false
    var completedVariationIds: Set<String> = []
    var fewestMistakes: Int?
    /// The furthest the learner has got through the tutorial, from 0 to 100.
    var bestPercent: Int?
}

/// Saves tutorial progress on the device. No account is involved.
nonisolated struct OpeningTutorialProgressStore {
    static let storageKey = "freemate.openingTutorials.v1"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = storageKey) {
        self.defaults = defaults
        self.key = key
    }

    func progress(for openingId: String) -> OpeningTutorialProgress {
        all()[openingId] ?? OpeningTutorialProgress()
    }

    func update(_ openingId: String, _ change: (inout OpeningTutorialProgress) -> Void) {
        var map = all()
        var entry = map[openingId] ?? OpeningTutorialProgress()
        change(&entry)
        map[openingId] = entry
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: key)
        }
    }

    private func all() -> [String: OpeningTutorialProgress] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: OpeningTutorialProgress].self, from: data)) ?? [:]
    }
}
