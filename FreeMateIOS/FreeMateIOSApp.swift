import SwiftUI

@main
struct FreeMateIOSApp: App {
    @StateObject private var game = GameState()
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .preferredColorScheme(appearance.colorScheme)
                .tint(Theme.accent)
                .onAppear(perform: start)
                .onOpenURL { game.open($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { WidgetSnapshotWriter.write(game) }
                }
        }
    }

    private func start() {
        CloudSync.shared.onRemoteChange = { [game] in
            game.reloadProgress()
            WidgetSnapshotWriter.write(game)
        }
        CloudSync.shared.start()
        game.onProgressChange = { [game] in WidgetSnapshotWriter.write(game) }
        WidgetSnapshotWriter.write(game)
        #if DEBUG
        DebugLaunchRoute.apply(to: game)
        #endif
    }
}
