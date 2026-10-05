import Foundation

struct HighlightMark: Equatable, Identifiable {
    var square: String
    var className: String
    var id: String { "\(square)-\(className)" }
}

struct LessonChoice: Equatable, Identifiable {
    var label: String
    var value: String
    var id: String { value + label }
}

struct LessonStep: Equatable, Identifiable {
    var type: String
    var title: String
    var body: String
    var fen: String?
    var question: String?
    var choices: [LessonChoice]
    var correctChoice: String?
    var targetSquare: String?
    var targetSquares: [String]
    var startSquare: String?
    var highlightSquares: [HighlightMark]
    var allowedMoves: [String]
    var solutionMoves: [String]
    var lockToAllowedMoves: Bool?
    var successText: String?
    var errorText: String?
    var tasks: [String]
    var board: Bool
    var orientation: String?
    var mode: String?
    var showCoordinates: Bool?
    var enableSounds: Bool?
    var completeOnSuccess: Bool?
    var objective: String?
    var endpoint: String?
    var placeholder: String?
    var id: String { "\(type)|\(title)|\(fen ?? "")|\(question ?? "")" }
}

struct Lesson: Equatable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var steps: [LessonStep]
    var difficulty: String
    var timeMinutes: Int
    var ratingRange: String
    var locked: Bool
    var order: Int
    var topic: String
    var bracketName: String
    var coachIntro: String?
    var courseId: String = ""
    var categoryTitle: String = ""
    var categoryId: String = ""
    var skillTitle: String = ""
    var skillId: String = ""
}

struct CourseSkill: Equatable, Identifiable {
    var id: String
    var title: String
    var lessons: [Lesson]
}

struct CourseCategory: Equatable, Identifiable {
    var id: String
    var title: String
    var description: String
    var skills: [CourseSkill]
}

struct Course: Equatable, Identifiable {
    var id: String
    var title: String
    var description: String
    var difficulty: String
    var bracketName: String
    var order: Int
    var categories: [CourseCategory]
}

struct BracketItem: Equatable, Identifiable {
    var id: String
    var kind: String
    var courseId: String?
    var title: String
    var description: String
    var href: String
    var lessonIds: [String]
}

struct SkillBracket: Equatable, Identifiable {
    var id: String
    var slug: String
    var title: String
    var range: String
    var description: String
    var learn: [String]
    var items: [BracketItem]
}

struct OpeningMove: Equatable, Identifiable {
    var uci: String
    var san: String
    var title: String
    var explanation: String
    var lineIndex: Int
    var id: String { "\(lineIndex)-\(uci)" }

    var asLineMove: OpeningLineMove {
        OpeningLineMove(uci: uci, san: san, title: title, explanation: explanation)
    }
}

struct TrainingLine: Equatable, Identifiable {
    var id: String
    var title: String
    var description: String
    var hints: [String]
    var coachingNotes: [String]
    var completionMessage: String?
    var sectionId: String
    var sectionTitle: String
    var isMainLine: Bool
    var moves: [OpeningMove]
}

struct OpeningTraining: Equatable {
    var mode: String
    var startingFen: String
    var sideToTrain: String
}

struct OpeningCourse: Equatable, Identifiable {
    var id: String
    var name: String
    var eco: String
    var difficulty: String
    var side: String
    var description: String
    var ideas: [String]
    var commonMistakes: [String]
    var training: OpeningTraining
    var lines: [TrainingLine]
    var mainMoves: [OpeningMove]
    var sectionCount: Int

    var moveCount: Int { mainMoves.count }
}

struct CourseLibraryMeta: Equatable, Identifiable {
    var id: String { course.id }
    var course: Course
    var bracket: SkillBracket?
    var bracketLabel: String
    var bracketRange: String
    var topic: String
    var color: String
    var type: String
    var status: String
    var statusLabel: String
    var progress: Int
    var lessonCount: Int
    var estimatedMinutes: Int
    var nextLesson: Lesson?
}

enum CourseLibrarySort: String, CaseIterable, Identifiable {
    case recommended, progress, title, level, time
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recommended: return "Recommended"
        case .progress: return "Progress"
        case .title: return "Title"
        case .level: return "Level"
        case .time: return "Time"
        }
    }
}

enum CurriculumLoader {
    static let courseFolderOrder = [
        "beginner-fundamentals": 1,
        "beginner-opening-principles": 2,
        "beginner-tactics": 3,
        "beginner-endgames": 4,
        "beginner-practical-play": 5,
    ]
    static let courseBracketDefaults = [
        "beginner-fundamentals": "Beginner",
        "beginner-endgames": "Beginner",
        "beginner-opening-principles": "Beginner+",
        "beginner-tactics": "Beginner+",
        "beginner-practical-play": "Beginner+",
    ]
    static let categoryTitles = [
        "beginner-fundamentals": "Fundamentals",
        "beginner-opening-principles": "Opening Principles",
        "beginner-tactics": "Tactics",
        "beginner-endgames": "Endgames",
        "beginner-practical-play": "Practical Play",
    ]

    static func loadBundled() -> (courses: [Course], brackets: [SkillBracket], openings: [OpeningCourse]) {
        guard let data = catalogData() else { return ([], [], []) }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([], [], [])
        }
        let folders = (root["courseFolders"] as? [[String: Any]] ?? []).map(parseFolder)
        let courses = buildCourses(from: folders)
        let rawBrackets = (root["brackets"] as? [[String: Any]] ?? []).map(parseBracket)
        let brackets = hydrateBrackets(rawBrackets, courses: courses)
        let openings = (root["openings"] as? [[String: Any]] ?? []).compactMap { entry -> OpeningCourse? in
            guard let opening = entry["opening"] as? [String: Any] else { return nil }
            return parseOpening(opening)
        }
        return (courses, brackets, openings)
    }

    private static func catalogData() -> Data? {
        let bundleCandidates = [
            Bundle.main.url(forResource: "FreeMateCatalog", withExtension: "json"),
            Bundle.main.url(forResource: "FreeMateCatalog", withExtension: "json", subdirectory: "Resources"),
        ]
        for url in bundleCandidates.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url) { return data }
        }
        let file = URL(fileURLWithPath: "/workspace/FreeMateIOS/Resources/FreeMateCatalog.json")
        return try? Data(contentsOf: file)
    }

    private static func buildCourses(from folders: [(name: String, files: [(name: String, lesson: [String: Any])])]) -> [Course] {
        let sorted = folders.sorted {
            let left = courseFolderOrder[$0.name] ?? 999
            let right = courseFolderOrder[$1.name] ?? 999
            if left != right { return left < right }
            return $0.name < $1.name
        }
        return sorted.compactMap { folder in
            let lessons = folder.files.map { normalizeLesson($0.lesson, courseId: folder.name, fileName: $0.name) }
            if lessons.isEmpty { return nil }
            return buildCourse(id: folder.name, lessons: lessons)
        }
    }

    private static func normalizeLesson(_ raw: [String: Any], courseId: String, fileName: String) -> Lesson {
        let stem = fileName.replacingOccurrences(of: ".json", with: "")
        let fallbackId = stem.split(separator: "_", maxSplits: 1).last.map(String.init) ?? stem
        let id = string(raw["id"]) ?? fallbackId
        let bracket = string(raw["bracket"]) ?? courseBracketDefaults[courseId] ?? "Beginner"
        let order = int(raw["order"]) ?? orderFromFile(fileName)
        return Lesson(
            id: id,
            title: string(raw["title"]) ?? humanize(id),
            summary: string(raw["summary"]) ?? "Starter lesson scaffold.",
            steps: (raw["steps"] as? [Any] ?? []).compactMap { parseStep($0) },
            difficulty: string(raw["difficulty"]) ?? bracket,
            timeMinutes: int(raw["timeMinutes"]) ?? 5,
            ratingRange: string(raw["ratingRange"]) ?? ratingRange(bracket),
            locked: bool(raw["locked"]),
            order: order,
            topic: string(raw["topic"]) ?? "fundamentals",
            bracketName: bracket,
            coachIntro: string(raw["coachIntro"])
        )
    }

    private static func buildCourse(id: String, lessons: [Lesson]) -> Course {
        let sorted = lessons.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.title < $1.title
        }
        let title = humanize(id)
        let description = sorted.first?.summary ?? "\(title) lesson set."
        let bracket = sorted.first?.bracketName ?? courseBracketDefaults[id] ?? "Beginner"
        let skills = sorted.map { lesson in
            CourseSkill(id: lesson.id, title: lesson.title, lessons: [lesson])
        }
        let category = CourseCategory(
            id: "\(id)-lessons",
            title: categoryTitles[id] ?? "Lessons",
            description: description,
            skills: skills
        )
        return Course(
            id: id,
            title: title,
            description: description,
            difficulty: bracket,
            bracketName: bracket,
            order: courseFolderOrder[id] ?? sorted.first?.order ?? 999,
            categories: [category]
        )
    }

    static func courseLessons(_ course: Course?) -> [Lesson] {
        guard let course else { return [] }
        return course.categories.flatMap { category in
            category.skills.flatMap { skill in
                skill.lessons.map { lesson in
                    var copy = lesson
                    copy.courseId = course.id
                    copy.categoryTitle = category.title
                    copy.categoryId = category.id
                    copy.skillTitle = skill.title
                    copy.skillId = skill.id
                    return copy
                }
            }
        }
    }

    static func isCourseLessonUnlocked(_ course: Course, lessonId: String, completed: Set<String>) -> Bool {
        let lessons = courseLessons(course)
        guard let index = lessons.firstIndex(where: { $0.id == lessonId }) else { return false }
        let lesson = lessons[index]
        if !lesson.locked || index == 0 { return true }
        let previous = index > 0 ? lessons[index - 1].id : nil
        return previous.map { completed.contains($0) } ?? false
    }

    static func lessonStateLabel(_ course: Course, lessonId: String, completed: Set<String>) -> String {
        let lessons = courseLessons(course)
        guard lessons.contains(where: { $0.id == lessonId }) else { return "Open" }
        if completed.contains(lessonId) { return "Done" }
        return isCourseLessonUnlocked(course, lessonId: lessonId, completed: completed) ? "Open" : "Locked"
    }

    static func courseProgress(_ course: Course, completed: Set<String>) -> Int {
        let lessons = courseLessons(course)
        if lessons.isEmpty { return 0 }
        let done = lessons.filter { completed.contains($0.id) }.count
        return Int((Double(done) / Double(lessons.count) * 100).rounded())
    }

    static func nextUnlockedLesson(_ course: Course, completed: Set<String>) -> Lesson? {
        let lessons = courseLessons(course)
        return lessons.first { isCourseLessonUnlocked(course, lessonId: $0.id, completed: completed) && !completed.contains($0.id) }
            ?? lessons.first
    }

    private static func parseStep(_ any: Any) -> LessonStep? {
        guard let raw = any as? [String: Any] else { return nil }
        let highlights = parseHighlights(raw["highlightSquares"] ?? raw["highlights"])
        return LessonStep(
            type: string(raw["type"]) ?? "explain",
            title: string(raw["title"]) ?? "",
            body: string(raw["body"]) ?? "",
            fen: string(raw["fen"]),
            question: string(raw["question"]),
            choices: parseChoices(raw["choices"]),
            correctChoice: string(raw["correctChoice"]) ?? string(raw["correctAnswer"]) ?? string(raw["answer"]),
            targetSquare: string(raw["targetSquare"]),
            targetSquares: (raw["targetSquares"] as? [Any] ?? []).compactMap { string($0) },
            startSquare: string(raw["startSquare"]),
            highlightSquares: highlights,
            allowedMoves: (raw["allowedMoves"] as? [Any] ?? []).compactMap { string($0) },
            solutionMoves: (raw["solutionMoves"] as? [Any] ?? []).compactMap { string($0) },
            lockToAllowedMoves: raw["lockToAllowedMoves"] as? Bool,
            successText: string(raw["successText"]),
            errorText: string(raw["errorText"]),
            tasks: (raw["tasks"] as? [Any] ?? []).compactMap { string($0) },
            board: bool(raw["board"]),
            orientation: string(raw["orientation"]),
            mode: string(raw["mode"]),
            showCoordinates: raw["showCoordinates"] as? Bool,
            enableSounds: raw["enableSounds"] as? Bool,
            completeOnSuccess: raw["completeOnSuccess"] as? Bool,
            objective: string(raw["objective"]),
            endpoint: string(raw["endpoint"]),
            placeholder: string(raw["placeholder"])
        )
    }

    private static func parseHighlights(_ any: Any?) -> [HighlightMark] {
        guard let any else { return [] }
        if let text = any as? String { return [HighlightMark(square: text, className: "focus")] }
        if let list = any as? [Any] {
            return list.flatMap { entry -> [HighlightMark] in
                if let text = entry as? String { return [HighlightMark(square: text, className: "focus")] }
                if let object = entry as? [String: Any], let square = string(object["square"]) {
                    return [HighlightMark(square: square, className: string(object["className"]) ?? "focus")]
                }
                if let nested = entry as? [Any] { return parseHighlights(nested) }
                return []
            }
        }
        return []
    }

    private static func parseChoices(_ any: Any?) -> [LessonChoice] {
        (any as? [Any] ?? []).compactMap { entry in
            if let text = entry as? String { return LessonChoice(label: text, value: text) }
            if let object = entry as? [String: Any] {
                let value = string(object["value"]) ?? string(object["label"]) ?? ""
                let label = string(object["label"]) ?? value
                return LessonChoice(label: label, value: value)
            }
            return nil
        }
    }

    private static func parseBracket(_ raw: [String: Any]) -> SkillBracket {
        let id = string(raw["id"]) ?? string(raw["slug"]) ?? "bracket"
        let items = (raw["items"] as? [[String: Any]] ?? []).map { item in
            BracketItem(
                id: string(item["id"]) ?? UUID().uuidString,
                kind: string(item["kind"]) ?? "course",
                courseId: string(item["courseId"]),
                title: string(item["title"]) ?? "Course",
                description: string(item["description"]) ?? "",
                href: string(item["href"]) ?? "",
                lessonIds: (item["lessonIds"] as? [Any] ?? []).compactMap { string($0) }
            )
        }
        return SkillBracket(
            id: id,
            slug: string(raw["slug"]) ?? id,
            title: string(raw["title"]) ?? humanize(id),
            range: string(raw["range"]) ?? "",
            description: string(raw["description"]) ?? "",
            learn: (raw["learn"] as? [Any] ?? []).compactMap { string($0) },
            items: items
        )
    }

    static func hydrateBrackets(_ brackets: [SkillBracket], courses: [Course]) -> [SkillBracket] {
        brackets.map { bracket in
            var copy = bracket
            copy.items = bracket.items.map { item in
                var next = item
                if next.href.isEmpty, let courseId = next.courseId {
                    next.href = "/courses/\(courseId)"
                }
                if next.lessonIds.isEmpty, let courseId = next.courseId, let course = courses.first(where: { $0.id == courseId }) {
                    next.lessonIds = courseLessons(course).map(\.id)
                }
                return next
            }
            return copy
        }
    }

    private static func parseOpening(_ raw: [String: Any]) -> OpeningCourse {
        let trainingRaw = raw["training"] as? [String: Any] ?? [:]
        let training = OpeningTraining(
            mode: string(trainingRaw["mode"]) ?? "guided-line",
            startingFen: string(trainingRaw["startingFen"]) ?? "startpos",
            sideToTrain: string(trainingRaw["sideToTrain"]) ?? "white"
        )
        let sections = raw["sections"] as? [[String: Any]] ?? []
        var lines: [TrainingLine] = []
        for section in sections {
            let branches = (section["branches"] as? [[String: Any]]) ?? (section["lessons"] as? [[String: Any]]) ?? []
            for branch in branches {
                let moves = parseMoves(branch["moves"], section: section, lesson: branch)
                if moves.isEmpty { continue }
                lines.append(TrainingLine(
                    id: string(branch["id"]) ?? "line",
                    title: string(branch["title"]) ?? "Line",
                    description: string(branch["description"]) ?? "",
                    hints: (branch["hints"] as? [Any] ?? []).compactMap { string($0) },
                    coachingNotes: (branch["coachingNotes"] as? [Any] ?? []).compactMap { string($0) },
                    completionMessage: string(branch["completionMessage"]),
                    sectionId: string(section["id"]) ?? "",
                    sectionTitle: string(section["title"]) ?? "",
                    isMainLine: bool(branch["isMainLine"]),
                    moves: moves
                ))
            }
        }
        let mainLines = lines.filter(\.isMainLine)
        let otherLines = lines.filter { !$0.isMainLine }
        lines = mainLines + otherLines
        if lines.isEmpty {
            let moves = parseMoves(raw["moves"], section: [:], lesson: [:])
            lines = [TrainingLine(id: "main-line", title: "Main Line", description: "", hints: [], coachingNotes: [], completionMessage: nil, sectionId: "main-line", sectionTitle: "Main Line", isMainLine: true, moves: moves)]
        }
        let main = mainLine(sections: sections, fallback: parseMoves(raw["moves"], section: [:], lesson: [:]))
        return OpeningCourse(
            id: string(raw["id"]) ?? "",
            name: string(raw["name"]) ?? "Opening",
            eco: string(raw["eco"]) ?? "",
            difficulty: string(raw["difficulty"]) ?? "",
            side: string(raw["side"]) ?? "",
            description: string(raw["description"]) ?? "",
            ideas: (raw["ideas"] as? [Any] ?? []).compactMap { string($0) },
            commonMistakes: (raw["commonMistakes"] as? [Any] ?? []).compactMap { string($0) },
            training: training,
            lines: lines,
            mainMoves: main,
            sectionCount: sections.count
        )
    }

    private static func mainLine(sections: [[String: Any]], fallback: [OpeningMove]) -> [OpeningMove] {
        for section in sections {
            let branches = (section["branches"] as? [[String: Any]]) ?? (section["lessons"] as? [[String: Any]]) ?? []
            for branch in branches where bool(branch["isMainLine"]) || string(branch["id"]) == "main-line" {
                return parseMoves(branch["moves"], section: section, lesson: branch)
            }
        }
        for section in sections {
            let branches = (section["branches"] as? [[String: Any]]) ?? (section["lessons"] as? [[String: Any]]) ?? []
            for branch in branches {
                let moves = parseMoves(branch["moves"], section: section, lesson: branch)
                if !moves.isEmpty { return moves }
            }
        }
        return fallback
    }

    private static func parseMoves(_ any: Any?, section: [String: Any], lesson: [String: Any]) -> [OpeningMove] {
        (any as? [[String: Any]] ?? []).enumerated().map { index, move in
            OpeningMove(
                uci: string(move["uci"]) ?? "",
                san: string(move["san"]) ?? "",
                title: string(move["title"]) ?? "",
                explanation: string(move["explanation"]) ?? "",
                lineIndex: index
            )
        }
    }

    private static func parseFolder(_ raw: [String: Any]) -> (name: String, files: [(name: String, lesson: [String: Any])]) {
        let name = string(raw["name"]) ?? ""
        let files = (raw["files"] as? [[String: Any]] ?? []).compactMap { file -> (String, [String: Any])? in
            guard let lesson = file["lesson"] as? [String: Any] else { return nil }
            return (string(file["name"]) ?? "lesson.json", lesson)
        }
        return (name, files)
    }

    static func humanize(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map { part in
                let text = String(part)
                guard let first = text.first else { return "" }
                return first.uppercased() + text.dropFirst().lowercased()
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func ratingRange(_ bracket: String) -> String {
        switch bracket {
        case "Beginner": return "0-100"
        case "Beginner+": return "100-400"
        case "Novice": return "400-600"
        case "Intermediate": return "600-900"
        case "Advanced Beginner": return "900-1200"
        default: return "0-100"
        }
    }

    private static func orderFromFile(_ name: String) -> Int {
        let prefix = name.split(separator: "_").first.map(String.init) ?? ""
        return Int(prefix) ?? 999
    }

    static func string(_ any: Any?) -> String? {
        if let value = any as? String { return value }
        if any is NSNull { return nil }
        return nil
    }

    static func int(_ any: Any?) -> Int? {
        if let value = any as? Int { return value }
        if let value = any as? NSNumber { return value.intValue }
        if let value = any as? String, let parsed = Int(value) { return parsed }
        return nil
    }

    static func bool(_ any: Any?) -> Bool {
        if let value = any as? Bool { return value }
        if let value = any as? NSNumber { return value.boolValue }
        return false
    }
}

enum CourseLibrary {
    static func meta(for course: Course, brackets: [SkillBracket], completed: Set<String>) -> CourseLibraryMeta {
        let lessons = CurriculumLoader.courseLessons(course)
        let bracket = brackets.first { bracket in
            bracket.items.contains { $0.courseId == course.id || $0.id == course.id }
        }
        let progress = CurriculumLoader.courseProgress(course, completed: completed)
        let done = lessons.filter { completed.contains($0.id) }.count
        let status = progress >= 100 ? "completed" : done > 0 ? "in-progress" : "not-started"
        let topic = inferTopic(course)
        let minutes = lessons.reduce(0) { $0 + $1.timeMinutes }
        return CourseLibraryMeta(
            course: course,
            bracket: bracket,
            bracketLabel: bracket?.title ?? course.difficulty,
            bracketRange: bracket?.range ?? course.difficulty,
            topic: topic,
            color: inferColor(course),
            type: inferType(course, topic: topic),
            status: status,
            statusLabel: status == "completed" ? "Completed" : status == "in-progress" ? "In progress" : "Not started",
            progress: progress,
            lessonCount: lessons.count,
            estimatedMinutes: minutes,
            nextLesson: lessons.first { !completed.contains($0.id) && CurriculumLoader.isCourseLessonUnlocked(course, lessonId: $0.id, completed: completed) } ?? lessons.first
        )
    }

    static func matches(_ meta: CourseLibraryMeta, state: CourseLibraryState, brackets: [SkillBracket]) -> Bool {
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            let categories = meta.course.categories.map(\.title).joined(separator: " ")
            let haystack = [
                meta.course.title, meta.course.description, meta.course.id,
                meta.bracketLabel, meta.bracketRange, meta.topic, meta.color,
                meta.type, meta.statusLabel, categories,
            ].joined(separator: " ").lowercased()
            if !haystack.contains(query) { return false }
        }
        if state.bracket != "all" && meta.bracket?.id != state.bracket && meta.bracket?.slug != state.bracket { return false }
        if state.topic != "all" && meta.topic.lowercased() != state.topic { return false }
        if state.color != "all" && meta.color.lowercased() != state.color { return false }
        if state.type != "all" && meta.type.lowercased() != state.type { return false }
        if state.status != "all" && meta.status != state.status { return false }
        return true
    }

    static func sorted(_ entries: [CourseLibraryMeta], sort: CourseLibrarySort, brackets: [SkillBracket]) -> [CourseLibraryMeta] {
        entries.sorted { compare(sortValue($0, sort: sort, brackets: brackets), sortValue($1, sort: sort, brackets: brackets)) }
    }

    private static func compare(_ left: [SortKey], _ right: [SortKey]) -> Bool {
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : .text("")
            let r = index < right.count ? right[index] : .text("")
            if l == r { continue }
            switch (l, r) {
            case let (.number(a), .number(b)): return a < b
            default: return l.text < r.text
            }
        }
        return false
    }

    private enum SortKey: Equatable {
        case number(Int)
        case text(String)
        var text: String {
            switch self {
            case .number(let value): return "\(value)"
            case .text(let value): return value
            }
        }
    }

    private static func sortValue(_ meta: CourseLibraryMeta, sort: CourseLibrarySort, brackets: [SkillBracket]) -> [SortKey] {
        let bracketIndex = brackets.firstIndex { $0.id == meta.bracket?.id || $0.slug == meta.bracket?.slug || $0.title == meta.bracketLabel } ?? -1
        let bracketKey = bracketIndex < 0 ? 99 : bracketIndex
        let difficulty = [
            "Beginner": 0, "Beginner+": 1, "Novice": 2, "Intermediate": 3, "Advanced Beginner": 4, "Advanced": 5,
        ][meta.course.difficulty] ?? 99
        let statusRank = meta.status == "in-progress" ? 0 : meta.status == "not-started" ? 1 : 2
        switch sort {
        case .recommended:
            return [.number(statusRank), .number(bracketKey), .number(meta.course.order), .text(meta.course.title.lowercased())]
        case .progress:
            return [.number(-meta.progress), .number(bracketKey), .number(meta.course.order), .text(meta.course.title.lowercased())]
        case .title:
            return [.text(meta.course.title.lowercased())]
        case .level:
            return [.number(difficulty), .number(meta.progress), .text(meta.course.title.lowercased())]
        case .time:
            return [.number(-meta.estimatedMinutes), .number(meta.progress), .text(meta.course.title.lowercased())]
        }
    }

    private static func inferTopic(_ course: Course) -> String {
        let text = "\(course.title) \(course.description) \(course.id)".lowercased()
        if matches(text, pattern: "(endgame|opposition|promotion|rook endgame|king and pawn|pawn endgame)") { return "Endgame" }
        if matches(text, pattern: "(checkmate|mate|fork|pin|skewer|tactics|blunder)") { return "Tactics" }
        if matches(text, pattern: "(opening|defense|gambit|repertoire|english|italian|london|scandinavian|caro|french|sicilian|pirc|modern|nimzo|slav|vienna|scotch|queen.?s gambit|queens gambit)") { return "Openings" }
        if matches(text, pattern: "(strategy|planning|positional|pawn structure|candidate move|practical|checks|captures|threats|before you move)") { return "Strategy" }
        return "Fundamentals"
    }

    private static func inferColor(_ course: Course) -> String {
        let text = "\(course.title) \(course.description) \(course.id)".lowercased()
        if matches(text, pattern: "(defense|scandinavian|caro|sicilian|french|pirc|modern|nimzo|slav|king'?s indian|kings indian)") { return "Black" }
        if matches(text, pattern: "(italian|london|queen.?s gambit|queens gambit|english|vienna|scotch|four knights|queen.?s pawn opening|queens pawn opening)") { return "White" }
        return "Both"
    }

    private static func inferType(_ course: Course, topic: String) -> String {
        let text = "\(course.title) \(course.description) \(course.id)".lowercased()
        if topic == "Openings" { return "Opening course" }
        if matches(text, pattern: "blunder") { return "Quiz" }
        if matches(text, pattern: "checkmate|mate|fork|pin|skewer|tactic") { return "Drill" }
        if matches(text, pattern: "practice") { return "Practice" }
        return "Interactive lesson"
    }

    private static func matches(_ text: String, pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}

struct CourseLibraryState: Equatable {
    var query = ""
    var bracket = "all"
    var topic = "all"
    var color = "all"
    var type = "all"
    var status = "all"
    var sort: CourseLibrarySort = .recommended

    static let reset = CourseLibraryState()
}
