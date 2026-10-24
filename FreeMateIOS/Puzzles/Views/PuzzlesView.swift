import SwiftUI

/// The bundled puzzles, loaded once.
enum PuzzleContent {
    static let catalog = try? PuzzleLibrary.loadCatalog()
    static let drills = (try? PuzzleLibrary.loadDrills()) ?? []
    static let blunderChecks = (try? BlunderCheckLibrary.loadBundled()) ?? []
    static var levels: [PuzzleLevel] { catalog?.levels ?? [] }
    static var collections: [PuzzleCollection] { catalog?.collections ?? [] }
    static let dailyPool = DailyPuzzle.pool(catalog: catalog, drills: drills)

    /// Collections shown as modes on the Puzzles page; the rest are themes.
    static let modeCollectionIds: Set<String> = ["endgames", "mate-in-two"]

    static var allPuzzles: [Puzzle] { dailyPool }

    static func dailySet(on date: Date) -> PuzzleSet? {
        DailyPuzzle.set(on: date, pool: dailyPool)
    }

    static func set(id: String) -> PuzzleSet? {
        if id.hasPrefix("daily/") {
            let day = String(id.dropFirst("daily/".count))
            return date(fromDay: day).flatMap(dailySet(on:))
        }
        if let level = levels.first(where: { PuzzleSet(level: $0).id == id }) { return PuzzleSet(level: level) }
        if let collection = collections.first(where: { PuzzleSet(collection: $0).id == id }) { return PuzzleSet(collection: collection) }
        if let drill = drills.first(where: { PuzzleSet(drill: $0).id == id }) { return PuzzleSet(drill: drill) }
        return nil
    }

    private static func date(fromDay day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

/// The Puzzles tab: the daily puzzle, the modes, the level path, and themes.
struct PuzzlesView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.scenePhase) private var scenePhase
    @State private var solved: Set<String> = []
    @State private var rushBest = 0
    @State private var blundersCorrect = 0
    @State private var today = Date()

    var body: some View {
        NavigationStack(path: $game.puzzlePath) {
            List {
                if let daily = PuzzleContent.dailySet(on: today) {
                    Section {
                        dailyCard(daily)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section {
                    modes
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if let catalog = PuzzleContent.catalog {
                    Section {
                        ForEach(catalog.levels) { level in
                            levelRow(level, in: catalog)
                        }
                    } header: {
                        Text("Path")
                    } footer: {
                        Text("Solve \(catalog.unlockAfter) in a level to unlock the next.")
                    }
                }
                Section {
                    ForEach(PuzzleContent.drills) { drill in
                        setRow(PuzzleSet(drill: drill), style: Self.style(for: drill.id))
                    }
                    ForEach(PuzzleContent.collections.filter { !PuzzleContent.modeCollectionIds.contains($0.id) }) { collection in
                        setRow(PuzzleSet(collection: collection), style: Self.style(for: collection.id, fallback: collection.symbol))
                    }
                } header: {
                    Text("Themes")
                } footer: {
                    Text("\(solved.count) solved")
                        .monospacedDigit()
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(Theme.Spacing.l)
            .navigationTitle("Puzzles")
            .navigationDestination(for: PuzzleRoute.self) { route in
                switch route {
                case .set(let id):
                    if let set = PuzzleContent.set(id: id) {
                        PuzzleTrainerView(set: set)
                    } else {
                        ContentUnavailableView("Puzzle Not Found", systemImage: "puzzlepiece")
                    }
                case .rush:
                    RushView()
                case .blunderCheck:
                    BlunderCheckView(checks: PuzzleContent.blunderChecks)
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: game.puzzlePath) { refresh() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        }
    }

    // MARK: - Daily

    private func dailyCard(_ set: PuzzleSet) -> some View {
        let puzzle = set.puzzles[0]
        let isSolved = solved.contains(set.key(for: puzzle))
        let streak = DailyPuzzle.streak(solved: solved, today: today)
        return Button {
            game.puzzlePath.append(.set(set.id))
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                BoardThumbnail(fen: puzzle.fen, isFlipped: puzzle.sideToMove == .black)
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Puzzle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(today.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("\(puzzle.sideToMove.label) to move")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    HStack(spacing: Theme.Spacing.s) {
                        if isSolved {
                            Label("Solved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                        } else {
                            Text("Solve")
                                .foregroundStyle(Theme.accent)
                        }
                        if streak > 0 {
                            Label("\(streak)", systemImage: "flame.fill")
                                .foregroundStyle(Theme.warning)
                                .accessibilityLabel("\(streak)-day streak")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 2)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.m)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isSolved ? "Solved today" : "Opens today's puzzle")
    }

    // MARK: - Modes

    private var modes: some View {
        let columns = [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)]
        return LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            tile("Puzzle Rush", detail: rushBest > 0 ? "Best \(rushBest)" : "3 minutes", systemImage: "bolt.fill", color: Theme.warning, route: .rush)
            tile(
                "Blunder Check",
                detail: "\(blundersCorrect) of \(PuzzleContent.blunderChecks.count)",
                systemImage: "exclamationmark.shield.fill",
                color: Theme.danger,
                route: .blunderCheck
            )
            ForEach(PuzzleContent.collections.filter { PuzzleContent.modeCollectionIds.contains($0.id) }) { collection in
                let set = PuzzleSet(collection: collection)
                let style = Self.style(for: collection.id, fallback: collection.symbol)
                tile(
                    collection.title,
                    detail: "\(done(in: set)) of \(set.puzzles.count)",
                    systemImage: style.symbol,
                    color: style.color,
                    route: .set(set.id)
                )
            }
        }
    }

    private func tile(_ title: String, detail: String, systemImage: String, color: Color, route: PuzzleRoute) -> some View {
        Button {
            game.puzzlePath.append(route)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(height: 30)
                Spacer(minLength: Theme.Spacing.m)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Rows

    private static let levelStyles: [(symbol: String, color: Color)] = [
        ("shoeprints.fill", Theme.accent),
        ("arrow.up.left.and.arrow.down.right", Theme.success),
        ("line.diagonal.arrow", Theme.warning),
        ("eye.fill", .purple),
    ]

    @ViewBuilder
    private func levelRow(_ level: PuzzleLevel, in catalog: PuzzleCatalog) -> some View {
        let set = PuzzleSet(level: level)
        let style = Self.levelStyles[(level.level - 1) % Self.levelStyles.count]
        if catalog.isUnlocked(level, solved: solved) {
            NavigationLink(value: PuzzleRoute.set(set.id)) {
                IconRow(title: level.title, subtitle: "Level \(level.level)", systemImage: style.symbol, color: style.color) {
                    progress(done: done(in: set), total: set.puzzles.count)
                }
            }
        } else {
            IconRow(title: level.title, subtitle: "Level \(level.level)", systemImage: "lock.fill", color: Color(.systemGray3)) {
                Image(systemName: "lock")
                    .accessibilityLabel("Locked")
            }
            .opacity(0.6)
        }
    }

    private func setRow(_ set: PuzzleSet, style: (symbol: String, color: Color)) -> some View {
        NavigationLink(value: PuzzleRoute.set(set.id)) {
            IconRow(title: set.title, systemImage: style.symbol, color: style.color) {
                progress(done: done(in: set), total: set.puzzles.count)
            }
        }
    }

    @ViewBuilder
    private func progress(done: Int, total: Int) -> some View {
        if done == total && total > 0 {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.success)
                .accessibilityLabel("Complete")
        } else if done > 0 {
            Text("\(done)/\(total)")
        }
    }

    private func done(in set: PuzzleSet) -> Int {
        set.puzzles.filter { solved.contains(set.key(for: $0)) }.count
    }

    static func style(for id: String, fallback: String = "target") -> (symbol: String, color: Color) {
        switch id {
        case "mate-in-one": return ("crown", Theme.highlight)
        case "forks": return ("arrow.triangle.branch", Theme.warning)
        case "pins": return ("pin.fill", .purple)
        case "hanging": return ("hand.raised.fill", Theme.success)
        case "out-of-check": return ("shield.lefthalf.filled", Theme.accent)
        case "skewers": return ("line.diagonal.arrow", .teal)
        case "discovered-attacks": return ("rays", .indigo)
        case "endgames": return ("flag.checkered", Theme.success)
        case "mate-in-two": return ("crown.fill", .purple)
        default: return (fallback, .gray)
        }
    }

    private func refresh() {
        today = Date()
        solved = PuzzleProgressStore().solved
        rushBest = RushStore().best
        blundersCorrect = BlunderProgressStore().correct.count
    }
}
