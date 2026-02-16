import XCTest
@testable import Quill_Pilot

final class SceneManagerTests: XCTestCase {

    private var manager: SceneManager!

    override func setUp() {
        super.setUp()
        manager = SceneManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Scene CRUD

    func testAddScene() {
        let scene = Scene(order: 0, title: "First")
        manager.addScene(scene)
        XCTAssertEqual(manager.sceneCount, 1)
        XCTAssertEqual(manager.scenes.first?.title, "First")
    }

    func testAddMultipleScenesAreSorted() {
        manager.addScene(Scene(order: 2, title: "C"))
        manager.addScene(Scene(order: 0, title: "A"))
        manager.addScene(Scene(order: 1, title: "B"))
        XCTAssertEqual(manager.scenes.map(\.title), ["A", "B", "C"])
    }

    func testUpdateScene() {
        var scene = Scene(order: 0, title: "Original")
        manager.addScene(scene)
        scene.title = "Updated"
        manager.updateScene(scene)
        XCTAssertEqual(manager.scenes.first?.title, "Updated")
    }

    func testDeleteScene() {
        let scene = Scene(order: 0, title: "Delete Me")
        manager.addScene(scene)
        XCTAssertEqual(manager.sceneCount, 1)
        manager.deleteScene(id: scene.id)
        XCTAssertEqual(manager.sceneCount, 0)
    }

    func testDeleteSceneReordersRemaining() {
        let a = Scene(order: 0, title: "A")
        let b = Scene(order: 1, title: "B")
        let c = Scene(order: 2, title: "C")
        manager.addScene(a)
        manager.addScene(b)
        manager.addScene(c)
        manager.deleteScene(id: b.id)
        XCTAssertEqual(manager.scenes.map(\.order), [0, 1])
        XCTAssertEqual(manager.scenes.map(\.title), ["A", "C"])
    }

    func testSceneWithId() {
        let scene = Scene(order: 0, title: "Findable")
        manager.addScene(scene)
        XCTAssertNotNil(manager.scene(withId: scene.id))
        XCTAssertNil(manager.scene(withId: UUID()))
    }

    func testMoveScene() {
        manager.addScene(Scene(order: 0, title: "A"))
        manager.addScene(Scene(order: 1, title: "B"))
        manager.addScene(Scene(order: 2, title: "C"))
        manager.moveScene(from: 0, to: 2)
        XCTAssertEqual(manager.scenes.map(\.title), ["B", "C", "A"])
    }

    func testMoveSceneInvalidIndicesNoOp() {
        manager.addScene(Scene(order: 0, title: "Only"))
        manager.moveScene(from: -1, to: 5)
        XCTAssertEqual(manager.sceneCount, 1)
    }

    // MARK: - Chapter CRUD

    func testAddChapter() {
        let chapter = Chapter(order: 0, title: "Ch 1")
        manager.addChapter(chapter)
        XCTAssertEqual(manager.chapterCount, 1)
    }

    func testUpdateChapter() {
        var chapter = Chapter(order: 0, title: "Original")
        manager.addChapter(chapter)
        chapter.title = "Revised"
        manager.updateChapter(chapter)
        XCTAssertEqual(manager.chapters.first?.title, "Revised")
    }

    func testDeleteChapterUnassignsScenes() {
        let chapter = Chapter(order: 0, title: "Ch 1")
        manager.addChapter(chapter)
        let scene = Scene(order: 0, title: "Assigned", chapterId: chapter.id)
        manager.addScene(scene)
        XCTAssertEqual(manager.scenes.first?.chapterId, chapter.id)
        manager.deleteChapter(id: chapter.id)
        XCTAssertNil(manager.scenes.first?.chapterId)
        XCTAssertEqual(manager.chapterCount, 0)
    }

    // MARK: - Queries

    func testScenesInChapter() {
        let chapter = Chapter(order: 0, title: "Ch 1")
        manager.addChapter(chapter)
        manager.addScene(Scene(order: 0, title: "In Chapter", chapterId: chapter.id))
        manager.addScene(Scene(order: 1, title: "No Chapter"))
        let inChapter = manager.scenes(inChapter: chapter.id)
        XCTAssertEqual(inChapter.count, 1)
        XCTAssertEqual(inChapter.first?.title, "In Chapter")
    }

    func testUnassignedScenes() {
        let chapter = Chapter(order: 0)
        manager.addChapter(chapter)
        manager.addScene(Scene(order: 0, title: "Assigned", chapterId: chapter.id))
        manager.addScene(Scene(order: 1, title: "Unassigned"))
        let unassigned = manager.unassignedScenes()
        XCTAssertEqual(unassigned.count, 1)
        XCTAssertEqual(unassigned.first?.title, "Unassigned")
    }

    func testScenesWithState() {
        manager.addScene(Scene(order: 0, revisionState: .draft))
        manager.addScene(Scene(order: 1, revisionState: .polished))
        manager.addScene(Scene(order: 2, revisionState: .draft))
        XCTAssertEqual(manager.scenes(withState: .draft).count, 2)
        XCTAssertEqual(manager.scenes(withState: .polished).count, 1)
        XCTAssertEqual(manager.scenes(withState: .final).count, 0)
    }

    func testScenesWithIntent() {
        manager.addScene(Scene(order: 0, intent: .setup))
        manager.addScene(Scene(order: 1, intent: .climax))
        manager.addScene(Scene(order: 2, intent: .setup))
        XCTAssertEqual(manager.scenes(withIntent: .setup).count, 2)
        XCTAssertEqual(manager.scenes(withIntent: .climax).count, 1)
    }

    func testAssignScene() {
        let chapter = Chapter(order: 0)
        manager.addChapter(chapter)
        let scene = Scene(order: 0, title: "Unassigned")
        manager.addScene(scene)
        XCTAssertNil(manager.scenes.first?.chapterId)
        manager.assignScene(scene.id, toChapter: chapter.id)
        XCTAssertEqual(manager.scenes.first?.chapterId, chapter.id)
    }

    // MARK: - Persistence Round-Trip

    func testEncodeDecodeRoundTrip() throws {
        let chapter = Chapter(order: 0, title: "Ch 1")
        manager.addChapter(chapter)
        manager.addScene(Scene(order: 0, title: "Scene A", chapterId: chapter.id))
        manager.addScene(Scene(order: 1, title: "Scene B"))

        let data = try manager.encode()

        let restored = SceneManager()
        try restored.decode(from: data)

        XCTAssertEqual(restored.sceneCount, 2)
        XCTAssertEqual(restored.chapterCount, 1)
        XCTAssertEqual(restored.chapters.first?.title, "Ch 1")
        XCTAssertEqual(restored.scenes.map(\.title), ["Scene A", "Scene B"])
    }

    // MARK: - Clear

    func testClear() {
        manager.addScene(Scene(order: 0))
        manager.addChapter(Chapter(order: 0))
        manager.clear()
        XCTAssertEqual(manager.sceneCount, 0)
        XCTAssertEqual(manager.chapterCount, 0)
    }
}
