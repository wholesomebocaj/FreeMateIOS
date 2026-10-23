import SwiftUI

/// The list of guided tutorials shown at the top of the Openings tab.
struct OpeningTutorialsSection: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        if !game.openingTutorials.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Guided tutorials")
                    .font(.title3.bold())
                Text("Walk through the main line with the squares highlighted, then answer the opponent's other tries.")
                    .font(.subheadline)
                    .foregroundStyle(FreeMateTheme.muted)
                ForEach(game.openingTutorials) { tutorial in
                    OpeningTutorialCard(tutorial: tutorial)
                }
            }
        }
    }
}

struct OpeningTutorialCard: View {
    @EnvironmentObject private var game: GameState
    let tutorial: OpeningTutorial
    @State private var progress = OpeningTutorialProgress()

    var body: some View {
        let opening = tutorial.opening
        Button {
            game.openTutorial(opening.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(opening.eco ?? "Opening") · You play \(opening.userSide.label)")
                    .font(.caption.bold())
                    .foregroundStyle(FreeMateTheme.accent)
                Text(opening.name)
                    .font(.headline)
                    .foregroundStyle(FreeMateTheme.text)
                Text(opening.summary)
                    .font(.subheadline)
                    .foregroundStyle(FreeMateTheme.muted)
                    .multilineTextAlignment(.leading)
                Text(statusLine(opening))
                    .font(.caption)
                    .foregroundStyle(progress.mainLineCompleted ? FreeMateTheme.green : FreeMateTheme.muted)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the guided tutorial")
        .onAppear { progress = OpeningTutorialProgressStore().progress(for: opening.id) }
    }

    private func statusLine(_ opening: ChessOpening) -> String {
        let total = opening.variations.count
        let done = progress.completedVariationIds.intersection(opening.variations.map(\.id)).count
        guard progress.mainLineCompleted else {
            return "\(opening.mainLine.count) moves in the main line · \(total) what-if lines"
        }
        return "Main line learned · \(done) of \(total) what-if lines"
    }
}

struct OpeningTutorialView: View {
    @EnvironmentObject private var game: GameState
    let tutorialId: String

    var body: some View {
        if let tutorial = game.openingTutorial(id: tutorialId) {
            OpeningTutorialScreen(tutorial: tutorial)
        } else {
            Text("Tutorial not found")
                .foregroundStyle(FreeMateTheme.text)
        }
    }
}

struct OpeningTutorialScreen: View {
    @StateObject private var controller: OpeningTutorialController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(tutorial: OpeningTutorial) {
        _controller = StateObject(wrappedValue: OpeningTutorialController(tutorial: tutorial))
    }

    var body: some View {
        let session = controller.session
        FreeMateScreen(title: session.opening.name) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(session)
                    ChessboardView(board: controller.board)
                        .modifier(ShakeEffect(travel: reduceMotion ? 0 : 8, animatableData: CGFloat(controller.rejectionCount)))
                        .animation(reduceMotion ? nil : .linear(duration: 0.35), value: controller.rejectionCount)
                        .allowsHitTesting(session.isUserTurn)
                    messageCard(session.coachMessage)
                    if let feedback = session.feedbackMessage {
                        messageCard(feedback)
                            .transition(.opacity)
                    }
                    actions(session)
                    playedMoves(session)
                    whatIfLines(session)
                    ideas(session.opening)
                }
                .padding()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: session.feedbackMessage)
            }
        }
        .onChange(of: session.feedbackMessage) { _, message in
            guard let message else { return }
            AccessibilityNotification.Announcement("\(message.title). \(message.body)").post()
        }
    }

    private func header(_ session: OpeningTutorialSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.stageLabel)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(FreeMateTheme.accent.opacity(0.18), in: Capsule())
                    .foregroundStyle(FreeMateTheme.accent)
                Spacer()
                Text("You play \(session.opening.userSide.label)")
                    .font(.caption)
                    .foregroundStyle(FreeMateTheme.muted)
            }
            if let ecoName = session.opening.ecoName, let eco = session.opening.eco {
                Text("\(eco) · \(ecoName)")
                    .font(.caption)
                    .foregroundStyle(FreeMateTheme.muted)
            }
            ProgressMeter(value: session.progressPercent)
        }
    }

    private func messageCard(_ message: TutorialMessage) -> some View {
        let tint: Color = switch message.tone {
        case .neutral: FreeMateTheme.panel
        case .success: FreeMateTheme.green.opacity(0.18)
        case .hint: FreeMateTheme.gold.opacity(0.16)
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text(message.title)
                .font(.headline)
                .foregroundStyle(FreeMateTheme.text)
            if !message.body.isEmpty {
                Text(message.body)
                    .font(.subheadline)
                    .foregroundStyle(FreeMateTheme.muted)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func actions(_ session: OpeningTutorialSession) -> some View {
        HStack {
            switch session.phase {
            case .mainLineComplete:
                Button(session.opening.variations.isEmpty ? "Finish" : "Start What if? practice") {
                    controller.startWhatIfPractice()
                }
                .buttonStyle(.borderedProminent)
                .tint(FreeMateTheme.green)
            case .whatIf where session.isCurrentLineComplete:
                Button(session.hasMoreVariations ? "Next what-if" : "Finish") { controller.nextVariation() }
                    .buttonStyle(.borderedProminent)
                    .tint(FreeMateTheme.green)
            case .completed:
                Button("Practice again") { controller.restart() }
                    .buttonStyle(.borderedProminent)
                    .tint(FreeMateTheme.green)
            case .mainLine, .whatIf:
                if session.isUserTurn && session.highlightedSquares == nil {
                    Button("Show hint") { controller.showHint() }
                        .buttonStyle(.bordered)
                }
            }
            if session.phase == .mainLine || session.phase == .whatIf {
                Button(session.phase == .whatIf ? "Restart line" : "Start over") { controller.restart() }
                    .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func playedMoves(_ session: OpeningTutorialSession) -> some View {
        let moves = session.phase == .whatIf
            ? Array(session.mainLineMoves.prefix(session.currentVariation?.branchPly ?? 0)) + session.playedMoves
            : session.playedMoves
        if !moves.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Moves").font(.headline)
                Text(moves.map(\.moveNumberLabel).joined(separator: "  "))
                    .font(.subheadline.monospaced())
                    .foregroundStyle(FreeMateTheme.muted)
            }
        }
    }

    @ViewBuilder
    private func whatIfLines(_ session: OpeningTutorialSession) -> some View {
        let opening = session.opening
        if !opening.variations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("What if? lines").font(.headline)
                ForEach(opening.variations) { variation in
                    let done = session.completedVariationIds.contains(variation.id)
                        || controller.progress.completedVariationIds.contains(variation.id)
                    let current = session.currentVariation?.id == variation.id
                    let mainMove = opening.mainLine[variation.branchPly].san
                    let branch = TutorialMove.label(san: variation.moves[0].san, ply: variation.branchPly)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: done ? "checkmark.circle.fill" : current ? "arrow.right.circle.fill" : "circle")
                            .foregroundStyle(done ? FreeMateTheme.green : current ? FreeMateTheme.accent : FreeMateTheme.muted)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(variation.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(current ? FreeMateTheme.accent : FreeMateTheme.text)
                            Text("\(branch) instead of \(mainMove)\(variation.eco.map { " · \($0)" } ?? "")")
                                .font(.caption)
                                .foregroundStyle(FreeMateTheme.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(done ? "Completed" : current ? "In progress" : "Not started")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FreeMateTheme.panel, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func ideas(_ opening: ChessOpening) -> some View {
        if !opening.ideas.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ideas to remember").font(.headline)
                ForEach(opening.ideas, id: \.self) { idea in
                    Text("• \(idea)")
                        .font(.subheadline)
                        .foregroundStyle(FreeMateTheme.muted)
                }
            }
        }
    }
}

/// A short side-to-side shake. Each increment of `animatableData` plays two full swings.
nonisolated private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}
