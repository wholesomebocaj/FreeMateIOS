import SwiftUI

/// Adds the account button that `FreeMateScreen` provides, for screens with native styling.
struct AccountToolbar: ViewModifier {
    @EnvironmentObject private var game: GameState
    @State private var showAuth = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAuth = true
                    } label: {
                        Image(systemName: game.currentUser == nil ? "person.crop.circle" : "person.crop.circle.fill")
                    }
                    .accessibilityLabel(game.currentUser?.displayName ?? "Sign in")
                }
            }
            .sheet(isPresented: $showAuth) {
                AuthView().environmentObject(game)
            }
    }
}

extension View {
    func accountToolbar() -> some View {
        modifier(AccountToolbar())
    }
}
