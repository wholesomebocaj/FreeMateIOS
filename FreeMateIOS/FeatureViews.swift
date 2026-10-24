import SwiftUI

struct BracketDetailView: View {
    @EnvironmentObject private var game: GameState
    let bracketId: String

    var body: some View {
        let bracket = game.bracket(id: bracketId)
        List {
            if let bracket {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text(bracket.description)
                        ProgressView(value: Double(game.bracketProgress(bracket)), total: 100)
                            .tint(Theme.accent)
                    }
                    .padding(.vertical, Theme.Spacing.xxs)
                } footer: {
                    Text("Rating \(bracket.range)")
                }
                Section("Courses") {
                    ForEach(bracket.items) { item in
                        if let courseId = item.courseId, item.kind != "preview" {
                            NavigationLink(value: LessonRoute.course(courseId)) {
                                bracketRow(item)
                            }
                        } else {
                            bracketRow(item)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(bracket?.title ?? "Level")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bracketRow(_ item: BracketItem) -> some View {
        let isPreview = item.kind == "preview"
        return VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
            Text(isPreview ? "Coming soon" : "\(game.bracketItemProgress(item))% complete")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct CourseDetailView: View {
    @EnvironmentObject private var game: GameState
    let courseId: String

    var body: some View {
        let course = game.courses.first { $0.id == courseId } ?? game.courses.first
        List {
            if let course {
                let lessons = CurriculumLoader.courseLessons(course)
                let done = lessons.filter { game.completedLessons.contains($0.id) }.count
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text(course.description)
                        ProgressView(value: Double(done), total: Double(max(lessons.count, 1)))
                            .tint(done == lessons.count ? Theme.success : Theme.accent)
                    }
                    .padding(.vertical, Theme.Spacing.xxs)
                } footer: {
                    Text("\(done) of \(lessons.count) lessons complete")
                }
                ForEach(course.categories) { category in
                    Section(course.categories.count > 1 ? category.title : "Lessons") {
                        ForEach(category.skills.flatMap(\.lessons)) { lesson in
                            lessonRow(course: course, lesson: lesson, number: (lessons.firstIndex { $0.id == lesson.id } ?? 0) + 1)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(course?.title ?? "Course")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func lessonRow(course: Course, lesson: Lesson, number: Int) -> some View {
        let unlocked = CurriculumLoader.isCourseLessonUnlocked(course, lessonId: lesson.id, completed: game.completedLessons)
        let done = game.completedLessons.contains(lesson.id)
        let row = HStack(spacing: Theme.Spacing.s) {
            ZStack {
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.success)
                } else if unlocked {
                    Text("\(number)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28, height: 28)
                        .background(Theme.accent.opacity(0.14), in: Circle())
                } else {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(lesson.title)
                    .foregroundStyle(unlocked ? .primary : .secondary)
                Text(lesson.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.xs)
            Text("\(lesson.timeMinutes) min")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Completed" : unlocked ? "" : "Locked")
        if unlocked {
            NavigationLink(value: LessonRoute.lesson(lesson.id)) { row }
        } else {
            row
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if session.scaffold {
                    message(symbol: "hammer.fill", color: .secondary, title: "Coming Soon", body: "This lesson does not have steps yet.")
                } else if session.finished {
                    message(symbol: "checkmark.seal.fill", color: Theme.success, title: "Lesson Complete", body: "Nice work. It will come back for a quick review tomorrow.")
                } else if let step = session.step {
                    stepView(step)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .focusedScreen()
        .safeAreaInset(edge: .top, spacing: 0) {
            if !session.scaffold && !session.finished && !lesson.steps.isEmpty {
                ProgressView(value: Double(session.index + 1), total: Double(lesson.steps.count))
                    .tint(Theme.accent)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.xs)
                    .accessibilityLabel("Step \(session.index + 1) of \(lesson.steps.count)")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session.step != nil && !session.scaffold && !session.finished {
                stepControls
            } else if session.finished, let next = game.nextLesson(), next.id != lesson.id {
                bottomBar {
                    Button {
                        game.lessonPath.removeLast()
                        game.openLesson(next.id)
                    } label: {
                        Text("Next Lesson: \(next.title)")
                            .font(.headline)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .animation(DesignMotion.spring, value: session.index)
    }

    private var stepControls: some View {
        bottomBar {
            if session.index > 0 {
                Button {
                    session.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 24)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Back")
            }
            Button {
                session.goForward()
            } label: {
                Text(session.nextTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!session.canAdvance)
        }
    }

    private func bottomBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            content()
        }
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func stepView(_ step: LessonStep) -> some View {
        Text(step.title)
            .font(.title2.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
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
    }

    private func message(symbol: String, color: Color, title: String, body: String) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: symbol)
                .font(.system(size: 52))
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: session.finished)
            Text(title)
                .font(.title2.weight(.bold))
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
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
        List {
            if let opening {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        HStack(spacing: Theme.Spacing.m) {
                            SideTile(isWhite: opening.side == "White", size: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(opening.name)
                                    .font(.title2.weight(.bold))
                                Text("\(opening.eco) · \(opening.difficulty) · \(opening.side)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(opening.description)
                            .foregroundStyle(.secondary)
                        Button {
                            game.openTrainer(id: opening.id, line: nil)
                        } label: {
                            Label("Start Training", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
                if !opening.mainMoves.isEmpty {
                    Section("Main Line") {
                        ForEach(Array(opening.mainMoves.enumerated()), id: \.offset) { index, move in
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                                Text(index % 2 == 0 ? "\(index / 2 + 1). \(move.san)" : "\(index / 2 + 1)… \(move.san)")
                                    .font(.body.monospaced().weight(.semibold))
                                    .frame(width: 84, alignment: .leading)
                                Text(move.explanation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                bulletSection("Ideas", opening.ideas)
                bulletSection("Common Mistakes", opening.commonMistakes)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(opening?.name ?? "Opening")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func bulletSection(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
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
            ContentUnavailableView("Opening Not Found", systemImage: "questionmark.square.dashed")
        }
    }
}

struct OpeningTrainerBody: View {
    @StateObject private var trainer: OpeningTrainer
    @State private var showsLines = false

    init(opening: OpeningCourse, game: GameState, lineId: String?) {
        _trainer = StateObject(wrappedValue: OpeningTrainer(opening: opening, game: game, requestedLineId: lineId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trainer.kicker)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(trainer.prompt)
                        .font(.title2.weight(.bold))
                        .contentTransition(.opacity)
                }
                ModernBoardView(board: trainer.board)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trainer.noteTitle)
                        .font(.headline)
                    Text(trainer.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !trainer.feedback.isEmpty {
                        Label(trainer.feedback, systemImage: trainer.feedbackKind == "error" ? "lightbulb.fill" : "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(trainer.feedbackKind == "error" ? Theme.warning : Theme.success)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle(trainer.opening.name)
        .navigationBarTitleDisplayMode(.inline)
        .focusedScreen()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsLines = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("Lines")
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    trainer.jump(to: trainer.moveIndex - 1)
                } label: {
                    Label("Previous Move", systemImage: "chevron.backward")
                }
                .disabled(trainer.moveIndex <= 0)
                Spacer()
                Text(trainer.status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(trainer.statusDone ? Theme.success : .secondary)
                Spacer()
                Button {
                    trainer.jump(to: trainer.moveIndex + 1)
                } label: {
                    Label("Next Move", systemImage: "chevron.forward")
                }
            }
        }
        .sheet(isPresented: $showsLines) {
            linesSheet
                .presentationDetents([.medium, .large])
        }
    }

    private var linesSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(trainer.lines) { line in
                        lineRow(line)
                    }
                }
                if !trainer.opening.ideas.isEmpty {
                    Section("Ideas") {
                        ForEach(trainer.opening.ideas, id: \.self) { Text($0).font(.subheadline) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Lines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsLines = false }
                }
            }
        }
    }

    private func lineRow(_ line: TrainingLine) -> some View {
        let isActive = line.id == trainer.activeLine.id
        let isComplete = trainer.completions[line.id]?.completed == true
        return Button {
            trainer.loadBranch(line)
            showsLines = false
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : isActive ? "play.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isComplete ? Theme.success : isActive ? Theme.accent : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.title)
                        .foregroundStyle(.primary)
                    Text("\(line.moves.count) moves · \(trainer.lineProgress(line))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ReviewView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        let queue = game.reviewQueue()
        let upcoming = game.upcomingReviews()
        List {
            if !queue.isEmpty {
                Section("Due Now") {
                    ForEach(queue) { item in
                        Button {
                            open(item)
                        } label: {
                            dueRow(item)
                        }
                    }
                }
            } else if !upcoming.isEmpty {
                Section {
                    HStack(spacing: Theme.Spacing.s) {
                        IconTile(systemImage: "checkmark", color: Theme.success, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All caught up")
                            Text("Nothing is due right now.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming.prefix(20)) { item in
                        upcomingRow(item)
                    }
                } header: {
                    Text("Coming Up")
                } footer: {
                    Text("Reviews come back after 1, 3, 7, and 14 days. Miss one and it starts over.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if queue.isEmpty && upcoming.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to Review", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Finish a lesson or an opening line, and it comes back here to review.")
                } actions: {
                    Button("Start a Lesson") { game.selectedTab = .lessons }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .navigationTitle("Review")
    }

    private func dueRow(_ item: ReviewItem) -> some View {
        let isOpening = item.kind == .opening
        return HStack(spacing: Theme.Spacing.s) {
            IconTile(
                systemImage: isOpening ? "arrow.triangle.branch" : "book.fill",
                color: isOpening ? Theme.topic("openings").color : Theme.accent,
                size: 32
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .foregroundStyle(.primary)
                Text(game.reviewLabel(item))
                    .font(.subheadline)
                    .foregroundStyle(item.state == .shaky ? Theme.warning : .secondary)
            }
            Spacer(minLength: Theme.Spacing.xs)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func upcomingRow(_ item: ReviewItem) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .lineLimit(1)
                StageDots(stage: item.stage)
            }
            Spacer(minLength: Theme.Spacing.xs)
            if let due = item.dueAt {
                Text(due.formatted(.relative(presentation: .named)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func open(_ item: ReviewItem) {
        switch item.kind {
        case .opening: game.openTrainer(id: item.itemId, line: item.branchId)
        case .lesson: game.openLesson(item.itemId)
        }
    }
}

/// Where an item is on the 1, 3, 7, and 14 day ladder.
struct StageDots: View {
    var stage: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReviewSchedule.intervals.indices, id: \.self) { index in
                Capsule()
                    .fill(index < stage ? Theme.success : Theme.fill)
                    .frame(width: 18, height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(min(stage, ReviewSchedule.intervals.count)) of \(ReviewSchedule.intervals.count) check-ins passed")
    }
}
