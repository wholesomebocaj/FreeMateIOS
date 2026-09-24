import SwiftUI

@main
struct FreeMateIOSApp: App {
    @StateObject private var game = GameState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .preferredColorScheme(.dark)
                .tint(FreeMateTheme.accent)
        }
    }
}
