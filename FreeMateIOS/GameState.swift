import Combine
import Foundation

/// The app's shared state: the bundled curriculum, navigation, and the learner's progress.
///
/// Progress is one `LearnerProgress` value saved by `LearnerProgressStore`. There are no
/// accounts. iCloud sync (see `CloudSync`) replaces the saved value and calls `reloadProgress()`.
@MainActor
final class GameState: ObservableObject {
    @Published private(set) var courses: [Course] = []
    @Published private(set) var brackets: [SkillBracket] = []
    @Published private(set) var openings: [OpeningCourse] = []
    @Published private(set) var openingTutorials: [OpeningTutorial] = []
    @Published private(set) var progress: LearnerProgress
    @Published var library = CourseLibraryState()
    @Published var selectedTab = AppTab.home
    @Published var lessonPath = [LessonRoute]()
    @Published var openingPath = [OpeningRoute]()
    @Published var practicePath = [PracticeRoute]()
    @Published var puzzlePath = [PuzzleRoute]()
    @Published var homePath = [HomeRoute]()

    private let store: LearnerProgressStore
    private let activity: ActivityStore
    /// Called after every progress change, so the widget snapshot stays current.
    var onProgressChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        store = LearnerProgressStore(defaults: defaults)
        activity = ActivityStore(defaults: defaults)
        progress = store.load()
        let loaded = CurriculumLoader.loadBundled()
        courses = loaded.courses
        brackets = loaded.brackets
        openings = loaded.openings
        do {
            openingTutorials = try OpeningTutorialLibrary.loadBundled()
        } catch {
            print("Opening tutorials unavailable: \(error.localizedDescription)")
        }
    }

    var completedLessons: Set<String> { progress.completedLessons }

    var allLessons: [Lesson] {
        courses.flatMap { CurriculumLoader.courseLessons($0) }
    }

    func lesson(id: String) -> Lesson? { allLessons.first { $0.id == id } }
    func course(id: String) -> Course? { courses.first { $0.id == id } ?? courses.first }
    func opening(id: String) -> OpeningCourse? { openings.first { $0.id == id } }
    func openingTutorial(id: String) -> OpeningTutorial? { openingTutorials.first { $0.id == id } }
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
        return Int((Double(progress.lessonSteps[lesson.id] ?? 0) / Double(steps) * 100).rounded())
    }

    func savedStep(for lessonId: String) -> Int? { progress.lessonSteps[lessonId] }

    // MARK: - Recording progress

    func markLessonComplete(_ lesson: Lesson) {
        let course = courses.first { CurriculumLoader.courseLessons($0).contains { $0.id == lesson.id } }
        update { progress in
            progress.completeLesson(lesson.id, seed: ReviewSeed(
                kind: .lesson, itemId: lesson.id, branchId: nil,
                title: lesson.title, subtitle: course?.title ?? "Lesson review"
            ))
        }
    }

    func noteLessonStep(lessonId: String, index: Int) {
        update { $0.noteStep(index, lesson: lessonId) }
    }

    func recordReviewFailure(_ seed: ReviewSeed) {
        update { $0.recordFailure(seed) }
    }

    func setActiveOpeningLine(openingId: String, lineId: String) {
        update(countsAsPractice: false) { $0.setActiveLine(openingId: openingId, lineId: lineId) }
    }

    func openingProgressRecord(for openingId: String) -> OpeningProgressRecord {
        progress.openings[openingId] ?? OpeningProgressRecord()
    }

    func branchCompletionMap(for openingId: String) -> [String: BranchCompletion] {
        openingProgressRecord(for: openingId).completions
    }

    func saveOpeningLine(
        openingId: String,
        line: TrainingLine,
        moveIndex: Int,
        playedMoves: [String],
        currentFen: String,
        completed: Bool
    ) {
        update {
            $0.saveLine(openingId: openingId, lineId: line.id, progress: OpeningLineProgress(
                moveIndex: moveIndex, playedMoves: playedMoves, currentFen: currentFen,
                completed: completed, updatedAt: Date()
            ))
        }
    }

    func markBranchComplete(opening: OpeningCourse, line: TrainingLine) {
        update {
            $0.completeBranch(openingId: opening.id, lineId: line.id, seed: ReviewSeed(
                kind: .opening, itemId: opening.id, branchId: line.id,
                title: "\(opening.name): \(line.title)", subtitle: opening.name
            ))
        }
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

    // MARK: - Review

    func reviewQueue(now: Date = Date()) -> [ReviewItem] { progress.reviewQueue(now: now) }

    func upcomingReviews(now: Date = Date()) -> [ReviewItem] { progress.upcomingReviews(now: now) }

    func reviewLabel(_ item: ReviewItem) -> String {
        switch item.state {
        case .shaky: return "Missed recently"
        case .learning: return "\(ReviewSchedule.intervals[max(0, min(item.stage, ReviewSchedule.intervals.count) - 1)])-day check-in"
        case .mastered: return "Mastered"
        }
    }

    // MARK: - Activity

    var streak: Int { activity.streak() }

    func recordActivity() {
        activity.record()
        onProgressChange?()
    }

    /// Picks up progress that iCloud sync wrote while the app was running.
    func reloadProgress() {
        progress = store.load()
    }

    private func update(countsAsPractice: Bool = true, _ change: (inout LearnerProgress) -> Void) {
        change(&progress)
        store.save(progress)
        if countsAsPractice { activity.record() }
        onProgressChange?()
    }

    private func pretty(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ").capitalized
    }

    // MARK: - Navigation

    /// Opens a link from the widget: `freemate://review`, `freemate://lesson/<id>`, or
    /// `freemate://lessons`.
    func open(_ url: URL) {
        guard url.scheme == "freemate" else { return }
        switch url.host() {
        case "review": openReview()
        case "lessons": selectedTab = .lessons
        case "lesson":
            let id = url.pathComponents.dropFirst().first ?? ""
            if lesson(id: id) != nil {
                lessonPath = []
                openLesson(id)
            } else {
                selectedTab = .lessons
            }
        default: selectedTab = .home
        }
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

    /// Review lives on Today, next to what is due.
    func openReview() {
        selectedTab = .home
        homePath = [.review]
    }

    func openPuzzles(_ route: PuzzleRoute? = nil) {
        selectedTab = .puzzles
        puzzlePath = route.map { [$0] } ?? []
    }

    func openPractice(_ route: PracticeRoute) {
        selectedTab = .practice
        practicePath = [route]
    }

    func openTutorial(_ id: String) {
        selectedTab = .openings
        openingPath.append(.tutorial(id))
    }

}

enum AppTab: Hashable {
    case home, lessons, openings, puzzles, practice
}

enum HomeRoute: Hashable {
    case review
}

enum PuzzleRoute: Hashable {
    /// A level, collection, drill, or daily puzzle, by `PuzzleSet.id`.
    case set(String)
    case rush
    case blunderCheck
}

enum LessonRoute: Hashable {
    case bracket(String)
    case course(String)
    case lesson(String)
}

enum PracticeRoute: Hashable {
    case computer
    case freeBoard
}

enum OpeningRoute: Hashable {
    case overview(String)
    case train(id: String, line: String?)
    case tutorial(String)
}
