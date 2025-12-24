import Foundation

// MARK: - Chapter Model
/// A chapter groups multiple scenes together.
/// This is purely organizational metadata - it does NOT touch the editor.
struct Chapter: Identifiable, Codable {
    let id: UUID
    var order: Int
    var title: String
    var synopsis: String
    var notes: String

    // Timestamps
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        order: Int,
        title: String = "Untitled Chapter",
        synopsis: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.synopsis = synopsis
        self.notes = notes
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    mutating func touch() {
        modifiedAt = Date()
    }
}

extension Chapter {
    /// Returns the number label (Chapter 1, Chapter 2, etc.)
    func numberLabel(at index: Int) -> String {
        "Chapter \(index + 1)"
    }
}
