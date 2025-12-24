import Foundation

// MARK: - Scene Manager
/// Manages the collection of scenes and chapters for a project.
/// IMPORTANT: This manager handles metadata ONLY. It never accesses
/// the main document editor to avoid any risk of corruption.
final class SceneManager {

    // MARK: - Storage
    private(set) var scenes: [Scene] = []
    private(set) var chapters: [Chapter] = []

    // MARK: - Scene CRUD

    func addScene(_ scene: Scene) {
        scenes.append(scene)
        sortScenes()
    }

    func updateScene(_ scene: Scene) {
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
            var updated = scene
            updated.touch()
            scenes[index] = updated
        }
    }

    func deleteScene(id: UUID) {
        scenes.removeAll { $0.id == id }
        reorderScenes()
    }

    func scene(withId id: UUID) -> Scene? {
        scenes.first { $0.id == id }
    }

    func moveScene(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < scenes.count,
              destinationIndex >= 0, destinationIndex < scenes.count else {
            return
        }

        let scene = scenes.remove(at: sourceIndex)
        scenes.insert(scene, at: destinationIndex)
        reorderScenes()
    }

    // MARK: - Chapter CRUD

    func addChapter(_ chapter: Chapter) {
        chapters.append(chapter)
        sortChapters()
    }

    func updateChapter(_ chapter: Chapter) {
        if let index = chapters.firstIndex(where: { $0.id == chapter.id }) {
            var updated = chapter
            updated.touch()
            chapters[index] = updated
        }
    }

    func deleteChapter(id: UUID) {
        // Unassign scenes from deleted chapter
        for i in scenes.indices where scenes[i].chapterId == id {
            scenes[i].chapterId = nil
        }
        chapters.removeAll { $0.id == id }
        reorderChapters()
    }

    func chapter(withId id: UUID) -> Chapter? {
        chapters.first { $0.id == id }
    }

    // MARK: - Queries

    /// Returns scenes belonging to a specific chapter, sorted by order
    func scenes(inChapter chapterId: UUID) -> [Scene] {
        scenes.filter { $0.chapterId == chapterId }.sorted { $0.order < $1.order }
    }

    /// Returns scenes not assigned to any chapter
    func unassignedScenes() -> [Scene] {
        scenes.filter { $0.chapterId == nil }.sorted { $0.order < $1.order }
    }

    /// Returns scenes filtered by revision state
    func scenes(withState state: RevisionState) -> [Scene] {
        scenes.filter { $0.revisionState == state }
    }

    /// Returns scenes filtered by intent
    func scenes(withIntent intent: SceneIntent) -> [Scene] {
        scenes.filter { $0.intent == intent }
    }

    /// Assigns a scene to a chapter
    func assignScene(_ sceneId: UUID, toChapter chapterId: UUID?) {
        if let index = scenes.firstIndex(where: { $0.id == sceneId }) {
            scenes[index].chapterId = chapterId
            scenes[index].touch()
        }
    }

    /// Returns total scene count
    var sceneCount: Int { scenes.count }

    /// Returns total chapter count
    var chapterCount: Int { chapters.count }

    // MARK: - Persistence

    /// Encodes scenes and chapters to JSON data
    func encode() throws -> Data {
        let container = SceneManagerData(scenes: scenes, chapters: chapters)
        return try JSONEncoder().encode(container)
    }

    /// Decodes scenes and chapters from JSON data
    func decode(from data: Data) throws {
        let container = try JSONDecoder().decode(SceneManagerData.self, from: data)
        self.scenes = container.scenes
        self.chapters = container.chapters
        sortScenes()
        sortChapters()
    }

    /// Clears all data
    func clear() {
        scenes.removeAll()
        chapters.removeAll()
    }

    // MARK: - Private Helpers

    private func sortScenes() {
        scenes.sort { $0.order < $1.order }
    }

    private func sortChapters() {
        chapters.sort { $0.order < $1.order }
    }

    private func reorderScenes() {
        for i in scenes.indices {
            scenes[i].order = i
        }
    }

    private func reorderChapters() {
        for i in chapters.indices {
            chapters[i].order = i
        }
    }
}

// MARK: - Persistence Container
private struct SceneManagerData: Codable {
    let scenes: [Scene]
    let chapters: [Chapter]
}
