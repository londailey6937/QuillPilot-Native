//
//  AnalysisEngine.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation

struct AnalysisResults {
    var wordCount: Int = 0
    var sentenceCount: Int = 0
    var paragraphCount: Int = 0
    var averageParagraphLength: Int = 0
    var longParagraphs: [Int] = []
    var passiveVoiceCount: Int = 0
    var passiveVoicePhrases: [String] = []
    var sensoryDetailCount: Int = 0
    var missingSensoryDetail: Bool = false
}

class AnalysisEngine {

    // Passive voice patterns
    private let passiveVoicePatterns = [
        "was \\w+ed", "were \\w+ed", "is \\w+ed", "are \\w+ed",
        "been \\w+ed", "being \\w+ed", "be \\w+ed",
        "was written", "were written", "was made", "were made",
        "was given", "were given", "was taken", "were taken"
    ]

    // Sensory words
    private let sensoryWords = [
        // Visual
        "see", "saw", "look", "looked", "bright", "dark", "colorful", "gleaming", "shadowy", "shimmering",
        // Auditory
        "hear", "heard", "sound", "loud", "quiet", "whisper", "shout", "echo", "silence", "rumble",
        // Tactile
        "feel", "felt", "touch", "rough", "smooth", "soft", "hard", "cold", "warm", "hot",
        // Olfactory
        "smell", "smelled", "scent", "fragrant", "musty", "fresh", "acrid", "aromatic",
        // Gustatory
        "taste", "tasted", "flavor", "sweet", "sour", "bitter", "salty", "savory", "delicious"
    ]

    func analyzeText(_ text: String) -> AnalysisResults {
        var results = AnalysisResults()

        // Basic counts
        results.wordCount = countWords(text)
        results.sentenceCount = countSentences(text)

        // Paragraph analysis
        let paragraphs = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        results.paragraphCount = paragraphs.count

        if results.paragraphCount > 0 {
            var totalWords = 0
            for (index, paragraph) in paragraphs.enumerated() {
                let wordCount = countWords(paragraph)
                totalWords += wordCount

                // Flag long paragraphs (>150 words)
                if wordCount > 150 {
                    results.longParagraphs.append(index + 1)
                }
            }
            results.averageParagraphLength = totalWords / results.paragraphCount
        }

        // Passive voice detection
        (results.passiveVoiceCount, results.passiveVoicePhrases) = detectPassiveVoice(text)

        // Sensory detail analysis
        results.sensoryDetailCount = countSensoryWords(text)
        results.missingSensoryDetail = results.sensoryDetailCount < (results.wordCount / 50) // Less than 2% sensory words

        return results
    }

    private func countWords(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return words.count
    }

    private func countSentences(_ text: String) -> Int {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return sentences.count
    }

    private func detectPassiveVoice(_ text: String) -> (Int, [String]) {
        var count = 0
        var phrases: [String] = []

        let lowercasedText = text.lowercased()

        for pattern in passiveVoicePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(lowercasedText.startIndex..., in: lowercasedText)
                let matches = regex.matches(in: lowercasedText, range: range)

                count += matches.count

                for match in matches.prefix(10) {
                    if let range = Range(match.range, in: lowercasedText) {
                        let phrase = String(lowercasedText[range])
                        if !phrases.contains(phrase) {
                            phrases.append(phrase)
                        }
                    }
                }
            }
        }

        return (count, phrases)
    }

    private func countSensoryWords(_ text: String) -> Int {
        let lowercasedText = text.lowercased()
        var count = 0

        for word in sensoryWords {
            let pattern = "\\b\(word)\\w*\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(lowercasedText.startIndex..., in: lowercasedText)
                let matches = regex.numberOfMatches(in: lowercasedText, range: range)
                count += matches
            }
        }

        return count
    }
}
