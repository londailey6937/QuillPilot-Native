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

    // Dialogue analysis (based on 10 dialogue quality tips)
    var dialogueQualityScore: Int = 0 // 0-100 overall score
    var dialogueSegmentCount: Int = 0
    var dialogueFillerCount: Int = 0 // "uh", "um", "well"
    var dialogueRepetitionScore: Int = 0 // 0-100 (higher = more repetitive)
    var dialogueTagVariety: Int = 0 // Unique dialogue tags count
    var dialogueMonotonyIssues: [String] = [] // Examples of same voice
    var dialoguePredictablePhrases: [String] = [] // Clichéd dialogue
    var dialogueExpositionCount: Int = 0 // Info-dump lines
    var dialoguePacingScore: Int = 0 // 0-100 (length variety)
    var hasDialogueConflict: Bool = false // Tension/disagreement present

    // Plot point analysis
    var plotAnalysis: PlotAnalysis?

    // Decision-Belief Loop Framework
    var decisionBeliefLoops: [DecisionBeliefLoop] = []
    var characterInteractions: [CharacterInteraction] = []
    var characterPresence: [CharacterPresence] = []

    // Belief/Value Shift Matrices
    var beliefShiftMatrices: [BeliefShiftMatrix] = []

    // Decision-Consequence Chains
    var decisionConsequenceChains: [DecisionConsequenceChain] = []

    // Relationship Evolution Maps
    var relationshipEvolutionData: RelationshipEvolutionData = RelationshipEvolutionData()

    // Internal vs External Alignment Charts
    var internalExternalAlignment: InternalExternalAlignmentData = InternalExternalAlignmentData()

    // Language Drift Analysis
    var languageDriftData: LanguageDriftData = LanguageDriftData()
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

    // Dialogue filler words (Tip #3: Overuse of Filler)
    private static let dialogueFillers: Set<String> = [
        "uh", "um", "well", "like", "you know", "actually",
        "basically", "literally", "honestly", "i mean",
        "sort of", "kind of", "you see", "right"
    ]

    // Predictable/clichéd dialogue phrases (Tip #5: Predictability)
    private static let predictableDialogue = [
        "we need to talk", "it's not what it looks like",
        "i can explain", "you wouldn't understand",
        "this isn't over", "we meet again",
        "you have no idea", "trust me", "believe me",
        "i'm fine", "everything's fine", "don't worry about it",
        "it's complicated", "long story", "never mind",
        "forget about it", "what are you doing here",
        "who are you", "what do you want"
    ]

    // Conflict/tension indicators (Tip #8: Lack of Conflict)
    private static let conflictWords: Set<String> = [
        "but", "no", "never", "don't", "can't", "won't",
        "disagree", "wrong", "impossible", "ridiculous",
        "stupid", "idiot", "fool", "liar", "lie",
        "fight", "argue", "angry", "furious", "hate"
    ]

    // Maximum text length to analyze (500KB) - prevents system overload
    private let maxAnalysisLength = 500_000

    func analyzeText(_ text: String, outlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = nil, pageMapping: [(location: Int, page: Int)]? = nil) -> AnalysisResults {
        var results = AnalysisResults()

        // Truncate extremely long text to prevent system overload
        let analysisText: String
        if text.count > maxAnalysisLength {
            analysisText = String(text.prefix(maxAnalysisLength))
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

        // Dialogue percentage
        results.dialoguePercentage = calculateDialoguePercentage(text: analysisText)

        // Dialogue quality analysis (10 tips from The Silent Operator_Dialogue)
        let dialogueAnalysis = analyzeDialogueQuality(text: analysisText)
        results.dialogueQualityScore = dialogueAnalysis.qualityScore
        results.dialogueSegmentCount = dialogueAnalysis.segmentCount
        results.dialogueFillerCount = dialogueAnalysis.fillerCount
        results.dialogueRepetitionScore = dialogueAnalysis.repetitionScore
        results.dialogueTagVariety = dialogueAnalysis.tagVariety
        results.dialogueMonotonyIssues = dialogueAnalysis.monotonyIssues
        results.dialoguePredictablePhrases = dialogueAnalysis.predictablePhrases
        results.dialogueExpositionCount = dialogueAnalysis.expositionCount
        results.dialoguePacingScore = dialogueAnalysis.pacingScore
        results.hasDialogueConflict = dialogueAnalysis.hasConflict

        // Page count (industry standard: ~250 words per manuscript page)
        results.pageCount = max(1, (results.wordCount + 249) / 250)

        // Plot point analysis
        let plotDetector = PlotPointDetector()
        results.plotAnalysis = plotDetector.detectPlotPoints(text: analysisText, wordCount: results.wordCount)

        // Character arc analysis
        // Extract character names from text (capitalized words that appear frequently)
        let characterNames = extractCharacterNames(from: analysisText)
        if !characterNames.isEmpty {
            let (loops, interactions, presence) = analyzeCharacterArcs(text: analysisText, characterNames: characterNames, outlineEntries: outlineEntries)
            results.decisionBeliefLoops = loops
            results.characterInteractions = interactions
            results.characterPresence = presence

            // Generate belief shift matrices for characters
            results.beliefShiftMatrices = generateBeliefShiftMatrices(text: analysisText, characterNames: characterNames, outlineEntries: outlineEntries)

            // Generate decision-consequence chains
            results.decisionConsequenceChains = generateDecisionConsequenceChains(text: analysisText, characterNames: characterNames, outlineEntries: outlineEntries)

            // Generate relationship evolution maps
            let analyzer = DecisionBeliefLoopAnalyzer()
            results.relationshipEvolutionData = analyzer.generateRelationshipEvolutionData(from: analysisText, characterNames: characterNames)

            // Generate internal vs external alignment charts
            results.internalExternalAlignment = analyzer.generateInternalExternalAlignment(from: analysisText, characterNames: characterNames, outlineEntries: outlineEntries)

            // Generate language drift analysis
            results.languageDriftData = analyzer.generateLanguageDriftAnalysis(from: analysisText, characterNames: characterNames, outlineEntries: outlineEntries)
        }

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

    // MARK: - Dialogue Analysis (10 Quality Tips)

    struct DialogueQualityMetrics {
        var qualityScore: Int = 0
        var segmentCount: Int = 0
        var fillerCount: Int = 0
        var repetitionScore: Int = 0
        var tagVariety: Int = 0
        var monotonyIssues: [String] = []
        var predictablePhrases: [String] = []
        var expositionCount: Int = 0
        var pacingScore: Int = 0
        var hasConflict: Bool = false
    }

    private func analyzeDialogueQuality(text: String) -> DialogueQualityMetrics {
        var metrics = DialogueQualityMetrics()

        // Extract dialogue segments
        let dialogueSegments = extractDialogue(from: text)
        metrics.segmentCount = dialogueSegments.count

        guard !dialogueSegments.isEmpty else {
            return metrics // No dialogue to analyze
        }

        var qualityPoints = 0
        let maxPoints = 10

        // Tip #1: Lack of Depth (check for subtext vs direct statements)
        // Good dialogue has variety in length and complexity
        let avgLength = dialogueSegments.map { $0.count }.reduce(0, +) / dialogueSegments.count
        if avgLength > 50 { // More complex dialogue suggests depth
            qualityPoints += 1
        }

        // Tip #2: Repetition - check for repeated phrases
        let (hasRepetition, repetitionScore) = detectDialogueRepetition(dialogueSegments)
        metrics.repetitionScore = repetitionScore
        if !hasRepetition {
            qualityPoints += 1
        }

        // Tip #3: Overuse of Filler
        metrics.fillerCount = countDialogueFillers(dialogueSegments)
        let fillerRatio = Double(metrics.fillerCount) / Double(dialogueSegments.count)
        if fillerRatio < 0.2 { // Less than 20% have fillers
            qualityPoints += 1
        }

        // Tip #4: Monotony - check for unique dialogue tags/attribution
        metrics.tagVariety = detectDialogueTagVariety(text)
        if metrics.tagVariety > 5 { // More than 5 unique ways to attribute dialogue
            qualityPoints += 1
        }

        // Tip #5: Predictability - detect clichéd phrases
        metrics.predictablePhrases = detectPredictableDialogue(dialogueSegments)
        if metrics.predictablePhrases.count < 3 {
            qualityPoints += 1
        }

        // Tip #6: Character Growth - check if dialogue changes throughout
        // (simplified: more variety in later segments)
        if dialogueSegments.count > 10 {
            let firstHalf = Array(dialogueSegments.prefix(dialogueSegments.count / 2))
            let secondHalf = Array(dialogueSegments.suffix(dialogueSegments.count / 2))
            if Set(secondHalf).count > Set(firstHalf).count {
                qualityPoints += 1
            }
        }

        // Tip #7: Over-Exposition - detect info-dump dialogue
        metrics.expositionCount = detectExpositionDialogue(dialogueSegments)
        if metrics.expositionCount < dialogueSegments.count / 5 { // Less than 20%
            qualityPoints += 1
        }

        // Tip #8: Lack of Conflict/Tension
        metrics.hasConflict = detectDialogueConflict(dialogueSegments)
        if metrics.hasConflict {
            qualityPoints += 1
        }

        // Tip #9: Emotional Resonance - variety in punctuation (!, ?, ...)
        let hasEmotionalVariety = detectEmotionalResonance(dialogueSegments)
        if hasEmotionalVariety {
            qualityPoints += 1
        }

        // Tip #10: Pacing - mix of short and long dialogue
        metrics.pacingScore = calculateDialoguePacing(dialogueSegments)
        if metrics.pacingScore > 60 {
            qualityPoints += 1
        }

        // Calculate overall quality score
        metrics.qualityScore = (qualityPoints * 100) / maxPoints

        return metrics
    }

    private func extractDialogue(from text: String) -> [String] {
        var dialogueSegments: [String] = []
        var currentDialogue = ""
        var inDialogue = false

        for char in text {
            if char == "\"" || char == "\"" || char == "\"" {
                if inDialogue {
                    // End of dialogue
                    dialogueSegments.append(currentDialogue.trimmingCharacters(in: .whitespaces))
                    currentDialogue = ""
                }
                inDialogue.toggle()
            } else if inDialogue {
                currentDialogue.append(char)
            }
        }

        return dialogueSegments.filter { !$0.isEmpty }
    }

    private func detectDialogueRepetition(_ segments: [String]) -> (Bool, Int) {
        guard segments.count > 5 else { return (false, 0) }

        var phraseCounts: [String: Int] = [:]

        for segment in segments {
            let normalized = segment.lowercased().trimmingCharacters(in: .punctuationCharacters)
            phraseCounts[normalized, default: 0] += 1
        }

        let repetitions = phraseCounts.filter { $0.value > 2 }.count
        let repetitionScore = min(100, (repetitions * 100) / max(1, segments.count))

        return (repetitions > 0, repetitionScore)
    }

    private func countDialogueFillers(_ segments: [String]) -> Int {
        var count = 0

        for segment in segments {
            let lowercased = segment.lowercased()
            for filler in AnalysisEngine.dialogueFillers {
                if lowercased.contains(filler) {
                    count += 1
                    break // Count segment once even if multiple fillers
                }
            }
        }

        return count
    }

    private func detectDialogueTagVariety(_ text: String) -> Int {
        let commonTags = ["said", "asked", "replied", "answered", "whispered",
                         "shouted", "yelled", "muttered", "murmured", "exclaimed",
                         "stated", "remarked", "noted", "added", "continued"]

        var foundTags = Set<String>()
        let lowercased = text.lowercased()

        for tag in commonTags {
            if lowercased.contains(tag) {
                foundTags.insert(tag)
            }
        }

        return foundTags.count
    }

    private func detectPredictableDialogue(_ segments: [String]) -> [String] {
        var found: [String] = []

        for segment in segments {
            let lowercased = segment.lowercased()
            for predictable in AnalysisEngine.predictableDialogue {
                if lowercased.contains(predictable) && !found.contains(predictable) {
                    found.append(predictable)
                    if found.count >= 5 {
                        return found
                    }
                }
            }
        }

        return found
    }

    private func detectExpositionDialogue(_ segments: [String]) -> Int {
        // Exposition dialogue tends to be:
        // - Very long (>100 characters)
        // - Contains many factual statements
        // - Lacks questions or emotional punctuation

        var expositionCount = 0

        for segment in segments {
            if segment.count > 100 && !segment.contains("?") && !segment.contains("!") {
                expositionCount += 1
            }
        }

        return expositionCount
    }

    private func detectDialogueConflict(_ segments: [String]) -> Bool {
        var conflictScore = 0

        for segment in segments {
            let lowercased = segment.lowercased()
            for conflictWord in AnalysisEngine.conflictWords {
                if lowercased.contains(conflictWord) {
                    conflictScore += 1
                    break
                }
            }
        }

        // If more than 20% of dialogue contains conflict markers
        return Double(conflictScore) / Double(max(1, segments.count)) > 0.2
    }

    private func detectEmotionalResonance(_ segments: [String]) -> Bool {
        var hasExclamation = false
        var hasQuestion = false
        var hasEllipsis = false

        for segment in segments {
            if segment.contains("!") { hasExclamation = true }
            if segment.contains("?") { hasQuestion = true }
            if segment.contains("...") || segment.contains("…") { hasEllipsis = true }
        }

        // Good emotional variety if at least 2 types present
        return [hasExclamation, hasQuestion, hasEllipsis].filter { $0 }.count >= 2
    }

    private func calculateDialoguePacing(_ segments: [String]) -> Int {
        guard segments.count > 1 else { return 0 }

        let lengths = segments.map { $0.count }
        let average = Double(lengths.reduce(0, +)) / Double(lengths.count)
        let variance = lengths.map { pow(Double($0) - average, 2) }.reduce(0, +) / Double(lengths.count)
        let standardDeviation = sqrt(variance)

        // Higher standard deviation = better pacing variety
        // Normalize to 0-100 scale (stdev of 30+ = 100%)
        return min(100, Int((standardDeviation / 30.0) * 100))
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

    // MARK: - Character Arc Analysis

    private func extractCharacterNames(from text: String) -> [String] {
        // Get library character names first
        let libraryNames = Set(CharacterLibrary.shared.characters.map { $0.fullName })

        // Find capitalized words (potential names)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var nameCounts: [String: Int] = [:]

        // Common words to exclude - only used for non-library characters
        let excludeWords: Set<String> = [
            "The", "A", "An", "He", "She", "They", "I", "We", "You",
            "But", "And", "Or", "If", "When", "Where", "Why", "How",
            "Chapter", "Part", "Section", "Act",
            "His", "Her", "Their", "Its", "My", "Our", "Your",
            "It", "As", "At", "In", "On", "To", "From", "With",
            "This", "That", "These", "Those", "What", "Which", "Who",
            "All", "Some", "Any", "No", "Not", "Yes"
        ]

        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            // Check if word starts with capital and is 2+ chars
            if cleaned.count >= 2,
               let first = cleaned.first,
               first.isUppercase {
                // If in library, always include; otherwise check excludeWords
                if libraryNames.contains(cleaned) || !excludeWords.contains(cleaned) {
                    nameCounts[cleaned, default: 0] += 1
                }
            }
        }

        // Return names that appear at least 3 times, sorted by frequency
        let characters = nameCounts
            .filter { $0.value >= 3 }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }

        return Array(characters)
    }

    func analyzeCharacterArcs(text: String, characterNames: [String], outlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = nil, pageMapping: [(location: Int, page: Int)]? = nil) -> ([DecisionBeliefLoop], [CharacterInteraction], [CharacterPresence]) {
        let analyzer = DecisionBeliefLoopAnalyzer()

        // Analyze text and populate Decision-Belief Loop with actual detected patterns
        let loops = analyzer.analyzeLoops(text: text, characterNames: characterNames, outlineEntries: outlineEntries, pageMapping: pageMapping)
        let interactions = analyzer.analyzeInteractions(text: text, characterNames: characterNames)
        let presence = analyzer.analyzePresenceByChapter(text: text, characterNames: characterNames, outlineEntries: outlineEntries)

        return (loops, interactions, presence)
    }

    func generateBeliefShiftMatrices(text: String, characterNames: [String], outlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = nil) -> [BeliefShiftMatrix] {
        var matrices: [BeliefShiftMatrix] = []

        // Get actual chapters from outline or fall back to regex detection
        let chapters: [(number: Int, text: String)]
        if let entries = outlineEntries, !entries.isEmpty {
            // Look for level 1 entries (chapters) first
            let chapterEntries = entries.filter { $0.level == 1 }
            let effectiveEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]
            if !chapterEntries.isEmpty {
                effectiveEntries = chapterEntries
            } else {
                // Fallback: try level 0 (parts) or level 2 (headings)
                let level0Entries = entries.filter { $0.level == 0 }
                let level2Entries = entries.filter { $0.level == 2 }
                if !level0Entries.isEmpty {
                    effectiveEntries = level0Entries
                } else if !level2Entries.isEmpty {
                    effectiveEntries = Array(level2Entries.prefix(10))
                } else {
                    effectiveEntries = []
                }
            }
            if !effectiveEntries.isEmpty {
                let fullText = text as NSString
                chapters = effectiveEntries.enumerated().map { index, entry in
                    let startLocation = entry.range.location
                    let endLocation: Int
                    if index < effectiveEntries.count - 1 {
                        endLocation = effectiveEntries[index + 1].range.location
                    } else {
                        endLocation = fullText.length
                    }
                    let chapterRange = NSRange(location: startLocation, length: endLocation - startLocation)
                    return (number: index + 1, text: fullText.substring(with: chapterRange))
                }
            } else {
                // No outline structure found - use regex detection
                let chapterTexts = splitIntoChapters(text: text)
                chapters = chapterTexts.enumerated().map { (number: $0 + 1, text: $1) }
            }
        } else {
            let chapterTexts = splitIntoChapters(text: text)
            chapters = chapterTexts.enumerated().map { (number: $0 + 1, text: $1) }
        }

        // For now, generate sample data but use actual chapter numbers from document
        // In a future version, this would use NLP to detect belief statements in the narrative

        for characterName in characterNames.prefix(3) { // Limit to top 3 characters
            var entries: [BeliefShiftMatrix.BeliefEntry] = []

            // Use actual chapter numbers from the document
            let chapterNumbers = chapters.map { $0.number }
            let sampleChapters = chapterNumbers.count >= 3 ?
                [chapterNumbers[0], chapterNumbers[min(chapterNumbers.count / 2, chapterNumbers.count - 1)], chapterNumbers[chapterNumbers.count - 1]] :
                chapterNumbers

            // Create sample entries for demonstration using actual chapter numbers
            if characterName.lowercased().contains("alex") || characterName.lowercased().contains("protagonist") {
                for (index, chapterNum) in sampleChapters.enumerated() {
                    if index == 0 {
                        entries.append(BeliefShiftMatrix.BeliefEntry(
                            chapter: chapterNum,
                            chapterPage: 12,
                            coreBelief: "I survive alone.",
                            evidence: "Refuses help from teammates, takes risky solo missions",
                            evidencePage: 15,
                            counterpressure: "Offered protection by mentor figure",
                            counterpressurePage: 18
                        ))
                    } else if index == 1 {
                        entries.append(BeliefShiftMatrix.BeliefEntry(
                            chapter: chapterNum,
                            chapterPage: 87,
                            coreBelief: "Help costs freedom.",
                            evidence: "Accepts dangerous deal to maintain autonomy",
                            evidencePage: 92,
                            counterpressure: "Loses control in exchange for assistance",
                            counterpressurePage: 95
                        ))
                    } else {
                        entries.append(BeliefShiftMatrix.BeliefEntry(
                            chapter: chapterNum,
                            chapterPage: 203,
                            coreBelief: "Interdependence is strength.",
                            evidence: "Makes voluntary sacrifice for team",
                            evidencePage: 210,
                            counterpressure: "Fear of betrayal resurfaces briefly",
                            counterpressurePage: 215
                        ))
                    }
                }
            } else {
                // Generic entries for other characters using actual chapter numbers
                for (index, chapterNum) in sampleChapters.prefix(2).enumerated() {
                    if index == 0 {
                        entries.append(BeliefShiftMatrix.BeliefEntry(
                            chapter: chapterNum,
                            chapterPage: 20,
                            coreBelief: "The rules protect us.",
                            evidence: "Follows protocol strictly",
                            evidencePage: 25,
                            counterpressure: "Protocol fails in critical moment",
                            counterpressurePage: 30
                        ))
                    } else {
                        entries.append(BeliefShiftMatrix.BeliefEntry(
                            chapter: chapterNum,
                            chapterPage: 145,
                            coreBelief: "Some rules must be broken for the greater good.",
                            evidence: "Makes unauthorized decision that saves lives",
                            evidencePage: 150,
                            counterpressure: "Faces consequences and judgment",
                            counterpressurePage: 155
                        ))
                    }
                }
            }

            if !entries.isEmpty {
                let matrix = BeliefShiftMatrix(characterName: characterName, entries: entries)
                matrices.append(matrix)
            }
        }

        return matrices
    }

    func generateDecisionConsequenceChains(text: String, characterNames: [String], outlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = nil) -> [DecisionConsequenceChain] {
        var chains: [DecisionConsequenceChain] = []

        // Get actual chapters from outline or fall back to regex detection
        let chapters: [(number: Int, text: String)]
        if let entries = outlineEntries, !entries.isEmpty {
            // Look for level 1 entries (chapters) first
            let chapterEntries = entries.filter { $0.level == 1 }
            let effectiveEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]
            if !chapterEntries.isEmpty {
                effectiveEntries = chapterEntries
            } else {
                // Fallback: try level 0 (parts) or level 2 (headings)
                let level0Entries = entries.filter { $0.level == 0 }
                let level2Entries = entries.filter { $0.level == 2 }
                if !level0Entries.isEmpty {
                    effectiveEntries = level0Entries
                } else if !level2Entries.isEmpty {
                    effectiveEntries = Array(level2Entries.prefix(10))
                } else {
                    effectiveEntries = []
                }
            }
            if !effectiveEntries.isEmpty {
                let fullText = text as NSString
                chapters = effectiveEntries.enumerated().map { index, entry in
                    let startLocation = entry.range.location
                    let endLocation: Int
                    if index < effectiveEntries.count - 1 {
                        endLocation = effectiveEntries[index + 1].range.location
                    } else {
                        endLocation = fullText.length
                    }
                    let chapterRange = NSRange(location: startLocation, length: endLocation - startLocation)
                    return (number: index + 1, text: fullText.substring(with: chapterRange))
                }
            } else {
                // No outline structure found - use regex detection
                let chapterTexts = splitIntoChapters(text: text)
                chapters = chapterTexts.enumerated().map { (number: $0 + 1, text: $1) }
            }
        } else {
            let chapterTexts = splitIntoChapters(text: text)
            chapters = chapterTexts.enumerated().map { (number: $0 + 1, text: $1) }
        }

        // For now, generate sample data but use actual chapter numbers from document
        // In a future version, this would use NLP to detect decision points and consequences

        for characterName in characterNames.prefix(3) { // Limit to top 3 characters
            var entries: [DecisionConsequenceChain.ChainEntry] = []

            // Use actual chapter numbers from the document
            let chapterNumbers = chapters.map { $0.number }
            let sampleChapters = chapterNumbers.count >= 4 ?
                [chapterNumbers[0], chapterNumbers[min(chapterNumbers.count / 3, chapterNumbers.count - 1)],
                 chapterNumbers[min((chapterNumbers.count * 2) / 3, chapterNumbers.count - 1)], chapterNumbers[chapterNumbers.count - 1]] :
                chapterNumbers

            // Create sample entries for demonstration using actual chapter numbers
            if characterName.lowercased().contains("alex") || characterName.lowercased().contains("protagonist") {
                for (index, chapterNum) in sampleChapters.enumerated() {
                    switch index {
                    case 0:
                        entries.append(DecisionConsequenceChain.ChainEntry(
                            chapter: chapterNum,
                            chapterPage: 15,
                            decision: "Refuses help from mentor, chooses solo mission",
                            decisionPage: 15,
                            immediateOutcome: "Nearly fails first objective alone",
                            immediateOutcomePage: 22,
                            longTermEffect: "Develops mistrust of authority figures",
                            longTermEffectPage: 30
                        ))
                    case 1:
                        entries.append(DecisionConsequenceChain.ChainEntry(
                            chapter: chapterNum,
                            chapterPage: 68,
                            decision: "Accepts dangerous alliance to gain intel",
                            decisionPage: 68,
                            immediateOutcome: "Gets valuable information but makes enemy",
                            immediateOutcomePage: 75,
                            longTermEffect: "Creates secondary antagonist for Act 2",
                            longTermEffectPage: 95
                        ))
                    case 2:
                        entries.append(DecisionConsequenceChain.ChainEntry(
                            chapter: chapterNum,
                            chapterPage: 142,
                            decision: "Reveals secret to save teammate",
                            decisionPage: 142,
                            immediateOutcome: "Team member survives but learns truth",
                            immediateOutcomePage: 148,
                            longTermEffect: "Relationship dynamic permanently shifts, builds trust",
                            longTermEffectPage: 165
                        ))
                    default:
                        entries.append(DecisionConsequenceChain.ChainEntry(
                            chapter: chapterNum,
                            chapterPage: 205,
                            decision: "Sacrifices personal goal for greater good",
                            decisionPage: 205,
                            immediateOutcome: "Mission succeeds, personal loss sustained",
                            immediateOutcomePage: 212,
                            longTermEffect: "Character growth complete, embraces new identity",
                            longTermEffectPage: 220
                        ))
                    }
                }
            } else {
                // Generic entries for other characters using actual chapter numbers
                for (index, chapterNum) in sampleChapters.prefix(2).enumerated() {
                    if index == 0 {
                        entries.append(DecisionConsequenceChain.ChainEntry(
                            chapter: chapterNum,
                            chapterPage: 35,
                            decision: "Chooses loyalty over personal safety",
                            decisionPage: 35,
                            immediateOutcome: "Gains trust but faces danger",
                            immediateOutcomePage: 40,
                            longTermEffect: "Becomes key ally in conflict",
                            longTermEffectPage: 55
                        ))
                    } else {
                        entries.append(DecisionConsequenceChain.ChainEntry(
                            chapter: chapterNum,
                            chapterPage: 125,
                            decision: "Breaks protocol to help protagonist",
                            decisionPage: 125,
                            immediateOutcome: "Faces disciplinary action",
                            immediateOutcomePage: 130,
                            longTermEffect: "Solidifies commitment to cause",
                            longTermEffectPage: 145
                        ))
                    }
                }
            }

            if !entries.isEmpty {
                let chain = DecisionConsequenceChain(characterName: characterName, entries: entries)
                chains.append(chain)
            }
        }

        return chains
    }

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
}

