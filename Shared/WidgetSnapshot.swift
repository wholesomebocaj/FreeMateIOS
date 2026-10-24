import Foundation

/// What the Home Screen widget shows, written by the app into the shared App Group.
///
/// It stores review due dates and practice days rather than counts, so the widget can work out
/// "3 to review today" and the streak at the time it renders, even if the app has not run since.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    static let appGroup = "group.com.jacobbakerpersonalteam.FreeMateIOS"
    static let storageKey = "freemate.widget.v1"

    var nextLessonId: String?
    var nextLessonTitle: String?
    var courseTitle: String?
    var lessonsDone: Int
    var lessonsTotal: Int
    var reviewDueDates: [Date]
    var activeDays: [String]
    var updatedAt: Date

    static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load(from defaults: UserDefaults? = sharedDefaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: storageKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func save(to defaults: UserDefaults? = sharedDefaults) {
        if let data = encoded() { defaults?.set(data, forKey: Self.storageKey) }
    }

    /// Dates to the second, which is all the widget needs.
    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(self)
    }

    func dueReviews(at date: Date) -> Int {
        reviewDueDates.filter { $0 <= date }.count
    }

    /// The next time the due count goes up, so the widget can refresh then.
    func nextReviewDate(after date: Date) -> Date? {
        reviewDueDates.filter { $0 > date }.min()
    }

    /// Days in a row ending today, or yesterday if today has no practice yet.
    func streak(at date: Date, calendar: Calendar = .current) -> Int {
        let days = Set(activeDays)
        func key(_ day: Date) -> String {
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }
        var day = date
        if !days.contains(key(day)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(key(yesterday)) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(key(day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
