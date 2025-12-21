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

    // Pressure indicators (conflict, dilemma, force)
    private let pressureWords = [
        "must", "need", "forced", "threatened", "danger", "risk", "challenge", "problem",
        "confronted", "demanded", "urgent", "crisis", "deadline", "pressure", "choice",
        "decide", "conflict", "struggle", "dilemma", "torn", "caught", "trapped"
    ]

    // Decision indicators
    private let decisionWords = [
        "decided", "chose", "choose", "picked", "selected", "agreed", "refused",
        "accepted", "rejected", "committed", "promised", "vowed", "resolved",
        "determined", "opted", "went with", "settled on"
    ]

    // Outcome indicators
    private let outcomeWords = [
        "resulted", "consequence", "outcome", "happened", "led to", "caused",
        "because of", "as a result", "therefore", "thus", "success", "failed",
        "worked", "backfired", "paid off", "cost", "gained", "lost"
    ]

    // Belief/value words
    private let beliefWords = [
        "believe", "think", "thought", "realize", "understand", "see", "know",
        "trust", "faith", "doubt", "sure", "certain", "convinced", "learned",
        "always", "never", "must", "should", "wrong", "right", "value"
    ]

    /// Analyze and populate loop entries for each character from the actual text
    func initializeLoops(characterNames: [String], chapterCount: Int) -> [DecisionBeliefLoop] {
        // For now, create empty templates - full analysis requires the chapter text
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

    /// Analyze text and populate Decision-Belief Loop with detected patterns
    func analyzeLoops(text: String, characterNames: [String]) -> [DecisionBeliefLoop] {
        let chapters = splitIntoChapters(text: text)
        var loops: [DecisionBeliefLoop] = []

        for characterName in characterNames {
            var loop = DecisionBeliefLoop(characterName: characterName)

            for (chapterIndex, chapterText) in chapters.enumerated() {
                let chapterNum = chapterIndex + 1

                // Only analyze chapters where the character appears
                guard chapterText.lowercased().contains(characterName.lowercased()) else {
                    continue
                }

                // Extract elements from the chapter
                let pressure = extractPressure(from: chapterText, character: characterName)
                let belief = extractBelief(from: chapterText, character: characterName)
                let decision = extractDecision(from: chapterText, character: characterName)
                let outcome = extractOutcome(from: chapterText, character: characterName)
                let shift = extractBeliefShift(from: chapterText, character: characterName)

                let entry = DecisionBeliefLoop.LoopEntry(
                    chapter: chapterNum,
                    pressure: pressure,
                    beliefInPlay: belief,
                    decision: decision,
                    outcome: outcome,
                    beliefShift: shift
                )

                loop.entries.append(entry)
            }

            loops.append(loop)
        }

        return loops
    }

    private func extractPressure(from text: String, character: String) -> String {
        let sentences = getSentencesNear(character: character, in: text, proximity: 3)

        for sentence in sentences {
            let lower = sentence.lowercased()
            // Look for pressure indicators
            for word in pressureWords {
                if lower.contains(word) {
                    return cleanExtract(sentence)
                }
            }

            // Look for question marks (dilemma)
            if sentence.contains("?") {
                return cleanExtract(sentence)
            }
        }

        return ""
    }

    private func extractBelief(from text: String, character: String) -> String {
        let sentences = getSentencesNear(character: character, in: text, proximity: 3)

        for sentence in sentences {
            let lower = sentence.lowercased()
            // Look for belief indicators
            for word in beliefWords {
                if lower.contains(word) {
                    return cleanExtract(sentence)
                }
            }
        }

        return ""
    }

    private func extractDecision(from text: String, character: String) -> String {
        let sentences = getSentencesNear(character: character, in: text, proximity: 3)

        for sentence in sentences {
            let lower = sentence.lowercased()
            // Look for decision indicators
            for word in decisionWords {
                if lower.contains(word) {
                    return cleanExtract(sentence)
                }
            }
        }

        return ""
    }

    private func extractOutcome(from text: String, character: String) -> String {
        let sentences = getSentencesNear(character: character, in: text, proximity: 3)

        for sentence in sentences {
            let lower = sentence.lowercased()
            // Look for outcome indicators
            for word in outcomeWords {
                if lower.contains(word) {
                    return cleanExtract(sentence)
                }
            }
        }

        return ""
    }

    private func extractBeliefShift(from text: String, character: String) -> String {
        let sentences = getSentencesNear(character: character, in: text, proximity: 5)

        // Look for words indicating change
        let changeWords = ["realized", "learned", "understood", "saw", "discovered",
                          "changed", "shifted", "no longer", "now", "finally"]

        for sentence in sentences {
            let lower = sentence.lowercased()
            for word in changeWords {
                if lower.contains(word) {
                    return cleanExtract(sentence)
                }
            }
        }

        return ""
    }

    private func getSentencesNear(character: String, in text: String, proximity: Int) -> [String] {
        let allSentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var nearSentences: [String] = []

        for (index, sentence) in allSentences.enumerated() {
            if sentence.lowercased().contains(character.lowercased()) {
                // Get surrounding sentences
                let start = max(0, index - proximity)
                let end = min(allSentences.count, index + proximity + 1)
                nearSentences.append(contentsOf: allSentences[start..<end])
            }
        }

        return Array(Set(nearSentences)) // Remove duplicates
    }

    private func cleanExtract(_ text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Limit to first 150 characters for readability
        if clean.count > 150 {
            let index = clean.index(clean.startIndex, offsetBy: 150)
            clean = String(clean[..<index]) + "..."
        }
        return clean
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
