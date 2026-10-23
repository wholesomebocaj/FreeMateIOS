import Foundation
import XCTest
@testable import FreeMateIOS

@MainActor
enum TutorialFixtures {
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FreeMateIOS/OpeningTutorials/opening-tutorials.json")

    /// Uses the host app's bundle under Xcode, and the file in the repo under `swift test`.
    static func bundledOpenings() throws -> [ChessOpening] {
        if let tutorials = try? OpeningTutorialLibrary.loadBundled() {
            return tutorials.map(\.opening)
        }
        return try OpeningTutorialLibrary.decode(Data(contentsOf: catalogURL)).map(\.opening)
    }

    static func opening(_ id: String) throws -> ChessOpening {
        try XCTUnwrap(bundledOpenings().first { $0.id == id }, "Missing opening \(id)")
    }

    static func step(_ san: String) -> OpeningStep {
        OpeningStep(san: san, title: san, explanation: "", hint: nil)
    }

    /// A short Ruy Lopez with one Berlin variation, independent of the bundled data.
    static func miniRuyLopez() -> ChessOpening {
        ChessOpening(
            id: "mini-ruy",
            name: "Mini Ruy Lopez",
            eco: "C60",
            ecoName: nil,
            userSide: .white,
            summary: "",
            ideas: [],
            mainLine: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4"].map(step),
            variations: [
                OpeningVariation(
                    id: "berlin",
                    name: "Berlin Defense",
                    eco: nil,
                    ecoName: nil,
                    branchPly: 5,
                    summary: "",
                    moves: [step("Nf6"), OpeningStep(san: "O-O", title: "Castle", explanation: "", hint: "Get your king safe.")]
                ),
            ]
        )
    }
}

@MainActor
extension OpeningTutorialSession {
    /// Plays the expected move for the learner and every opponent reply until the line ends
    /// or the learner is on move again.
    mutating func playExpectedMove(file: StaticString = #filePath, line: UInt = #line) {
        guard let move = expectedUserMove else {
            XCTFail("It is not the learner's turn", file: file, line: line)
            return
        }
        guard case .correct = submitMove(from: move.from, to: move.to, promotion: move.promotion) else {
            XCTFail("\(move.san) was rejected", file: file, line: line)
            return
        }
        playOpponentReplies()
    }

    mutating func playOpponentReplies() {
        while isAwaitingOpponent {
            playOpponentMove()
        }
    }

    mutating func playToEndOfCurrentLine(file: StaticString = #filePath, line: UInt = #line) {
        playOpponentReplies()
        while expectedUserMove != nil {
            playExpectedMove(file: file, line: line)
        }
    }
}
