import SwiftUI

/// The "Puzzles" side of the Practice tab: curated puzzles by level, then the drills.
struct PuzzleHubView: View {
    @State private var catalog: PuzzleCatalog?
    @State private var drills: [Drill] = []
    @State private var solved: Set<String> = []
    @State private var loadError = false
    private let store = PuzzleProgressStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let catalog {
                SectionHeader(
                    title: "Puzzles",
                    subtitle: "One move wins. Solve \(catalog.unlockAfter) in a level to open the next."
                )
                ForEach(catalog.levels) { level in
                    levelCard(level, in: catalog)
                }
            }
            if !drills.isEmpty {
                SectionHeader(title: "Drills", subtitle: "Short sets on one idea. Repeat them any time.")
                    .padding(.top, 8)
                ForEach(drills) { drill in
                    drillCard(drill)
                }
            }
            if loadError {
                Text("Puzzles could not be loaded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        solved = store.solved
        guard catalog == nil else { return }
        do {
            catalog = try PuzzleLibrary.loadCatalog()
            drills = try PuzzleLibrary.loadDrills()
        } catch {
            loadError = true
        }
    }

    @ViewBuilder
    private func levelCard(_ level: PuzzleLevel, in catalog: PuzzleCatalog) -> some View {
        let set = PuzzleSet(level: level)
        let done = level.puzzles.filter { solved.contains(set.key(for: $0)) }.count
        if catalog.isUnlocked(level, solved: solved) {
            NavigationLink {
                PuzzleTrainerView(set: set)
            } label: {
                setRow(
                    eyebrow: "Level \(level.level)",
                    title: level.title,
                    summary: level.summary,
                    done: done,
                    total: level.puzzles.count,
                    systemImage: done == level.puzzles.count ? "checkmark.seal.fill" : "puzzlepiece.fill",
                    color: done == level.puzzles.count ? Theme.success : Theme.accent
                )
            }
            .buttonStyle(PressableCardStyle())
        } else {
            setRow(
                eyebrow: "Level \(level.level)",
                title: level.title,
                summary: "Solve \(catalog.unlockAfter) puzzles in Level \(level.level - 1) to unlock.",
                done: nil,
                total: level.puzzles.count,
                systemImage: "lock.fill",
                color: .secondary
            )
            .opacity(0.7)
            .accessibilityLabel("Level \(level.level), \(level.title), locked")
        }
    }

    private func drillCard(_ drill: Drill) -> some View {
        let set = PuzzleSet(drill: drill)
        let done = drill.puzzles.filter { solved.contains(set.key(for: $0)) }.count
        return NavigationLink {
            PuzzleTrainerView(set: set)
        } label: {
            setRow(
                eyebrow: "Drill",
                title: drill.title,
                summary: drill.summary,
                done: done,
                total: drill.puzzles.count,
                systemImage: Self.drillSymbol(drill.id),
                color: done == drill.puzzles.count ? Theme.success : Theme.warning
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    private func setRow(
        eyebrow: String,
        title: String,
        summary: String,
        done: Int?,
        total: Int,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            IconTile(systemImage: systemImage, color: color, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow).eyebrowStyle()
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let done {
                    HStack(spacing: Theme.Spacing.xs) {
                        CapsuleProgressBar(fraction: Double(done) / Double(max(total, 1)), tint: color)
                            .frame(height: 6)
                        Text("\(done)/\(total)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if done != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .multilineTextAlignment(.leading)
        .cardStyle()
    }

    static func drillSymbol(_ id: String) -> String {
        switch id {
        case "mate-in-one": return "crown.fill"
        case "forks": return "arrow.triangle.branch"
        case "pins": return "pin.fill"
        case "hanging": return "hand.raised.fill"
        case "out-of-check": return "shield.lefthalf.filled"
        default: return "target"
        }
    }
}
