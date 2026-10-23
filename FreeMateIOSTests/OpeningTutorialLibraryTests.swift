import XCTest
@testable import FreeMateIOS

@MainActor
final class OpeningTutorialLibraryTests: XCTestCase {
    func testBundledTutorialsDecodeAndResolve() async throws {
        let openings = try TutorialFixtures.bundledOpenings()

        XCTAssertEqual(openings.map(\.id), ["ruy-lopez", "caro-kann"])
        let ruy = try XCTUnwrap(openings.first)
        XCTAssertEqual(ruy.userSide, .white)
        XCTAssertEqual(ruy.eco, "C92")
        XCTAssertEqual(ruy.variations.first?.ecoName, "Ruy Lopez: Berlin Defense")
    }

    func testVariationTreeMergesSharedMoves() async throws {
        let caro = try TutorialFixtures.opening("caro-kann")
        let tree = caro.variationTree

        let afterD5 = try XCTUnwrap(tree.node(following: ["e4", "c6", "d4", "d5"]))
        XCTAssertEqual(afterD5.children.compactMap(\.step?.san), ["Nc3", "e5", "exd5"])
        let afterExchange = try XCTUnwrap(tree.node(following: ["e4", "c6", "d4", "d5", "exd5", "cxd5"]))
        XCTAssertEqual(Set(afterExchange.children.compactMap(\.step?.san)), ["Bd3", "c4"])
        XCTAssertEqual(afterExchange.variationIds.sorted(), ["exchange", "panov"])
        XCTAssertNil(tree.node(following: ["d4"]))
    }

    func testSANMatchingIgnoresCheckMarks() async {
        XCTAssertTrue(SANText.matches("Qxd8+", "Qxd8"))
        XCTAssertTrue(SANText.matches("O-O", "0-0"))
        XCTAssertFalse(SANText.matches("O-O", "O-O-O"))
    }

    func testIllegalMoveInDataIsRejected() async {
        var opening = TutorialFixtures.miniRuyLopez()
        opening.mainLine[2] = TutorialFixtures.step("Nf4")

        XCTAssertThrowsError(try OpeningTutorialSession(opening: opening)) { error in
            XCTAssertEqual(error as? OpeningTutorialError, .illegalMove(openingId: "mini-ruy", line: "main line", ply: 2, san: "Nf4"))
        }
    }

    func testVariationMustBranchOnAnOpponentMove() async {
        var opening = TutorialFixtures.miniRuyLopez()
        opening.variations[0].branchPly = 4

        XCTAssertThrowsError(try OpeningTutorialPlan(opening: opening)) { error in
            guard case .invalidVariation(_, "berlin", _) = error as? OpeningTutorialError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testProgressIsSavedOnTheDevice() async throws {
        let suite = "OpeningTutorialLibraryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = OpeningTutorialProgressStore(defaults: defaults)

        store.update("ruy-lopez") { progress in
            progress.mainLineCompleted = true
            progress.completedVariationIds.insert("berlin")
        }

        let reloaded = OpeningTutorialProgressStore(defaults: defaults).progress(for: "ruy-lopez")
        XCTAssertTrue(reloaded.mainLineCompleted)
        XCTAssertEqual(reloaded.completedVariationIds, ["berlin"])
        XCTAssertEqual(store.progress(for: "caro-kann"), OpeningTutorialProgress())
    }
}
