//
//  CharacterLibrary.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

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
        self.principles = principles
        self.skills = skills
        self.motivations = motivations
        self.weaknesses = weaknesses
        self.connections = connections
        self.quotes = quotes
        self.notes = notes
        self.isSampleCharacter = isSampleCharacter
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
            // Be resilient to multi-word names and prefixes like "Dr." or "Mr.".
            for raw in trimmedFull.split(whereSeparator: { $0.isWhitespace }) {
                let token = String(raw).trimmingCharacters(in: .punctuationCharacters)
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
    private func charactersURL(for documentURL: URL) -> URL {
        return documentURL.appendingPathExtension("characters.json")
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
            let decoded = try JSONDecoder().decode([CharacterProfile].self, from: data)
            characters = decoded
            DebugLog.log("📚 Loaded \(characters.count) characters from \(charactersFile.lastPathComponent)")
        } catch {
            // If no saved characters for this document, start with empty library
            DebugLog.log("📚 No existing characters file for document, starting fresh")
            characters = []
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
    ///
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

    /// Clear all characters for a new document (for backward compatibility)
    func clearForNewDocument() {
        DebugLog.log("📚 CharacterLibrary: Clearing characters for new document")
        loadCharacters(for: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let characterLibraryDidChange = Notification.Name("characterLibraryDidChange")
}
