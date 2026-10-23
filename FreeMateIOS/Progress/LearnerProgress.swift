import Foundation

// The learner's lesson, opening, and review progress as one typed, Codable value. It replaces
// the loose UserDefaults keys and hand-built JSON from the web port. It is UI-free, so the
// review schedule and the iCloud merge are unit tested with `swift test`.

nonisolated enum ReviewKind: String, Codable, Sendable {
    case lesson
    case opening
}

nonisolated enum ReviewState: String, Codable, Sendable {
    /// Missed recently. Due now.
    case shaky
    /// Climbing the 1, 3, 7, and 14 day ladder.
    case learning
    /// Passed the 14-day check. Retired from the queue.
    case mastered

    /// Most urgent first.
    var urgency: Int {
        switch self {
        case .shaky: return 0
        case .learning: return 1
        case .mastered: return 2
        }
    }
}

/// What to put in the review queue, from a lesson or an opening line.
nonisolated struct ReviewSeed: Equatable, Sendable {
    var kind: ReviewKind
    var itemId: String
    var branchId: String?
    var title: String
    var subtitle: String

    var key: String { ReviewItem.key(kind: kind, itemId: itemId, branchId: branchId) }
}

nonisolated struct ReviewItem: Codable, Equatable, Identifiable, Sendable {
    var kind: ReviewKind
    var itemId: String
    var branchId: String?
    var title: String
    var subtitle: String
    var state: ReviewState
    /// How far up the ladder the item is. Stage n waits `ReviewSchedule.intervals[n - 1]` days.
    var stage: Int
    var failures: Int
    var attempts: Int
    var successes: Int
    var successStreak: Int
    var lastFailedAt: Date?
    var lastSucceededAt: Date?
    var updatedAt: Date
    /// When it comes back. Nil once mastered.
    var dueAt: Date?

    var id: String { key }
    var key: String { Self.key(kind: kind, itemId: itemId, branchId: branchId) }

    static func key(kind: ReviewKind, itemId: String, branchId: String?) -> String {
        [kind.rawValue, itemId, branchId].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ":")
    }

    func isDue(at now: Date) -> Bool {
        guard let dueAt else { return false }
        return dueAt <= now
    }
}

/// Spaced repetition: a review comes back after 1, 3, 7, and then 14 days. A miss sends it
/// back to the start, due at once. Passing the 14-day check masters it.
nonisolated enum ReviewSchedule {
    static let intervals = [1, 3, 7, 14]

    static func dueDate(forStage stage: Int, after date: Date, calendar: Calendar = .current) -> Date? {
        guard stage >= 1, stage <= intervals.count else { return nil }
        return calendar.date(byAdding: .day, value: intervals[stage - 1], to: date)
    }

    static func failure(_ existing: ReviewItem?, seed: ReviewSeed, now: Date) -> ReviewItem {
        var item = existing ?? newItem(seed, now: now)
        item.title = seed.title
        item.subtitle = seed.subtitle
        item.state = .shaky
        item.stage = 0
        item.failures += 1
        item.attempts += 1
        item.successStreak = 0
        item.lastFailedAt = now
        item.updatedAt = now
        item.dueAt = now
        return item
    }

    /// Moves the item one rung up the ladder. Practicing before it is due does not move it,
    /// so cramming cannot skip the waits.
    static func success(_ existing: ReviewItem?, seed: ReviewSeed, now: Date, calendar: Calendar = .current) -> ReviewItem {
        var item = existing ?? newItem(seed, now: now)
        item.title = seed.title
        item.subtitle = seed.subtitle
        item.attempts += 1
        item.successes += 1
        item.successStreak += 1
        item.lastSucceededAt = now
        item.updatedAt = now
        let advances = existing == nil || existing?.state == .shaky || item.isDue(at: now)
        guard advances, item.state != .mastered else { return item }
        item.stage += 1
        if let due = dueDate(forStage: item.stage, after: now, calendar: calendar) {
            item.state = .learning
            item.dueAt = due
        } else {
            item.state = .mastered
            item.dueAt = nil
        }
        return item
    }

    private static func newItem(_ seed: ReviewSeed, now: Date) -> ReviewItem {
        ReviewItem(
            kind: seed.kind, itemId: seed.itemId, branchId: seed.branchId,
            title: seed.title, subtitle: seed.subtitle,
            state: .learning, stage: 0, failures: 0, attempts: 0, successes: 0, successStreak: 0,
            lastFailedAt: nil, lastSucceededAt: nil, updatedAt: now, dueAt: nil
        )
    }
}

nonisolated struct OpeningLineProgress: Codable, Equatable, Sendable {
    var moveIndex: Int
    var playedMoves: [String]
    var currentFen: String?
    var completed: Bool
    var updatedAt: Date?
}

nonisolated struct BranchCompletion: Codable, Equatable, Sendable {
    var completed: Bool
    var completedAt: Date?
}

nonisolated struct OpeningProgressRecord: Codable, Equatable, Sendable {
    var activeLineId: String?
    var lines: [String: OpeningLineProgress] = [:]
    var completions: [String: BranchCompletion] = [:]
}

nonisolated struct LearnerProgress: Codable, Equatable, Sendable {
    static let storageKey = "freemate.progress.v2"

    var completedLessons: Set<String> = []
    /// The step each unfinished lesson was left on.
    var lessonSteps: [String: Int] = [:]
    var reviews: [String: ReviewItem] = [:]
    var openings: [String: OpeningProgressRecord] = [:]

    // MARK: Lessons

    mutating func completeLesson(_ id: String, seed: ReviewSeed, now: Date = Date()) {
        completedLessons.insert(id)
        lessonSteps[id] = nil
        recordSuccess(seed, now: now)
    }

    mutating func noteStep(_ index: Int, lesson id: String) {
        lessonSteps[id] = max(0, index)
    }

    // MARK: Openings

    mutating func saveLine(openingId: String, lineId: String, progress: OpeningLineProgress) {
        openings[openingId, default: OpeningProgressRecord()].activeLineId = lineId
        openings[openingId, default: OpeningProgressRecord()].lines[lineId] = progress
    }

    mutating func setActiveLine(openingId: String, lineId: String) {
        openings[openingId, default: OpeningProgressRecord()].activeLineId = lineId
    }

    mutating func completeBranch(openingId: String, lineId: String, seed: ReviewSeed, now: Date = Date()) {
        openings[openingId, default: OpeningProgressRecord()].completions[lineId] = BranchCompletion(completed: true, completedAt: now)
        recordSuccess(seed, now: now)
    }

    // MARK: Reviews

    mutating func recordFailure(_ seed: ReviewSeed, now: Date = Date()) {
        reviews[seed.key] = ReviewSchedule.failure(reviews[seed.key], seed: seed, now: now)
    }

    mutating func recordSuccess(_ seed: ReviewSeed, now: Date = Date()) {
        reviews[seed.key] = ReviewSchedule.success(reviews[seed.key], seed: seed, now: now)
    }

    /// Due items, missed ones first, then the longest overdue.
    func reviewQueue(now: Date = Date()) -> [ReviewItem] {
        reviews.values
            .filter { $0.isDue(at: now) }
            .sorted { lhs, rhs in
                if lhs.state.urgency != rhs.state.urgency { return lhs.state.urgency < rhs.state.urgency }
                return (lhs.dueAt ?? now) < (rhs.dueAt ?? now)
            }
    }

    /// Scheduled items that are not due yet, soonest first.
    func upcomingReviews(now: Date = Date()) -> [ReviewItem] {
        reviews.values
            .filter { $0.dueAt.map { $0 > now } ?? false }
            .sorted { ($0.dueAt ?? now) < ($1.dueAt ?? now) }
    }

    // MARK: iCloud merge

    /// Combines two devices' progress without losing work on either: completions are unions,
    /// steps keep the furthest point, and reviews and lines keep the newer copy.
    static func merged(_ a: LearnerProgress, _ b: LearnerProgress) -> LearnerProgress {
        var result = a
        result.completedLessons.formUnion(b.completedLessons)
        result.lessonSteps.merge(b.lessonSteps, uniquingKeysWith: max)
        for id in result.completedLessons { result.lessonSteps[id] = nil }
        result.reviews.merge(b.reviews) { $0.updatedAt >= $1.updatedAt ? $0 : $1 }
        result.openings.merge(b.openings) { left, right in
            var record = left
            record.activeLineId = left.activeLineId ?? right.activeLineId
            record.lines.merge(right.lines) { ($0.updatedAt ?? .distantPast) >= ($1.updatedAt ?? .distantPast) ? $0 : $1 }
            record.completions.merge(right.completions) { $0.completed || !$1.completed ? $0 : $1 }
            return record
        }
        return result
    }
}

/// Saves `LearnerProgress` as one JSON value, migrating the old keys the first time.
nonisolated struct LearnerProgressStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LearnerProgress {
        if let saved = decodeSaved() { return saved }
        let migrated = LegacyProgressMigration.migrate(defaults)
        save(migrated)
        LegacyProgressMigration.removeLegacyKeys(defaults)
        // Read it back, so the first launch sees the same value as every later one.
        return decodeSaved() ?? migrated
    }

    private func decodeSaved() -> LearnerProgress? {
        guard let data = defaults.data(forKey: LearnerProgress.storageKey) else { return nil }
        return try? JSONDecoder.progress.decode(LearnerProgress.self, from: data)
    }

    func save(_ progress: LearnerProgress) {
        if let data = try? JSONEncoder.progress.encode(progress) {
            defaults.set(data, forKey: LearnerProgress.storageKey)
        }
    }
}

extension JSONEncoder {
    /// ISO 8601 dates with fractions of a second, and stable key order, so a saved value
    /// decodes to exactly what was saved and equal progress encodes to equal bytes.
    nonisolated static var progress: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(ProgressDateFormat.style))
        }
        encoder.outputFormatting = .sortedKeys
        return encoder
    }
}

extension JSONDecoder {
    nonisolated static var progress: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(text, strategy: ProgressDateFormat.style) { return date }
            if let date = try? Date(text, strategy: .iso8601) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
        }
        return decoder
    }
}

nonisolated enum ProgressDateFormat {
    static let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
}
