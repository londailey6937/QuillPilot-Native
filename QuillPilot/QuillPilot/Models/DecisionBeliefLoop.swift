//
//  DecisionBeliefLoop.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation

// MARK: - Decision-Belief Loop Framework

/// The Decision-Belief Loop tracks how characters evolve through decisions that reshape beliefs,
/// and beliefs that reshape future decisions. This framework works across literary and genre fiction
/// and scales from a lone protagonist to an ensemble.

struct DecisionBeliefLoop {
    let characterName: String
    var entries: [LoopEntry] = []

    /// A single loop entry tracking one decision-belief cycle
    struct LoopEntry: Identifiable {
        let id = UUID()
        let chapter: Int
        var pressure: String        // What new force acts on the character?
        var beliefInPlay: String    // Which core belief is being tested?
        var decision: String        // What choice does the character make because of that belief?
        var outcome: String         // What happens immediately because of the decision?
        var beliefShift: String     // How does the belief change after the outcome?

        init(chapter: Int, pressure: String = "", beliefInPlay: String = "", decision: String = "", outcome: String = "", beliefShift: String = "") {
            self.chapter = chapter
            self.pressure = pressure
            self.beliefInPlay = beliefInPlay
            self.decision = decision
            self.outcome = outcome
            self.beliefShift = beliefShift
        }
    }

    /// Character growth indicators
    var arcQuality: ArcQuality {
        guard entries.count >= 2 else { return .insufficient }

        // Check for repetitive patterns
        let uniqueBeliefs = Set(entries.map { $0.beliefInPlay.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        let uniqueShifts = Set(entries.map { $0.beliefShift.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })

        // If beliefs never change, arc is flat
        if uniqueBeliefs.count == 1 && uniqueShifts.count <= 1 {
            return .flat
        }

        // If there are meaningful variations in beliefs and shifts
        if uniqueBeliefs.count >= 2 && uniqueShifts.count >= 2 {
            return .evolving
        }

        return .developing
    }

    enum ArcQuality: String {
        case insufficient = "Insufficient Data"
        case flat = "Flat Arc - Beliefs unchanging"
        case developing = "Developing Arc - Some changes"
        case evolving = "Evolving Arc - Clear pattern change"
    }
}

// MARK: - Character Presence (kept for Document Analysis graph)

struct CharacterPresence {
    let characterName: String
    var chapterPresence: [Int: Int] = [:]  // Chapter # -> mention count
}

// MARK: - Character Interaction (kept for relationship tracking)

struct CharacterInteraction {
    let character1: String
    let character2: String
    var coAppearances: Int = 0
    var sections: [Int] = []  // Which sections they appear together
    var relationshipStrength: Double = 0.0  // 0-1
}

// MARK: - Decision-Belief Loop Analyzer

class DecisionBeliefLoopAnalyzer {

    /// Initialize loop entries for each character based on chapter structure
    /// Note: This creates empty templates - the writer fills them in as they write
    func initializeLoops(characterNames: [String], chapterCount: Int) -> [DecisionBeliefLoop] {
        var loops: [DecisionBeliefLoop] = []

        for characterName in characterNames {
            var loop = DecisionBeliefLoop(characterName: characterName)

            // Create an entry for each chapter
            for chapter in 1...chapterCount {
                let entry = DecisionBeliefLoop.LoopEntry(chapter: chapter)
                loop.entries.append(entry)
            }

            loops.append(loop)
        }

        return loops
    }

    /// Analyze character presence across chapters for the presence graph
    func analyzePresenceByChapter(text: String, characterNames: [String]) -> [CharacterPresence] {
        var presenceData: [CharacterPresence] = []

        // Split text by chapters
        let chapters = splitIntoChapters(text: text)

        for characterName in characterNames {
            var presence = CharacterPresence(characterName: characterName)

            for (index, chapter) in chapters.enumerated() {
                let chapterNumber = index + 1
                let mentions = countMentions(of: characterName, in: chapter)
                if mentions > 0 {
                    presence.chapterPresence[chapterNumber] = mentions
                }
            }

            presenceData.append(presence)
        }

        return presenceData
    }

    /// Analyze character interactions for relationship strength
    func analyzeInteractions(text: String, characterNames: [String]) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Split text into sections (every ~1000 words)
        let sections = splitIntoSections(text: text, wordsPerSection: 1000)

        // Check each pair of characters
        for i in 0..<characterNames.count {
            for j in (i+1)..<characterNames.count {
                let char1 = characterNames[i]
                let char2 = characterNames[j]

                var interaction = CharacterInteraction(
                    character1: char1,
                    character2: char2
                )

                // Check each section for co-appearances
                for (sectionIndex, section) in sections.enumerated() {
                    let hasChar1 = section.lowercased().contains(char1.lowercased())
                    let hasChar2 = section.lowercased().contains(char2.lowercased())

                    if hasChar1 && hasChar2 {
                        interaction.coAppearances += 1
                        interaction.sections.append(sectionIndex)
                    }
                }

                // Calculate relationship strength (0-1)
                // Based on frequency of co-appearances
                if !sections.isEmpty {
                    interaction.relationshipStrength = Double(interaction.coAppearances) / Double(sections.count)
                }

                if interaction.coAppearances > 0 {
                    interactions.append(interaction)
                }
            }
        }

        return interactions.sorted { $0.coAppearances > $1.coAppearances }
    }

    // MARK: - Helper Methods

    private func splitIntoChapters(text: String) -> [String] {
        // Split by common chapter markers
        let patterns = [
            "Chapter \\d+",
            "CHAPTER \\d+",
            "Ch\\. \\d+",
            "\\d+\\.",
            "# Chapter"
        ]

        var chapters: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var currentChapter = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var isChapterMarker = false

            // Check if line matches any chapter pattern
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                    isChapterMarker = true
                    break
                }
            }

            if isChapterMarker && !currentChapter.isEmpty {
                chapters.append(currentChapter)
                currentChapter = line + "\n"
            } else {
                currentChapter += line + "\n"
            }
        }

        // Add the last chapter
        if !currentChapter.isEmpty {
            chapters.append(currentChapter)
        }

        // If no chapters found, treat entire text as one chapter
        return chapters.isEmpty ? [text] : chapters
    }

    private func splitIntoSections(text: String, wordsPerSection: Int) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var sections: [String] = []

        var currentSection: [String] = []
        for word in words {
            currentSection.append(word)

            if currentSection.count >= wordsPerSection {
                sections.append(currentSection.joined(separator: " "))
                currentSection = []
            }
        }

        // Add remaining words as last section
        if !currentSection.isEmpty {
            sections.append(currentSection.joined(separator: " "))
        }

        return sections
    }

    private func countMentions(of characterName: String, in text: String) -> Int {
        let lowercasedText = text.lowercased()
        let lowercasedName = characterName.lowercased()

        var count = 0
        var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex

        while let range = lowercasedText.range(of: lowercasedName, options: [], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<lowercasedText.endIndex
        }

        return count
    }
}
