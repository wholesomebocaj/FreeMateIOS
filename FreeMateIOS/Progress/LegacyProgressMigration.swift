import Foundation

/// Reads progress saved before `LearnerProgress` existed: loose UserDefaults keys with JSON built
/// by hand, plus the "progress rows" that were only written for local accounts.
nonisolated enum LegacyProgressMigration {
    static let completedLessonsKey = "freemate.completedLessons"
    static let stepKeys = ["freemate.lessonSteps", "freemate.savedSteps"]
    static let reviewKey = "freemate.reviewQueue"
    static let openingProgressPrefix = "freemate-opening-progress:"
    static let openingCompletionsPrefix = "freemate-opening-completions:"
    static let lessonRowsKey = "freemate.progress.lessons"
    static let openingRowsKey = "freemate.progress.openings"
    static let courseRowsKey = "freemate.progress.courses"
    /// Local accounts are gone. Their password hashes and session cookie are deleted.
    static let accountKeys = ["freemate.users", "freemate_auth"]

    static func migrate(_ defaults: UserDefaults, now: Date = Date()) -> LearnerProgress {
        var progress = LearnerProgress()
        if let ids = defaults.array(forKey: completedLessonsKey) as? [String] {
            progress.completedLessons = Set(ids)
        }
        for key in stepKeys {
            for (id, value) in object(defaults, key) ?? [:] {
                if let step = int(value) { progress.lessonSteps[id] = max(progress.lessonSteps[id] ?? 0, step) }
            }
        }
        for raw in (object(defaults, reviewKey) ?? [:]).values {
            if let item = review(raw as? [String: Any] ?? [:], now: now) { progress.reviews[item.key] = item }
        }
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(openingProgressPrefix) {
                let id = String(key.dropFirst(openingProgressPrefix.count))
                let raw = object(defaults, key) ?? [:]
                progress.openings[id, default: OpeningProgressRecord()].activeLineId = raw["activeLineId"] as? String
                for (lineId, value) in raw["lines"] as? [String: Any] ?? [:] {
                    guard let row = value as? [String: Any] else { continue }
                    progress.openings[id, default: OpeningProgressRecord()].lines[lineId] = OpeningLineProgress(
                        moveIndex: int(row["moveIndex"]) ?? 0,
                        playedMoves: row["playedMoves"] as? [String] ?? [],
                        currentFen: row["currentFen"] as? String,
                        completed: row["completed"] as? Bool ?? false,
                        updatedAt: date(row["updatedAt"])
                    )
                }
            } else if key.hasPrefix(openingCompletionsPrefix) {
                let id = String(key.dropFirst(openingCompletionsPrefix.count))
                for (lineId, value) in object(defaults, key) ?? [:] {
                    guard let row = value as? [String: Any] else { continue }
                    progress.openings[id, default: OpeningProgressRecord()].completions[lineId] = BranchCompletion(
                        completed: row["completed"] as? Bool ?? false,
                        completedAt: date(row["completedAt"])
                    )
                }
            }
        }
        // Rows written while signed in to a local account.
        for row in rows(defaults, lessonRowsKey) {
            guard let id = row["lessonId"] as? String else { continue }
            if row["completed"] as? Bool == true || row["status"] as? String == "mastered" {
                progress.completedLessons.insert(id)
            } else if let step = int(row["lastStepIndex"]) {
                progress.lessonSteps[id] = max(progress.lessonSteps[id] ?? 0, step)
            }
        }
        for row in rows(defaults, openingRowsKey) where row["completed"] as? Bool == true {
            guard let id = row["openingKey"] as? String, let line = row["branchKey"] as? String else { continue }
            progress.openings[id, default: OpeningProgressRecord()].completions[line] = BranchCompletion(
                completed: true, completedAt: date(row["updatedAt"])
            )
        }
        for id in progress.completedLessons { progress.lessonSteps[id] = nil }
        return progress
    }

    static func removeLegacyKeys(_ defaults: UserDefaults) {
        var keys = [completedLessonsKey, reviewKey, lessonRowsKey, openingRowsKey, courseRowsKey] + stepKeys + accountKeys
        keys += defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(openingProgressPrefix) || $0.hasPrefix(openingCompletionsPrefix)
        }
        for key in keys { defaults.removeObject(forKey: key) }
    }

    /// The old queue marked an item "mastered" forever after one success. Those items start the
    /// new ladder at its first rung instead.
    static func review(_ raw: [String: Any], now: Date) -> ReviewItem? {
        guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
        let kind = ReviewKind(rawValue: raw["type"] as? String ?? "") ?? .lesson
        let branch = raw["branchId"] as? String
        let lastSucceeded = date(raw["lastSucceededAt"])
        let mastered = raw["state"] as? String == "mastered"
        return ReviewItem(
            kind: kind,
            itemId: id,
            branchId: branch?.isEmpty == true ? nil : branch,
            title: raw["title"] as? String ?? id,
            subtitle: raw["subtitle"] as? String ?? "",
            state: mastered ? .learning : .shaky,
            stage: mastered ? 1 : 0,
            failures: int(raw["failures"]) ?? 0,
            attempts: int(raw["attempts"]) ?? 0,
            successes: int(raw["successes"]) ?? 0,
            successStreak: int(raw["successStreak"]) ?? 0,
            lastFailedAt: date(raw["lastFailedAt"]),
            lastSucceededAt: lastSucceeded,
            updatedAt: date(raw["updatedAt"]) ?? now,
            dueAt: mastered ? ReviewSchedule.dueDate(forStage: 1, after: lastSucceeded ?? now) : (date(raw["dueAt"]) ?? now)
        )
    }

    private static func object(_ defaults: UserDefaults, _ key: String) -> [String: Any]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func rows(_ defaults: UserDefaults, _ key: String) -> [[String: Any]] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? Double { return Int(number) }
        if let text = value as? String { return Int(text) }
        return nil
    }

    static func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}
