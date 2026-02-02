//
//  PoetryUtilities.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation
import Cocoa

// MARK: - Syllable Counting

struct SyllableCounter {

    /// Count syllables in a word using a heuristic approach
    static func countSyllables(in word: String) -> Int {
        let word = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard !word.isEmpty else { return 0 }

        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var previousWasVowel = false

        for char in word {
            let isVowel = vowels.contains(char)
            if isVowel && !previousWasVowel {
                count += 1
            }
            previousWasVowel = isVowel
        }

        // Adjust for silent e at end
        if word.hasSuffix("e") && count > 1 && !word.hasSuffix("le") {
            count -= 1
        }

        // Adjust for -ed endings that don't add syllable
        if word.hasSuffix("ed") && count > 1 {
            let beforeEd = String(word.dropLast(2))
            if let lastChar = beforeEd.last, !vowels.contains(lastChar) && lastChar != "t" && lastChar != "d" {
                count -= 1
            }
        }

        // Common exceptions
        let exceptions: [String: Int] = [
            "the": 1, "every": 3, "different": 3, "evening": 3,
            "heaven": 2, "given": 2, "haven": 2, "seven": 2,
            "poem": 2, "poet": 2, "poetry": 3, "being": 2,
            "seeing": 2, "agreeing": 3, "idea": 3, "real": 1,
            "hour": 1, "our": 1, "fire": 1, "desire": 2,
            "tired": 1, "quiet": 2, "science": 2, "riot": 2,
            "diet": 2, "lion": 2, "giant": 2, "violet": 3,
            "theatre": 2, "theater": 2, "favourite": 3, "favorite": 3,
            "beautiful": 3, "interesting": 4, "difference": 3,
            "business": 2, "Wednesday": 2, "vegetable": 3
        ]

        if let exception = exceptions[word] {
            return exception
        }

        return max(count, 1)
    }

    /// Count syllables in a line of text
    static func countSyllablesInLine(_ line: String) -> Int {
        let words = line.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        return words.reduce(0) { $0 + countSyllables(in: $1) }
    }

    /// Get syllable counts for each line in text
    static func syllableCountsPerLine(in text: String) -> [(line: String, syllables: Int)] {
        let lines = text.components(separatedBy: .newlines)
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return (line: trimmed, syllables: countSyllablesInLine(trimmed))
        }
    }
}

// MARK: - Scansion (Stress Patterns)

struct ScansionHelper {

    /// Represents stress pattern for a word
    enum Stress: String {
        case stressed = "/"      // Strong stress
        case unstressed = "u"    // Weak stress
        case secondary = "\\"    // Secondary stress
    }

    /// Common stress patterns for English words
    /// Key is word, value is array of stress marks (one per syllable)
    private static let stressPatterns: [String: [Stress]] = [
        // One syllable (usually stressed in context)
        "the": [.unstressed],
        "a": [.unstressed],
        "an": [.unstressed],
        "and": [.unstressed],
        "but": [.unstressed],
        "or": [.unstressed],
        "for": [.unstressed],
        "to": [.unstressed],
        "of": [.unstressed],
        "in": [.unstressed],
        "on": [.unstressed],
        "at": [.unstressed],
        "by": [.unstressed],
        "with": [.unstressed],
        "from": [.unstressed],
        "as": [.unstressed],
        "is": [.unstressed],
        "was": [.unstressed],
        "are": [.unstressed],
        "were": [.unstressed],
        "be": [.unstressed],
        "been": [.unstressed],
        "have": [.unstressed],
        "has": [.unstressed],
        "had": [.unstressed],
        "do": [.unstressed],
        "does": [.unstressed],
        "did": [.unstressed],
        "will": [.unstressed],
        "would": [.unstressed],
        "could": [.unstressed],
        "should": [.unstressed],
        "may": [.unstressed],
        "might": [.unstressed],
        "must": [.unstressed],
        "can": [.unstressed],
        "it": [.unstressed],
        "its": [.unstressed],
        "my": [.unstressed],
        "your": [.unstressed],
        "his": [.unstressed],
        "her": [.unstressed],
        "our": [.unstressed],
        "their": [.unstressed],
        "this": [.unstressed],
        "that": [.unstressed],
        "these": [.unstressed],
        "those": [.unstressed],

        // Two syllables
        "above": [.unstressed, .stressed],
        "about": [.unstressed, .stressed],
        "across": [.unstressed, .stressed],
        "after": [.stressed, .unstressed],
        "again": [.unstressed, .stressed],
        "against": [.unstressed, .stressed],
        "along": [.unstressed, .stressed],
        "among": [.unstressed, .stressed],
        "around": [.unstressed, .stressed],
        "away": [.unstressed, .stressed],
        "before": [.unstressed, .stressed],
        "behind": [.unstressed, .stressed],
        "below": [.unstressed, .stressed],
        "beneath": [.unstressed, .stressed],
        "beside": [.unstressed, .stressed],
        "between": [.unstressed, .stressed],
        "beyond": [.unstressed, .stressed],
        "morning": [.stressed, .unstressed],
        "evening": [.stressed, .unstressed],
        "beauty": [.stressed, .unstressed],
        "never": [.stressed, .unstressed],
        "ever": [.stressed, .unstressed],
        "over": [.stressed, .unstressed],
        "under": [.stressed, .unstressed],
        "water": [.stressed, .unstressed],
        "nature": [.stressed, .unstressed],
        "silence": [.stressed, .unstressed],
        "heaven": [.stressed, .unstressed],
        "gentle": [.stressed, .unstressed],
        "whisper": [.stressed, .unstressed],
        "shadow": [.stressed, .unstressed],
        "hollow": [.stressed, .unstressed],
        "sorrow": [.stressed, .unstressed],
        "follow": [.stressed, .unstressed],
        "window": [.stressed, .unstressed],
        "meadow": [.stressed, .unstressed],
        "yellow": [.stressed, .unstressed],
        "silver": [.stressed, .unstressed],
        "golden": [.stressed, .unstressed],
        "hidden": [.stressed, .unstressed],
        "sudden": [.stressed, .unstressed],
        "broken": [.stressed, .unstressed],
        "spoken": [.stressed, .unstressed],
        "frozen": [.stressed, .unstressed],
        "chosen": [.stressed, .unstressed],
        "alone": [.unstressed, .stressed],
        "begin": [.unstressed, .stressed],
        "belong": [.unstressed, .stressed],
        "become": [.unstressed, .stressed],
        "believe": [.unstressed, .stressed],
        "return": [.unstressed, .stressed],
        "upon": [.unstressed, .stressed],
        "until": [.unstressed, .stressed],
        "within": [.unstressed, .stressed],
        "without": [.unstressed, .stressed],

        // Three syllables
        "beautiful": [.stressed, .unstressed, .unstressed],
        "wonderful": [.stressed, .unstressed, .unstressed],
        "terrible": [.stressed, .unstressed, .unstressed],
        "possible": [.stressed, .unstressed, .unstressed],
        "different": [.stressed, .unstressed, .unstressed],
        "yesterday": [.stressed, .unstressed, .secondary],
        "tomorrow": [.unstressed, .stressed, .unstressed],
        "forever": [.unstressed, .stressed, .unstressed],
        "together": [.unstressed, .stressed, .unstressed],
        "remember": [.unstressed, .stressed, .unstressed],
        "imagine": [.unstressed, .stressed, .unstressed],
        "continue": [.unstressed, .stressed, .unstressed],
        "another": [.unstressed, .stressed, .unstressed],
        "whatever": [.unstressed, .stressed, .unstressed],
        "however": [.unstressed, .stressed, .unstressed],
        "whenever": [.unstressed, .stressed, .unstressed],
        "wherever": [.unstressed, .stressed, .unstressed],

        // Four syllables
        "understanding": [.secondary, .unstressed, .stressed, .unstressed],
        "imagination": [.unstressed, .secondary, .unstressed, .stressed, .unstressed],
        "everybody": [.stressed, .unstressed, .secondary, .unstressed],
        "everything": [.stressed, .unstressed, .secondary],
    ]

    /// Get stress pattern for a word
    static func stressPattern(for word: String) -> [Stress] {
        let lowercased = word.lowercased().trimmingCharacters(in: .punctuationCharacters)

        // Check dictionary first
        if let pattern = stressPatterns[lowercased] {
            return pattern
        }

        // Heuristic: guess based on syllable count and common patterns
        let syllables = SyllableCounter.countSyllables(in: lowercased)

        switch syllables {
        case 1:
            // Single syllable content words are usually stressed
            return [.stressed]
        case 2:
            // Most two-syllable nouns/adjectives: stressed-unstressed
            // Most two-syllable verbs: unstressed-stressed
            // Default to trochaic (stressed-unstressed) for safety
            if lowercased.hasSuffix("ly") || lowercased.hasSuffix("ness") ||
               lowercased.hasSuffix("ment") || lowercased.hasSuffix("ful") {
                return [.stressed, .unstressed]
            }
            if lowercased.hasPrefix("un") || lowercased.hasPrefix("re") ||
               lowercased.hasPrefix("de") || lowercased.hasPrefix("pre") {
                return [.unstressed, .stressed]
            }
            return [.stressed, .unstressed]
        case 3:
            // Common patterns for 3 syllables
            if lowercased.hasSuffix("ity") || lowercased.hasSuffix("ify") {
                return [.stressed, .unstressed, .unstressed]
            }
            if lowercased.hasSuffix("tion") || lowercased.hasSuffix("sion") {
                return [.unstressed, .stressed, .unstressed]
            }
            return [.stressed, .unstressed, .unstressed]
        default:
            // For longer words, alternate with primary stress early
            var pattern: [Stress] = []
            for i in 0..<syllables {
                if i == 0 {
                    pattern.append(.stressed)
                } else if i == syllables - 1 {
                    pattern.append(.unstressed)
                } else if i % 2 == 0 {
                    pattern.append(.secondary)
                } else {
                    pattern.append(.unstressed)
                }
            }
            return pattern
        }
    }

    /// Get scansion for a line of poetry
    static func scanLine(_ line: String) -> [(word: String, pattern: [Stress])] {
        let words = line.components(separatedBy: .whitespaces)
            .filter { !$0.trimmingCharacters(in: .punctuationCharacters).isEmpty }

        return words.map { word in
            (word: word, pattern: stressPattern(for: word))
        }
    }

    /// Format scansion as a string with stress marks above
    static func formatScansion(for line: String) -> String {
        let scanned = scanLine(line)
        var stressLine = ""
        var wordLine = ""

        for (word, pattern) in scanned {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            let stressMarks = pattern.map { $0.rawValue }.joined()

            // Pad to align
            let maxLen = max(cleanWord.count, stressMarks.count)
            let paddedStress = stressMarks.padding(toLength: maxLen, withPad: " ", startingAt: 0)
            let paddedWord = cleanWord.padding(toLength: maxLen, withPad: " ", startingAt: 0)

            stressLine += paddedStress + " "
            wordLine += paddedWord + " "
        }

        return stressLine.trimmingCharacters(in: .whitespaces) + "\n" + wordLine.trimmingCharacters(in: .whitespaces)
    }

    /// Detect likely meter from a set of lines
    static func detectMeter(lines: [String]) -> String {
        guard !lines.isEmpty else { return "Free Verse" }

        // Count syllables per line
        let syllableCounts = lines.map { SyllableCounter.countSyllablesInLine($0) }
        let nonZeroCounts = syllableCounts.filter { $0 > 0 }
        guard !nonZeroCounts.isEmpty else { return "Free Verse" }

        // Check for consistent syllable counts (suggests formal verse)
        let avgSyllables = Double(nonZeroCounts.reduce(0, +)) / Double(nonZeroCounts.count)
        let variance = nonZeroCounts.map { pow(Double($0) - avgSyllables, 2) }.reduce(0, +) / Double(nonZeroCounts.count)
        let stdDev = sqrt(variance)

        // Check for haiku (5-7-5)
        if syllableCounts.count == 3 {
            let counts = syllableCounts
            if (counts[0] == 5 || counts[0] == 4 || counts[0] == 6) &&
               (counts[1] == 7 || counts[1] == 6 || counts[1] == 8) &&
               (counts[2] == 5 || counts[2] == 4 || counts[2] == 6) {
                return "Haiku"
            }
        }

        // Check for consistent line lengths
        if stdDev < 1.5 {
            let rounded = Int(round(avgSyllables))
            switch rounded {
            case 10:
                return "Iambic Pentameter (10 syllables/line)"
            case 8:
                return "Tetrameter (8 syllables/line)"
            case 12:
                return "Alexandrine (12 syllables/line)"
            case 14:
                return "Fourteener (14 syllables/line)"
            default:
                return "Regular Meter (\(rounded) syllables/line)"
            }
        }

        return "Free Verse"
    }
}

// MARK: - Sound Devices

struct SoundDeviceDetector {

    struct SoundDevice {
        let type: DeviceType
        let examples: [String]
        let count: Int

        enum DeviceType: String {
            case alliteration = "Alliteration"
            case assonance = "Assonance"
            case consonance = "Consonance"
            case internalRhyme = "Internal Rhyme"
            case sibilance = "Sibilance"
            case onomatopoeia = "Onomatopoeia"
        }
    }

    private static let onomatopoeiaWords: Set<String> = [
        "buzz", "hiss", "splash", "crash", "bang", "boom", "pop", "click",
        "crack", "snap", "sizzle", "whisper", "murmur", "rustle", "rumble",
        "roar", "growl", "howl", "hoot", "chirp", "tweet", "caw", "coo",
        "meow", "woof", "bark", "moo", "oink", "neigh", "baa", "cluck",
        "quack", "ribbit", "slurp", "gulp", "burp", "hiccup", "cough",
        "sneeze", "sniffle", "wheeze", "gasp", "pant", "sigh", "groan",
        "moan", "scream", "shriek", "screech", "squeal", "squeak", "creak",
        "thud", "thump", "bump", "clunk", "clang", "ding", "ring", "ping",
        "zing", "whiz", "whoosh", "swoosh", "swish", "fizz", "drip", "drop",
        "plop", "splat", "squelch", "squish", "crunch", "munch", "chomp"
    ]

    /// Detect all sound devices in the text
    static func detectSoundDevices(in lines: [String]) -> [SoundDevice] {
        var devices: [SoundDevice] = []

        // Flatten to words
        let allWords = lines.flatMap { $0.components(separatedBy: .whitespaces) }
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        // Alliteration (repeated initial consonant sounds)
        let alliterationExamples = detectAlliteration(lines: lines)
        if !alliterationExamples.isEmpty {
            devices.append(SoundDevice(type: .alliteration, examples: alliterationExamples, count: alliterationExamples.count))
        }

        // Assonance (repeated vowel sounds)
        let assonanceExamples = detectAssonance(words: allWords)
        if !assonanceExamples.isEmpty {
            devices.append(SoundDevice(type: .assonance, examples: assonanceExamples, count: assonanceExamples.count))
        }

        // Consonance (repeated consonant sounds, not at start)
        let consonanceExamples = detectConsonance(words: allWords)
        if !consonanceExamples.isEmpty {
            devices.append(SoundDevice(type: .consonance, examples: consonanceExamples, count: consonanceExamples.count))
        }

        // Sibilance (s, sh, z sounds)
        let sibilanceExamples = detectSibilance(words: allWords)
        if !sibilanceExamples.isEmpty {
            devices.append(SoundDevice(type: .sibilance, examples: sibilanceExamples, count: sibilanceExamples.count))
        }

        // Onomatopoeia
        let onomatopoeiaExamples = allWords.filter { onomatopoeiaWords.contains($0) }
        if !onomatopoeiaExamples.isEmpty {
            // Keep occurrences so the badge count matches what the user can expand and see.
            devices.append(SoundDevice(type: .onomatopoeia, examples: onomatopoeiaExamples, count: onomatopoeiaExamples.count))
        }

        // Internal rhyme
        let internalRhymeExamples = detectInternalRhyme(lines: lines)
        if !internalRhymeExamples.isEmpty {
            devices.append(SoundDevice(type: .internalRhyme, examples: internalRhymeExamples, count: internalRhymeExamples.count))
        }

        return devices
    }

    private static func detectAlliteration(lines: [String]) -> [String] {
        var examples: [String] = []

        for line in lines {
            let words = line.components(separatedBy: .whitespaces)
                .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty && $0.count > 1 }

            guard words.count >= 2 else { continue }

            var currentGroup: [String] = []
            var currentSound: Character? = nil

            for word in words {
                guard let firstChar = word.first, firstChar.isLetter else { continue }

                // Skip common short words
                let skipWords: Set<String> = ["the", "a", "an", "and", "or", "but", "to", "of", "in", "on", "at", "by", "for", "with", "as", "is", "it"]
                if skipWords.contains(word) { continue }

                if firstChar == currentSound {
                    currentGroup.append(word)
                } else {
                    if currentGroup.count >= 2 {
                        examples.append(currentGroup.joined(separator: " "))
                    }
                    currentGroup = [word]
                    currentSound = firstChar
                }
            }

            if currentGroup.count >= 2 {
                examples.append(currentGroup.joined(separator: " "))
            }
        }

        return Array(examples.prefix(8))
    }

    private static func detectAssonance(words: [String]) -> [String] {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        var vowelGroups: [Character: [String]] = [:]

        for word in words where word.count > 2 {
            // Get the stressed vowel (simplified: first vowel)
            if let vowel = word.first(where: { vowels.contains($0) }) {
                vowelGroups[vowel, default: []].append(word)
            }
        }

        var examples: [String] = []
        for (_, group) in vowelGroups where group.count >= 3 {
            let sample = Array(Set(group)).prefix(3).joined(separator: ", ")
            examples.append(sample)
        }

        return Array(examples.prefix(5))
    }

    private static func detectConsonance(words: [String]) -> [String] {
        var endingSounds: [String: [String]] = [:]

        for word in words where word.count > 2 {
            // Get ending consonant cluster
            var ending = ""
            for char in word.reversed() {
                if "aeiou".contains(char) { break }
                ending = String(char) + ending
            }
            if ending.count >= 1 && ending.count <= 3 {
                endingSounds[ending, default: []].append(word)
            }
        }

        var examples: [String] = []
        for (_, group) in endingSounds where group.count >= 3 {
            let uniqueWords = Array(Set(group))
            if uniqueWords.count >= 3 {
                let sample = uniqueWords.prefix(3).joined(separator: ", ")
                examples.append(sample)
            }
        }

        return Array(examples.prefix(5))
    }

    private static func detectSibilance(words: [String]) -> [String] {
        let sibilantPatterns = ["ss", "sh", "ch", "s", "z", "x"]
        var sibilantWords: [String] = []

        for word in words {
            for pattern in sibilantPatterns {
                if word.contains(pattern) {
                    sibilantWords.append(word)
                    break
                }
            }
        }

        // Return unique examples if there's a notable concentration
        let uniqueWords = Array(Set(sibilantWords))
        if Double(sibilantWords.count) / Double(max(1, words.count)) > 0.2 {
            return Array(uniqueWords.prefix(8))
        }
        return []
    }

    private static func detectInternalRhyme(lines: [String]) -> [String] {
        var examples: [String] = []

        for line in lines {
            let words = line.components(separatedBy: .whitespaces)
                .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty && $0.count > 2 }

            guard words.count >= 3 else { continue }

            // Check for rhyming words within the line (not at end)
            let middleWords = Array(words.dropLast())
            for i in 0..<middleWords.count {
                for j in (i+1)..<middleWords.count {
                    if wordsRhyme(middleWords[i], middleWords[j]) {
                        examples.append("\(middleWords[i]) / \(middleWords[j])")
                    }
                }
            }
        }

        return Array(Set(examples)).prefix(6).map { $0 }
    }

    private static func wordsRhyme(_ word1: String, _ word2: String) -> Bool {
        guard word1 != word2 else { return false }
        guard word1.count >= 2 && word2.count >= 2 else { return false }

        // Simple rhyme check: same ending sounds (last 2-3 characters)
        let ending1 = String(word1.suffix(min(3, word1.count)))
        let ending2 = String(word2.suffix(min(3, word2.count)))

        return ending1 == ending2 ||
               String(word1.suffix(2)) == String(word2.suffix(2))
    }
}

// MARK: - Word Frequency

struct WordFrequencyAnalyzer {

    struct WordFrequency {
        let word: String
        let count: Int
        let percentage: Double
    }

    /// Get word frequencies, excluding common stopwords
    static func analyze(text: String, topN: Int = 50) -> [WordFrequency] {
        let stopwords: Set<String> = [
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
            "be", "have", "has", "had", "do", "does", "did", "will", "would",
            "could", "should", "may", "might", "must", "shall", "can", "need",
            "it", "its", "this", "that", "these", "those", "i", "you", "he",
            "she", "we", "they", "me", "him", "her", "us", "them", "my", "your",
            "his", "her", "our", "their", "what", "which", "who", "whom", "whose",
            "where", "when", "why", "how", "all", "each", "every", "both", "few",
            "more", "most", "other", "some", "such", "no", "nor", "not", "only",
            "own", "same", "so", "than", "too", "very", "just", "also", "now",
            "then", "here", "there", "into", "out", "up", "down", "about", "after",
            "before", "over", "under", "again", "further", "once", "if"
        ]

        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !stopwords.contains($0) }

        var counts: [String: Int] = [:]
        for word in words {
            counts[word, default: 0] += 1
        }

        let totalWords = Double(words.count)
        let sorted = counts.sorted { $0.value > $1.value }

        return sorted.prefix(topN).map { word, count in
            WordFrequency(
                word: word,
                count: count,
                percentage: totalWords > 0 ? (Double(count) / totalWords) * 100 : 0
            )
        }
    }
}

// MARK: - Poetry Form Templates

struct PoetryFormTemplate {
    let name: String
    let description: String
    let structure: String
    let example: String
    let rules: [String]

    static let allForms: [PoetryFormTemplate] = [
        sonnet,
        villanelle,
        haiku,
        tanka,
        ghazal,
        pantoum,
        sestina,
        limerick,
        freeVerse,
        blankVerse
    ]

    static let sonnet = PoetryFormTemplate(
        name: "Sonnet (Shakespearean)",
        description: "14 lines in iambic pentameter with ABAB CDCD EFEF GG rhyme scheme",
        structure: """
        [Line 1 - A]
        [Line 2 - B]
        [Line 3 - A]
        [Line 4 - B]

        [Line 5 - C]
        [Line 6 - D]
        [Line 7 - C]
        [Line 8 - D]

        [Line 9 - E]
        [Line 10 - F]
        [Line 11 - E]
        [Line 12 - F]

        [Line 13 - G] (couplet)
        [Line 14 - G] (couplet)
        """,
        example: """
        Shall I compare thee to a summer's day?
        Thou art more lovely and more temperate:
        Rough winds do shake the darling buds of May,
        And summer's lease hath all too short a date.

        Sometime too hot the eye of heaven shines,
        And often is his gold complexion dimm'd;
        And every fair from fair sometime declines,
        By chance, or nature's changing course untrimm'd;

        But thy eternal summer shall not fade,
        Nor lose possession of that fair thou ow'st;
        Nor shall death brag thou wander'st in his shade,
        When in eternal lines to time thou grow'st:

        So long as men can breathe, or eyes can see,
        So long lives this, and this gives life to thee.
        """,
        rules: [
            "14 lines total",
            "Iambic pentameter (10 syllables per line, alternating unstressed/stressed)",
            "Rhyme scheme: ABAB CDCD EFEF GG",
            "Three quatrains develop the theme",
            "Final couplet provides resolution or twist"
        ]
    )

    static let villanelle = PoetryFormTemplate(
        name: "Villanelle",
        description: "19 lines with two repeating refrains and ABA rhyme scheme",
        structure: """
        [A1 - first refrain]
        [b]
        [A2 - second refrain]

        [a]
        [b]
        [A1]

        [a]
        [b]
        [A2]

        [a]
        [b]
        [A1]

        [a]
        [b]
        [A2]

        [a]
        [b]
        [A1]
        [A2]
        """,
        example: """
        Do not go gentle into that good night,
        Old age should burn and rave at close of day;
        Rage, rage against the dying of the light.

        Though wise men at their end know dark is right,
        Because their words had forked no lightning they
        Do not go gentle into that good night.

        Good men, the last wave by, crying how bright
        Their frail deeds might have danced in a green bay,
        Rage, rage against the dying of the light.
        """,
        rules: [
            "19 lines total",
            "5 tercets (3-line stanzas) followed by a quatrain",
            "Line 1 repeats as lines 6, 12, 18",
            "Line 3 repeats as lines 9, 15, 19",
            "Rhyme scheme: ABA ABA ABA ABA ABA ABAA"
        ]
    )

    static let haiku = PoetryFormTemplate(
        name: "Haiku",
        description: "Japanese form: 3 lines with 5-7-5 syllable pattern",
        structure: """
        [5 syllables]
        [7 syllables]
        [5 syllables]
        """,
        example: """
        An old silent pond...
        A frog jumps into the pond,
        splash! Silence again.
        """,
        rules: [
            "3 lines total",
            "5 syllables in first line",
            "7 syllables in second line",
            "5 syllables in third line",
            "Traditionally includes a seasonal reference (kigo)",
            "Contains a cutting word or pause (kireji)"
        ]
    )

    static let tanka = PoetryFormTemplate(
        name: "Tanka",
        description: "Japanese form: 5 lines with 5-7-5-7-7 syllable pattern",
        structure: """
        [5 syllables]
        [7 syllables]
        [5 syllables]
        [7 syllables]
        [7 syllables]
        """,
        example: """
        A thousand years, you said,
        as our hearts melted together—
        how many days, gone by?
        the years scatter like shattered glass,
        and I, with no voice left to cry.
        """,
        rules: [
            "5 lines total",
            "Syllable pattern: 5-7-5-7-7",
            "First 3 lines (kami-no-ku) set the scene",
            "Last 2 lines (shimo-no-ku) provide commentary or emotional response",
            "Often expresses intense emotion"
        ]
    )

    static let ghazal = PoetryFormTemplate(
        name: "Ghazal",
        description: "Arabic/Persian form: couplets with repeating end word",
        structure: """
        [Line ending in radif] [radif]
        [Line ending in radif] [radif]

        [Line not ending in radif]
        [Line ending in radif] [radif]

        [Line not ending in radif]
        [Line ending in radif] [radif]

        (continue pattern for 5-15 couplets)

        [Poet's signature in final couplet]
        [Line ending in radif] [radif]
        """,
        example: """
        Where are you now? Who lies beneath your spell tonight?
        Whom else from rapture's road will you expel tonight?

        My heart is broken; should I cry or try to sleep?
        What is the difference when I have no eyes to tell tonight?
        """,
        rules: [
            "5-15 couplets (sher)",
            "Both lines of first couplet end with the radif (refrain)",
            "Second line of each subsequent couplet ends with the radif",
            "Each couplet is thematically independent",
            "Poet's name (takhallus) appears in final couplet"
        ]
    )

    static let pantoum = PoetryFormTemplate(
        name: "Pantoum",
        description: "Malaysian form: interlocking quatrains with repeating lines",
        structure: """
        [Line 1]
        [Line 2]
        [Line 3]
        [Line 4]

        [Line 2 repeated]
        [Line 5]
        [Line 4 repeated]
        [Line 6]

        [Line 5 repeated]
        [Line 7]
        [Line 6 repeated]
        [Line 8]

        (continue pattern)

        [Second-to-last line]
        [Line 3 from stanza 1]
        [Last line]
        [Line 1 from stanza 1]
        """,
        example: """
        The rain falls soft on summer leaves,
        while memories drift like morning fog.
        In quiet moments, the heart still grieves
        for paths we walked, now lost in smog.

        While memories drift like morning fog,
        the old house stands, its windows dark.
        For paths we walked, now lost in smog,
        we search for light, some lasting spark.
        """,
        rules: [
            "Quatrains with ABAB rhyme scheme",
            "Lines 2 and 4 of each stanza become lines 1 and 3 of the next",
            "Final stanza: lines 1 and 3 from first stanza return as lines 4 and 2",
            "Creates circular, obsessive quality",
            "No fixed length—continue as long as the poem requires"
        ]
    )

    static let sestina = PoetryFormTemplate(
        name: "Sestina",
        description: "Complex form: 6 stanzas of 6 lines + 3-line envoi with rotating end words",
        structure: """
        Stanza 1: End words A B C D E F
        Stanza 2: End words F A E B D C
        Stanza 3: End words C F D A B E
        Stanza 4: End words E C B F A D
        Stanza 5: End words D E A C F B
        Stanza 6: End words B D F E C A
        Envoi (3 lines): Contains all 6 words
        """,
        example: """
        I saw my soul at rest upon a day
        As a bird sleeping in the nest of night,
        Among soft leaves that give the starlight way
        To touch its wings but not to wake with light;
        So that it knew as one in visions may,
        And knew not as men waking, of delight.
        """,
        rules: [
            "39 lines total (six 6-line stanzas + 3-line envoi)",
            "Six end words rotate through all stanzas in fixed pattern",
            "No rhyme—repetition of end words creates structure",
            "Envoi contains all six words (3 in middle, 3 at end of lines)",
            "Pattern: ABCDEF → FAEBDC → CFDABE → ECBFAD → DEACFB → BDFECA"
        ]
    )

    static let limerick = PoetryFormTemplate(
        name: "Limerick",
        description: "Humorous form: 5 lines with AABBA rhyme and anapestic meter",
        structure: """
        [Line 1 - A] (7-10 syllables)
        [Line 2 - A] (7-10 syllables)
        [Line 3 - B] (5-7 syllables)
        [Line 4 - B] (5-7 syllables)
        [Line 5 - A] (7-10 syllables)
        """,
        example: """
        There once was a man from Nantucket
        Who kept all his cash in a bucket.
            His daughter, named Nan,
            Ran away with a man
        And as for the bucket, Nan took it.
        """,
        rules: [
            "5 lines total",
            "Rhyme scheme: AABBA",
            "Lines 1, 2, 5 have 7-10 syllables (longer)",
            "Lines 3, 4 have 5-7 syllables (shorter)",
            "Anapestic meter (da-da-DUM)",
            "Usually humorous with twist ending"
        ]
    )

    static let freeVerse = PoetryFormTemplate(
        name: "Free Verse",
        description: "No fixed meter, rhyme scheme, or line length",
        structure: """
        [No fixed structure]
        [Lines break where the poet chooses]
        [Rhythm comes from natural speech patterns]
        [White space and line breaks create emphasis]
        """,
        example: """
        So much depends
        upon

        a red wheel
        barrow

        glazed with rain
        water

        beside the white
        chickens.
        """,
        rules: [
            "No required meter or rhyme",
            "Line breaks are a creative choice",
            "Rhythm comes from cadence and breath",
            "May use occasional rhyme or repetition for effect",
            "Visual arrangement on page is part of the form"
        ]
    )

    static let blankVerse = PoetryFormTemplate(
        name: "Blank Verse",
        description: "Unrhymed iambic pentameter",
        structure: """
        [10 syllables - iambic] (no rhyme required)
        [10 syllables - iambic]
        [10 syllables - iambic]
        [10 syllables - iambic]
        (continue as long as needed)
        """,
        example: """
        Tomorrow, and tomorrow, and tomorrow,
        Creeps in this petty pace from day to day,
        To the last syllable of recorded time;
        And all our yesterdays have lighted fools
        The way to dusty death.
        """,
        rules: [
            "Iambic pentameter throughout",
            "10 syllables per line (unstressed-STRESSED pattern)",
            "No end rhyme required",
            "No stanza requirement—flows continuously",
            "Common in dramatic poetry and epic"
        ]
    )
}

// MARK: - Line Length Analysis

struct LineLengthAnalyzer {

    struct LineLengthData {
        let lineNumber: Int
        let text: String
        let syllables: Int
        let words: Int
        let characters: Int
    }

    static func analyze(text: String) -> [LineLengthData] {
        let lines = text.components(separatedBy: .newlines)

        return lines.enumerated().map { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            return LineLengthData(
                lineNumber: index + 1,
                text: trimmed,
                syllables: SyllableCounter.countSyllablesInLine(trimmed),
                words: words.count,
                characters: trimmed.count
            )
        }
    }

    /// Calculate statistics about line length variation
    static func statistics(from data: [LineLengthData], measure: Measure = .syllables) -> (average: Double, stdDev: Double, min: Int, max: Int) {
        let values: [Double] = data.map {
            switch measure {
            case .syllables: return Double($0.syllables)
            case .words: return Double($0.words)
            case .characters: return Double($0.characters)
            }
        }
        guard !values.isEmpty else { return (0, 0, 0, 0) }

        let avg = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        let minVal = Int(values.min() ?? 0)
        let maxVal = Int(values.max() ?? 0)

        return (avg, stdDev, minVal, maxVal)
    }

    enum Measure {
        case syllables
        case words
        case characters
    }
}
