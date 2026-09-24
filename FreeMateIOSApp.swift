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

#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    ContentView()
        .environmentObject(GameState())
        .preferredColorScheme(.dark)
}

#Preview("iPhone 16 Pro Max", traits: .fixedLayout(width: 440, height: 956)) {
    ContentView()
        .environmentObject(GameState())
        .preferredColorScheme(.dark)
}
