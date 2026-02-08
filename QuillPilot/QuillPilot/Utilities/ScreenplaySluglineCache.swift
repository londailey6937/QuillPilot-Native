import Foundation

/// Caches screenplay sluglines derived from the active editor text.
///
/// This exists so metadata-only UI (Scenes window / Scene Inspector) can display
/// a slugline annotation without directly touching the editor.
final class ScreenplaySluglineCache {

    static let shared = ScreenplaySluglineCache()

    private let queue = DispatchQueue(label: "QuillPilot.ScreenplaySluglineCache", qos: .userInitiated)
    private var sluglinesByDocumentKey: [String: [String]] = [:]

    private init() {}

    private func documentKey(for documentURL: URL?) -> String {
        guard let url = documentURL else {
            return "QuillPilot.Scenes.Untitled"
        }
        return "QuillPilot.Scenes.\(url.path)"
    }

    func setSluglines(_ sluglines: [String], for documentURL: URL?) {
        let key = documentKey(for: documentURL)
        queue.async {
            self.sluglinesByDocumentKey[key] = sluglines
        }
    }

    func slugline(for documentURL: URL?, sceneOrder: Int) -> String? {
        guard sceneOrder >= 0 else { return nil }
        let key = documentKey(for: documentURL)
        return queue.sync {
            guard let sluglines = sluglinesByDocumentKey[key] else { return nil }
            guard sceneOrder < sluglines.count else { return nil }
            let slug = sluglines[sceneOrder].trimmingCharacters(in: .whitespacesAndNewlines)
            return slug.isEmpty ? nil : slug
        }
    }
}
