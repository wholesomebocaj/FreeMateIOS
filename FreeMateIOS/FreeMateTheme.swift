import SwiftUI

enum FreeMateTheme {
    static let bg = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let panel = Color(red: 0.122, green: 0.161, blue: 0.216)
    static let panelSoft = Color(red: 0.149, green: 0.196, blue: 0.267)
    static let panelDeep = Color(red: 0.043, green: 0.071, blue: 0.125)
    static let accent = Color(red: 0.525, green: 0.937, blue: 0.675)
    static let text = Color(red: 0.976, green: 0.980, blue: 0.984)
    static let muted = Color(red: 0.612, green: 0.639, blue: 0.686)
    static let green = Color(red: 0.133, green: 0.773, blue: 0.369)
    static let gold = Color(red: 0.980, green: 0.800, blue: 0.082)
    static let red = Color(red: 0.973, green: 0.443, blue: 0.443)
    static let lightSquare = Color(red: 0.941, green: 0.851, blue: 0.710)
    static let darkSquare = Color(red: 0.710, green: 0.533, blue: 0.388)
}

struct FreeMateScreen<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    @EnvironmentObject private var game: GameState
    @State private var showAuth = false

    var body: some View {
        ZStack {
            FreeMateTheme.bg.ignoresSafeArea()
            content()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(game.currentUser?.displayName ?? "Sign in") { showAuth = true }
                    .foregroundStyle(FreeMateTheme.accent)
            }
        }
        .sheet(isPresented: $showAuth) { AuthView().environmentObject(game) }
        .toolbarBackground(FreeMateTheme.panel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct ProgressMeter: View {
    var value: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FreeMateTheme.muted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FreeMateTheme.panelDeep)
                    Capsule().fill(FreeMateTheme.green).frame(width: geo.size.width * CGFloat(min(max(value, 0), 100)) / 100)
                }
            }
            .frame(height: 8)
        }
    }
}
