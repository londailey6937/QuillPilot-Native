//
//  PoetryCollection.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation

// MARK: - Poetry Collection Model

/// Represents a collection/chapbook of poems
struct PoetryCollection: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var author: String
    var description: String
    var poems: [PoemEntry]
    var sections: [CollectionSection]
    var createdAt: Date
    var modifiedAt: Date
    var metadata: CollectionMetadata

    // Hashable conformance (using id only for identity)
    static func == (lhs: PoetryCollection, rhs: PoetryCollection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(
        id: UUID = UUID(),
        title: String = "Untitled Collection",
        author: String = "",
        description: String = "",
        poems: [PoemEntry] = [],
        sections: [CollectionSection] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        metadata: CollectionMetadata = CollectionMetadata()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.poems = poems
        self.sections = sections
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.metadata = metadata
    }

    /// Total number of poems
    var poemCount: Int {
        poems.count
    }

    /// Poems organized by section
    var poemsBySection: [CollectionSection: [PoemEntry]] {
        var result: [CollectionSection: [PoemEntry]] = [:]
        for section in sections {
            result[section] = poems.filter { $0.sectionId == section.id }
        }
        // Unsectioned poems
        let unsectioned = poems.filter { poem in
            !sections.contains { $0.id == poem.sectionId }
        }
        if !unsectioned.isEmpty {
            let defaultSection = CollectionSection(id: UUID(), title: "Uncategorized", order: -1)
            result[defaultSection] = unsectioned
        }
        return result
    }
}

/// A poem entry in the collection
struct PoemEntry: Codable, Identifiable {
    let id: UUID
    var title: String
    var order: Int
    var sectionId: UUID?
    var fileReference: String?  // Path or identifier to actual poem file
    var content: String?        // Inline content if not using file reference
    var notes: String
    var tags: [String]
    var addedAt: Date
    var wordCount: Int
    var lineCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        order: Int = 0,
        sectionId: UUID? = nil,
        fileReference: String? = nil,
        content: String? = nil,
        notes: String = "",
        tags: [String] = [],
        addedAt: Date = Date(),
        wordCount: Int = 0,
        lineCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.sectionId = sectionId
        self.fileReference = fileReference
        self.content = content
        self.notes = notes
        self.tags = tags
        self.addedAt = addedAt
        self.wordCount = wordCount
        self.lineCount = lineCount
    }
}

/// A section/chapter in the collection
struct CollectionSection: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var epigraph: String?
    var order: Int

    init(
        id: UUID = UUID(),
        title: String,
        epigraph: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.epigraph = epigraph
        self.order = order
    }
}

/// Metadata for the collection
struct CollectionMetadata: Codable {
    var dedication: String
    var acknowledgments: String
    var aboutAuthor: String
    var isbn: String
    var publisher: String
    var yearPublished: Int?
    var coverImagePath: String?

    init(
        dedication: String = "",
        acknowledgments: String = "",
        aboutAuthor: String = "",
        isbn: String = "",
        publisher: String = "",
        yearPublished: Int? = nil,
        coverImagePath: String? = nil
    ) {
        self.dedication = dedication
        self.acknowledgments = acknowledgments
        self.aboutAuthor = aboutAuthor
        self.isbn = isbn
        self.publisher = publisher
        self.yearPublished = yearPublished
        self.coverImagePath = coverImagePath
    }
}

// MARK: - Collection Manager

/// Manages poetry collections
final class PoetryCollectionManager {

    static let shared = PoetryCollectionManager()

    private let collectionsKey = "poetryCollections"
    private var collections: [PoetryCollection] = []

    private init() {
        loadCollections()
    }

    // MARK: - CRUD Operations

    func createCollection(title: String, author: String = "") -> PoetryCollection {
        let collection = PoetryCollection(title: title, author: author)
        collections.append(collection)
        saveCollections()
        return collection
    }

    func getCollections() -> [PoetryCollection] {
        collections
    }

    func getCollection(id: UUID) -> PoetryCollection? {
        collections.first { $0.id == id }
    }

    func updateCollection(_ collection: PoetryCollection) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            var updated = collection
            updated.modifiedAt = Date()
            collections[index] = updated
            saveCollections()
        }
    }

    func deleteCollection(id: UUID) {
        collections.removeAll { $0.id == id }
        saveCollections()
    }

    // MARK: - Poem Operations

    func addPoem(to collectionId: UUID, title: String, content: String?, fileReference: String? = nil) {
        guard var collection = getCollection(id: collectionId) else { return }

        let order = collection.poems.map { $0.order }.max().map { $0 + 1 } ?? 0
        let poem = PoemEntry(
            title: title,
            order: order,
            fileReference: fileReference,
            content: content,
            wordCount: content?.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count ?? 0,
            lineCount: content?.components(separatedBy: .newlines).count ?? 0
        )

        collection.poems.append(poem)
        updateCollection(collection)
    }

    func removePoem(from collectionId: UUID, poemId: UUID) {
        guard var collection = getCollection(id: collectionId) else { return }
        collection.poems.removeAll { $0.id == poemId }
        updateCollection(collection)
    }

    func movePoem(_ poemId: UUID, from sourceCollectionId: UUID, to destinationCollectionId: UUID, sectionId: UUID? = nil) {
        guard sourceCollectionId != destinationCollectionId else {
            movePoem(poemId, to: sectionId, in: sourceCollectionId)
            return
        }
        guard var source = getCollection(id: sourceCollectionId),
              var destination = getCollection(id: destinationCollectionId) else {
            return
        }
        guard let index = source.poems.firstIndex(where: { $0.id == poemId }) else { return }

        var poem = source.poems.remove(at: index)
        poem.sectionId = sectionId
        poem.order = (destination.poems.map { $0.order }.max().map { $0 + 1 } ?? 0)
        destination.poems.append(poem)

        updateCollection(source)
        updateCollection(destination)
    }

    func reorderPoems(in collectionId: UUID, poemIds: [UUID]) {
        guard var collection = getCollection(id: collectionId) else { return }

        var reordered: [PoemEntry] = []
        for (index, poemId) in poemIds.enumerated() {
            if var poem = collection.poems.first(where: { $0.id == poemId }) {
                poem.order = index
                reordered.append(poem)
            }
        }

        collection.poems = reordered
        updateCollection(collection)
    }

    // MARK: - Section Operations

    func addSection(to collectionId: UUID, title: String) {
        guard var collection = getCollection(id: collectionId) else { return }

        let order = collection.sections.map { $0.order }.max().map { $0 + 1 } ?? 0
        let section = CollectionSection(title: title, order: order)

        collection.sections.append(section)
        updateCollection(collection)
    }

    func movePoem(_ poemId: UUID, to sectionId: UUID?, in collectionId: UUID) {
        guard var collection = getCollection(id: collectionId) else { return }

        if let index = collection.poems.firstIndex(where: { $0.id == poemId }) {
            collection.poems[index].sectionId = sectionId
            // Force a new array instance so SwiftUI reliably refreshes derived section groupings.
            collection.poems = Array(collection.poems)
            updateCollection(collection)
        }
    }

    func removeSection(from collectionId: UUID, sectionId: UUID) {
        guard var collection = getCollection(id: collectionId) else { return }

        // Move any poems in this section back to unsectioned.
        for index in collection.poems.indices {
            if collection.poems[index].sectionId == sectionId {
                collection.poems[index].sectionId = nil
            }
        }

        collection.sections.removeAll { $0.id == sectionId }
        updateCollection(collection)
    }

    // MARK: - Export

    func generateTableOfContents(for collection: PoetryCollection) -> String {
        var toc = "\(collection.title)\n"
        toc += "by \(collection.author)\n\n"
        toc += "Contents\n"
        toc += String(repeating: "─", count: 40) + "\n\n"

        let sortedPoems = collection.poems.sorted { $0.order < $1.order }

        if collection.sections.isEmpty {
            for (index, poem) in sortedPoems.enumerated() {
                toc += "\(index + 1). \(poem.title)\n"
            }
        } else {
            let poemsBySection = collection.poemsBySection
            for section in collection.sections.sorted(by: { $0.order < $1.order }) {
                toc += "\n\(section.title.uppercased())\n"
                if let poems = poemsBySection[section] {
                    for poem in poems.sorted(by: { $0.order < $1.order }) {
                        toc += "    • \(poem.title)\n"
                    }
                }
            }
        }

        return toc
    }

    // MARK: - Persistence

    private func loadCollections() {
        guard let data = UserDefaults.standard.data(forKey: collectionsKey) else { return }
        do {
            collections = try JSONDecoder().decode([PoetryCollection].self, from: data)
        } catch {
            print("Failed to load collections: \(error)")
        }
    }

    private func saveCollections() {
        do {
            let data = try JSONEncoder().encode(collections)
            UserDefaults.standard.set(data, forKey: collectionsKey)
        } catch {
            print("Failed to save collections: \(error)")
        }
    }
}
