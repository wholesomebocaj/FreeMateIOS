import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        FreeMateScreen(title: "FreeMate", largeTitle: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    hero
                    HStack(alignment: .top, spacing: Theme.Spacing.s) {
                        feature("square.grid.3x3.fill", Theme.accent, "Interactive", "Boards and guided lessons")
                        feature("figure.walk", Theme.success, "Beginner first", "Clear steps, calm pacing")
                        feature("chart.line.uptrend.xyaxis", Theme.topic("openings").color, "Always growing", "Lessons, openings, review")
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        SectionHeader(title: "What should I learn next?", subtitle: "Your path through the curriculum")
                        roadmap
                    }
                    if let next = game.nextBracket() {
                        Button {
                            game.openBracket(next.slug)
                        } label: {
                            Text("Continue \(next.title)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .primaryButtonStyle()
                        .controlSize(.large)
                    }
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Beginner chess coaching")
                .eyebrowStyle()
            Text("Learn chess the right way.")
                .font(.title.weight(.bold))
            Text("Free structured lessons, practice, and opening training for beginners who want a calm, clear path forward.")
                .font(.body)
                .foregroundStyle(.secondary)
            HStack(spacing: Theme.Spacing.s) {
                Button("Start Learning") { game.selectedTab = .lessons }
                    .primaryButtonStyle()
                Button("Explore Openings") { game.selectedTab = .openings }
                    .secondaryButtonStyle()
            }
            .font(.headline)
            .controlSize(.large)
            .padding(.top, Theme.Spacing.xxs)
        }
    }

    private func feature(_ symbol: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            IconTile(systemImage: symbol, color: color, size: 36)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: Theme.Spacing.s)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
    }

    private var roadmap: some View {
        let categories = game.courses.flatMap(\.categories)
        return VStack(spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                let lessons = category.skills.flatMap(\.lessons)
                let complete = !lessons.isEmpty && lessons.allSatisfy { game.completedLessons.contains($0.id) }
                let unlocked = lessons.contains { lesson in
                    game.lesson(id: lesson.id).map { game.isUnlocked($0) } ?? false
                }
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: complete ? "checkmark.circle.fill" : unlocked ? "circle.lefthalf.filled" : "lock.fill")
                        .foregroundStyle(complete ? Theme.success : unlocked ? Theme.accent : Color.secondary)
                        .frame(width: 24)
                    Text(category.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(complete || unlocked ? Color.primary : Color.secondary)
                    Spacer()
                    Text(complete ? "Done" : unlocked ? "Open" : "Locked")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Theme.Spacing.s)
                .accessibilityElement(children: .combine)
                if index < categories.count - 1 {
                    Divider().padding(.leading, 36)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .cardStyle(padding: Theme.Spacing.m)
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
                    let ids = game.bracketLessonIds(bracket)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            Text("Rating \(bracket.range)").eyebrowStyle()
                            Text(bracket.description)
                                .font(.body)
                            Text(bracket.learn.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(ids.filter { game.completedLessons.contains($0) }.count) of \(ids.count) lessons complete")
                                .font(.subheadline.weight(.semibold))
                                .padding(.top, Theme.Spacing.xxs)
                            ProgressMeter(value: game.bracketProgress(bracket))
                        }
                        .cardStyle()
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            SectionHeader(title: "In this bracket")
                            ForEach(bracket.items) { item in
                                bracketItem(item)
                            }
                        }
                    }
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func bracketItem(_ item: BracketItem) -> some View {
        let isPreview = item.kind == "preview"
        let progress = game.bracketItemProgress(item)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            StatusBadge(
                text: isPreview ? "Coming soon" : item.kind == "track" ? "Track" : "Course",
                systemImage: isPreview ? "clock" : "book.closed.fill",
                tint: isPreview ? Color.secondary : Theme.accent
            )
            Text(item.title)
                .font(.title3.weight(.bold))
            Text(item.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !isPreview {
                ProgressMeter(value: progress)
                    .padding(.top, Theme.Spacing.xxs)
            }
            if let courseId = item.courseId, !isPreview {
                Button(progress > 0 ? "Continue" : "Open") { game.openCourse(courseId) }
                    .primaryButtonStyle()
                    .padding(.top, Theme.Spacing.xxs)
            }
        }
        .cardStyle()
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
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            Text(course.description)
                                .font(.body)
                            Text("\(done) of \(lessons.count) lessons complete")
                                .font(.subheadline.weight(.semibold))
                            ProgressMeter(value: CurriculumLoader.courseProgress(course, completed: game.completedLessons))
                        }
                        .cardStyle()
                        if course.categories.isEmpty {
                            Text("This course is part of the FreeMate roadmap.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(course.categories) { category in
                                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                                    SectionHeader(title: category.title, subtitle: category.description)
                                    ForEach(category.skills) { skill in
                                        ForEach(skill.lessons) { lesson in
                                            lessonRow(course: course, lesson: lesson)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func lessonRow(course: Course, lesson: Lesson) -> some View {
        let unlocked = CurriculumLoader.isCourseLessonUnlocked(course, lessonId: lesson.id, completed: game.completedLessons)
        let done = game.completedLessons.contains(lesson.id)
        return Button {
            if unlocked { game.openLesson(lesson.id) }
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                IconTile(
                    systemImage: done ? "checkmark" : unlocked ? "play.fill" : "lock.fill",
                    color: done ? Theme.success : unlocked ? Theme.accent : Color.gray,
                    size: 40
                )
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("\(lesson.timeMinutes) min · \(lesson.ratingRange)")
                        .eyebrowStyle()
                    Text(lesson.title)
                        .font(.headline)
                        .foregroundStyle(unlocked ? Color.primary : Color.secondary)
                    Text(lesson.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    if unlocked && !done {
                        ProgressMeter(value: game.lessonProgressPercent(lesson))
                            .padding(.top, Theme.Spacing.xxs)
                    }
                }
                Spacer(minLength: 0)
                StatusBadge(
                    text: done ? "Review" : unlocked ? "Open" : "Locked",
                    tint: done ? Theme.success : unlocked ? Theme.accent : Color.secondary
                )
            }
            .cardStyle()
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!unlocked)
        .accessibilityElement(children: .combine)
    }
}

struct LessonPlayerView: View {
    @EnvironmentObject private var game: GameState
    let lessonId: String

    var body: some View {
        if let lesson = game.lesson(id: lessonId) ?? game.allLessons.first {
            LessonPlayerBody(lesson: lesson, game: game)
        } else {
            ContentUnavailableView("Lesson Not Found", systemImage: "book.closed")
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
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    if session.scaffold {
                        messageCard(symbol: "hammer.fill", color: Color.secondary, title: "Lesson Scaffold", body: "This lesson is ready for content. Add steps when you are ready to build it out.")
                    } else if session.finished {
                        messageCard(symbol: "checkmark.seal.fill", color: Theme.success, title: "Lesson Complete", body: "Great work. Continue to the next lesson.")
                    } else if let step = session.step {
                        stepView(step)
                    }
                    sidebar
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .animation(DesignMotion.spring, value: session.index)
        }
    }

    @ViewBuilder
    private func stepView(_ step: LessonStep) -> some View {
        let isDone = session.completedSteps.contains(session.index)
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("Step \(session.index + 1) of \(lesson.steps.count)")
                    .eyebrowStyle()
                Spacer()
                StatusBadge(
                    text: isDone ? "Completed" : "In Progress",
                    systemImage: isDone ? "checkmark" : nil,
                    tint: isDone ? Theme.success : Color.secondary
                )
            }
            CapsuleProgressBar(fraction: Double(session.index + 1) / Double(max(lesson.steps.count, 1)), tint: Theme.accent)
        }
        Text(step.title)
            .font(.title2.weight(.bold))
        if !step.body.isEmpty {
            Text(step.body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        if step.type == "checklist" {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(step.tasks, id: \.self) { task in
                    Label(task, systemImage: "checkmark.circle")
                        .font(.body)
                }
            }
            .cardStyle()
        }
        if let board = session.board {
            ModernBoardView(board: board)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            Text(note(for: step))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if step.type == "click-all-squares" {
                Text("\(session.foundSquares.count) of \(step.targetSquares.count) squares found")
                    .font(.footnote.weight(.semibold).monospacedDigit())
            }
        }
        if step.type == "multiple-choice" {
            Text(step.question ?? "Choose the best response.")
                .font(.headline)
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(step.choices) { choice in
                    Button {
                        session.choose(choice)
                    } label: {
                        Text(choice.label)
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryButtonStyle()
                    .controlSize(.large)
                }
            }
        }
        if !session.feedback.isEmpty {
            let isError = session.feedbackKind == "error"
            Label(session.feedback, systemImage: isError ? "lightbulb.fill" : "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isError ? Theme.warning : Theme.success)
                .padding(Theme.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((isError ? Theme.warning : Theme.success).opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .transition(.opacity)
        }
        HStack(spacing: Theme.Spacing.s) {
            if session.index > 0 {
                Button {
                    session.goBack()
                } label: {
                    Text("Back").frame(maxWidth: .infinity)
                }
                .secondaryButtonStyle()
            }
            Button {
                session.goForward()
            } label: {
                Text(session.nextTitle).frame(maxWidth: .infinity)
            }
            .primaryButtonStyle()
            .disabled(!session.canAdvance)
        }
        .font(.headline)
        .controlSize(.large)
    }

    private func messageCard(symbol: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            IconTile(systemImage: symbol, color: color, size: 44)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var sidebar: some View {
        let course = game.courses.first { CurriculumLoader.courseLessons($0).contains { $0.id == lesson.id } }
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let course {
                SectionHeader(title: course.title)
                    .padding(.top, Theme.Spacing.s)
                VStack(spacing: 0) {
                    let lessons = CurriculumLoader.courseLessons(course)
                    ForEach(Array(lessons.enumerated()), id: \.element.id) { index, item in
                        let unlocked = CurriculumLoader.isCourseLessonUnlocked(course, lessonId: item.id, completed: game.completedLessons)
                        let done = game.completedLessons.contains(item.id)
                        let isCurrent = item.id == lesson.id
                        Button {
                            if unlocked || isCurrent { game.openLesson(item.id) }
                        } label: {
                            HStack(spacing: Theme.Spacing.s) {
                                Image(systemName: done ? "checkmark.circle.fill" : isCurrent ? "play.circle.fill" : unlocked ? "circle" : "lock.fill")
                                    .foregroundStyle(done ? Theme.success : isCurrent ? Theme.accent : Color.secondary)
                                    .frame(width: 24)
                                Text(item.title)
                                    .font(.body.weight(isCurrent ? .semibold : .regular))
                                    .foregroundStyle(unlocked || isCurrent ? Color.primary : Color.secondary)
                                Spacer()
                                Text(done ? "Done" : isCurrent ? "Current" : unlocked ? "Open" : "Locked")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, Theme.Spacing.s)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!unlocked && !isCurrent)
                        if index < lessons.count - 1 {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .cardStyle(padding: Theme.Spacing.m)
            }
        }
    }

    private func note(for step: LessonStep) -> String {
        switch step.type {
        case "click-all-squares": return "Complete every highlighted square to unlock the next step."
        case "square-click": return "Tap the target square to continue."
        case "board-task", "move-task", "capture-task", "tactic-task": return "Make the correct board action to continue."
        case "board-demo": return "Study the board, then continue when you are ready."
        default: return "Complete the interaction to continue."
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
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            HStack(spacing: Theme.Spacing.s) {
                                SideTile(isWhite: opening.side == "White")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(opening.eco) · \(opening.difficulty) · \(opening.side)").eyebrowStyle()
                                    Text(opening.name).font(.title2.weight(.bold))
                                }
                            }
                            Text(opening.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Button {
                                game.openTrainer(id: opening.id, line: nil)
                            } label: {
                                Label("Train This Repertoire", systemImage: "play.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .primaryButtonStyle()
                            .controlSize(.large)
                            .padding(.top, Theme.Spacing.xxs)
                        }
                        bulletSection("Ideas to Remember", items: opening.ideas, symbol: "lightbulb.fill", color: Theme.accent)
                        bulletSection("Common Mistakes", items: opening.commonMistakes, symbol: "exclamationmark.triangle.fill", color: Theme.warning)
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            SectionHeader(title: "Main Training Path")
                            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                                ForEach(Array(opening.mainMoves.enumerated()), id: \.offset) { index, move in
                                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                                        Text("\(index + 1). \(move.san)")
                                            .font(.headline.monospaced())
                                            .frame(minWidth: 72, alignment: .leading)
                                        Text(move.explanation)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .cardStyle()
                        }
                        Text("Lichess explorer stats stay on the web service. This build trains from the local FreeMate lines.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func bulletSection(_ title: String, items: [String], symbol: String, color: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: title)
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(items, id: \.self) { item in
                        Label {
                            Text(item).font(.subheadline)
                        } icon: {
                            Image(systemName: symbol).foregroundStyle(color)
                        }
                    }
                }
                .cardStyle()
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
            ContentUnavailableView("Opening Not Found", systemImage: "questionmark.square.dashed")
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
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            Text(trainer.kicker).eyebrowStyle()
                            Spacer()
                            StatusBadge(text: trainer.status, tint: trainer.statusDone ? Theme.success : Color.secondary)
                        }
                        Text(trainer.prompt)
                            .font(.title3.weight(.bold))
                    }
                    ModernBoardView(board: trainer.board)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(trainer.noteTitle)
                            .font(.headline)
                        Text(trainer.explanation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !trainer.feedback.isEmpty {
                            Text(trainer.feedback)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(trainer.feedbackKind == "error" ? Theme.warning : trainer.feedbackKind == "success" ? Theme.success : Color.secondary)
                        }
                    }
                    .cardStyle()
                    HStack(spacing: Theme.Spacing.s) {
                        Button {
                            trainer.jump(to: trainer.moveIndex - 1)
                        } label: {
                            Label("Previous", systemImage: "chevron.left").frame(maxWidth: .infinity)
                        }
                        Button {
                            trainer.jump(to: trainer.moveIndex + 1)
                        } label: {
                            Label("Next", systemImage: "chevron.right").frame(maxWidth: .infinity)
                        }
                    }
                    .secondaryButtonStyle()
                    .controlSize(.large)
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        SectionHeader(title: "Lines")
                        ForEach(trainer.lines) { line in
                            lineCard(line)
                        }
                    }
                    ideaList("Ideas", items: trainer.opening.ideas, symbol: "lightbulb.fill", color: Theme.accent)
                    ideaList("Common Mistakes", items: trainer.opening.commonMistakes, symbol: "exclamationmark.triangle.fill", color: Theme.warning)
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func lineCard(_ line: TrainingLine) -> some View {
        let isActive = line.id == trainer.activeLine.id
        let isComplete = trainer.completions[line.id]?.completed == true
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button {
                trainer.loadBranch(line)
            } label: {
                HStack {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : isActive ? "play.circle.fill" : "circle")
                        .foregroundStyle(isComplete ? Theme.success : isActive ? Theme.accent : Color.secondary)
                    Text(line.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isActive ? Theme.accent : Color.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            ProgressMeter(value: trainer.lineProgress(line))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(line.moves.enumerated()), id: \.offset) { index, move in
                        let state = trainer.moveState(line: line, index: index)
                        Button {
                            if line.id != trainer.activeLine.id { trainer.loadBranch(line) }
                            trainer.jump(to: index)
                        } label: {
                            Text(trainer.moveLabel(move, index: index))
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .foregroundStyle(state == "active" ? Color.white : Color.primary)
                                .background(
                                    state == "active" ? Theme.accent : state == "done" ? Theme.success.opacity(0.18) : Theme.fill,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func ideaList(_ title: String, items: [String], symbol: String, color: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: title)
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(items, id: \.self) { item in
                        Label {
                            Text(item).font(.subheadline)
                        } icon: {
                            Image(systemName: symbol).foregroundStyle(color)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }
}

struct ReviewView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        let queue = game.hydratedQueue()
        FreeMateScreen(title: "Review", largeTitle: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    if queue.isEmpty {
                        VStack(spacing: Theme.Spacing.m) {
                            IconTile(systemImage: "checkmark", color: Theme.success, size: 56)
                            Text("Nothing due")
                                .font(.title2.weight(.bold))
                            Text("Missed lesson tasks and opening branches appear here automatically.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            HStack(spacing: Theme.Spacing.s) {
                                Button("Continue Lessons") { game.selectedTab = .lessons }
                                    .primaryButtonStyle()
                                Button("Train Openings") { game.selectedTab = .openings }
                                    .secondaryButtonStyle()
                            }
                            .font(.headline)
                            .controlSize(.large)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.l)
                        .cardStyle()
                    } else {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("\(queue.count) item\(queue.count == 1 ? "" : "s") ready")
                                .font(.headline)
                            ProgressMeter(value: min(100, queue.count * 18), tint: Theme.warning)
                        }
                        .cardStyle()
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            SectionHeader(title: "Due Now")
                            ForEach(queue, id: \.key) { item in
                                reviewCard(item)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func reviewCard(_ item: ReviewItem) -> some View {
        let isOpening = item.type == "opening"
        return HStack(alignment: .top, spacing: Theme.Spacing.s) {
            IconTile(
                systemImage: isOpening ? "arrow.triangle.branch" : "book.fill",
                color: isOpening ? Theme.topic("openings").color : Theme.accent,
                size: 44
            )
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("\(isOpening ? "Opening branch" : "Lesson") · \(game.reviewLabel(item))")
                    .eyebrowStyle()
                Text(item.title)
                    .font(.headline)
                Text(item.subtitle.isEmpty ? "Practice this once, then move on." : item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(item.failures) miss\(item.failures == 1 ? "" : "es") · \(item.successStreak) correct in a row")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Review") { open(item) }
                    .primaryButtonStyle()
                    .controlSize(.small)
                    .padding(.top, Theme.Spacing.xxs)
            }
            Spacer(minLength: 0)
            StatusBadge(text: item.state.capitalized, tint: Theme.warning)
        }
        .cardStyle()
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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if let user = game.currentUser {
                        HStack(spacing: Theme.Spacing.s) {
                            IconTile(systemImage: "person.fill", color: Theme.accent, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Signed in as").eyebrowStyle()
                                Text(user.displayName).font(.title3.weight(.bold))
                            }
                        }
                        .cardStyle()
                        Button(role: .destructive) {
                            game.logOut()
                            dismiss()
                        } label: {
                            Text("Log Out").frame(maxWidth: .infinity)
                        }
                        .secondaryButtonStyle(tint: Theme.danger)
                        .controlSize(.large)
                    } else {
                        Text("Learning never needs an account. Sign in only to keep a named profile on this device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Account", selection: $mode) {
                            Text("Sign In").tag("login")
                            Text("Create Account").tag("signup")
                        }
                        .pickerStyle(.segmented)
                        VStack(spacing: Theme.Spacing.xs) {
                            TextField("Username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .padding(Theme.Spacing.s)
                                .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                            SecureField("Password", text: $password)
                                .textContentType(mode == "login" ? .password : .newPassword)
                                .padding(Theme.Spacing.s)
                                .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                        }
                        Button {
                            submit()
                        } label: {
                            Text(mode == "login" ? "Sign In" : "Create Account")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .primaryButtonStyle()
                        .controlSize(.large)
                        if !message.isEmpty {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(failed ? Theme.danger : Color.secondary)
                        }
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .themeBackground()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
    }

    private func submit() {
        message = mode == "login" ? "Signing in..." : "Creating account..."
        failed = false
        let error = mode == "login"
            ? game.logIn(username: username, password: password)
            : game.signUp(username: username, password: password)
        if let error {
            message = error
            failed = true
        } else {
            dismiss()
        }
    }
}
