import SwiftUI

@main
struct FreeMateIOSApp: App {
    @StateObject private var game = GameState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onAppear(perform: applyLaunchRoute)
        }
    }

    private func applyLaunchRoute() {
        #if DEBUG
        DebugLaunchRoute.apply(to: game)
        #endif
    }
}
