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
    targets: [
        .target(
            name: "FreeMateIOS",
            path: "FreeMateIOS",
            exclude: [
                "AuthSession.swift",
                "ChessboardView.swift",
                "ContentView.swift",
                "Curriculum.swift",
                "FeatureViews.swift",
                "FreeMateIOSApp.swift",
                "GameState.swift",
                "LessonSession.swift",
                "OpeningTrainer.swift",
                "PracticeBoard.swift",
                "README.md",
                "DesignSystem/BoardThumbnail.swift",
                "DesignSystem/ChessPieceShape.swift",
                "DesignSystem/Haptics.swift",
                "DesignSystem/ModernBoardView.swift",
                "DesignSystem/MotionEffects.swift",
                "OpeningTutorials/OpeningTutorialController.swift",
                "OpeningTutorials/Views",
                "OpeningTutorials/opening-tutorials.json",
            ],
            sources: [
                "ChessEngine.swift",
                "DesignSystem/BoardPieceLayout.swift",
                "OpeningTutorials/ChessOpening.swift",
                "OpeningTutorials/OpeningTutorialLibrary.swift",
                "OpeningTutorials/OpeningTutorialPresentation.swift",
                "OpeningTutorials/OpeningTutorialSession.swift",
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
