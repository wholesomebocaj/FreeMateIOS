import Foundation

/// The days the learner practiced anything, for the streak. Saved on the device as calendar
/// days ("2026-10-23"), so a streak follows the learner's own time zone.
nonisolated struct ActivityStore {
    static let storageKey = "freemate.activity.v1"

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    var days: Set<String> {
        guard let data = defaults.data(forKey: Self.storageKey),
              let days = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(days)
    }

    func record(_ date: Date = Date()) {
        var days = days
        guard days.insert(Self.day(date, calendar: calendar)).inserted,
              let data = try? JSONEncoder().encode(days.sorted()) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Days in a row ending today, or ending yesterday when today has no practice yet, so the
    /// streak does not reset at midnight.
    func streak(today: Date = Date()) -> Int {
        Self.streak(days: days, today: today, calendar: calendar)
    }

    static func streak(days: Set<String>, today: Date, calendar: Calendar = .current) -> Int {
        var date = today
        if !days.contains(day(date, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
                  days.contains(day(yesterday, calendar: calendar)) else { return 0 }
            date = yesterday
        }
        var count = 0
        while days.contains(day(date, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return count
    }

    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
