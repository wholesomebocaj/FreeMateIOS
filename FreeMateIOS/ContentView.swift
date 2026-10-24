import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        TabView(selection: $game.selectedTab) {
            Tab("Today", systemImage: "sun.max", value: AppTab.home) {
                NavigationStack(path: $game.homePath) {
                    HomeView()
                        .navigationDestination(for: HomeRoute.self) { route in
                            switch route {
                            case .review: ReviewView()
                            }
                        }
                }
            }
            .badge(game.reviewQueue().count)

            Tab("Learn", systemImage: "book", value: AppTab.lessons) {
                NavigationStack(path: $game.lessonPath) {
                    CourseLibraryView()
                        .navigationDestination(for: LessonRoute.self) { route in
                            switch route {
                            case .bracket(let id): BracketDetailView(bracketId: id)
                            case .course(let id): CourseDetailView(courseId: id)
                            case .lesson(let id): LessonPlayerView(lessonId: id)
                            }
                        }
                }
            }

            Tab("Openings", systemImage: "arrow.triangle.branch", value: AppTab.openings) {
                NavigationStack(path: $game.openingPath) {
                    OpeningBrowserView()
                        .navigationDestination(for: OpeningRoute.self) { route in
                            switch route {
                            case .overview(let id): OpeningOverviewView(openingId: id)
                            case .train(let id, let line): OpeningTrainerView(openingId: id, lineId: line)
                            case .tutorial(let id): OpeningTutorialView(tutorialId: id)
                            }
                        }
                }
            }

            Tab("Puzzles", systemImage: "puzzlepiece", value: AppTab.puzzles) {
                PuzzlesView()
            }

            Tab("Play", systemImage: "checkerboard.rectangle", value: AppTab.practice) {
                PracticeView()
            }
        }
    }
}
