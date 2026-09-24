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
        .safeAreaInset(edge: .top, spacing: 8) {
            freeMateHeaderBar
        }
    }

    private var freeMateHeaderBar: some View {
        HStack(spacing: 12) {
            Text("♔ FreeMate Chess")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Spacer(minLength: 8)

            Text("Level: Beginner")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.07, green: 0.18, blue: 0.42))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
    }
}

#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    ContentView()
        .environmentObject(GameState())
        .preferredColorScheme(.dark)
}

#Preview("iPhone 16 Pro", traits: .fixedLayout(width: 402, height: 874)) {
    ContentView()
        .environmentObject(GameState())
        .preferredColorScheme(.dark)
}

#Preview("iPhone 16 Pro Max", traits: .fixedLayout(width: 440, height: 956)) {
    ContentView()
        .environmentObject(GameState())
        .preferredColorScheme(.dark)
}
