//
//  DraftVersion.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation

// MARK: - Draft Version Model

/// Represents a saved draft version of a document
struct DraftVersion: Codable, Identifiable {
    let id: UUID
    let documentId: String  // Reference to the parent document
    var versionNumber: Int
    var title: String
    var content: String
    var fileReference: String?
    var notes: String
    var createdAt: Date
    var wordCount: Int
    var characterCount: Int

    init(
        id: UUID = UUID(),
        documentId: String,
        versionNumber: Int,
        title: String = "",
        content: String,
        fileReference: String? = nil,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.versionNumber = versionNumber
        self.title = title.isEmpty ? "Draft \(versionNumber)" : title
        self.content = content
        self.fileReference = fileReference
        self.notes = notes
        self.createdAt = createdAt
        self.wordCount = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        self.characterCount = content.count
    }
}

// MARK: - Draft Comparison

struct DraftComparison {
    let older: DraftVersion
    let newer: DraftVersion

    var wordCountDifference: Int {
        newer.wordCount - older.wordCount
    }

    var characterCountDifference: Int {
        newer.characterCount - older.characterCount
    }

    var addedLines: [String] {
        let oldLines = Set(older.content.components(separatedBy: .newlines))
        let newLines = newer.content.components(separatedBy: .newlines)
        return newLines.filter { !oldLines.contains($0) && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var removedLines: [String] {
        let newLines = Set(newer.content.components(separatedBy: .newlines))
        let oldLines = older.content.components(separatedBy: .newlines)
        return oldLines.filter { !newLines.contains($0) && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Simple diff showing changes
    func generateDiff() -> String {
        var diff = "Comparison: Draft \(older.versionNumber) → Draft \(newer.versionNumber)\n"
        diff += String(repeating: "─", count: 50) + "\n\n"

        diff += "Statistics:\n"
        diff += "  Words: \(older.wordCount) → \(newer.wordCount) (\(wordCountDifference >= 0 ? "+" : "")\(wordCountDifference))\n"
        diff += "  Characters: \(older.characterCount) → \(newer.characterCount) (\(characterCountDifference >= 0 ? "+" : "")\(characterCountDifference))\n\n"

        if !addedLines.isEmpty {
            diff += "Added lines (\(addedLines.count)):\n"
            for line in addedLines.prefix(10) {
                diff += "+ \(line)\n"
            }
            if addedLines.count > 10 {
                diff += "  ... and \(addedLines.count - 10) more\n"
            }
            diff += "\n"
        }

        if !removedLines.isEmpty {
            diff += "Removed lines (\(removedLines.count)):\n"
            for line in removedLines.prefix(10) {
                diff += "- \(line)\n"
            }
            if removedLines.count > 10 {
                diff += "  ... and \(removedLines.count - 10) more\n"
            }
        }

        return diff
    }
}

// MARK: - Draft Manager

/// Manages draft versions for documents
final class DraftVersionManager {

    static let shared = DraftVersionManager()

    private let draftsKey = "draftVersions"
    private var drafts: [String: [DraftVersion]] = [:]  // documentId -> versions

    private init() {
        loadDrafts()
    }

    // MARK: - CRUD Operations

    /// Save a new draft version for a document
    func saveDraft(documentId: String, content: String, fileReference: String? = nil, notes: String = "", title: String = "") -> DraftVersion {
        var documentDrafts = drafts[documentId] ?? []

        let nextVersion = (documentDrafts.map { $0.versionNumber }.max() ?? 0) + 1
        let draft = DraftVersion(
            documentId: documentId,
            versionNumber: nextVersion,
            title: title,
            content: content,
            fileReference: fileReference,
            notes: notes
        )

        documentDrafts.append(draft)
        drafts[documentId] = documentDrafts
        saveDrafts()

        return draft
    }

    /// Get all drafts for a document
    func getDrafts(for documentId: String) -> [DraftVersion] {
        (drafts[documentId] ?? []).sorted { $0.versionNumber > $1.versionNumber }
    }

    /// Get a specific draft
    func getDraft(id: UUID, documentId: String) -> DraftVersion? {
        drafts[documentId]?.first { $0.id == id }
    }

    /// Get the latest draft
    func getLatestDraft(for documentId: String) -> DraftVersion? {
        getDrafts(for: documentId).first
    }

    /// Update draft notes
    func updateDraftNotes(id: UUID, documentId: String, notes: String) {
        guard var documentDrafts = drafts[documentId],
              let index = documentDrafts.firstIndex(where: { $0.id == id }) else { return }

        documentDrafts[index].notes = notes
        drafts[documentId] = documentDrafts
        saveDrafts()
    }

    /// Update draft title
    func updateDraftTitle(id: UUID, documentId: String, title: String) {
        guard var documentDrafts = drafts[documentId],
              let index = documentDrafts.firstIndex(where: { $0.id == id }) else { return }

        documentDrafts[index].title = title
        drafts[documentId] = documentDrafts
        saveDrafts()
    }

    /// Delete a draft
    func deleteDraft(id: UUID, documentId: String) {
        drafts[documentId]?.removeAll { $0.id == id }
        saveDrafts()
    }

    /// Delete all drafts for a document
    func deleteAllDrafts(for documentId: String) {
        drafts.removeValue(forKey: documentId)
        saveDrafts()
    }

    // MARK: - Comparison

    func compare(draftId1: UUID, draftId2: UUID, documentId: String) -> DraftComparison? {
        guard let draft1 = getDraft(id: draftId1, documentId: documentId),
              let draft2 = getDraft(id: draftId2, documentId: documentId) else { return nil }

        if draft1.versionNumber < draft2.versionNumber {
            return DraftComparison(older: draft1, newer: draft2)
        } else {
            return DraftComparison(older: draft2, newer: draft1)
        }
    }

    /// Compare latest draft with previous
    func compareLatestWithPrevious(documentId: String) -> DraftComparison? {
        let drafts = getDrafts(for: documentId)
        guard drafts.count >= 2 else { return nil }
        return DraftComparison(older: drafts[1], newer: drafts[0])
    }

    // MARK: - Restore

    /// Restore content from a draft
    func getContentFromDraft(id: UUID, documentId: String) -> String? {
        getDraft(id: id, documentId: documentId)?.content
    }

    // MARK: - Persistence

    private func loadDrafts() {
        guard let data = UserDefaults.standard.data(forKey: draftsKey) else { return }
        do {
            drafts = try JSONDecoder().decode([String: [DraftVersion]].self, from: data)
        } catch {
            print("Failed to load drafts: \(error)")
        }
    }

    private func saveDrafts() {
        do {
            let data = try JSONEncoder().encode(drafts)
            UserDefaults.standard.set(data, forKey: draftsKey)
        } catch {
            print("Failed to save drafts: \(error)")
        }
    }

    // MARK: - Cleanup

    /// Keep only the last N drafts for a document
    func pruneOldDrafts(documentId: String, keepCount: Int = 10) {
        guard var documentDrafts = drafts[documentId], documentDrafts.count > keepCount else { return }

        documentDrafts.sort { $0.versionNumber > $1.versionNumber }
        drafts[documentId] = Array(documentDrafts.prefix(keepCount))
        saveDrafts()
    }
}
