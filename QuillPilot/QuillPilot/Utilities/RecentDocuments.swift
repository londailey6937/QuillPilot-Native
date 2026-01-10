import Foundation

/// App-managed recent documents list.
///
/// QuillPilot is not NSDocument-based; also, macOS can disable system-managed recents globally.
/// This store keeps a small MRU list so the Welcome screen + File ▸ Recently Opened work reliably.
final class RecentDocuments {
    static let shared = RecentDocuments()

    private let defaults = UserDefaults.standard
    private let key = "QuillPilot.RecentDocuments.Bookmarks"
    private let maxItems = 12

    private init() {}

    func note(_ url: URL) {
        var urls = recentURLs()
        urls.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        urls.insert(url, at: 0)
        urls = Array(urls.prefix(maxItems))

        let bookmarkData: [Data] = urls.compactMap { u in
            // Use security-scoped bookmarks when available (safe for non-sandbox too).
            return try? u.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        defaults.set(bookmarkData, forKey: key)
    }

    func recentURLs() -> [URL] {
        guard let dataArray = defaults.array(forKey: key) as? [Data] else { return [] }

        var result: [URL] = []
        result.reserveCapacity(min(maxItems, dataArray.count))

        for data in dataArray {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
                result.append(url)
            }
        }

        // De-dupe + keep order.
        var seen = Set<URL>()
        var deduped: [URL] = []
        for url in result {
            let keyURL = url.standardizedFileURL
            if seen.contains(keyURL) { continue }
            seen.insert(keyURL)
            deduped.append(url)
        }
        return Array(deduped.prefix(maxItems))
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
