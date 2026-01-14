import Foundation

/// Per-document story development notes (Theme, Locations, Outline, Directions).
///
/// Stored alongside the document as a JSON sidecar:
/// `MyStory.docx.storynotes.json`
final class StoryNotesStore {
    static let shared = StoryNotesStore()

    struct Notes: Codable {
        var theme: String
        var locations: String
        var outline: String
        var directions: String

        static let empty = Notes(theme: "", locations: "", outline: "", directions: "")
    }

    private(set) var currentDocumentURL: URL?
    private(set) var notes: Notes = .empty

    private init() {}

    private func notesURL(for documentURL: URL) -> URL {
        documentURL.appendingPathExtension("storynotes.json")
    }

    /// Load notes for a document. Also becomes the active document for this store.
    @discardableResult
    func load(for documentURL: URL?) -> Notes {
        currentDocumentURL = documentURL

        guard let documentURL else {
            notes = .empty
            return notes
        }

        let url = notesURL(for: documentURL)
        do {
            let data = try Data(contentsOf: url)
            notes = try JSONDecoder().decode(Notes.self, from: data)
        } catch {
            notes = .empty
        }
        return notes
    }

    func setDocumentURL(_ url: URL?) {
        currentDocumentURL = url

        // If we have unsaved notes in memory, persist them once a concrete URL exists.
        if url != nil {
            save()
        }
    }

    func updateTheme(_ theme: String) {
        notes.theme = theme
        save()
    }

    func updateLocations(_ locations: String) {
        notes.locations = locations
        save()
    }

    func updateOutline(_ outline: String) {
        notes.outline = outline
        save()
    }

    func updateDirections(_ directions: String) {
        notes.directions = directions
        save()
    }

    func save() {
        guard let documentURL = currentDocumentURL else { return }
        let url = notesURL(for: documentURL)
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: url, options: .atomic)
        } catch {
            // Best-effort; notes are non-critical.
        }
    }
}
