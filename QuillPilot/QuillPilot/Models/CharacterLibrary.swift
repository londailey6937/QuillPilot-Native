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
}

// MARK: - Character Library Manager

class CharacterLibrary {
    static let shared = CharacterLibrary()

    private(set) var characters: [CharacterProfile] = []

    private init() {
        loadCharacters()
    }

    private var libraryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("QuillPilot", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        return appFolder.appendingPathComponent("CharacterLibrary.json")
    }

    func loadCharacters() {
        do {
            let data = try Data(contentsOf: libraryURL)
            let decoded = try JSONDecoder().decode([CharacterProfile].self, from: data)
            characters = decoded
        } catch {
            // If no saved characters, start with empty library
            characters = []
        }
    }

    func saveCharacters() {
        do {
            let data = try JSONEncoder().encode(characters)
            try data.write(to: libraryURL)
        } catch {
            // Error saving, silent failure
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

    /// Clear all characters for a new document
    func clearForNewDocument() {
        NSLog("📚 CharacterLibrary: Clearing \(characters.count) characters")
        characters = []
        saveCharacters()
        NSLog("📚 CharacterLibrary: Posting notification")
        NotificationCenter.default.post(name: .characterLibraryDidChange, object: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let characterLibraryDidChange = Notification.Name("characterLibraryDidChange")
}
