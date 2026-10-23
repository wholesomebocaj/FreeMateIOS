import SwiftUI

/// Light, dark, or whatever the system uses. A device preference, so it is not synced.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "freemate.appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Adds the settings button that `FreeMateScreen` provides, for screens with native styling.
struct SettingsToolbar: ViewModifier {
    @State private var showsSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
    }
}

extension View {
    func settingsToolbar() -> some View {
        modifier(SettingsToolbar())
    }
}

struct SettingsView: View {
    @ObservedObject private var sync = CloudSync.shared
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    syncCard
                    appearanceCard
                    Text("FreeMate has no accounts, ads, or tracking. Your progress stays on this device and in your own iCloud.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .themeBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var syncCard: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconTile(
                systemImage: sync.isAvailable ? "icloud.fill" : "icloud.slash",
                color: sync.isAvailable ? Theme.accent : .secondary,
                size: 44
            )
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("iCloud Sync").font(.headline)
                Text(sync.isAvailable
                     ? "Lessons, reviews, openings, puzzles, and games sync to your other devices automatically."
                     : "Sign in to iCloud in the Settings app to keep your progress on all your devices. Until then, it stays on this one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if sync.isAvailable, let lastSynced = sync.lastSynced {
                    Text("Last synced \(lastSynced.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Appearance").font(.headline)
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .cardStyle()
    }
}
