import SwiftUI

struct OpeningTutorialView: View {
    @EnvironmentObject private var game: GameState
    let tutorialId: String

    var body: some View {
        if let tutorial = game.openingTutorial(id: tutorialId) {
            OpeningTutorialScreen(tutorial: tutorial)
        } else {
            ContentUnavailableView("Tutorial Not Found", systemImage: "questionmark.square.dashed")
        }
    }
}

/// The active tutorial: progress on top, the board in the middle, and a floating card below.
struct OpeningTutorialScreen: View {
    @StateObject private var controller: OpeningTutorialController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(tutorial: OpeningTutorial) {
        _controller = StateObject(wrappedValue: OpeningTutorialController(tutorial: tutorial))
    }

    var body: some View {
        let session = controller.session
        let card = session.card
        ScrollView {
            VStack(spacing: 22) {
                TutorialProgressHeader(summary: session.progressSummary, isComplete: session.phase == .completed)
                ModernBoardView(
                    board: controller.board,
                    isInteractive: session.isUserTurn,
                    shakeSquare: controller.rejectedSquare,
                    shakeTrigger: controller.rejectionCount
                )
                .frame(maxWidth: 560)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .themeBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session.phase != .completed {
                TutorialInstructionCard(
                    content: card,
                    shakeTrigger: controller.rejectionCount,
                    onAction: { perform(card.action) },
                    onHint: { controller.showHint() }
                )
                .id(card.sceneID)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
                .frame(maxWidth: 640)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .overlay {
            if session.phase == .completed {
                TutorialCompletionOverlay(
                    openingName: session.opening.name,
                    stats: session.completionStats,
                    onDone: { dismiss() },
                    onPracticeAgain: { controller.restartTutorial() }
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DesignMotion.spring, value: card.sceneID)
        .animation(reduceMotion ? nil : DesignMotion.spring, value: session.phase)
        .navigationTitle(session.opening.name)
        .navigationBarTitleDisplayMode(.inline)
        .focusedScreen()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if session.phase == .whatIf {
                        Button("Restart This Variation", systemImage: "arrow.counterclockwise") { controller.restart() }
                    }
                    Button("Start Over", systemImage: "backward.end") { controller.restartTutorial() }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
        }
        .onChange(of: controller.rejectionCount) { Haptics.error() }
        .onChange(of: session.feedback) { _, feedback in
            switch feedback {
            case .correct, .mainLineComplete, .variationComplete:
                Haptics.light()
            case .none, .opponentMoved, .incorrect, .tutorialComplete:
                break
            }
        }
    }

    private func perform(_ action: TutorialCardContent.Action?) {
        switch action {
        case .startBranching: controller.startWhatIfPractice()
        case .nextVariation, .finish: controller.nextVariation()
        case nil: break
        }
    }
}
