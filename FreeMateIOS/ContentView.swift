import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        VStack(spacing: 0) {
            freeMateHeaderBar

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

    private var freeMateHeaderBar: some View {
        HStack {
            Text("♔ FreeMate Chess")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer()

            Text("Level: Beginner")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .padding()
        .background(Color(red: 0.07, green: 0.18, blue: 0.42))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}
