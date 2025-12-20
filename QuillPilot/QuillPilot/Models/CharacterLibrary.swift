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
            if decoded.isEmpty {
                // Seed with samples when the persisted library is empty
                characters = createSampleCharacters()
                saveCharacters()
            } else {
                characters = decoded
            }
        } catch {
            // If no saved characters, load sample characters
            characters = createSampleCharacters()
            saveCharacters()
        }
    }

    func saveCharacters() {
        do {
            let data = try JSONEncoder().encode(characters)
            try data.write(to: libraryURL)
        } catch {
            NSLog("❌ Failed to save character library: \(error)")
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

    private func createSampleCharacters() -> [CharacterProfile] {
        return [
            CharacterProfile(
                fullName: "Alex Ross Applegate",
                nickname: "Alex",
                role: .protagonist,
                age: "Mid-20s",
                occupation: "Operative / Contractor",
                appearance: "Athletic build, alert eyes, moves with practiced grace. Dresses practically—capable of blending in or standing out as needed.",
                background: """
Alex grew up on a sprawling Virginia estate, raised by a father whose old-money wealth masked a lifetime of intelligence work. After his parents were killed in what officials called a "random accident," Alex discovered the truth: his father was a legendary CIA operative, and the family's enemies had finally caught up with them.

Inheriting his father's network, fortune, and enemies, Alex was recruited into a shadowy private intelligence firm. Now he operates in the gray zone between nations—taking contracts that governments can't officially sanction, protecting those who can't protect themselves, and hunting the people who destroyed his family.
""",
                education: "Private tutors, elite preparatory academies, Ivy League degree in International Relations. Supplemented by intensive training in tradecraft, combat, and languages.",
                residence: "Primary residence in Georgetown; maintains safehouses internationally",
                family: """
Father (deceased): Legendary CIA operative, killed when Alex was young
Mother (deceased): Socialite and covert asset, killed alongside father
Grandfather: Retired intelligence director, occasional mentor and contact
""",
                pets: "A German Shepherd named Shadow—trained protection dog and loyal companion",
                personalityTraits: [
                    "Calculating but not cold",
                    "Loyal to those who earn it",
                    "Haunted by survivor's guilt",
                    "Dry wit under pressure",
                    "Struggles with trust"
                ],
                principles: [
                    "Never betray a source",
                    "Protect the innocent, even at personal cost",
                    "Everyone lies—find out why",
                    "Violence is a tool, not a solution",
                    "The mission comes first, but the team comes close second",
                    "Some secrets are worth dying for"
                ],
                skills: [
                    "Firearms: Expert marksman, particularly with pistols and precision rifles",
                    "Explosives: Trained in demolitions and IED detection",
                    "Tradecraft: Surveillance, counter-surveillance, dead drops, clandestine communications",
                    "Hand-to-Hand: Krav Maga, Brazilian Jiu-Jitsu",
                    "Languages: English, Russian, Arabic, Mandarin",
                    "Technical: Hacking, lock-picking, document forgery"
                ],
                motivations: "Seeking justice for his parents' murder while protecting others from similar fates. Driven by a need to find meaning in the violence he's trained for.",
                weaknesses: "Tendency toward isolation. Struggles to form lasting relationships. Sometimes takes unnecessary risks to prove something to himself.",
                connections: "Network of intelligence contacts, underworld informants, and former operatives. Maintains complicated relationship with official agencies.",
                quotes: [
                    "Trust is earned in drops and lost in floods.",
                    "Everyone's got a price. The trick is knowing what currency they deal in.",
                    "I don't believe in coincidences. I believe in enemies who are patient."
                ],
                notes: "Primary protagonist. Arc involves learning to trust again while uncovering conspiracy behind parents' deaths.",
                isSampleCharacter: true
            ),

            CharacterProfile(
                fullName: "Viktor Mikhailovich Kurgan",
                nickname: "The Ghost",
                role: .antagonist,
                age: "38",
                occupation: "Freelance Assassin / Former FSB Agent",
                appearance: "Tall and lean with sharp Slavic features. Gray-blue eyes that seem to look through people rather than at them. A thin scar runs from his left temple to jaw. Moves with unsettling stillness—never fidgets, rarely blinks.",
                background: """
Born in the industrial wastelands of Norilsk, Siberia, Viktor learned survival before he learned to read. His father, a prison guard, taught him that power comes from being the one who isn't afraid. His mother died of lung disease when he was seven.

Recruited into FSB's wetwork division at nineteen, Viktor quickly earned a reputation for efficiency and emotional detachment. After a operation in Chechnya went wrong—leaving him the sole survivor—he was officially "killed in action." In reality, he'd been burned by his own agency and left for dead.

Now he works for whoever pays, but his real agenda is personal: hunting down the handlers who betrayed him while building the resources to one day destroy the organization that made him.
""",
                education: "Soviet-era military academy. FSB special operations training. Self-educated in chemistry, psychology, and languages.",
                residence: "No fixed address. Maintains a network of bolt-holes across Europe and Asia.",
                family: """
Father: Former prison guard, deceased (Viktor killed him at age 16 in self-defense)
Mother: Deceased from respiratory illness
No known siblings or children
""",
                pets: "None. \"Attachments are vulnerabilities.\"",
                personalityTraits: [
                    "Emotionally detached",
                    "Highly intelligent",
                    "Patient to the point of obsession",
                    "Paradoxically honest—never lies when the truth will hurt more",
                    "Capable of mimicking warmth but doesn't feel it"
                ],
                principles: [
                    "Emotion is weakness; eliminate it",
                    "Everyone betrays eventually—strike first",
                    "Pain is information",
                    "Leave no witnesses, but always leave a message",
                    "The job is never personal—until it is"
                ],
                skills: [
                    "Assassination: Poisons, garrotes, sniper, close-quarters",
                    "Infiltration: Social engineering, disguise, impersonation",
                    "Interrogation: Physical and psychological techniques",
                    "Combat: Sambo, Systema, knife fighting",
                    "Languages: Russian, English, German, Turkish, Arabic",
                    "Surveillance: Counter-intelligence, electronic warfare"
                ],
                motivations: "Revenge against the FSB handlers who burned him. Accumulating enough power and resources to feel truly safe for the first time in his life.",
                weaknesses: "Inability to understand genuine human connection. Obsessive need for control. Underestimates opponents who act irrationally or emotionally.",
                connections: "Network of criminal contacts, corrupt officials, and intelligence assets he's cultivated or blackmailed. No friends—only assets.",
                quotes: [
                    "I don't enjoy killing. I don't dislike it either. It's simply what I do.",
                    "You think you're the hero of this story? There are no heroes. Only survivors.",
                    "The difference between us? I know exactly what I am."
                ],
                notes: "Primary antagonist. Mirror to Alex—both made by violence, but Viktor embraced the darkness while Alex fights against it.",
                isSampleCharacter: true
            )
        ]
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let characterLibraryDidChange = Notification.Name("characterLibraryDidChange")
}
