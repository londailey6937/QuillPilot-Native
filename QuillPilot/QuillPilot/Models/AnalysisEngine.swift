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
    var adverbCount: Int = 0
    var adverbPhrases: [String] = []
    var sensoryDetailCount: Int = 0
    var missingSensoryDetail: Bool = false
    var readingLevel: String = "--"
    var dialoguePercentage: Int = 0

    // New metrics
    var weakVerbCount: Int = 0
    var weakVerbPhrases: [String] = []
    var clicheCount: Int = 0
    var clichePhrases: [String] = []
    var filterWordCount: Int = 0
    var filterWordPhrases: [String] = []
    var sentenceVarietyScore: Int = 0 // 0-100
    var sentenceLengths: [Int] = [] // For graphing

    // Page count (estimated at ~250 words per page)
    var pageCount: Int = 0
}

class AnalysisEngine {

    // Passive voice patterns
    private static let passiveVoicePatterns = [
        "was \\w+ed", "were \\w+ed", "is \\w+ed", "are \\w+ed",
        "been \\w+ed", "being \\w+ed", "be \\w+ed",
        "was written", "were written", "was made", "were made",
        "was given", "were given", "was taken", "were taken"
    ]

    private static let passiveVoiceRegexes: [NSRegularExpression] = {
        return passiveVoicePatterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    // Common non-adverb words ending in -ly
    private static let adverbExceptions: Set<String> = [
        "family", "only", "lovely", "lonely", "friendly", "silly", "ugly", "early", "daily", "weekly", "monthly", "yearly", "holy", "jelly", "belly", "bully", "fly", "rely", "supply", "apply", "reply"
    ]

    // Sensory words
    private static let sensoryWords = [
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

    private static let sensoryWordRegex: NSRegularExpression? = {
        let pattern = "\\b(" + sensoryWords.joined(separator: "|") + ")\\w*\\b"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    // Weak verbs to avoid
    private static let weakVerbs: Set<String> = [
        "is", "are", "was", "were", "be", "being", "been",
        "have", "has", "had", "having",
        "do", "does", "did", "doing",
        "get", "gets", "got", "getting", "gotten",
        "make", "makes", "made", "making",
        "go", "goes", "went", "going", "gone",
        "come", "comes", "came", "coming",
        "take", "takes", "took", "taking", "taken",
        "give", "gives", "gave", "giving", "given",
        "put", "puts", "putting",
        "seem", "seems", "seemed", "seeming",
        "become", "becomes", "became", "becoming"
    ]

    // Common clichés to detect
    private static let cliches = [
        "at the end of the day", "think outside the box", "bottom line",
        "hit the ground running", "low-hanging fruit", "move the needle",
        "eyes sparkled", "eyes gleamed", "heart raced", "blood ran cold",
        "time stood still", "moment of truth", "breath caught",
        "crystal clear", "clear as day", "cold as ice", "dark as night",
        "quiet as a mouse", "quick as lightning", "strong as an ox",
        "busy as a bee", "light as a feather", "fit as a fiddle",
        "last but not least", "it goes without saying", "needless to say",
        "at this point in time", "in this day and age", "for all intents and purposes",
        "each and every", "first and foremost", "sad but true",
        "only time will tell", "easier said than done", "better late than never",
        "actions speak louder than words", "the tip of the iceberg",
        "a blessing in disguise", "add insult to injury", "beat around the bush",
        // Physical reaction clichés
        "heart pounded", "heart sank", "heart skipped", "heart leaped",
        "stomach churned", "stomach dropped", "stomach turned",
        "knees buckled", "knees weak", "jaw dropped", "jaw clenched",
        "fists clenched", "pulse quickened", "palms sweaty",
        "spine tingled", "hair stood on end", "goosebumps",
        "butterflies in stomach", "lump in throat", "face flushed",
        "cheeks burned", "ears burned", "blood boiled",
        // Emotional clichés
        "breath away", "swept off feet", "head over heels",
        "love at first sight", "match made in heaven",
        "writing on the wall", "threw caution to the wind",
        "caught between a rock and a hard place",
        "avoid like the plague", "bite the bullet", "break the ice",
        "cutting corners", "give the benefit of the doubt",
        "hit the nail on the head", "in the heat of the moment",
        "jump on the bandwagon", "let the cat out of the bag",
        "piece of cake", "raining cats and dogs", "bite off more than you can chew"
    ]

    // Filter words that create distance
    private static let filterWords: Set<String> = [
        "saw", "see", "sees", "seeing", "seen",
        "heard", "hear", "hears", "hearing",
        "felt", "feel", "feels", "feeling",
        "noticed", "notice", "notices", "noticing",
        "seemed", "seem", "seems", "seeming",
        "realized", "realize", "realizes", "realizing",
        "thought", "think", "thinks", "thinking",
        "wondered", "wonder", "wonders", "wondering",
        "watched", "watch", "watches", "watching",
        "looked", "look", "looks", "looking",
        "smelled", "smell", "smells", "smelling"
    ]

    // Maximum text length to analyze (500KB) - prevents system overload
    private let maxAnalysisLength = 500_000

    func analyzeText(_ text: String) -> AnalysisResults {
        var results = AnalysisResults()

        // Truncate extremely long text to prevent system overload
        let analysisText: String
        if text.count > maxAnalysisLength {
            analysisText = String(text.prefix(maxAnalysisLength))
            print("⚠️ Text truncated for analysis: \(text.count) -> \(maxAnalysisLength) chars")
        } else {
            analysisText = text
        }

        // Tokenize once for word-based analysis
        let words = analysisText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Basic counts (use full text for accurate word count)
        results.wordCount = countWords(text)
        results.sentenceCount = countSentences(analysisText)

        // Paragraph analysis
        let paragraphs = analysisText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
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
        (results.passiveVoiceCount, results.passiveVoicePhrases) = detectPassiveVoice(analysisText)

        // Adverb detection
        (results.adverbCount, results.adverbPhrases) = detectAdverbs(words)

        // Sensory detail analysis
        results.sensoryDetailCount = countSensoryWords(analysisText)
        // Missing sensory detail if: no sensory words at all, OR less than 2% sensory words (with minimum threshold of 1)
        let minSensoryWords = max(1, results.wordCount / 50)
        results.missingSensoryDetail = results.wordCount > 0 && results.sensoryDetailCount < minSensoryWords

        // Weak verb detection
        (results.weakVerbCount, results.weakVerbPhrases) = detectWeakVerbs(words)

        // Cliché detection
        (results.clicheCount, results.clichePhrases) = detectCliches(analysisText)

        // Filter word detection
        (results.filterWordCount, results.filterWordPhrases) = detectFilterWords(words)

        // Sentence variety
        (results.sentenceVarietyScore, results.sentenceLengths) = analyzeSentenceVariety(analysisText)

        // Readability
        results.readingLevel = calculateReadingLevel(text: analysisText, wordCount: results.wordCount, sentenceCount: results.sentenceCount)

        // Dialogue
        results.dialoguePercentage = calculateDialoguePercentage(text: analysisText)

        // Page count (industry standard: ~250 words per manuscript page)
        results.pageCount = max(1, (results.wordCount + 249) / 250)

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

        let range = NSRange(text.startIndex..., in: text)

        for regex in AnalysisEngine.passiveVoiceRegexes {
            let matches = regex.matches(in: text, range: range)
            count += matches.count

            for match in matches.prefix(10) {
                if let range = Range(match.range, in: text) {
                    let phrase = String(text[range]).lowercased()
                    if !phrases.contains(phrase) {
                        phrases.append(phrase)
                    }
                }
            }
        }

        return (count, phrases)
    }

    private func countSensoryWords(_ text: String) -> Int {
        guard let regex = AnalysisEngine.sensoryWordRegex else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, range: range)
    }

    private func detectAdverbs(_ words: [String]) -> (Int, [String]) {
        var count = 0
        var phrases: [String] = []

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            if cleanWord.hasSuffix("ly") && !AnalysisEngine.adverbExceptions.contains(cleanWord) && cleanWord.count > 2 {
                count += 1
                if phrases.count < 10 && !phrases.contains(cleanWord) {
                    phrases.append(cleanWord)
                }
            }
        }

        return (count, phrases)
    }

    private func calculateReadingLevel(text: String, wordCount: Int, sentenceCount: Int) -> String {
        guard wordCount > 0, sentenceCount > 0 else { return "--" }

        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var syllableCount = 0
        for word in words {
            syllableCount += countSyllables(word: word)
        }

        // Flesch-Kincaid Grade Level formula
        let gradeLevel = 0.39 * (Double(wordCount) / Double(sentenceCount)) + 11.8 * (Double(syllableCount) / Double(wordCount)) - 15.59

        let grade = Int(max(0, min(18, gradeLevel)))
        return "Grade \(grade)"
    }

    private func countSyllables(word: String) -> Int {
        let word = word.lowercased()
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

        // Adjust for silent e
        if word.hasSuffix("e") && count > 1 {
            count -= 1
        }

        return max(count, 1)
    }

    private func calculateDialoguePercentage(text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        let totalLength = text.count
        var dialogueLength = 0
        var inDialogue = false

        for char in text {
            if char == "\"" || char == "“" || char == "”" {
                inDialogue.toggle()
            } else if inDialogue {
                dialogueLength += 1
            }
        }

        return Int((Double(dialogueLength) / Double(totalLength)) * 100)
    }
    private func detectWeakVerbs(_ words: [String]) -> (Int, [String]) {
        var count = 0
        var phrases: [String] = []

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            if AnalysisEngine.weakVerbs.contains(cleanWord) {
                count += 1
                if phrases.count < 10 && !phrases.contains(cleanWord) {
                    phrases.append(cleanWord)
                }
            }
        }

        return (count, phrases)
    }

    private func detectCliches(_ text: String) -> (Int, [String]) {
        var count = 0
        var found: [String] = []

        let lowercased = text.lowercased()

        for cliche in AnalysisEngine.cliches {
            if lowercased.contains(cliche) {
                count += 1
                if found.count < 10 && !found.contains(cliche) {
                    found.append(cliche)
                }
            }
        }

        return (count, found)
    }

    private func detectFilterWords(_ words: [String]) -> (Int, [String]) {
        var count = 0
        var phrases: [String] = []

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            if AnalysisEngine.filterWords.contains(cleanWord) {
                count += 1
                if phrases.count < 10 && !phrases.contains(cleanWord) {
                    phrases.append(cleanWord)
                }
            }
        }

        return (count, phrases)
    }

    private func analyzeSentenceVariety(_ text: String) -> (Int, [Int]) {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard sentences.count > 1 else { return (0, []) }

        var lengths: [Int] = []
        for sentence in sentences {
            let wordCount = sentence.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            lengths.append(wordCount)
        }

        // Calculate standard deviation to measure variety
        let average = Double(lengths.reduce(0, +)) / Double(lengths.count)
        let variance = lengths.map { pow(Double($0) - average, 2) }.reduce(0, +) / Double(lengths.count)
        let standardDeviation = sqrt(variance)

        // Higher standard deviation = better variety
        // Normalize to 0-100 scale (stdev of 5+ = 100%)
        let varietyScore = min(100, Int((standardDeviation / 5.0) * 100))

        return (varietyScore, lengths)
    }
}
