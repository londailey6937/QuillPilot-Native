//
//  CharacterLibrary.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import Foundation
import CryptoKit

// MARK: - Character Model

enum CharacterRole: String, CaseIterable, Codable {
    case protagonist = "Protagonist"
    case antagonist = "Antagonist"
    case supporting = "Supporting"
    case minor = "Minor"

    var color: NSColor {
        switch self {
        case .protagonist: return .systemBlue
        case .antagonist: return .systemRed
        case .supporting: return .systemGreen
        case .minor: return .systemGray
        }
    }
}

struct CharacterProfile: Codable, Identifiable {
    var id: UUID
    var fullName: String
    var nickname: String
    var role: CharacterRole
    var age: String
    var occupation: String
    var appearance: String
    var background: String
    var education: String
    var residence: String
    var family: String
    var pets: String
    var personalityTraits: [String]
    /// Primary worldview rule the character operates under.
    /// Stored separately but also intended to be included in `principles` for analysis/UI consistency.
    var coreBelief: String
    var principles: [String]
    var skills: [String]
    var motivations: String
    var weaknesses: String
    var connections: String
    var quotes: [String]
    var notes: String

    var isSampleCharacter: Bool

    init(id: UUID = UUID(),
         fullName: String = "",
         nickname: String = "",
         role: CharacterRole = .supporting,
         age: String = "",
         occupation: String = "",
         appearance: String = "",
         background: String = "",
         education: String = "",
         residence: String = "",
         family: String = "",
         pets: String = "",
         personalityTraits: [String] = [],
         coreBelief: String = "",
         principles: [String] = [],
         skills: [String] = [],
         motivations: String = "",
         weaknesses: String = "",
         connections: String = "",
         quotes: [String] = [],
         notes: String = "",
         isSampleCharacter: Bool = false) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
        self.role = role
        self.age = age
        self.occupation = occupation
        self.appearance = appearance
        self.background = background
        self.education = education
        self.residence = residence
        self.family = family
        self.pets = pets
        self.personalityTraits = personalityTraits
        self.coreBelief = coreBelief
        self.principles = principles
        self.skills = skills
        self.motivations = motivations
        self.weaknesses = weaknesses
        self.connections = connections
        self.quotes = quotes
        self.notes = notes
        self.isSampleCharacter = isSampleCharacter
    }

    // Backward-compatible Codable: older saved JSON may not include `coreBelief`.
    enum CodingKeys: String, CodingKey {
        case id
        case fullName
        case nickname
        case role
        case age
        case occupation
        case appearance
        case background
        case education
        case residence
        case family
        case pets
        case personalityTraits
        case coreBelief
        case principles
        case skills
        case motivations
        case weaknesses
        case connections
        case quotes
        case notes
        case isSampleCharacter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        role = (try? container.decode(CharacterRole.self, forKey: .role)) ?? .supporting
        age = try container.decodeIfPresent(String.self, forKey: .age) ?? ""
        occupation = try container.decodeIfPresent(String.self, forKey: .occupation) ?? ""
        appearance = try container.decodeIfPresent(String.self, forKey: .appearance) ?? ""
        background = try container.decodeIfPresent(String.self, forKey: .background) ?? ""
        education = try container.decodeIfPresent(String.self, forKey: .education) ?? ""
        residence = try container.decodeIfPresent(String.self, forKey: .residence) ?? ""
        family = try container.decodeIfPresent(String.self, forKey: .family) ?? ""
        pets = try container.decodeIfPresent(String.self, forKey: .pets) ?? ""
        personalityTraits = try container.decodeIfPresent([String].self, forKey: .personalityTraits) ?? []
        coreBelief = try container.decodeIfPresent(String.self, forKey: .coreBelief) ?? ""
        principles = try container.decodeIfPresent([String].self, forKey: .principles) ?? []
        skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? []
        motivations = try container.decodeIfPresent(String.self, forKey: .motivations) ?? ""
        weaknesses = try container.decodeIfPresent(String.self, forKey: .weaknesses) ?? ""
        connections = try container.decodeIfPresent(String.self, forKey: .connections) ?? ""
        quotes = try container.decodeIfPresent([String].self, forKey: .quotes) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isSampleCharacter = try container.decodeIfPresent(Bool.self, forKey: .isSampleCharacter) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(role, forKey: .role)
        try container.encode(age, forKey: .age)
        try container.encode(occupation, forKey: .occupation)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(background, forKey: .background)
        try container.encode(education, forKey: .education)
        try container.encode(residence, forKey: .residence)
        try container.encode(family, forKey: .family)
        try container.encode(pets, forKey: .pets)
        try container.encode(personalityTraits, forKey: .personalityTraits)
        try container.encode(coreBelief, forKey: .coreBelief)
        try container.encode(principles, forKey: .principles)
        try container.encode(skills, forKey: .skills)
        try container.encode(motivations, forKey: .motivations)
        try container.encode(weaknesses, forKey: .weaknesses)
        try container.encode(connections, forKey: .connections)
        try container.encode(quotes, forKey: .quotes)
        try container.encode(notes, forKey: .notes)
        try container.encode(isSampleCharacter, forKey: .isSampleCharacter)
    }

    var displayName: String {
        if !nickname.isEmpty && !fullName.isEmpty {
            return "\(fullName) (\(nickname))"
        }
        return fullName.isEmpty ? "Unnamed Character" : fullName
    }

    /// Canonical key used for analysis + chart labels.
    /// Prefer the first token of `fullName` (matches screenplay character cues),
    /// falling back to `nickname` when `fullName` is empty.
    var analysisKey: String? {
        let trimmedFull = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFull.isEmpty {
            // Be resilient to multi-word names and prefixes/titles like "Dr.", "Mr.", "Chief", etc.
            let titleTokens: Set<String> = [
                "mr", "mrs", "ms", "miss", "dr", "prof", "professor",
                "chief", "capt", "captain", "officer", "detective", "sgt", "sergeant",
                "agent", "inspector", "superintendent", "lieutenant", "lt", "colonel", "col",
                "major", "gen", "general", "sir", "madam"
            ]
            for raw in trimmedFull.split(whereSeparator: { $0.isWhitespace }) {
                let token = String(raw).trimmingCharacters(in: .punctuationCharacters)
                let tokenKey = token.lowercased()
                if titleTokens.contains(tokenKey) { continue }
                if !token.isEmpty {
                    return token
                }
            }
        }

        let trimmedNick = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNick.isEmpty { return nil }
        return trimmedNick.trimmingCharacters(in: .punctuationCharacters)
    }

    /// Minor characters should not be included in analysis windows.
    var isAnalysisEligible: Bool {
        role != .minor
    }
}

// MARK: - Character Library Manager

class CharacterLibrary {
    static let shared = CharacterLibrary()

    private(set) var characters: [CharacterProfile] = []
    private(set) var currentDocumentURL: URL?

    private init() {
        // Start with empty library - characters load when document opens
    }

    /// Characters that should appear in analysis windows (excludes `.minor`).
    /// Returned in the library's current order.
    var analysisEligibleCharacters: [CharacterProfile] {
        characters.filter { $0.isAnalysisEligible && ($0.analysisKey != nil) }
    }

    /// Canonical character keys used by analysis + charts.
    /// Returned in the library's current order.
    var analysisCharacterKeys: [String] {
        analysisEligibleCharacters.compactMap { $0.analysisKey }
    }

    /// Get the sidecar file URL for a document's characters
    /// Example: "MyStory.docx" -> "MyStory.docx.characters.json"
    /// Application Support directory for per-document character libraries.
    /// `~/Library/Application Support/Quill Pilot/StoryNotes/Characters/`
    private static func charactersDirectoryURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("Quill Pilot", isDirectory: true)
            .appendingPathComponent("StoryNotes", isDirectory: true)
            .appendingPathComponent("Characters", isDirectory: true)
    }

    /// Legacy sidecar file URL next to the manuscript.
    /// Example: "MyStory.docx" -> "MyStory.docx.characters.json"
    private func legacyCharactersURL(for documentURL: URL) -> URL {
        documentURL.appendingPathExtension("characters.json")
    }

    private func ensureCharactersDirectoryExists() {
        guard let dir = Self.charactersDirectoryURL() else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            // Best-effort.
        }
    }

    private func stableDocumentIdentityString(for documentURL: URL) -> String {
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

    /// Primary character library URL (Application Support). Falls back to legacy sidecar if needed.
    private func charactersURL(for documentURL: URL) -> URL {
        guard let dir = Self.charactersDirectoryURL() else {
            return legacyCharactersURL(for: documentURL)
        }

        ensureCharactersDirectoryExists()

        let identity = stableDocumentIdentityString(for: documentURL)
        let hash = shortStableHash(identity)
        let stem = sanitizedStem(for: documentURL)
        let filename = "\(stem)-\(hash).characters.json"
        return dir.appendingPathComponent(filename, isDirectory: false)
    }

    private func migrateLegacyCharactersIfNeeded(for documentURL: URL, destinationURL: URL) -> [CharacterProfile]? {
        let legacyURL = legacyCharactersURL(for: documentURL)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: legacyURL)
            if let decoded = decodeCharacterProfiles(from: data) {
                characters = decoded
                saveCharacters()

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try? FileManager.default.removeItem(at: legacyURL)
                }
                return decoded
            }
        } catch {
            // If we can't read legacy sidecar (sandbox), silently fall back.
        }
        return nil
    }

    /// Load characters for a specific document
    func loadCharacters(for documentURL: URL?) {
        guard let documentURL = documentURL else {
            DebugLog.log("📚 No document URL provided, starting with empty library")
            characters = []
            currentDocumentURL = nil
            NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
            return
        }

        currentDocumentURL = documentURL
        let charactersFile = charactersURL(for: documentURL)

        do {
            let data = try Data(contentsOf: charactersFile)
            if let decoded = decodeCharacterProfiles(from: data) {
                characters = decoded
                DebugLog.log("📚 Loaded \(characters.count) characters from \(charactersFile.lastPathComponent)")
            } else {
                DebugLog.log("❌ Could not decode characters from \(charactersFile.lastPathComponent); starting fresh")
                characters = []
            }
        } catch {
            if let migrated = migrateLegacyCharactersIfNeeded(for: documentURL, destinationURL: charactersFile) {
                characters = migrated
            } else {
                DebugLog.log("📚 No existing characters file for document (\(charactersFile.lastPathComponent)); starting fresh")
                characters = []
            }
        }

        NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
    }

    /// Save characters for the current document
    func saveCharacters() {
        guard let documentURL = currentDocumentURL else {
            DebugLog.log("⚠️ Cannot save characters - no document URL set")
            return
        }

        let charactersFile = charactersURL(for: documentURL)

        do {
            let data = try JSONEncoder().encode(characters)
            try data.write(to: charactersFile, options: .atomic)
            DebugLog.log("📚 Saved \(characters.count) characters to \(charactersFile.lastPathComponent)")
        } catch {
            DebugLog.log("❌ Error saving characters: \(error.localizedDescription)")
        }
    }

    /// Update the current document URL without reloading characters (for Save As operations)
    func setDocumentURL(_ url: URL?) {
        currentDocumentURL = url
        if let url = url {
            DebugLog.log("📚 Document URL updated to \(url.lastPathComponent)")

            // If we already have characters in memory (e.g., seeded on import for an unsaved document),
            // persist them now that we have a concrete location.
            if !characters.isEmpty {
                saveCharacters()
            }
        }
    }

    func addCharacter(_ character: CharacterProfile) {
        characters.insert(character, at: 0) // Insert at beginning
        saveCharacters()
        NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
    }

    func updateCharacter(_ character: CharacterProfile) {
        if let index = characters.firstIndex(where: { $0.id == character.id }) {
            characters[index] = character
            saveCharacters()
            NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
        }
    }

    func deleteCharacter(_ character: CharacterProfile) {
        characters.removeAll { $0.id == character.id }
        saveCharacters()
        NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
    }

    func createNewCharacter() -> CharacterProfile {
        return CharacterProfile(
            fullName: "",
            role: .supporting,
            isSampleCharacter: false
        )
    }

    /// Seed the character library once when opening/importing a document.
            static let characterLibraryAccessDenied = Notification.Name("characterLibraryAccessDenied")
    /// This is primarily used for Screenplay imports where character cues are reliably styled
    /// but no sidecar `.characters.json` exists yet.
    func seedCharactersIfEmpty(_ names: [String]) {
        let cleaned = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { return }
        guard characters.isEmpty else { return }

        characters = cleaned.map { name in
            CharacterProfile(
                fullName: name,
                role: .supporting,
                isSampleCharacter: false
            )
        }

        if currentDocumentURL != nil {
            saveCharacters()
        } else {
            DebugLog.log("📚 Seeded \(characters.count) characters in memory (no document URL yet)")
        }
        NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
    }

    /// Permanently remove all characters for the current document.
    /// This deletes the sidecar `.characters.json` (if present) and clears the in-memory library.
    func purgeCharactersForCurrentDocument() {
        guard let documentURL = currentDocumentURL else {
            characters = []
            NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
            return
        }

        let charactersFile = charactersURL(for: documentURL)
        if FileManager.default.fileExists(atPath: charactersFile.path) {
            do {
                try FileManager.default.removeItem(at: charactersFile)
                DebugLog.log("🧹 Purged character sidecar: \(charactersFile.lastPathComponent)")
            } catch {
                DebugLog.log("⚠️ Failed to delete character sidecar (\(charactersFile.lastPathComponent)): \(error.localizedDescription)")
            }
        }

        characters = []
        NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
    }

    /// Clear all characters for a new document (for backward compatibility)
    func clearForNewDocument() {
        DebugLog.log("📚 CharacterLibrary: Clearing characters for new document")
        loadCharacters(for: nil)
    }

    private func decodeCharacterProfiles(from data: Data) -> [CharacterProfile]? {
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([CharacterProfile].self, from: data) {
            return decoded
        }

        // Salvage path: sometimes tools/formatters accidentally concatenate two JSON arrays.
        // Attempt to decode the first top-level JSON array in the file.
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        guard let firstArrayEndIndex = firstTopLevelJSONArrayEndIndex(in: text) else { return nil }

        let prefix = String(text[..<firstArrayEndIndex])
        guard let prefixData = prefix.data(using: .utf8) else { return nil }
        if let decoded = try? decoder.decode([CharacterProfile].self, from: prefixData) {
            DebugLog.log("⚠️ Salvaged characters by decoding the first JSON array only")
            return decoded
        }
        return nil
    }

    private func firstTopLevelJSONArrayEndIndex(in text: String) -> String.Index? {
        // Returns the index *after* the closing bracket of the first top-level array.
        var depth = 0
        var inString = false
        var escaping = false
        var started = false

        var idx = text.startIndex
        while idx < text.endIndex {
            let ch = text[idx]

            if inString {
                if escaping {
                    escaping = false
                } else if ch == "\\" {
                    escaping = true
                } else if ch == "\"" {
                    inString = false
                }
                idx = text.index(after: idx)
                continue
            }

            if ch == "\"" {
                inString = true
                idx = text.index(after: idx)
                continue
            }

            if !started {
                if ch == "[" {
                    started = true
                    depth = 1
                }
                idx = text.index(after: idx)
                continue
            }

            if ch == "[" { depth += 1 }
            if ch == "]" {
                depth -= 1
                if depth == 0 {
                    return text.index(after: idx)
                }
            }

            idx = text.index(after: idx)
        }

        return nil
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let characterLibraryDidChange = Notification.Name("characterLibraryDidChange")
}
