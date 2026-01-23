//
//  NotesManager.swift
//  QuillPilot
//
//  Manages footnotes and endnotes using a Word-like structured object model.
//  Each note is a distinct object with a unique ID, reference marker, and note body.
//

import Cocoa

// MARK: - Attribute Keys for Note Storage

extension NSAttributedString.Key {
    /// Marks a footnote reference in the main text. Value is the note ID (String).
    static let qpFootnoteRef = NSAttributedString.Key("QPFootnoteRef")
    /// Marks an endnote reference in the main text. Value is the note ID (String).
    static let qpEndnoteRef = NSAttributedString.Key("QPEndnoteRef")
}

// MARK: - Note Types

enum NoteType: String, Codable, CaseIterable {
    case footnote = "Footnote"
    case endnote = "Endnote"

    var attributeKey: NSAttributedString.Key {
        switch self {
        case .footnote: return .qpFootnoteRef
        case .endnote: return .qpEndnoteRef
        }
    }
}

// MARK: - Note Numbering Style

enum NoteNumberingStyle: String, Codable, CaseIterable {
    case arabic = "1, 2, 3..."
    case romanLower = "i, ii, iii..."
    case romanUpper = "I, II, III..."
    case alphabetLower = "a, b, c..."
    case alphabetUpper = "A, B, C..."
    case symbols = "*, †, ‡..."

    func format(number: Int) -> String {
        switch self {
        case .arabic:
            return "\(number)"
        case .romanLower:
            return romanNumeral(for: number).lowercased()
        case .romanUpper:
            return romanNumeral(for: number)
        case .alphabetLower:
            return alphabeticLabel(for: number).lowercased()
        case .alphabetUpper:
            return alphabeticLabel(for: number)
        case .symbols:
            return symbolLabel(for: number)
        }
    }

    private func romanNumeral(for number: Int) -> String {
        let values = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
                      (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
                      (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var result = ""
        var remaining = number
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }

    private func alphabeticLabel(for number: Int) -> String {
        var result = ""
        var n = number
        while n > 0 {
            n -= 1
            result = String(UnicodeScalar(65 + (n % 26))!) + result
            n /= 26
        }
        return result
    }

    private func symbolLabel(for number: Int) -> String {
        let symbols = ["*", "†", "‡", "§", "‖", "¶"]
        let cycles = (number - 1) / symbols.count + 1
        let symbol = symbols[(number - 1) % symbols.count]
        return String(repeating: symbol, count: cycles)
    }
}

// MARK: - Note Restart Mode

enum NoteRestartMode: String, Codable, CaseIterable {
    case continuous = "Continuous"
    case eachSection = "Each Section"
    case eachPage = "Each Page"
}

// MARK: - Note Object

/// Represents a single footnote or endnote.
struct Note: Codable, Equatable, Identifiable {
    let id: String
    let type: NoteType
    var content: String
    var createdAt: Date

    init(type: NoteType, content: String = "") {
        self.id = Note.generateID()
        self.type = type
        self.content = content
        self.createdAt = Date()
    }

    static func generateID() -> String {
        "_Note\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))"
    }
}

// MARK: - Notes Manager

/// Manages all footnotes and endnotes for a document.
@MainActor
class NotesManager {

    /// All footnotes, keyed by ID, ordered by document position.
    private(set) var footnotes: [String: Note] = [:]

    /// All endnotes, keyed by ID, ordered by document position.
    private(set) var endnotes: [String: Note] = [:]

    /// Footnote numbering style
    var footnoteNumberingStyle: NoteNumberingStyle = .arabic

    /// Endnote numbering style
    var endnoteNumberingStyle: NoteNumberingStyle = .romanLower

    /// When to restart footnote numbering
    var footnoteRestartMode: NoteRestartMode = .continuous

    /// Reference to the document's text storage
    weak var textStorage: NSTextStorage?

    init(textStorage: NSTextStorage? = nil) {
        self.textStorage = textStorage
    }

    // MARK: - Note Creation

    /// Create a new footnote.
    func createFootnote(content: String = "") -> Note {
        let note = Note(type: .footnote, content: content)
        footnotes[note.id] = note
        return note
    }

    /// Create a new endnote.
    func createEndnote(content: String = "") -> Note {
        let note = Note(type: .endnote, content: content)
        endnotes[note.id] = note
        return note
    }

    // MARK: - Note Retrieval

    /// Get a note by ID.
    func note(withID id: String) -> Note? {
        return footnotes[id] ?? endnotes[id]
    }

    /// Get all footnotes sorted by their position in the document.
    func footnotesSortedByPosition() -> [Note] {
        guard let storage = textStorage else {
            return Array(footnotes.values).sorted { $0.createdAt < $1.createdAt }
        }

        var positions: [String: Int] = [:]
        storage.enumerateAttribute(.qpFootnoteRef, in: NSRange(location: 0, length: storage.length), options: []) { value, range, _ in
            if let noteID = value as? String {
                positions[noteID] = range.location
            }
        }

        return footnotes.values.sorted { note1, note2 in
            let pos1 = positions[note1.id] ?? Int.max
            let pos2 = positions[note2.id] ?? Int.max
            return pos1 < pos2
        }
    }

    /// Get all endnotes sorted by their position in the document.
    func endnotesSortedByPosition() -> [Note] {
        guard let storage = textStorage else {
            return Array(endnotes.values).sorted { $0.createdAt < $1.createdAt }
        }

        var positions: [String: Int] = [:]
        storage.enumerateAttribute(.qpEndnoteRef, in: NSRange(location: 0, length: storage.length), options: []) { value, range, _ in
            if let noteID = value as? String {
                positions[noteID] = range.location
            }
        }

        return endnotes.values.sorted { note1, note2 in
            let pos1 = positions[note1.id] ?? Int.max
            let pos2 = positions[note2.id] ?? Int.max
            return pos1 < pos2
        }
    }

    // MARK: - Note Numbering

    /// Get the display number for a footnote.
    func footnoteNumber(for noteID: String) -> Int {
        let sorted = footnotesSortedByPosition()
        guard let index = sorted.firstIndex(where: { $0.id == noteID }) else { return 0 }
        return index + 1
    }

    /// Get the display number for an endnote.
    func endnoteNumber(for noteID: String) -> Int {
        let sorted = endnotesSortedByPosition()
        guard let index = sorted.firstIndex(where: { $0.id == noteID }) else { return 0 }
        return index + 1
    }

    /// Get the formatted marker text for a footnote.
    func footnoteMarker(for noteID: String) -> String {
        let number = footnoteNumber(for: noteID)
        return footnoteNumberingStyle.format(number: number)
    }

    /// Get the formatted marker text for an endnote.
    func endnoteMarker(for noteID: String) -> String {
        let number = endnoteNumber(for: noteID)
        return endnoteNumberingStyle.format(number: number)
    }

    // MARK: - Note Modification

    /// Update a note's content.
    func updateNoteContent(id: String, content: String) {
        if var note = footnotes[id] {
            note.content = content
            footnotes[id] = note
        } else if var note = endnotes[id] {
            note.content = content
            endnotes[id] = note
        }
    }

    /// Delete a note (also removes its reference from the document).
    func deleteNote(id: String) {
        footnotes.removeValue(forKey: id)
        endnotes.removeValue(forKey: id)

        // Remove the reference from the text storage
        removeNoteReference(id: id)
    }

    /// Remove a note reference from the text storage.
    private func removeNoteReference(id: String) {
        guard let storage = textStorage else { return }

        // Find and remove the note reference
        var rangeToRemove: NSRange?

        storage.enumerateAttributes(in: NSRange(location: 0, length: storage.length), options: []) { attrs, range, stop in
            if let noteID = attrs[.qpFootnoteRef] as? String, noteID == id {
                rangeToRemove = range
                stop.pointee = true
            } else if let noteID = attrs[.qpEndnoteRef] as? String, noteID == id {
                rangeToRemove = range
                stop.pointee = true
            }
        }

        if let range = rangeToRemove {
            storage.beginEditing()
            storage.deleteCharacters(in: range)
            storage.endEditing()
        }
    }

    // MARK: - Conversion

    /// Convert a footnote to an endnote.
    func convertFootnoteToEndnote(id: String) {
        guard let note = footnotes.removeValue(forKey: id) else { return }
        let endnote = Note(type: .endnote, content: note.content)
        endnotes[endnote.id] = endnote

        // Update the reference in the text storage
        updateNoteReferenceType(oldID: id, newID: endnote.id, newType: .endnote)
    }

    /// Convert an endnote to a footnote.
    func convertEndnoteToFootnote(id: String) {
        guard let note = endnotes.removeValue(forKey: id) else { return }
        let footnote = Note(type: .footnote, content: note.content)
        footnotes[footnote.id] = footnote

        // Update the reference in the text storage
        updateNoteReferenceType(oldID: id, newID: footnote.id, newType: .footnote)
    }

    /// Update a note reference's type in the text storage.
    private func updateNoteReferenceType(oldID: String, newID: String, newType: NoteType) {
        guard let storage = textStorage else { return }

        storage.enumerateAttributes(in: NSRange(location: 0, length: storage.length), options: []) { attrs, range, stop in
            let isFootnote = attrs[.qpFootnoteRef] as? String == oldID
            let isEndnote = attrs[.qpEndnoteRef] as? String == oldID

            if isFootnote || isEndnote {
                storage.beginEditing()
                storage.removeAttribute(.qpFootnoteRef, range: range)
                storage.removeAttribute(.qpEndnoteRef, range: range)
                storage.addAttribute(newType.attributeKey, value: newID, range: range)
                storage.endEditing()
                stop.pointee = true
            }
        }
    }

    // MARK: - Document Position Lookup

    /// Find the location of a note reference in the text storage.
    func findNoteReferenceLocation(id: String) -> Int? {
        guard let storage = textStorage else { return nil }

        var foundLocation: Int?

        storage.enumerateAttributes(in: NSRange(location: 0, length: storage.length), options: []) { attrs, range, stop in
            if (attrs[.qpFootnoteRef] as? String == id) || (attrs[.qpEndnoteRef] as? String == id) {
                foundLocation = range.location
                stop.pointee = true
            }
        }

        return foundLocation
    }

    // MARK: - Update All Note Markers

    /// Update all footnote and endnote markers in the document to reflect current numbering.
    func updateAllNoteMarkers() {
        guard let storage = textStorage else { return }

        var updates: [(range: NSRange, noteID: String, type: NoteType)] = []

        // Collect all note references
        storage.enumerateAttributes(in: NSRange(location: 0, length: storage.length), options: []) { attrs, range, _ in
            if let noteID = attrs[.qpFootnoteRef] as? String {
                updates.append((range, noteID, .footnote))
            } else if let noteID = attrs[.qpEndnoteRef] as? String {
                updates.append((range, noteID, .endnote))
            }
        }

        // Sort by position descending so replacements don't affect other ranges
        updates.sort { $0.range.location > $1.range.location }

        storage.beginEditing()
        for (range, noteID, type) in updates {
            let marker: String
            switch type {
            case .footnote:
                marker = footnoteMarker(for: noteID)
            case .endnote:
                marker = endnoteMarker(for: noteID)
            }

            // Preserve existing attributes
            let existingAttrs = storage.attributes(at: range.location, effectiveRange: nil)
            let replacement = NSAttributedString(string: marker, attributes: existingAttrs)
            storage.replaceCharacters(in: range, with: replacement)
        }
        storage.endEditing()
    }

    // MARK: - Serialization

    /// Export notes to JSON for document saving.
    func exportNotes() -> Data? {
        let exportData = NotesExportData(
            footnotes: Array(footnotes.values),
            endnotes: Array(endnotes.values),
            footnoteNumberingStyle: footnoteNumberingStyle,
            endnoteNumberingStyle: endnoteNumberingStyle,
            footnoteRestartMode: footnoteRestartMode
        )
        return try? JSONEncoder().encode(exportData)
    }

    /// Import notes from JSON when loading a document.
    func importNotes(from data: Data) {
        guard let importData = try? JSONDecoder().decode(NotesExportData.self, from: data) else { return }

        footnotes.removeAll()
        endnotes.removeAll()

        for note in importData.footnotes {
            footnotes[note.id] = note
        }
        for note in importData.endnotes {
            endnotes[note.id] = note
        }

        footnoteNumberingStyle = importData.footnoteNumberingStyle
        endnoteNumberingStyle = importData.endnoteNumberingStyle
        footnoteRestartMode = importData.footnoteRestartMode
    }

    /// Clear all notes (for new document).
    func clearAll() {
        footnotes.removeAll()
        endnotes.removeAll()
    }
}

// MARK: - Serialization Helper

private struct NotesExportData: Codable {
    let footnotes: [Note]
    let endnotes: [Note]
    let footnoteNumberingStyle: NoteNumberingStyle
    let endnoteNumberingStyle: NoteNumberingStyle
    let footnoteRestartMode: NoteRestartMode
}
