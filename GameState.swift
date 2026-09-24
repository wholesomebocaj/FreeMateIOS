import Combine
import Foundation

struct ReviewItem: Equatable {
    var type: String
    var id: String
    var branchId: String?
    var title: String
    var subtitle: String
    var href: String
    var key: String
    var state: String
    var failures: Int
    var attempts: Int
    var successes: Int
    var successStreak: Int
    var lastFailedAt: String?
    var lastSucceededAt: String?
    var updatedAt: String?
    var dueAt: String?

}

struct OpeningLineProgress: Equatable {
    var moveIndex: Int
    var playedMoves: [String]
    var currentFen: String?
    var completed: Bool
    var updatedAt: String?
    var masteryScore: Double?
}

struct OpeningProgressRecord: Equatable {
    var activeLineId: String?
    var lines: [String: OpeningLineProgress]
}

private let stateRank = ["shaky": 0, "learning": 1, "new": 2, "mastered": 3]
private let allowedLessonStatuses: Set<String> = ["new", "learning", "shaky", "mastered"]

@MainActor
final class GameState: ObservableObject {
    @Published private(set) var courses: [Course] = []
    @Published private(set) var brackets: [SkillBracket] = []
    @Published private(set) var openings: [OpeningCourse] = []
    @Published private(set) var completedLessons: Set<String> = []
    @Published private(set) var savedSteps: [String: Int] = [:]
    @Published private(set) var reviewItems: [String: ReviewItem] = [:]
    @Published var library = CourseLibraryState()
    @Published private(set) var currentUser: FreeMateUser?
    @Published var selectedTab = AppTab.home
    @Published var lessonPath = [LessonRoute]()
    @Published var openingPath = [OpeningRoute]()
    @Published var authMessage = ""
    @Published var authError = ""

    private var openingProgress: [String: OpeningProgressRecord] = [:]
    private var branchCompletions: [String: [String: BranchCompletion]] = [:]
    private var lessonRows: [LessonProgressRow] = []
    private var openingRows: [OpeningProgressRow] = []
    private var courseRows: [CourseProgressRow] = []
    private var users: [FreeMateUser] = []
    private let defaults = UserDefaults.standard

    init() {
        let loaded = CurriculumLoader.loadBundled()
        courses = loaded.courses
        brackets = loaded.brackets
        openings = loaded.openings
        loadLocal()
        if currentUser != nil {
            hydrateFromProgressRows()
        }
    }

    var allLessons: [Lesson] {
        courses.flatMap { CurriculumLoader.courseLessons($0) }
    }

    func lesson(id: String) -> Lesson? { allLessons.first { $0.id == id } }
    func course(id: String) -> Course? { courses.first { $0.id == id } ?? courses.first }
    func opening(id: String) -> OpeningCourse? { openings.first { $0.id == id } }
    func bracket(id: String) -> SkillBracket? { brackets.first { $0.id == id || $0.slug == id } }

    func isUnlocked(_ lesson: Lesson) -> Bool {
        guard let index = allLessons.firstIndex(where: { $0.id == lesson.id }) else { return false }
        if index <= 0 { return true }
        return !lesson.locked || completedLessons.contains(allLessons[index - 1].id)
    }

    func nextLesson() -> Lesson? {
        allLessons.first { !completedLessons.contains($0.id) && isUnlocked($0) } ?? allLessons.first
    }

    func progressPercent() -> Int {
        let lessons = allLessons
        if lessons.isEmpty { return 0 }
        return Int((Double(lessons.filter { completedLessons.contains($0.id) }.count) / Double(lessons.count) * 100).rounded())
    }

    func bracketLessonIds(_ bracket: SkillBracket) -> [String] {
        var seen = Set<String>()
        return bracket.items.flatMap { itemLessonIds($0) }.filter { seen.insert($0).inserted }
    }

    func itemLessonIds(_ item: BracketItem) -> [String] {
        if !item.lessonIds.isEmpty { return item.lessonIds }
        guard let courseId = item.courseId, let course = course(id: courseId) else { return [] }
        return CurriculumLoader.courseLessons(course).map(\.id)
    }

    func bracketItemProgress(_ item: BracketItem) -> Int {
        let ids = Array(Set(itemLessonIds(item)))
        if ids.isEmpty { return 0 }
        let done = ids.filter { completedLessons.contains($0) }.count
        return Int((Double(done) / Double(ids.count) * 100).rounded())
    }

    func bracketProgress(_ bracket: SkillBracket) -> Int {
        let ids = bracketLessonIds(bracket)
        if ids.isEmpty { return 0 }
        let done = ids.filter { completedLessons.contains($0) }.count
        return Int((Double(done) / Double(ids.count) * 100).rounded())
    }

    func nextBracket() -> SkillBracket? {
        brackets.first { bracketProgress($0) < 100 } ?? brackets.first
    }

    func libraryEntries() -> [CourseLibraryMeta] {
        let all = courses.map { CourseLibrary.meta(for: $0, brackets: brackets, completed: completedLessons) }
        let visible = all.filter { CourseLibrary.matches($0, state: library, brackets: brackets) }
        return CourseLibrary.sorted(visible, sort: library.sort, brackets: brackets)
    }

    func activeLibraryTags() -> [String] {
        var tags: [String] = []
        if library.bracket != "all" {
            tags.append(brackets.first { $0.id == library.bracket || $0.slug == library.bracket }?.title ?? library.bracket)
        }
        if library.topic != "all" { tags.append(pretty(library.topic)) }
        if library.color != "all" { tags.append(pretty(library.color)) }
        if library.type != "all" { tags.append(pretty(library.type)) }
        if library.status != "all" { tags.append(pretty(library.status)) }
        return tags
    }

    func resetLibrary() { library = .reset }

    func lessonProgressPercent(_ lesson: Lesson) -> Int {
        if completedLessons.contains(lesson.id) { return 100 }
        let steps = max(lesson.steps.count, 1)
        return Int((Double(savedSteps[lesson.id] ?? 0) / Double(steps) * 100).rounded())
    }

    func markLessonComplete(_ lesson: Lesson) {
        completedLessons.insert(lesson.id)
        savedSteps[lesson.id] = 0
        saveProgress()
        let course = courses.first { CurriculumLoader.courseLessons($0).contains { $0.id == lesson.id } }
        let lessons = course.map { CurriculumLoader.courseLessons($0) } ?? allLessons
        let completedCount = lessons.filter { completedLessons.contains($0.id) }.count
        let percent = lessons.isEmpty ? 0 : Int((Double(completedCount) / Double(lessons.count) * 100).rounded())
        _ = upsertLessonProgress(
            lessonId: lesson.id,
            status: "mastered",
            completed: true,
            masteryScore: 100,
            lastStepIndex: 0,
            lastPositionFen: nil
        )
        if let course {
            _ = upsertCourseProgress(courseId: course.id, completedLessons: completedCount, completionPercent: Double(percent))
        }
        _ = recordReviewSuccess(ReviewSeed(
            type: "lesson",
            id: lesson.id,
            branchId: nil,
            title: lesson.title,
            subtitle: course?.title ?? "Lesson review",
            href: "/lessons/\(lesson.id)"
        ))
    }

    func noteLessonStep(lessonId: String, index: Int) {
        savedSteps[lessonId] = index
        saveProgress()
        guard currentUser != nil else { return }
        let lesson = lesson(id: lessonId)
        let mastered = completedLessons.contains(lessonId)
        let stepCount = max(lesson?.steps.count ?? 1, 1)
        let course = courses.first { CurriculumLoader.courseLessons($0).contains { $0.id == lessonId } }
        let lessons = course.map { CurriculumLoader.courseLessons($0) } ?? allLessons
        let completedCount = lessons.filter { completedLessons.contains($0.id) }.count
        let percent = lessons.isEmpty ? 0 : Int((Double(completedCount) / Double(lessons.count) * 100).rounded())
        let mastery = max(percent, index > 0 ? Int((Double(index) / Double(stepCount) * 100).rounded()) : 0)
        _ = upsertLessonProgress(
            lessonId: lessonId,
            status: mastered ? "mastered" : "learning",
            completed: mastered,
            masteryScore: Double(mastery),
            lastStepIndex: index,
            lastPositionFen: nil
        )
    }

    func setActiveOpeningLine(openingId: String, lineId: String) {
        var record = openingProgressRecord(for: openingId)
        record.activeLineId = lineId
        openingProgress[openingId] = record
        persistOpening(openingId)
    }

    func openingProgressRecord(for openingId: String) -> OpeningProgressRecord {
        openingProgress[openingId] ?? OpeningProgressRecord(activeLineId: nil, lines: [:])
    }

    func branchCompletionMap(for openingId: String) -> [String: BranchCompletion] {
        branchCompletions[openingId] ?? [:]
    }

    func saveOpeningLine(
        openingId: String,
        line: TrainingLine,
        moveIndex: Int,
        playedMoves: [String],
        currentFen: String,
        completed: Bool
    ) {
        var record = openingProgressRecord(for: openingId)
        record.activeLineId = line.id
        record.lines[line.id] = OpeningLineProgress(
            moveIndex: moveIndex,
            playedMoves: playedMoves,
            currentFen: currentFen,
            completed: completed,
            updatedAt: Self.isoNow(),
            masteryScore: nil
        )
        openingProgress[openingId] = record
        persistOpening(openingId)
        let mastery = line.moves.isEmpty ? 0 : Int((Double(moveIndex) / Double(line.moves.count) * 100).rounded())
        _ = upsertOpeningProgress(
            openingKey: openingId,
            branchKey: line.id,
            moveIndex: moveIndex,
            completed: completed,
            masteryScore: Double(mastery)
        )
    }

    func markBranchComplete(opening: OpeningCourse, line: TrainingLine) {
        var map = branchCompletionMap(for: opening.id)
        map[line.id] = BranchCompletion(completed: true, completedAt: Self.isoNow())
        branchCompletions[opening.id] = map
        persistOpening(opening.id)
        _ = recordReviewSuccess(ReviewSeed(
            type: "opening",
            id: opening.id,
            branchId: line.id,
            title: "\(opening.name): \(line.title)",
            subtitle: opening.name,
            href: "/openings/\(opening.id)/train?line=\(line.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? line.id)"
        ))
    }

    func normalizedLineState(saved: OpeningLineProgress?, line: TrainingLine) -> (moveIndex: Int, playedMoves: [String])? {
        guard let saved else { return nil }
        let moveIndex = max(0, min(saved.moveIndex, line.moves.count))
        let played = saved.playedMoves.isEmpty
            ? Array(line.moves.prefix(moveIndex).map(\.uci))
            : Array(saved.playedMoves.prefix(moveIndex))
        let expected = line.moves.prefix(moveIndex).map(\.uci)
        if !expected.enumerated().allSatisfy({ played.indices.contains($0.offset) && played[$0.offset] == $0.element }) {
            return nil
        }
        return (moveIndex, played)
    }

    @discardableResult
    func recordReviewFailure(_ seed: ReviewSeed) -> ReviewItem {
        let key = reviewKey(seed)
        let existing = reviewItems[key]
        let now = Self.isoNow()
        let item = ReviewItem(
            type: seed.type,
            id: seed.id,
            branchId: seed.branchId,
            title: seed.title.isEmpty ? seed.id : seed.title,
            subtitle: seed.subtitle,
            href: seed.href.isEmpty ? reviewHref(seed) : seed.href,
            key: key,
            state: "shaky",
            failures: (existing?.failures ?? 0) + 1,
            attempts: (existing?.attempts ?? 0) + 1,
            successes: existing?.successes ?? 0,
            successStreak: 0,
            lastFailedAt: now,
            lastSucceededAt: existing?.lastSucceededAt,
            updatedAt: now,
            dueAt: now
        )
        reviewItems[key] = item
        persistReview()
        return item
    }

    @discardableResult
    func recordReviewSuccess(_ seed: ReviewSeed) -> ReviewItem {
        let key = reviewKey(seed)
        let existing = reviewItems[key]
        let now = Self.isoNow()
        let streak = (existing?.successStreak ?? 0) + 1
        let item = ReviewItem(
            type: seed.type,
            id: seed.id,
            branchId: seed.branchId,
            title: seed.title.isEmpty ? seed.id : seed.title,
            subtitle: seed.subtitle,
            href: seed.href.isEmpty ? reviewHref(seed) : seed.href,
            key: key,
            state: "mastered",
            failures: existing?.failures ?? 0,
            attempts: (existing?.attempts ?? 0) + 1,
            successes: (existing?.successes ?? 0) + 1,
            successStreak: streak,
            lastFailedAt: existing?.lastFailedAt,
            lastSucceededAt: now,
            updatedAt: now,
            dueAt: nil
        )
        reviewItems[key] = item
        persistReview()
        return item
    }

    func reviewQueue(now: Date = Date()) -> [ReviewItem] {
        reviewItems.values
            .filter { $0.state != "mastered" }
            .filter { item in
                guard let due = item.dueAt else { return true }
                guard let date = Self.parseISO(due) else { return false }
                return date <= now
            }
            .sorted { lhs, rhs in
                let rank = (stateRank[lhs.state] ?? 9) - (stateRank[rhs.state] ?? 9)
                if rank != 0 { return rank < 0 }
                let left = lhs.updatedAt.flatMap(Self.parseISO) ?? .distantPast
                let right = rhs.updatedAt.flatMap(Self.parseISO) ?? .distantPast
                return left > right
            }
    }

    func reviewLabel(_ item: ReviewItem) -> String {
        switch item.state {
        case "shaky": return "Review soon"
        case "learning": return "Practice again"
        case "mastered": return "Mastered"
        default: return "New"
        }
    }

    func hydratedQueue() -> [ReviewItem] {
        reviewQueue().map { item in
            var copy = item
            if item.type == "lesson", let lesson = lesson(id: item.id) {
                let course = courses.first { CurriculumLoader.courseLessons($0).contains { $0.id == lesson.id } }
                if copy.title.isEmpty || copy.title == item.id { copy.title = lesson.title }
                if copy.subtitle.isEmpty { copy.subtitle = course?.title ?? "" }
                copy.href = "/lessons/\(lesson.id)"
            } else if item.type == "opening" {
                let name = opening(id: item.id)?.name ?? item.id
                if copy.title.isEmpty || copy.title == item.id { copy.title = name }
                if copy.subtitle.isEmpty { copy.subtitle = name }
                copy.href = reviewHref(ReviewSeed(type: item.type, id: item.id, branchId: item.branchId, title: copy.title, subtitle: copy.subtitle, href: ""))
            }
            return copy
        }
    }

    func signUp(username: String, password: String) -> String? {
        do {
            let normalized = try AuthSession.normalizeUsername(username)
            if users.contains(where: { $0.username == normalized }) {
                return "That username is already taken."
            }
            let hash = try AuthSession.hashPassword(password)
            let now = Self.isoNow()
            let user = FreeMateUser(
                id: (users.map(\.id).max() ?? 0) + 1,
                email: nil,
                username: normalized,
                passwordHash: hash,
                createdAt: now,
                updatedAt: now
            )
            users.append(user)
            currentUser = user
            defaults.set(AuthSession.createCookie(userId: user.id), forKey: AuthSession.cookieName)
            persistUsers()
            authError = ""
            authMessage = "Signed in as \(user.displayName)"
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func logIn(username: String, password: String) -> String? {
        do {
            let normalized = try AuthSession.normalizeUsername(username)
            guard let user = users.first(where: { $0.username == normalized }),
                  AuthSession.verifyPassword(password, storedHash: user.passwordHash) else {
                return "Invalid username or password."
            }
            currentUser = user
            defaults.set(AuthSession.createCookie(userId: user.id), forKey: AuthSession.cookieName)
            hydrateFromProgressRows()
            authError = ""
            authMessage = ""
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func logOut() {
        currentUser = nil
        defaults.removeObject(forKey: AuthSession.cookieName)
        authMessage = ""
    }

    func openLesson(_ id: String) {
        selectedTab = .lessons
        lessonPath.append(.lesson(id))
    }

    func openCourse(_ id: String) {
        selectedTab = .lessons
        lessonPath.append(.course(id))
    }

    func openBracket(_ id: String) {
        selectedTab = .lessons
        lessonPath.append(.bracket(id))
    }

    func openOpening(_ id: String) {
        selectedTab = .openings
        openingPath.append(.overview(id))
    }

    func openTrainer(id: String, line: String?) {
        selectedTab = .openings
        openingPath.append(.train(id: id, line: line))
    }

    private func reviewKey(_ seed: ReviewSeed) -> String {
        [seed.type, seed.id, seed.branchId].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: ":")
    }

    private func reviewHref(_ seed: ReviewSeed) -> String {
        if seed.type == "opening" {
            let line = seed.branchId.map { "?line=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)" } ?? ""
            return "/openings/\(seed.id)/train\(line)"
        }
        return "/lessons/\(seed.id)"
    }

    private func saveProgress() {
        defaults.set(Array(completedLessons), forKey: "freemate.completedLessons")
        if let data = try? JSONSerialization.data(withJSONObject: savedSteps) {
            defaults.set(data, forKey: "freemate.lessonSteps")
            defaults.set(data, forKey: "freemate.savedSteps")
        }
    }

    private func persistReview() {
        let payload = reviewItems.mapValues { item -> [String: Any] in
            var object: [String: Any] = [
                "type": item.type,
                "id": item.id,
                "title": item.title,
                "subtitle": item.subtitle,
                "href": item.href,
                "key": item.key,
                "state": item.state,
                "failures": item.failures,
                "attempts": item.attempts,
                "successes": item.successes,
                "successStreak": item.successStreak,
            ]
            if let branchId = item.branchId {
                object["branchId"] = branchId
            } else {
                object["branchId"] = NSNull()
            }
            if let lastFailedAt = item.lastFailedAt { object["lastFailedAt"] = lastFailedAt }
            if let lastSucceededAt = item.lastSucceededAt { object["lastSucceededAt"] = lastSucceededAt }
            if let updatedAt = item.updatedAt { object["updatedAt"] = updatedAt }
            if let dueAt = item.dueAt { object["dueAt"] = dueAt }
            return object
        }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            defaults.set(data, forKey: "freemate.reviewQueue")
        }
    }

    private func persistOpening(_ openingId: String) {
        let record = openingProgressRecord(for: openingId)
        var lines: [String: Any] = [:]
        for (id, line) in record.lines {
            var object: [String: Any] = [
                "moveIndex": line.moveIndex,
                "playedMoves": line.playedMoves,
                "completed": line.completed,
            ]
            if let fen = line.currentFen { object["currentFen"] = fen }
            if let updated = line.updatedAt { object["updatedAt"] = updated }
            lines[id] = object
        }
        var progress: [String: Any] = ["lines": lines]
        if let active = record.activeLineId { progress["activeLineId"] = active }
        if let data = try? JSONSerialization.data(withJSONObject: progress) {
            defaults.set(data, forKey: "freemate-opening-progress:\(openingId)")
        }
        var completions: [String: Any] = [:]
        for (id, completion) in branchCompletionMap(for: openingId) {
            var row: [String: Any] = ["completed": completion.completed]
            if let completedAt = completion.completedAt {
                row["completedAt"] = completedAt
            } else {
                row["completedAt"] = NSNull()
            }
            completions[id] = row
        }
        if let data = try? JSONSerialization.data(withJSONObject: completions) {
            defaults.set(data, forKey: "freemate-opening-completions:\(openingId)")
        }
    }

    private func loadLocal() {
        if let stored = defaults.array(forKey: "freemate.completedLessons") as? [String] {
            completedLessons = Set(stored)
        }
        savedSteps = mergedSteps()
        if let data = defaults.data(forKey: "freemate.reviewQueue"),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            reviewItems = object.mapValues(decodeReview)
        }
        for opening in openings {
            openingProgress[opening.id] = loadOpeningProgress(opening.id)
            branchCompletions[opening.id] = loadCompletions(opening.id)
        }
        if let data = defaults.data(forKey: "freemate.users"),
           let rows = try? JSONDecoder().decode([StoredUser].self, from: data) {
            users = rows.map(\.user)
        }
        if let token = defaults.string(forKey: AuthSession.cookieName),
           let userId = AuthSession.readCookie(token) {
            currentUser = users.first { $0.id == userId }
        }
        lessonRows = loadRows("freemate.progress.lessons", LessonProgressRow.self)
        openingRows = loadRows("freemate.progress.openings", OpeningProgressRow.self)
        courseRows = loadRows("freemate.progress.courses", CourseProgressRow.self)
    }

    private func mergedSteps() -> [String: Int] {
        var merged: [String: Int] = [:]
        for key in ["freemate.lessonSteps", "freemate.savedSteps"] {
            guard let data = defaults.data(forKey: key),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            for (id, value) in object {
                if let number = CurriculumLoader.int(value) { merged[id] = number }
            }
        }
        return merged
    }

    private func loadOpeningProgress(_ id: String) -> OpeningProgressRecord {
        guard let data = defaults.data(forKey: "freemate-opening-progress:\(id)"),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return OpeningProgressRecord(activeLineId: nil, lines: [:])
        }
        var lines: [String: OpeningLineProgress] = [:]
        let rawLines = object["lines"] as? [String: Any] ?? [:]
        for (lineId, value) in rawLines {
            guard let row = value as? [String: Any] else { continue }
            lines[lineId] = OpeningLineProgress(
                moveIndex: CurriculumLoader.int(row["moveIndex"]) ?? 0,
                playedMoves: (row["playedMoves"] as? [Any] ?? []).compactMap { CurriculumLoader.string($0) },
                currentFen: CurriculumLoader.string(row["currentFen"]),
                completed: CurriculumLoader.bool(row["completed"]),
                updatedAt: CurriculumLoader.string(row["updatedAt"]),
                masteryScore: row["masteryScore"] as? Double
            )
        }
        return OpeningProgressRecord(activeLineId: CurriculumLoader.string(object["activeLineId"]), lines: lines)
    }

    private func loadCompletions(_ id: String) -> [String: BranchCompletion] {
        guard let data = defaults.data(forKey: "freemate-opening-completions:\(id)"),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return [:] }
        return object.mapValues {
            BranchCompletion(completed: CurriculumLoader.bool($0["completed"]), completedAt: CurriculumLoader.string($0["completedAt"]))
        }
    }

    private func decodeReview(_ raw: [String: Any]) -> ReviewItem {
        ReviewItem(
            type: CurriculumLoader.string(raw["type"]) ?? "lesson",
            id: CurriculumLoader.string(raw["id"]) ?? "",
            branchId: CurriculumLoader.string(raw["branchId"]),
            title: CurriculumLoader.string(raw["title"]) ?? "",
            subtitle: CurriculumLoader.string(raw["subtitle"]) ?? "",
            href: CurriculumLoader.string(raw["href"]) ?? "",
            key: CurriculumLoader.string(raw["key"]) ?? "",
            state: CurriculumLoader.string(raw["state"]) ?? "new",
            failures: CurriculumLoader.int(raw["failures"]) ?? 0,
            attempts: CurriculumLoader.int(raw["attempts"]) ?? 0,
            successes: CurriculumLoader.int(raw["successes"]) ?? 0,
            successStreak: CurriculumLoader.int(raw["successStreak"]) ?? 0,
            lastFailedAt: CurriculumLoader.string(raw["lastFailedAt"]),
            lastSucceededAt: CurriculumLoader.string(raw["lastSucceededAt"]),
            updatedAt: CurriculumLoader.string(raw["updatedAt"]),
            dueAt: CurriculumLoader.string(raw["dueAt"])
        )
    }

    private func hydrateFromProgressRows() {
        for row in lessonRows {
            if row.completed || row.status == "mastered" { completedLessons.insert(row.lessonId) }
            if let index = row.lastStepIndex { savedSteps[row.lessonId] = index }
        }
        saveProgress()
        var grouped: [String: [OpeningProgressRow]] = [:]
        for row in openingRows { grouped[row.openingKey, default: []].append(row) }
        for (openingId, rows) in grouped {
            var completions = branchCompletionMap(for: openingId)
            var progress = openingProgressRecord(for: openingId)
            for row in rows {
                completions[row.branchKey] = BranchCompletion(completed: row.completed, completedAt: row.updatedAt)
                var line = progress.lines[row.branchKey] ?? OpeningLineProgress(moveIndex: 0, playedMoves: [], currentFen: nil, completed: false, updatedAt: nil, masteryScore: nil)
                line.moveIndex = row.moveIndex
                line.completed = row.completed
                line.masteryScore = row.masteryScore
                line.updatedAt = row.updatedAt
                progress.lines[row.branchKey] = line
            }
            if progress.activeLineId == nil { progress.activeLineId = rows.first?.branchKey }
            openingProgress[openingId] = progress
            branchCompletions[openingId] = completions
            persistOpening(openingId)
        }
    }

    @discardableResult
    private func upsertLessonProgress(
        lessonId: String,
        status: String?,
        completed: Bool?,
        masteryScore: Double?,
        lastStepIndex: Int?,
        lastPositionFen: String?
    ) -> String? {
        guard currentUser != nil else { return nil }
        var row = lessonRows.first { $0.lessonId == lessonId } ?? LessonProgressRow(
            lessonId: lessonId, status: "new", completed: false, masteryScore: 0, lastStepIndex: nil, lastPositionFen: nil, updatedAt: Self.isoNow()
        )
        if let status {
            let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard allowedLessonStatuses.contains(normalized) else {
                return "Lesson progress status must be new, learning, shaky, or mastered."
            }
            row.status = normalized
        }
        if let completed { row.completed = completed }
        if let masteryScore { row.masteryScore = masteryScore }
        if let lastStepIndex { row.lastStepIndex = max(0, lastStepIndex) }
        if let lastPositionFen { row.lastPositionFen = lastPositionFen }
        if row.completed && row.status != "mastered" { row.status = "mastered" }
        row.updatedAt = Self.isoNow()
        lessonRows.removeAll { $0.lessonId == lessonId }
        lessonRows.insert(row, at: 0)
        saveRows("freemate.progress.lessons", lessonRows)
        return nil
    }

    @discardableResult
    private func upsertOpeningProgress(
        openingKey: String,
        branchKey: String,
        moveIndex: Int,
        completed: Bool?,
        masteryScore: Double?
    ) -> String? {
        guard currentUser != nil else { return nil }
        var row = openingRows.first { $0.openingKey == openingKey && $0.branchKey == branchKey } ?? OpeningProgressRow(
            openingKey: openingKey, branchKey: branchKey, moveIndex: 0, completed: false, masteryScore: 0, updatedAt: Self.isoNow()
        )
        row.moveIndex = max(0, moveIndex)
        if let completed { row.completed = completed }
        if let masteryScore { row.masteryScore = masteryScore }
        row.updatedAt = Self.isoNow()
        openingRows.removeAll { $0.openingKey == openingKey && $0.branchKey == branchKey }
        openingRows.insert(row, at: 0)
        saveRows("freemate.progress.openings", openingRows)
        return nil
    }

    @discardableResult
    private func upsertCourseProgress(courseId: String, completedLessons: Int, completionPercent: Double) -> String? {
        guard currentUser != nil else { return nil }
        var row = courseRows.first { $0.courseId == courseId } ?? CourseProgressRow(
            courseId: courseId, completedLessons: 0, completionPercent: 0, updatedAt: Self.isoNow()
        )
        row.completedLessons = max(0, completedLessons)
        row.completionPercent = min(100, max(0, completionPercent))
        row.updatedAt = Self.isoNow()
        courseRows.removeAll { $0.courseId == courseId }
        courseRows.insert(row, at: 0)
        saveRows("freemate.progress.courses", courseRows)
        return nil
    }

    private func persistUsers() {
        let stored = users.map(StoredUser.init)
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: "freemate.users") }
    }

    private func loadRows<T: Codable>(_ key: String, _ type: T.Type) -> [T] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    private func saveRows<T: Codable>(_ key: String, _ rows: [T]) {
        if let data = try? JSONEncoder().encode(rows) { defaults.set(data, forKey: key) }
    }

    private func pretty(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ").capitalized
    }

    static func isoNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    static func parseISO(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

struct ReviewSeed {
    var type: String
    var id: String
    var branchId: String?
    var title: String
    var subtitle: String
    var href: String
}

struct BranchCompletion: Equatable, Codable {
    var completed: Bool
    var completedAt: String?
}

struct LessonProgressRow: Codable, Equatable {
    var lessonId: String
    var status: String
    var completed: Bool
    var masteryScore: Double
    var lastStepIndex: Int?
    var lastPositionFen: String?
    var updatedAt: String
}

struct OpeningProgressRow: Codable, Equatable {
    var openingKey: String
    var branchKey: String
    var moveIndex: Int
    var completed: Bool
    var masteryScore: Double
    var updatedAt: String
}

struct CourseProgressRow: Codable, Equatable {
    var courseId: String
    var completedLessons: Int
    var completionPercent: Double
    var updatedAt: String
}

private struct StoredUser: Codable {
    var id: Int
    var email: String?
    var username: String?
    var passwordHash: String
    var createdAt: String
    var updatedAt: String

    init(_ user: FreeMateUser) {
        id = user.id
        email = user.email
        username = user.username
        passwordHash = user.passwordHash
        createdAt = user.createdAt
        updatedAt = user.updatedAt
    }

    var user: FreeMateUser {
        FreeMateUser(id: id, email: email, username: username, passwordHash: passwordHash, createdAt: createdAt, updatedAt: updatedAt)
    }
}

enum AppTab: Hashable {
    case home, lessons, openings, practice, review
}

enum LessonRoute: Hashable {
    case bracket(String)
    case course(String)
    case lesson(String)
}

enum OpeningRoute: Hashable {
    case overview(String)
    case train(id: String, line: String?)
}
