#if DEBUG
import Foundation

/// Opens a screen from a launch argument so CI can screenshot it, for example
/// `-FreeMateScreen openings`, `-FreeMateScreen tutorial:ruy-lopez`, or
/// `-FreeMateScreen puzzles:level/1`.
enum DebugLaunchRoute {
    static func apply(to game: GameState) {
        guard let value = UserDefaults.standard.string(forKey: "FreeMateScreen") else { return }
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        let id = parts.count == 2 ? parts[1] : ""
        switch parts.first ?? "" {
        case "home": game.selectedTab = .home
        case "lessons": game.selectedTab = .lessons
        case "openings": game.selectedTab = .openings
        case "practice": game.selectedTab = .practice
        case "computer": game.openPractice(.computer)
        case "board": game.openPractice(.freeBoard)
        case "puzzles" where !id.isEmpty: game.openPractice(.puzzles(id))
        case "review": game.selectedTab = .review
        case "course" where !id.isEmpty: game.openCourse(id)
        case "lesson" where !id.isEmpty: game.openLesson(id)
        case "opening" where !id.isEmpty: game.openOpening(id)
        case "trainer" where !id.isEmpty: game.openTrainer(id: id, line: nil)
        case "tutorial" where !id.isEmpty: game.openTutorial(id)
        default: break
        }
    }
}
#endif
