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

struct SettingsView: View {
    @ObservedObject private var sync = CloudSync.shared
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        IconRow(title: "iCloud Sync", systemImage: sync.isAvailable ? "icloud.fill" : "icloud.slash", color: sync.isAvailable ? Theme.accent : Color(.systemGray))
                        Spacer()
                        Text(sync.isAvailable ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    if sync.isAvailable {
                        Text("Lessons, reviews, openings, puzzles, and games stay in step across your devices.")
                    } else {
                        Text("Sign in to iCloud in the Settings app to keep your progress on all your devices.")
                    }
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    LabeledContent("Version", value: version)
                } footer: {
                    Text("FreeMate is free, with no accounts, ads, or tracking.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
