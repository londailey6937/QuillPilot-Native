//
//  DocumentFieldsManager.swift
//  QuillPilot
//
//  Manages bookmarks and cross-references using a Word-like field model.
//  Bookmarks are named anchors; cross-references are fields that point to targets.
//

import Cocoa

// MARK: - Attribute Keys for Field Storage

extension NSAttributedString.Key {
    /// Marks a bookmark anchor. Value is the bookmark ID (String).
    static let qpBookmarkID = NSAttributedString.Key("QPBookmarkID")
    /// Marks a bookmark's name for display/lookup. Value is the bookmark name (String).
    static let qpBookmarkName = NSAttributedString.Key("QPBookmarkName")
    /// Marks a cross-reference field. Value is CrossReferenceField encoded as Data.
    static let qpCrossReferenceField = NSAttributedString.Key("QPCrossReferenceField")
}

// MARK: - Bookmark Target

/// Represents a referenceable target in the document.
struct BookmarkTarget: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let type: TargetType

    enum TargetType: String, Codable, CaseIterable {
        case bookmark = "Bookmark"
        case heading = "Heading"
        case caption = "Caption"
        case footnote = "Footnote"
        case endnote = "Endnote"
        case numberedItem = "Numbered Item"
    }

    static func generateID() -> String {
        "_Ref\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))"
    }
}

// MARK: - Cross-Reference Field

/// Represents a cross-reference field that points to a target.
struct CrossReferenceField: Codable, Equatable {
    let targetID: String
    let displayMode: DisplayMode
    let isHyperlink: Bool

    enum DisplayMode: String, Codable, CaseIterable {
        case text = "Text"
        case pageNumber = "Page Number"
        case paragraphNumber = "Paragraph Number"
        case aboveBelow = "Above/Below"
        case fullContext = "Full Context"

        var description: String {
            switch self {
            case .text: return "Referenced text"
            case .pageNumber: return "Page number"
            case .paragraphNumber: return "Paragraph/item number"
            case .aboveBelow: return "Relative position (above/below)"
            case .fullContext: return "Full context with page"
            }
        }
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> CrossReferenceField? {
        try? JSONDecoder().decode(CrossReferenceField.self, from: data)
    }
}

// MARK: - Document Fields Manager

/// Manages bookmarks and cross-references for a document.
/// This is designed to be held by the EditorViewController for each document.
@MainActor
class DocumentFieldsManager {

    /// All registered bookmarks in the document, keyed by ID.
    private(set) var bookmarks: [String: BookmarkTarget] = [:]

    /// Reverse lookup: bookmark name → ID
    private var nameToID: [String: String] = [:]

    weak var textStorage: NSTextStorage?

    init(textStorage: NSTextStorage? = nil) {
        self.textStorage = textStorage
    }

    // MARK: - Bookmark Management

    /// Register a new bookmark at a location.
    func createBookmark(name: String, type: BookmarkTarget.TargetType = .bookmark) -> BookmarkTarget {
        // Check for existing bookmark with same name
        if let existingID = nameToID[name], let existing = bookmarks[existingID] {
            return existing
        }

        let id = BookmarkTarget.generateID()
        let bookmark = BookmarkTarget(id: id, name: name, type: type)
        bookmarks[id] = bookmark
        nameToID[name] = id
        return bookmark
    }

    /// Remove a bookmark by ID.
    func removeBookmark(id: String) {
        if let bookmark = bookmarks[id] {
            nameToID.removeValue(forKey: bookmark.name)
            bookmarks.removeValue(forKey: id)
        }
    }

    /// Find a bookmark by name.
    func bookmark(named name: String) -> BookmarkTarget? {
        guard let id = nameToID[name] else { return nil }
        return bookmarks[id]
    }

    /// Find a bookmark by ID.
    func bookmark(withID id: String) -> BookmarkTarget? {
        bookmarks[id]
    }

    /// Get all bookmarks sorted by name.
    func allBookmarksSorted() -> [BookmarkTarget] {
        bookmarks.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Rename a bookmark.
    func renameBookmark(id: String, newName: String) -> Bool {
        guard var bookmark = bookmarks[id] else { return false }

        // Check if new name is already taken
        if let existingID = nameToID[newName], existingID != id {
            return false
        }

        nameToID.removeValue(forKey: bookmark.name)
        bookmark = BookmarkTarget(id: id, name: newName, type: bookmark.type)
        bookmarks[id] = bookmark
        nameToID[newName] = id
        return true
    }

    // MARK: - Scanning for Targets

    /// Scan the text storage and collect all referenceable targets (headings, captions, etc.)
    func collectReferenceableTargets() -> [BookmarkTarget] {
        var targets: [BookmarkTarget] = []

        // Add explicit bookmarks
        targets.append(contentsOf: allBookmarksSorted())

        // Scan for headings and other structural elements
        guard let storage = textStorage else { return targets }

        let fullString = storage.string as NSString
        var location = 0

        let headingStyles: Set<String> = [
            "Heading 1", "Heading 2", "Heading 3",
            "Chapter Title", "Chapter Number",
            "Part Title", "Book Title"
        ]

        let captionStyles: Set<String> = [
            "Figure Caption", "Table Caption"
        ]

        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else { break }

            let styleName = storage.attribute(NSAttributedString.Key("QuillStyleName"), at: paragraphRange.location, effectiveRange: nil) as? String

            if let style = styleName {
                let text = fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    if headingStyles.contains(style) {
                        // Create/find heading bookmark
                        let name = "Heading: \(text.prefix(50))"
                        if bookmark(named: name) == nil {
                            let target = createBookmark(name: name, type: .heading)
                            targets.append(target)
                        }
                    } else if captionStyles.contains(style) {
                        let name = "Caption: \(text.prefix(50))"
                        if bookmark(named: name) == nil {
                            let target = createBookmark(name: name, type: .caption)
                            targets.append(target)
                        }
                    }
                }
            }

            location = NSMaxRange(paragraphRange)
        }

        return targets
    }

    // MARK: - Cross-Reference Resolution

    /// Find the location of a bookmark in the text storage.
    func findBookmarkLocation(id: String) -> Int? {
        guard let storage = textStorage else { return nil }

        var foundLocation: Int?
        storage.enumerateAttribute(.qpBookmarkID, in: NSRange(location: 0, length: storage.length), options: []) { value, range, stop in
            if let bookmarkID = value as? String, bookmarkID == id {
                foundLocation = range.location
                stop.pointee = true
            }
        }
        return foundLocation
    }

    /// Get the text at a bookmark location.
    func getBookmarkText(id: String) -> String? {
        guard let storage = textStorage, let location = findBookmarkLocation(id: id) else { return nil }

        let fullString = storage.string as NSString
        let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
        return fullString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get the page number for a bookmark (requires page layout callback).
    func getBookmarkPage(id: String, pageNumberCallback: (Int) -> Int?) -> Int? {
        guard let location = findBookmarkLocation(id: id) else { return nil }
        return pageNumberCallback(location)
    }

    /// Resolve a cross-reference field to its display text.
    func resolveField(_ field: CrossReferenceField, referenceLocation: Int, pageNumberCallback: (Int) -> Int?) -> String {
        guard let bookmark = bookmark(withID: field.targetID) else {
            return "[Ref not found]"
        }

        switch field.displayMode {
        case .text:
            return getBookmarkText(id: field.targetID) ?? bookmark.name

        case .pageNumber:
            if let page = getBookmarkPage(id: field.targetID, pageNumberCallback: pageNumberCallback) {
                return "\(page)"
            }
            return "[Page ?]"

        case .paragraphNumber:
            // Would need paragraph numbering logic
            return bookmark.name

        case .aboveBelow:
            if let targetLoc = findBookmarkLocation(id: field.targetID) {
                return targetLoc < referenceLocation ? "above" : "below"
            }
            return "[Position ?]"

        case .fullContext:
            let text = getBookmarkText(id: field.targetID) ?? bookmark.name
            if let page = getBookmarkPage(id: field.targetID, pageNumberCallback: pageNumberCallback) {
                return "\(text) on page \(page)"
            }
            return text
        }
    }

    // MARK: - Field Updates

    /// Update all cross-reference fields in the document.
    func updateAllFields(pageNumberCallback: @escaping (Int) -> Int?) {
        guard let storage = textStorage else { return }

        var fieldsToUpdate: [(range: NSRange, field: CrossReferenceField)] = []

        // Collect all cross-reference fields
        storage.enumerateAttribute(.qpCrossReferenceField, in: NSRange(location: 0, length: storage.length), options: []) { value, range, _ in
            if let data = value as? Data, let field = CrossReferenceField.decode(from: data) {
                fieldsToUpdate.append((range, field))
            }
        }

        // Update in reverse order to preserve ranges
        fieldsToUpdate.sort { $0.range.location > $1.range.location }

        storage.beginEditing()
        for (range, field) in fieldsToUpdate {
            let newText = resolveField(field, referenceLocation: range.location, pageNumberCallback: pageNumberCallback)

            // Preserve attributes except the text
            let existingAttrs = storage.attributes(at: range.location, effectiveRange: nil)
            let replacement = NSAttributedString(string: newText, attributes: existingAttrs)
            storage.replaceCharacters(in: range, with: replacement)
        }
        storage.endEditing()
    }

    // MARK: - Serialization

    /// Export bookmarks to JSON for document saving.
    func exportBookmarks() -> Data? {
        try? JSONEncoder().encode(Array(bookmarks.values))
    }

    /// Import bookmarks from JSON when loading a document.
    func importBookmarks(from data: Data) {
        guard let loaded = try? JSONDecoder().decode([BookmarkTarget].self, from: data) else { return }
        bookmarks.removeAll()
        nameToID.removeAll()
        for bookmark in loaded {
            bookmarks[bookmark.id] = bookmark
            nameToID[bookmark.name] = bookmark.id
        }
    }

    /// Clear all bookmarks (for new document).
    func clearAll() {
        bookmarks.removeAll()
        nameToID.removeAll()
    }
}
