import Foundation
import CryptoKit

/// Per-document story development notes (Theme, Locations, Outline, Directions).
///
/// Stored per-document as a JSON sidecar.
///
/// As of Jan 2026, these files are stored under:
/// `~/Library/Application Support/Quill Pilot/StoryNotes/`
///
/// Legacy builds stored notes alongside the document as:
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

    static func storyNotesDirectoryURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("Quill Pilot", isDirectory: true)
            .appendingPathComponent("StoryNotes", isDirectory: true)
    }

    private func legacyNotesURL(for documentURL: URL) -> URL {
        documentURL.appendingPathExtension("storynotes.json")
    }

    private func ensureStoryNotesDirectoryExists() {
        guard let dir = Self.storyNotesDirectoryURL() else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            // Best-effort.
        }
    }

    private func stableDocumentIdentityString(for documentURL: URL) -> String {
        // Prefer a filesystem-provided identifier so notes survive renames/moves.
        if let values = try? documentURL.resourceValues(forKeys: [.fileResourceIdentifierKey]),
           let id = values.fileResourceIdentifier {
            return String(describing: id)
        }
        return documentURL.path
    }

    private func shortStableHash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(12))
    }

    private func sanitizedStem(for documentURL: URL) -> String {
        let stem = documentURL.deletingPathExtension().lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleanedScalars = stem.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let cleaned = String(cleanedScalars)
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " _-"))
        return cleaned.isEmpty ? "Document" : cleaned
    }

    private func notesURL(for documentURL: URL) -> URL {
        guard let dir = Self.storyNotesDirectoryURL() else {
            // Fallback to legacy location if Application Support is unavailable for some reason.
            return legacyNotesURL(for: documentURL)
        }

        ensureStoryNotesDirectoryExists()

        let identity = stableDocumentIdentityString(for: documentURL)
        let hash = shortStableHash(identity)
        let stem = sanitizedStem(for: documentURL)
        let filename = "\(stem)-\(hash).storynotes.json"
        return dir.appendingPathComponent(filename, isDirectory: false)
    }

    private func decodeNotes(from url: URL) throws -> Notes {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Notes.self, from: data)
    }

    private func migrateLegacyNotesIfNeeded(for documentURL: URL, destinationURL: URL) -> Notes? {
        let legacyURL = legacyNotesURL(for: documentURL)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return nil }

        do {
            let legacyNotes = try decodeNotes(from: legacyURL)
            notes = legacyNotes
            save() // writes to destinationURL via currentDocumentURL

            // Remove legacy sidecar once we know we can persist successfully.
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: legacyURL)
            }
            return legacyNotes
        } catch {
            return nil
        }
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
            notes = try decodeNotes(from: url)
        } catch {
            // Attempt to migrate from legacy sidecar if present.
            if let migrated = migrateLegacyNotesIfNeeded(for: documentURL, destinationURL: url) {
                notes = migrated
            } else {
                notes = .empty
            }
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
