//
//  CharacterArcAnalysis.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation

// MARK: - Character Arc Data

struct CharacterArc {
    let characterName: String
    var emotionalJourney: [EmotionalState] = []
    var presenceBySection: [Int] = []  // Mention count per section
    var totalMentions: Int = 0
    var arcType: ArcType = .flat
    var arcStrength: Double = 0.0  // 0-1, how pronounced the arc is
}

struct EmotionalState {
    let sectionIndex: Int
    let sentiment: Double      // -1.0 to 1.0 (negative to positive)
    let intensity: Double      // 0.0 to 1.0 (calm to intense)
    let wordPosition: Int
}

enum ArcType: String {
    case positive = "Positive Arc"      // Character improves/grows
    case negative = "Negative Arc"      // Character degrades/falls
    case flat = "Flat Arc"             // Character stays consistent
    case transformational = "Transformational"  // Major change
}

// NOTE: CharacterInteraction and CharacterPresence are now defined in DecisionBeliefLoop.swift
// These old definitions are kept for backward compatibility but should not be used

// MARK: - Character Arc Analyzer

class CharacterArcAnalyzer {

    private let sentimentWords: [String: Double] = [
        // Positive emotions
        "happy": 0.7, "joy": 0.8, "love": 0.9, "smile": 0.6,
        "laugh": 0.6, "excited": 0.7, "hope": 0.6, "proud": 0.7,
        "grateful": 0.7, "relieved": 0.6, "calm": 0.5, "peace": 0.7,

        // Negative emotions
        "sad": -0.6, "angry": -0.7, "fear": -0.7, "hate": -0.9,
        "cry": -0.6, "scream": -0.6, "terror": -0.8, "despair": -0.9,
        "rage": -0.8, "bitter": -0.6, "guilt": -0.6, "shame": -0.7
    ]

    private let intensityWords: Set<String> = [
        "violent", "explosive", "intense", "extreme", "desperate",
        "frantic", "wild", "furious", "explosive", "dramatic",
        "urgent", "critical", "severe", "acute"
    ]

    func analyzeCharacterArcs(text: String, characterNames: [String], wordCount: Int) -> [CharacterArc] {
        guard !characterNames.isEmpty && wordCount > 0 else { return [] }

        var characterArcs: [CharacterArc] = []

        // Split text into sections (every ~2000 words or by chapter)
        let sections = splitIntoSections(text: text)

        for characterName in characterNames {
            var arc = CharacterArc(characterName: characterName)

            // Track emotional journey through sections
            for (index, section) in sections.enumerated() {
                let mentions = countMentions(of: characterName, in: section.text)
                arc.presenceBySection.append(mentions)
                arc.totalMentions += mentions

                if mentions > 0 {
                    // Calculate emotional state when character is present
                    let sentiment = calculateSentiment(in: section.text, near: characterName)
                    let intensity = calculateIntensity(in: section.text, near: characterName)

                    let state = EmotionalState(
                        sectionIndex: index,
                        sentiment: sentiment,
                        intensity: intensity,
                        wordPosition: section.startWordPosition
                    )
                    arc.emotionalJourney.append(state)
                }
            }

            // Determine arc type and strength
            arc.arcType = determineArcType(emotionalJourney: arc.emotionalJourney)
            arc.arcStrength = calculateArcStrength(emotionalJourney: arc.emotionalJourney)

            characterArcs.append(arc)
        }

        return characterArcs
    }

    func analyzeInteractions(text: String, characterNames: [String]) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []
        let sections = splitIntoSections(text: text)

        // Check all character pairs
        for i in 0..<characterNames.count {
            for j in (i+1)..<characterNames.count {
                let char1 = characterNames[i]
                let char2 = characterNames[j]

                var interaction = CharacterInteraction(
                    character1: char1,
                    character2: char2
                )

                for (index, section) in sections.enumerated() {
                    let mentions1 = countMentions(of: char1, in: section.text)
                    let mentions2 = countMentions(of: char2, in: section.text)

                    // Both appear in same section
                    if mentions1 > 0 && mentions2 > 0 {
                        interaction.coAppearances += 1
                        interaction.sections.append(index)
                    }
                }

                // Calculate relationship strength (0-1)
                let maxPossibleAppearances = sections.count
                interaction.relationshipStrength = Double(interaction.coAppearances) / Double(max(1, maxPossibleAppearances))

                if interaction.coAppearances > 0 {
                    interactions.append(interaction)
                }
            }
        }

        return interactions.sorted { $0.coAppearances > $1.coAppearances }
    }

    func analyzePresenceByChapter(text: String, characterNames: [String]) -> [CharacterPresence] {
        var presenceData: [CharacterPresence] = []

        // Split by chapter markers
        let chapters = extractChapters(from: text)

        for characterName in characterNames {
            var presence = CharacterPresence(characterName: characterName)

            for (chapterNum, chapterText) in chapters {
                let mentions = countMentions(of: characterName, in: chapterText)
                if mentions > 0 {
                    presence.chapterPresence[chapterNum] = mentions
                }
            }

            presenceData.append(presence)
        }

        return presenceData
    }

    // MARK: - Helper Methods

    private struct TextSection {
        let text: String
        let startWordPosition: Int
    }

    private func splitIntoSections(text: String) -> [TextSection] {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var sections: [TextSection] = []
        let sectionSize = 2000  // Words per section

        var currentSection = ""
        var wordPosition = 0

        for (index, word) in words.enumerated() {
            currentSection += word + " "

            if (index + 1) % sectionSize == 0 || index == words.count - 1 {
                sections.append(TextSection(text: currentSection, startWordPosition: wordPosition))
                currentSection = ""
                wordPosition = index + 1
            }
        }

        return sections
    }

    private func extractChapters(from text: String) -> [(Int, String)] {
        var chapters: [(Int, String)] = []
        let lines = text.components(separatedBy: .newlines)

        var currentChapter = 1
        var currentText = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect chapter headers (e.g., "Chapter 1", "CHAPTER ONE", etc.)
            if trimmed.range(of: "^(chapter|CHAPTER)\\s+\\d+", options: .regularExpression) != nil {
                if !currentText.isEmpty {
                    chapters.append((currentChapter, currentText))
                    currentChapter += 1
                    currentText = ""
                }
            } else {
                currentText += line + "\n"
            }
        }

        if !currentText.isEmpty {
            chapters.append((currentChapter, currentText))
        }

        return chapters
    }

    private func countMentions(of name: String, in text: String) -> Int {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: name))\\b"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(text.startIndex..., in: text)
        return regex?.numberOfMatches(in: text, options: [], range: range) ?? 0
    }

    private func calculateSentiment(in text: String, near characterName: String) -> Double {
        // Find sentences containing character
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var relevantText = ""

        for sentence in sentences {
            if sentence.range(of: characterName, options: .caseInsensitive) != nil {
                relevantText += sentence + " "
            }
        }

        // Calculate sentiment from emotion words
        let words = relevantText.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var sentimentSum = 0.0
        var sentimentCount = 0

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if let sentiment = sentimentWords[cleanWord] {
                sentimentSum += sentiment
                sentimentCount += 1
            }
        }

        return sentimentCount > 0 ? sentimentSum / Double(sentimentCount) : 0.0
    }

    private func calculateIntensity(in text: String, near characterName: String) -> Double {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var relevantText = ""

        for sentence in sentences {
            if sentence.range(of: characterName, options: .caseInsensitive) != nil {
                relevantText += sentence + " "
            }
        }

        let words = relevantText.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var intensityCount = 0

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if intensityWords.contains(cleanWord) {
                intensityCount += 1
            }
        }

        // Count exclamation marks
        let exclamationCount = relevantText.filter { $0 == "!" }.count

        // Normalize to 0-1 (assume max ~5 intensity markers per 100 words)
        let wordCount = max(1, words.count)
        return min(1.0, Double(intensityCount + exclamationCount) / Double(wordCount) * 20.0)
    }

    private func determineArcType(emotionalJourney: [EmotionalState]) -> ArcType {
        guard emotionalJourney.count >= 3 else { return .flat }

        let sentiments = emotionalJourney.map { $0.sentiment }
        let firstThird = Array(sentiments.prefix(sentiments.count / 3))
        let lastThird = Array(sentiments.suffix(sentiments.count / 3))

        let startAvg = firstThird.reduce(0, +) / Double(max(1, firstThird.count))
        let endAvg = lastThird.reduce(0, +) / Double(max(1, lastThird.count))
        let change = endAvg - startAvg

        if abs(change) > 0.4 {
            return .transformational
        } else if change > 0.2 {
            return .positive
        } else if change < -0.2 {
            return .negative
        } else {
            return .flat
        }
    }

    private func calculateArcStrength(emotionalJourney: [EmotionalState]) -> Double {
        guard emotionalJourney.count >= 2 else { return 0.0 }

        let sentiments = emotionalJourney.map { $0.sentiment }

        // Calculate variance (higher variance = stronger arc)
        let mean = sentiments.reduce(0, +) / Double(sentiments.count)
        let squaredDiffs = sentiments.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(sentiments.count)

        // Normalize to 0-1 (assume max variance ~0.5)
        return min(1.0, variance * 2.0)
    }
}
