import XCTest
@testable import Quill_Pilot

final class ChapterTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInit() {
        let chapter = Chapter(order: 0)
        XCTAssertEqual(chapter.order, 0)
        XCTAssertEqual(chapter.title, "Untitled Chapter")
        XCTAssertEqual(chapter.synopsis, "")
        XCTAssertEqual(chapter.notes, "")
        XCTAssertNotNil(chapter.id)
    }

    func testCustomInit() {
        let chapter = Chapter(order: 3, title: "The Beginning", synopsis: "It all starts here", notes: "Draft 1")
        XCTAssertEqual(chapter.order, 3)
        XCTAssertEqual(chapter.title, "The Beginning")
        XCTAssertEqual(chapter.synopsis, "It all starts here")
        XCTAssertEqual(chapter.notes, "Draft 1")
    }

    // MARK: - Timestamps

    func testTouchUpdatesModifiedAt() {
        var chapter = Chapter(order: 0)
        let original = chapter.modifiedAt
        // Small delay to ensure timestamp changes
        Thread.sleep(forTimeInterval: 0.01)
        chapter.touch()
        XCTAssertGreaterThan(chapter.modifiedAt, original)
    }

    // MARK: - Number Label

    func testNumberLabel() {
        let chapter = Chapter(order: 0, title: "Test")
        XCTAssertEqual(chapter.numberLabel(at: 0), "Chapter 1")
        XCTAssertEqual(chapter.numberLabel(at: 4), "Chapter 5")
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let original = Chapter(order: 2, title: "Encoded", synopsis: "Test encoding", notes: "Note")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Chapter.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.order, original.order)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.synopsis, original.synopsis)
        XCTAssertEqual(decoded.notes, original.notes)
    }

    // MARK: - Identity

    func testUniqueIds() {
        let a = Chapter(order: 0)
        let b = Chapter(order: 1)
        XCTAssertNotEqual(a.id, b.id)
    }
}
