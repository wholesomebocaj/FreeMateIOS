import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        FreeMateScreen(title: "FreeMate") {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Beginner chess coaching")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FreeMateTheme.accent)
                    Text("Learn chess the right way.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(FreeMateTheme.text)
                    Text("Free structured lessons, practice, and opening training for beginners who want a calm, clear path forward.")
                        .foregroundStyle(FreeMateTheme.muted)
                    HStack {
                        Button("Start Learning") { game.selectedTab = .lessons }
                            .buttonStyle(.borderedProminent)
                            .tint(FreeMateTheme.green)
                        Button("Explore Openings") { game.selectedTab = .openings }
                            .buttonStyle(.bordered)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        stat("Interactive", "Practice boards and guided lessons")
                        stat("Beginner first", "Clear steps and calm pacing")
                        stat("Always progressing", "Lessons, openings, and review")
                    }
                    Text("What should I learn next?")
                        .font(.title2.bold())
                    roadmap
                    if let next = game.nextBracket() {
                        Button("Continue \(next.title)") { game.openBracket(next.slug) }
                            .buttonStyle(.borderedProminent)
                            .tint(FreeMateTheme.green)
                    }
                }
                .padding()
            }
        }
    }

    private var roadmap: some View {
        let categories = game.courses.flatMap(\.categories)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(categories) { category in
                let lessons = category.skills.flatMap(\.lessons)
                let complete = !lessons.isEmpty && lessons.allSatisfy { game.completedLessons.contains($0.id) }
                let unlocked = lessons.contains { lesson in
                    game.lesson(id: lesson.id).map { game.isUnlocked($0) } ?? false
                }
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(complete ? FreeMateTheme.green.opacity(0.25) : unlocked ? FreeMateTheme.accent.opacity(0.18) : FreeMateTheme.panel, in: Capsule())
                    .foregroundStyle(complete || unlocked ? FreeMateTheme.text : FreeMateTheme.muted)
            }
        }
    }

    private func stat(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold()).foregroundStyle(FreeMateTheme.text)
            Text(detail).font(.caption2).foregroundStyle(FreeMateTheme.muted)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CourseLibraryView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        FreeMateScreen(title: "Courses") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Browse the course library.")
                        .font(.title.bold())
                    Text("Filter by level, topic, color, and progress to find the next lesson path.")
                        .foregroundStyle(FreeMateTheme.muted)
                    let entries = game.libraryEntries()
                    Text("\(game.completedLessons.count) lessons complete")
                        .foregroundStyle(FreeMateTheme.accent)
                    ProgressMeter(value: game.progressPercent())
                    TextField("Search courses", text: $game.library.query)
                        .textFieldStyle(.roundedBorder)
                    filterMenus
                    Button("Reset") { game.resetLibrary() }
                        .buttonStyle(.bordered)
                    Text("\(entries.count) course\(entries.count == 1 ? "" : "s") shown")
                        .font(.subheadline)
                        .foregroundStyle(FreeMateTheme.muted)
                    if game.activeLibraryTags().isEmpty {
                        Text("All courses").font(.caption).foregroundStyle(FreeMateTheme.muted)
                    } else {
                        Text(game.activeLibraryTags().joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(FreeMateTheme.accent)
                    }
                    if entries.isEmpty {
                        Text("No courses match these filters.")
                            .foregroundStyle(FreeMateTheme.muted)
                    }
                    ForEach(entries) { meta in
                        courseCard(meta)
                    }
                    Text("Skill brackets")
                        .font(.title3.bold())
                        .padding(.top, 8)
                    ForEach(game.brackets) { bracket in
                        Button {
                            game.openBracket(bracket.slug)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(bracket.title) · \(bracket.range)")
                                    .font(.headline)
                                    .foregroundStyle(FreeMateTheme.text)
                                Text(bracket.description)
                                    .font(.subheadline)
                                    .foregroundStyle(FreeMateTheme.muted)
                                ProgressMeter(value: game.bracketProgress(bracket))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private var filterMenus: some View {
        VStack(spacing: 8) {
            Picker("Level", selection: $game.library.bracket) {
                Text("All levels").tag("all")
                ForEach(game.brackets) { bracket in
                    Text("\(bracket.title) (\(bracket.range))").tag(bracket.id)
                }
            }
            Picker("Topic", selection: $game.library.topic) {
                Text("All topics").tag("all")
                Text("Fundamentals").tag("fundamentals")
                Text("Openings").tag("openings")
                Text("Tactics").tag("tactics")
                Text("Endgame").tag("endgame")
                Text("Strategy").tag("strategy")
            }
            Picker("Color", selection: $game.library.color) {
                Text("All colors").tag("all")
                Text("White").tag("white")
                Text("Black").tag("black")
                Text("Both").tag("both")
            }
            Picker("Type", selection: $game.library.type) {
                Text("All types").tag("all")
                Text("Interactive lesson").tag("interactive lesson")
                Text("Opening course").tag("opening course")
                Text("Drill").tag("drill")
                Text("Quiz").tag("quiz")
                Text("Practice").tag("practice")
            }
            Picker("Status", selection: $game.library.status) {
                Text("All status").tag("all")
                Text("Not started").tag("not-started")
                Text("In progress").tag("in-progress")
                Text("Completed").tag("completed")
            }
            Picker("Sort", selection: $game.library.sort) {
                ForEach(CourseLibrarySort.allCases) { sort in
                    Text(sort.label).tag(sort)
                }
            }
        }
        .pickerStyle(.menu)
    }

    private func courseCard(_ meta: CourseLibraryMeta) -> some View {
        let label = meta.status == "completed" ? "Review" : meta.status == "in-progress" ? "Continue" : "Open"
        return Button {
            game.openCourse(meta.course.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(meta.bracketLabel).font(.caption.weight(.bold)).foregroundStyle(FreeMateTheme.accent)
                Text(meta.course.title).font(.headline).foregroundStyle(FreeMateTheme.text)
                Text(meta.course.description).font(.subheadline).foregroundStyle(FreeMateTheme.muted)
                Text("\(meta.bracketRange) · \(meta.topic) · \(meta.color) · \(meta.type)")
                    .font(.caption)
                    .foregroundStyle(FreeMateTheme.muted)
                ProgressMeter(value: meta.progress)
                Text(label).font(.caption.weight(.bold)).foregroundStyle(FreeMateTheme.green)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct BracketDetailView: View {
    @EnvironmentObject private var game: GameState
    let bracketId: String

    var body: some View {
        let bracket = game.bracket(id: bracketId)
        FreeMateScreen(title: bracket?.title ?? "Bracket") {
            ScrollView {
                if let bracket {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(bracket.range).foregroundStyle(FreeMateTheme.accent)
                        Text(bracket.description).foregroundStyle(FreeMateTheme.muted)
                        Text(bracket.learn.joined(separator: " · ")).font(.subheadline)
                        let ids = game.bracketLessonIds(bracket)
                        Text("\(ids.filter { game.completedLessons.contains($0) }.count) of \(ids.count) complete")
                        ProgressMeter(value: game.bracketProgress(bracket))
                        ForEach(bracket.items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.kind == "preview" ? "Preview" : item.kind == "track" ? "Track" : "Course")
                                    .font(.caption.bold())
                                    .foregroundStyle(FreeMateTheme.accent)
                                Text(item.title).font(.headline)
                                Text(item.description).font(.subheadline).foregroundStyle(FreeMateTheme.muted)
                                ProgressMeter(value: game.bracketItemProgress(item))
                                if let courseId = item.courseId, item.kind != "preview" {
                                    Button(game.bracketItemProgress(item) > 0 ? "Continue" : "Open") {
                                        game.openCourse(courseId)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(FreeMateTheme.green)
                                } else if item.kind == "preview" {
                                    Text("Preview").font(.caption).foregroundStyle(FreeMateTheme.muted)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct CourseDetailView: View {
    @EnvironmentObject private var game: GameState
    let courseId: String

    var body: some View {
        let course = game.courses.first { $0.id == courseId } ?? game.courses.first
        FreeMateScreen(title: course?.title ?? "Course") {
            ScrollView {
                if let course {
                    let lessons = CurriculumLoader.courseLessons(course)
                    let done = lessons.filter { game.completedLessons.contains($0.id) }.count
                    VStack(alignment: .leading, spacing: 16) {
                        Text(course.description).foregroundStyle(FreeMateTheme.muted)
                        Text("\(done) of \(lessons.count) complete")
                        ProgressMeter(value: CurriculumLoader.courseProgress(course, completed: game.completedLessons))
                        if course.categories.isEmpty {
                            Text("This course is part of the FreeMate roadmap.")
                        } else {
                            ForEach(course.categories) { category in
                                Text(category.title).font(.title3.bold())
                                Text(category.description).foregroundStyle(FreeMateTheme.muted)
                                ForEach(category.skills) { skill in
                                    ForEach(skill.lessons) { lesson in
                                        lessonRow(course: course, lesson: lesson)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func lessonRow(course: Course, lesson: Lesson) -> some View {
        let unlocked = CurriculumLoader.isCourseLessonUnlocked(course, lessonId: lesson.id, completed: game.completedLessons)
        let state = game.completedLessons.contains(lesson.id) ? "Done" : unlocked ? "Open" : "Locked"
        return VStack(alignment: .leading, spacing: 6) {
            Text(state).font(.caption.bold()).foregroundStyle(unlocked ? FreeMateTheme.accent : FreeMateTheme.muted)
            Text(lesson.title).font(.headline)
            Text(lesson.summary).font(.subheadline).foregroundStyle(FreeMateTheme.muted)
            Text("\(lesson.difficulty) · \(lesson.timeMinutes) min · \(lesson.ratingRange)")
                .font(.caption)
                .foregroundStyle(FreeMateTheme.muted)
            ProgressMeter(value: game.lessonProgressPercent(lesson))
            Button(game.completedLessons.contains(lesson.id) ? "Review" : unlocked ? "Open" : "Locked") {
                if unlocked { game.openLesson(lesson.id) }
            }
            .disabled(!unlocked)
            .buttonStyle(.borderedProminent)
            .tint(FreeMateTheme.green)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct LessonPlayerView: View {
    @EnvironmentObject private var game: GameState
    let lessonId: String

    var body: some View {
        if let lesson = game.lesson(id: lessonId) ?? game.allLessons.first {
            LessonPlayerBody(lesson: lesson, game: game)
        } else {
            Text("Lesson not found")
                .foregroundStyle(FreeMateTheme.text)
        }
    }
}

struct LessonPlayerBody: View {
    @EnvironmentObject private var game: GameState
    @StateObject private var session: LessonSession
    private let lesson: Lesson

    init(lesson: Lesson, game: GameState) {
        self.lesson = lesson
        _session = StateObject(wrappedValue: LessonSession(lesson: lesson, game: game))
    }

    var body: some View {
        FreeMateScreen(title: lesson.title) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if session.scaffold {
                        Text("Lesson Scaffold").font(.title2.bold())
                        Text("This lesson is ready for content. Add steps when you are ready to build it out.")
                            .foregroundStyle(FreeMateTheme.muted)
                    } else if session.finished {
                        Text("Lesson Complete").font(.title2.bold())
                        Text("Great work. Continue to the next lesson.")
                            .foregroundStyle(FreeMateTheme.muted)
                    } else if let step = session.step {
                        Text("Step \(session.index + 1) of \(lesson.steps.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FreeMateTheme.accent)
                        Text(session.completedSteps.contains(session.index) ? "Completed" : "In progress")
                            .font(.caption)
                            .foregroundStyle(session.completedSteps.contains(session.index) ? FreeMateTheme.green : FreeMateTheme.muted)
                        Text(step.title).font(.title2.bold())
                        if !step.body.isEmpty {
                            Text(step.body).foregroundStyle(FreeMateTheme.muted)
                        }
                        if step.type == "checklist" {
                            ForEach(step.tasks, id: \.self) { task in
                                Text("• \(task)")
                            }
                        }
                        if let board = session.board {
                            ChessboardView(board: board)
                            Text(note(for: step))
                                .font(.footnote)
                                .foregroundStyle(FreeMateTheme.muted)
                            if step.type == "click-all-squares" {
                                Text("\(session.foundSquares.count)/\(step.targetSquares.count) squares found")
                                    .font(.footnote)
                            }
                        }
                        if step.type == "multiple-choice" {
                            Text(step.question ?? "Choose the best response.")
                                .font(.headline)
                            ForEach(step.choices) { choice in
                                Button(choice.label) { session.choose(choice) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        if !session.feedback.isEmpty {
                            Text(session.feedback)
                                .foregroundStyle(session.feedbackKind == "error" ? FreeMateTheme.red : FreeMateTheme.accent)
                        }
                        HStack {
                            if session.index > 0 {
                                Button("Back") { session.goBack() }
                                    .buttonStyle(.bordered)
                            }
                            Button(session.nextTitle) { session.goForward() }
                                .buttonStyle(.borderedProminent)
                                .tint(FreeMateTheme.green)
                                .disabled(!session.canAdvance)
                        }
                    }
                    sidebar
                }
                .padding()
            }
        }
    }

    private var sidebar: some View {
        let course = game.courses.first { CurriculumLoader.courseLessons($0).contains { $0.id == lesson.id } }
        return VStack(alignment: .leading, spacing: 8) {
            if let course {
                Text(course.title).font(.headline)
                ForEach(CurriculumLoader.courseLessons(course)) { item in
                    let unlocked = CurriculumLoader.isCourseLessonUnlocked(course, lessonId: item.id, completed: game.completedLessons)
                    let label = game.completedLessons.contains(item.id) ? "Done" : item.id == lesson.id ? "Current" : unlocked ? "Open" : "Locked"
                    Button {
                        if unlocked || item.id == lesson.id { game.openLesson(item.id) }
                    } label: {
                        HStack {
                            Text(label).font(.caption).foregroundStyle(FreeMateTheme.accent)
                            Text(item.title).foregroundStyle(unlocked ? FreeMateTheme.text : FreeMateTheme.muted)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked && item.id != lesson.id)
                }
            }
        }
    }

    private func note(for step: LessonStep) -> String {
        switch step.type {
        case "click-all-squares": return "Complete every highlighted square to unlock the next step."
        case "square-click": return "Click the target square to continue."
        case "board-task", "move-task", "capture-task", "tactic-task": return "Make the correct board action to continue."
        case "board-demo": return "Study the board, then continue when you are ready."
        default: return "Complete the interaction to continue."
        }
    }
}

struct OpeningBrowserView: View {
    @EnvironmentObject private var game: GameState
    @State private var side = "all"
    @State private var difficulty = "all"

    var body: some View {
        let visible = game.openings.filter { opening in
            (side == "all" || opening.side == side) && (difficulty == "all" || opening.difficulty == difficulty)
        }
        FreeMateScreen(title: "Openings") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Train a beginner repertoire.")
                        .font(.title2.bold())
                    Text("\(visible.count) opening courses")
                        .foregroundStyle(FreeMateTheme.muted)
                    Picker("Side", selection: $side) {
                        Text("All sides").tag("all")
                        Text("White").tag("White")
                        Text("Black").tag("Black")
                    }
                    Picker("Difficulty", selection: $difficulty) {
                        Text("All levels").tag("all")
                        ForEach(Array(Set(game.openings.map(\.difficulty))).sorted(), id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    ForEach(visible) { opening in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(opening.eco) · \(opening.difficulty) · \(opening.side)")
                                .font(.caption.bold())
                                .foregroundStyle(FreeMateTheme.accent)
                            Text(opening.name).font(.headline)
                            Text(opening.description).font(.subheadline).foregroundStyle(FreeMateTheme.muted)
                            Text("\(opening.sectionCount) sections · \(opening.moveCount) moves")
                                .font(.caption)
                                .foregroundStyle(FreeMateTheme.muted)
                            HStack {
                                Button("Overview") { game.openOpening(opening.id) }
                                    .buttonStyle(.bordered)
                                Button("Train") { game.openTrainer(id: opening.id, line: nil) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(FreeMateTheme.green)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
        }
    }
}

struct OpeningOverviewView: View {
    @EnvironmentObject private var game: GameState
    let openingId: String

    var body: some View {
        let opening = game.opening(id: openingId)
        FreeMateScreen(title: opening?.name ?? "Opening") {
            ScrollView {
                if let opening {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(opening.eco) · \(opening.difficulty) · \(opening.side)")
                            .foregroundStyle(FreeMateTheme.accent)
                        Text(opening.description).foregroundStyle(FreeMateTheme.muted)
                        Button("Train this repertoire") { game.openTrainer(id: opening.id, line: nil) }
                            .buttonStyle(.borderedProminent)
                            .tint(FreeMateTheme.green)
                        Text("Ideas to remember").font(.headline)
                        ForEach(opening.ideas, id: \.self) { idea in Text("• \(idea)") }
                        Text("Common mistakes").font(.headline)
                        ForEach(opening.commonMistakes, id: \.self) { idea in Text("• \(idea)") }
                        Text("Main training path").font(.headline)
                        ForEach(Array(opening.mainMoves.enumerated()), id: \.offset) { index, move in
                            VStack(alignment: .leading) {
                                Text("\(index + 1). \(move.san)").font(.headline)
                                Text(move.explanation).font(.subheadline).foregroundStyle(FreeMateTheme.muted)
                            }
                        }
                        Text("Lichess explorer stats stay on the web service. This build trains from the local FreeMate lines.")
                            .font(.footnote)
                            .foregroundStyle(FreeMateTheme.muted)
                    }
                    .padding()
                }
            }
        }
    }
}

struct OpeningTrainerView: View {
    @EnvironmentObject private var game: GameState
    let openingId: String
    let lineId: String?

    var body: some View {
        if let opening = game.opening(id: openingId) {
            OpeningTrainerBody(opening: opening, game: game, lineId: lineId)
        } else {
            Text("Opening not found")
        }
    }
}

struct OpeningTrainerBody: View {
    @StateObject private var trainer: OpeningTrainer

    init(opening: OpeningCourse, game: GameState, lineId: String?) {
        _trainer = StateObject(wrappedValue: OpeningTrainer(opening: opening, game: game, requestedLineId: lineId))
    }

    var body: some View {
        FreeMateScreen(title: trainer.opening.name) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(trainer.kicker).font(.caption.bold()).foregroundStyle(FreeMateTheme.accent)
                    Text(trainer.prompt).font(.title3.bold())
                    Text(trainer.status)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(trainer.statusDone ? FreeMateTheme.green : FreeMateTheme.muted)
                    ChessboardView(board: trainer.board)
                    Text(trainer.noteTitle).font(.headline)
                    Text(trainer.explanation).foregroundStyle(FreeMateTheme.muted)
                    if !trainer.feedback.isEmpty {
                        Text(trainer.feedback)
                            .foregroundStyle(trainer.feedbackKind == "error" ? FreeMateTheme.red : trainer.feedbackKind == "success" ? FreeMateTheme.accent : FreeMateTheme.muted)
                    }
                    HStack {
                        Button("Previous") { trainer.jump(to: trainer.moveIndex - 1) }
                            .buttonStyle(.bordered)
                        Button("Next") { trainer.jump(to: trainer.moveIndex + 1) }
                            .buttonStyle(.bordered)
                    }
                    Text("Lines").font(.headline)
                    ForEach(trainer.lines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                trainer.loadBranch(line)
                            } label: {
                                HStack {
                                    Text(trainer.completions[line.id]?.completed == true ? "✓ \(line.title)" : line.title)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(trainer.lineProgress(line))%")
                                        .font(.caption)
                                }
                                .foregroundStyle(line.id == trainer.activeLine.id ? FreeMateTheme.accent : FreeMateTheme.text)
                            }
                            .buttonStyle(.plain)
                            ProgressMeter(value: trainer.lineProgress(line))
                            ForEach(Array(line.moves.enumerated()), id: \.offset) { index, move in
                                Button {
                                    if line.id != trainer.activeLine.id { trainer.loadBranch(line) }
                                    trainer.jump(to: index)
                                } label: {
                                    Text("\(stateIcon(trainer.moveState(line: line, index: index))) \(trainer.moveLabel(move, index: index))")
                                        .font(.caption)
                                        .foregroundStyle(FreeMateTheme.muted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text("Ideas").font(.headline)
                    ForEach(trainer.opening.ideas, id: \.self) { idea in Text("• \(idea)").font(.subheadline) }
                    Text("Common mistakes").font(.headline)
                    ForEach(trainer.opening.commonMistakes, id: \.self) { idea in Text("• \(idea)").font(.subheadline) }
                }
                .padding()
            }
        }
    }

    private func stateIcon(_ state: String) -> String {
        switch state {
        case "done": return "✓"
        case "active": return "→"
        default: return "•"
        }
    }
}

struct PracticeView: View {
    @StateObject private var board = PracticeBoard()

    var body: some View {
        FreeMateScreen(title: "Practice") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Free board practice.")
                        .font(.title2.bold())
                    Text("Move both sides, test legal moves, and load custom positions.")
                        .foregroundStyle(FreeMateTheme.muted)
                    Text(statusText)
                        .font(.headline)
                        .foregroundStyle(board.isCheckmate ? FreeMateTheme.red : board.isCheck ? FreeMateTheme.gold : FreeMateTheme.text)
                    Text("Current turn: \(turnText)")
                    Text("Last move: \(board.history.last?.san ?? "None")")
                    ChessboardView(board: board)
                    HStack {
                        Button("Reset") { board.reset() }.buttonStyle(.bordered)
                        Button("Flip") { board.flip() }.buttonStyle(.bordered)
                        Button("Clear") { board.clear() }.buttonStyle(.bordered)
                    }
                    FenForm(board: board)
                    Text("Move history").font(.headline)
                    if board.history.isEmpty {
                        Text("No moves yet.").foregroundStyle(FreeMateTheme.muted)
                    } else {
                        ForEach(board.history) { entry in
                            Text("\(entry.index). \(entry.san)")
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var turnText: String { board.turn == "white" ? "White" : "Black" }
    private var statusText: String {
        if board.isCheckmate { return "Checkmate — game over" }
        if board.isCheck { return "\(turnText) is in check" }
        return "\(turnText) to move"
    }
}

struct FenForm: View {
    @ObservedObject var board: PracticeBoard
    @State private var text = ChessEngine.startingFen
    @State private var message = ""
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading) {
            TextField("FEN", text: $text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Load position") {
                do {
                    try board.loadFen(text, setInitial: true, clearHistory: true)
                    message = "Position loaded."
                    failed = false
                } catch {
                    message = error.localizedDescription
                    failed = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(FreeMateTheme.green)
            if !message.isEmpty {
                Text(message).foregroundStyle(failed ? FreeMateTheme.red : FreeMateTheme.accent)
            }
        }
        .onChange(of: board.fen) { _, newValue in
            text = newValue
        }
    }
}

struct ReviewView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        let queue = game.hydratedQueue()
        FreeMateScreen(title: "Review") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(queue.isEmpty ? "Nothing due" : "\(queue.count) item\(queue.count == 1 ? "" : "s") ready")
                        .font(.headline)
                    ProgressMeter(value: queue.isEmpty ? 100 : min(100, queue.count * 18))
                    if queue.isEmpty {
                        Text("No shaky items right now.")
                            .font(.title3.bold())
                        Text("Missed lesson tasks and opening branches will appear here automatically.")
                            .foregroundStyle(FreeMateTheme.muted)
                        Button("Continue lessons") { game.selectedTab = .lessons }
                            .buttonStyle(.borderedProminent)
                            .tint(FreeMateTheme.green)
                        Button("Train openings") { game.selectedTab = .openings }
                            .buttonStyle(.bordered)
                    } else {
                        ForEach(Array(queue.enumerated()), id: \.element.key) { index, item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(index + 1). \(item.type == "opening" ? "Opening branch" : "Lesson") · \(game.reviewLabel(item))")
                                    .font(.caption.bold())
                                    .foregroundStyle(FreeMateTheme.accent)
                                Text(item.title).font(.headline)
                                Text(item.subtitle.isEmpty ? "Practice this once, then move on." : item.subtitle)
                                    .foregroundStyle(FreeMateTheme.muted)
                                Text("\(item.state) · \(item.failures) miss\(item.failures == 1 ? "" : "es") · \(item.successStreak) correct in a row")
                                    .font(.caption)
                                Button("Review") { open(item) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(FreeMateTheme.green)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func open(_ item: ReviewItem) {
        if item.type == "opening" {
            game.openTrainer(id: item.id, line: item.branchId)
        } else {
            game.openLesson(item.id)
        }
    }
}

struct AuthView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var mode = "login"
    @State private var message = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ZStack {
                FreeMateTheme.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    if let user = game.currentUser {
                        Text("Signed in as \(user.displayName)")
                            .font(.title3.bold())
                        Button("Log out") {
                            game.logOut()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FreeMateTheme.green)
                    } else {
                        Picker("Account", selection: $mode) {
                            Text("Sign in").tag("login")
                            Text("Create account").tag("signup")
                        }
                        .pickerStyle(.segmented)
                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                        Button(mode == "login" ? "Sign in" : "Create account") { submit() }
                            .buttonStyle(.borderedProminent)
                            .tint(FreeMateTheme.green)
                        if !message.isEmpty {
                            Text(message).foregroundStyle(failed ? FreeMateTheme.red : FreeMateTheme.accent)
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        message = mode == "login" ? "Signing in..." : "Creating account..."
        failed = false
        let error = mode == "login"
            ? game.logIn(username: username, password: password)
            : game.signUp(username: username, password: password)
        if let error {
            if mode == "signup" && error == "That username is already taken." {
                message = error
            } else if mode == "signup" && (error.contains("Username") || error.contains("Password") || error.contains("Choose")) {
                message = error
            } else if mode == "signup" {
                message = error == "Something went wrong creating your account." ? error : error
            } else {
                message = error
            }
            failed = true
        } else {
            dismiss()
        }
    }
}
