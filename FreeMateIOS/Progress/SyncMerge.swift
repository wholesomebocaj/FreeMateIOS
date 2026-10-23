import Foundation

/// How each synced store combines this device's copy with iCloud's. Every rule keeps work from
/// both sides and gives the same answer whichever copy comes first, so devices settle on the
/// same value no matter the order they sync in.
nonisolated enum SyncMerge {
    struct SyncedKey: Sendable {
        var key: String
        var merge: @Sendable (Data, Data) -> Data?
    }

    /// The stores that follow the learner across devices. Device preferences such as the
    /// computer's level or the appearance are not synced. The computer record syncs per device
    /// instead; see `deviceRecords(own:cloud:deviceId:)`.
    static let keys: [SyncedKey] = [
        SyncedKey(key: LearnerProgress.storageKey, merge: learnerProgress),
        SyncedKey(key: PuzzleProgressStore.storageKey, merge: puzzles),
        SyncedKey(key: OpeningTutorialProgressStore.storageKey, merge: tutorials),
        SyncedKey(key: ActivityStore.storageKey, merge: activity),
    ]

    /// Merges a local and a cloud value. A missing side takes the other one as is.
    static func merge(_ synced: SyncedKey, local: Data?, cloud: Data?) -> Data? {
        switch (local, cloud) {
        case (nil, nil): return nil
        case (let value?, nil), (nil, let value?): return value
        case (let local?, let cloud?): return synced.merge(local, cloud) ?? local
        }
    }

    @Sendable static func learnerProgress(_ a: Data, _ b: Data) -> Data? {
        guard let left = try? JSONDecoder.progress.decode(LearnerProgress.self, from: a),
              let right = try? JSONDecoder.progress.decode(LearnerProgress.self, from: b) else { return nil }
        return try? JSONEncoder.progress.encode(LearnerProgress.merged(left, right))
    }

    @Sendable static func puzzles(_ a: Data, _ b: Data) -> Data? {
        typealias Map = [String: PuzzleProgressStore.Record]
        guard let left = try? JSONDecoder().decode(Map.self, from: a),
              let right = try? JSONDecoder().decode(Map.self, from: b) else { return nil }
        let merged = left.merging(right) { PuzzleProgressStore.Record(firstTry: $0.firstTry || $1.firstTry) }
        return try? JSONEncoder.progress.encode(merged)
    }

    @Sendable static func tutorials(_ a: Data, _ b: Data) -> Data? {
        typealias Map = [String: OpeningTutorialProgress]
        guard let left = try? JSONDecoder().decode(Map.self, from: a),
              let right = try? JSONDecoder().decode(Map.self, from: b) else { return nil }
        let merged = left.merging(right) { x, y in
            var result = x
            result.mainLineCompleted = x.mainLineCompleted || y.mainLineCompleted
            result.completedVariationIds.formUnion(y.completedVariationIds)
            result.fewestMistakes = [x.fewestMistakes, y.fewestMistakes].compactMap { $0 }.min()
            result.bestPercent = [x.bestPercent, y.bestPercent].compactMap { $0 }.max()
            return result
        }
        return try? JSONEncoder.progress.encode(merged)
    }

    @Sendable static func activity(_ a: Data, _ b: Data) -> Data? {
        guard let left = try? JSONDecoder().decode([String].self, from: a),
              let right = try? JSONDecoder().decode([String].self, from: b) else { return nil }
        return try? JSONEncoder().encode(Set(left).union(right).sorted())
    }

    /// Games against the computer are counted per device and added up, so a game is never
    /// counted twice or lost when two devices sync. Returns the updated cloud map and the
    /// other devices' total.
    static func deviceRecords(
        own: ComputerGameRecord,
        cloud: [String: ComputerGameRecord],
        deviceId: String
    ) -> (cloud: [String: ComputerGameRecord], others: ComputerGameRecord) {
        var map = cloud
        map[deviceId] = own
        let others = map.filter { $0.key != deviceId }.values.reduce(ComputerGameRecord(), +)
        return (map, others)
    }
}

extension ComputerGameRecord {
    nonisolated static func + (lhs: ComputerGameRecord, rhs: ComputerGameRecord) -> ComputerGameRecord {
        ComputerGameRecord(wins: lhs.wins + rhs.wins, draws: lhs.draws + rhs.draws, losses: lhs.losses + rhs.losses)
    }
}
