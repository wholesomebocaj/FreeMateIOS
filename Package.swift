// swift-tools-version: 6.2
// Builds the UI-free core (chess engine and opening tutorials) so `swift test` runs
// without Xcode, including on Linux. The app itself builds from FreeMateIOS.xcodeproj.

import PackageDescription

let appSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "FreeMateIOS",
    // Without this, SwiftPM assumes an old macOS minimum, and toolchains that mark the
    // ISO 8601 date-format APIs as macOS 12+ reject the progress code.
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(
            name: "FreeMateIOS",
            path: "FreeMateIOS",
            exclude: [
                "Assets.xcassets",
                "ComputerGame.swift",
                "ComputerGameReview.swift",
                "DebugLaunchRoute.swift",
                "ContentView.swift",
                "Curriculum.swift",
                "FeatureViews.swift",
                "FreeMateIOSApp.swift",
                "GameState.swift",
                "LessonSession.swift",
                "OpeningTrainer.swift",
                "PracticeBoard.swift",
                "Progress/CloudSync.swift",
                "README.md",
                "Resources",
                "DesignSystem/BoardThumbnail.swift",
                "DesignSystem/ChessPieceShape.swift",
                "DesignSystem/Haptics.swift",
                "DesignSystem/ModernBoardView.swift",
                "DesignSystem/MotionEffects.swift",
                "DesignSystem/Theme.swift",
                "OpeningTutorials/OpeningTutorialController.swift",
                "OpeningTutorials/Views",
                "Puzzles/PuzzleTrainer.swift",
                "Puzzles/Views",
                "OpeningTutorials/opening-tutorials.json",
                "Tabs",
                "WidgetSnapshotWriter.swift",
            ],
            sources: [
                "ChessEngine.swift",
                "ComputerCoach.swift",
                "ComputerOpponent.swift",
                "DesignSystem/BoardPieceLayout.swift",
                "DesignSystem/MoveListFormatter.swift",
                "OpeningTutorials/ChessOpening.swift",
                "OpeningTutorials/OpeningTutorialLibrary.swift",
                "OpeningTutorials/OpeningTutorialPresentation.swift",
                "OpeningTutorials/OpeningTutorialSession.swift",
                "Progress/ActivityStore.swift",
                "Progress/LearnerProgress.swift",
                "Progress/LegacyProgressMigration.swift",
                "Progress/SyncMerge.swift",
                "Puzzles/Puzzle.swift",
            ],
            swiftSettings: appSettings
        ),
        .testTarget(
            name: "FreeMateIOSTests",
            dependencies: ["FreeMateIOS"],
            path: "FreeMateIOSTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
