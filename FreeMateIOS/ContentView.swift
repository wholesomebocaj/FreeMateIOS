import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        TabView(selection: $game.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack(path: $game.lessonPath) {
                CourseLibraryView()
                    .navigationDestination(for: LessonRoute.self) { route in
                        switch route {
                        case .bracket(let id):
                            BracketDetailView(bracketId: id)
                        case .course(let id):
                            CourseDetailView(courseId: id)
                        case .lesson(let id):
                            LessonPlayerView(lessonId: id)
                        }
                    }
            }
            .tabItem { Label("Lessons", systemImage: "book") }
            .tag(AppTab.lessons)

            NavigationStack(path: $game.openingPath) {
                OpeningBrowserView()
                    .navigationDestination(for: OpeningRoute.self) { route in
                        switch route {
                        case .overview(let id):
                            OpeningOverviewView(openingId: id)
                        case .train(let id, let line):
                            OpeningTrainerView(openingId: id, lineId: line)
                        case .tutorial(let id):
                            OpeningTutorialView(tutorialId: id)
                        }
                    }
            }
            .tabItem { Label("Openings", systemImage: "arrow.triangle.branch") }
            .tag(AppTab.openings)

            NavigationStack {
                PracticeView()
            }
            .tabItem { Label("Practice", systemImage: "square.grid.3x3") }
            .tag(AppTab.practice)

            NavigationStack {
                ReviewView()
            }
            .tabItem { Label("Review", systemImage: "arrow.clockwise") }
            .tag(AppTab.review)
        }
    }
}
