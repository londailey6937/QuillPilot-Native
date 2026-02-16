import XCTest
@testable import Quill_Pilot

final class SceneTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInit() {
        let scene = Scene(order: 0)
        XCTAssertEqual(scene.order, 0)
        XCTAssertEqual(scene.title, "Untitled Scene")
        XCTAssertEqual(scene.summary, "")
        XCTAssertEqual(scene.intent, .setup)
        XCTAssertEqual(scene.revisionState, .draft)
        XCTAssertTrue(scene.characters.isEmpty)
        XCTAssertNil(scene.targetWordCount)
        XCTAssertNil(scene.chapterId)
    }

    func testCustomInit() {
        let scene = Scene(
            order: 1,
            title: "The Chase",
            summary: "Hero pursues villain",
            intent: .climax,
            revisionState: .revised,
            pointOfView: "Hero",
            location: "Rooftop",
            timeOfDay: "Night",
            characters: ["Hero", "Villain"],
            goal: "Catch the villain",
            conflict: "Villain is faster",
            outcome: "Hero nearly catches them",
            targetWordCount: 2000
        )
        XCTAssertEqual(scene.title, "The Chase")
        XCTAssertEqual(scene.intent, .climax)
        XCTAssertEqual(scene.revisionState, .revised)
        XCTAssertEqual(scene.characters, ["Hero", "Villain"])
        XCTAssertEqual(scene.targetWordCount, 2000)
    }

    // MARK: - Touch

    func testTouchUpdatesModifiedAt() {
        var scene = Scene(order: 0)
        let original = scene.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        scene.touch()
        XCTAssertGreaterThan(scene.modifiedAt, original)
    }

    // MARK: - Display Helpers

    func testStatusDisplay() {
        let scene = Scene(order: 0, revisionState: .polished)
        XCTAssertTrue(scene.statusDisplay.contains("Polished"))
    }

    func testBriefDescriptionWithoutSummary() {
        let scene = Scene(order: 0, title: "Opening", intent: .exposition)
        XCTAssertEqual(scene.briefDescription, "Opening (Exposition)")
    }

    func testBriefDescriptionWithSummary() {
        let scene = Scene(order: 0, title: "Opening", summary: "The world is introduced", intent: .exposition)
        XCTAssertEqual(scene.briefDescription, "The world is introduced")
    }

    // MARK: - SceneIntent

    func testAllIntentsHaveDescriptions() {
        for intent in SceneIntent.allCases {
            XCTAssertFalse(intent.description.isEmpty, "\(intent) has empty description")
        }
    }

    // MARK: - RevisionState

    func testAllRevisionStatesHaveIcons() {
        for state in RevisionState.allCases {
            XCTAssertFalse(state.icon.isEmpty, "\(state) has empty icon")
        }
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let chapterId = UUID()
        let original = Scene(
            order: 5,
            title: "Test Scene",
            summary: "A test",
            intent: .conflict,
            revisionState: .needsWork,
            pointOfView: "Narrator",
            location: "Library",
            timeOfDay: "Dusk",
            characters: ["Alice", "Bob"],
            goal: "Find the book",
            conflict: "It's missing",
            outcome: "They search elsewhere",
            targetWordCount: 1500,
            chapterId: chapterId
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Scene.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.intent, original.intent)
        XCTAssertEqual(decoded.revisionState, original.revisionState)
        XCTAssertEqual(decoded.characters, original.characters)
        XCTAssertEqual(decoded.chapterId, chapterId)
        XCTAssertEqual(decoded.targetWordCount, 1500)
    }
}
