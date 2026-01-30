//
//  AnalysisEngine.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation
import Cocoa

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

    // Poetry (template-specific)
    var poetryInsights: PoetryInsights?
}

struct PoetryInsights {
    struct CountedItem {
        let text: String
        let count: Int
    }

    struct FormalTechnical {
        let lineCount: Int
        let stanzaCount: Int
        let averageLineLength: Int
        let lineLengthStdDev: Double
        let enjambmentRate: Double // 0..1
        let caesuraRate: Double // 0..1
        let rhymeSchemeByStanza: [String]
        let notableRepetitions: [CountedItem]
        let notableAnaphora: [CountedItem]
        let alliterationExamples: [String]
    }

    enum Sense: String, CaseIterable {
        case visual = "Visual"
        case auditory = "Auditory"
        case tactile = "Tactile"
        case olfactory = "Olfactory"
        case gustatory = "Gustatory"
        case kinesthetic = "Kinesthetic"
    }

    struct ImagerySensory {
        let countsBySense: [Sense: Int]
        let dominantSenses: [Sense]
        let topSensoryTokens: [CountedItem]
    }

    struct VoiceRhetoric {
        let firstPersonPronouns: Int
        let secondPersonPronouns: Int
        let thirdPersonPronouns: Int
        let questions: Int
        let exclamations: Int
        let hedges: [CountedItem]
        let modality: [CountedItem]
        let likelyAddressMode: String
        let candidateVoltaLine: Int?
    }

    struct EmotionalTrajectory {
        let lineScores: [Double] // -1..1 per analyzed line
        let stanzaScores: [Double] // -1..1 per stanza (average of lineScores)
        let peakLine: Int?
        let troughLine: Int?
        let peakStanza: Int?
        let troughStanza: Int?
        let volatility: Double
        let notableShiftLines: [Int]
        let notableShiftStanzas: [Int]
    }

    struct ThemeMotif {
        let topMotifs: [CountedItem]
        let repeatedPhrases: [CountedItem]
    }

    struct MacroStructure {
        let stanzaLineCounts: [Int]
        let longestStanzaIndex: Int?
        let shortestStanzaIndex: Int?
    }

    enum PoetryMode: String {
        case lyric = "Lyric"
        case contemplative = "Contemplative"
        case narrative = "Narrative"
        case hybrid = "Hybrid"
    }

    /// Writer-facing craft lenses ("How was this built—and how could I steal it?")
    struct WritersAnalysis {
        let mode: PoetryMode
        let modeRationale: String
        let pressurePoints: [String]
        let lineEnergy: [String]
        let imageLogic: [String]
        let voiceManagement: [String]
        let emotionalArc: [String]
        let compressionChoices: [String]
        let endingStrategy: [String]
    }

    let formal: FormalTechnical
    let imagery: ImagerySensory
    let voice: VoiceRhetoric
    let emotion: EmotionalTrajectory
    let motif: ThemeMotif
    let structure: MacroStructure
    let writers: WritersAnalysis
}

class AnalysisEngine {

    private func normalizedCharacterKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func libraryValidatedCharacterNames(from input: [String]) -> [String] {
        let library = CharacterLibrary.shared

        // Map normalized keys back to the library’s canonical display/analysis key.
        let libraryKeys = library.analysisCharacterKeys
        var normalizedToLibraryKey: [String: String] = [:]
        for key in libraryKeys {
            normalizedToLibraryKey[normalizedCharacterKey(key)] = key
        }

        var seen: Set<String> = []
        var out: [String] = []
        for name in input {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let normalized = normalizedCharacterKey(trimmed)
            let canonical = normalizedToLibraryKey[normalized] ?? trimmed
            if seen.insert(canonical).inserted {
                out.append(canonical)
            }
        }
        return out
    }

    // Passive voice patterns (expanded to catch common irregular participles)
    private static let passiveIrregularParticiples: [String] = [
        "known", "seen", "given", "taken", "done", "gone", "made", "found", "kept", "left", "lost",
        "built", "bought", "caught", "felt", "held", "heard", "lent", "paid", "read", "said",
        "sold", "sent", "set", "told", "thought", "understood", "written", "driven", "eaten",
        "thrown", "grown", "broken", "chosen", "spoken", "forgotten", "forgiven", "hidden",
        "shown", "sung", "worn", "born", "put", "cut", "hit", "hurt", "won", "beaten",
        "bound", "fed", "laid", "led", "met"
    ]

    private static let passiveVoicePatterns = [
        "\\b(?:am|is|are|was|were|be|been|being)\\b\\s+\\w+ed\\b",
        "\\b(?:am|is|are|was|were|be|been|being)\\b\\s+being\\s+\\w+ed\\b",
        "\\b(?:am|is|are|was|were|be|been|being)\\b\\s+(?:" + passiveIrregularParticiples.joined(separator: "|") + ")\\b"
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

    func analyzeText(
        _ text: String,
        outlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = nil,
        pageMapping: [(location: Int, page: Int)]? = nil,
        pageCountOverride: Int? = nil
    ) -> AnalysisResults {
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
        if StyleCatalog.shared.isPoetryTemplate {
            let poemLines = poetryBodyLines(from: text)
            let poemTokens = poemLines.flatMap { tokenizeWords($0) }
            if !poemTokens.isEmpty {
                results.wordCount = poemTokens.count
            }
        }
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

        // Page count (manuscript: ~250 words/page; screenplay: ~55 lines/page)
        // Use content-based detection so screenplay behavior works even if the user didn't pick a screenplay template.
        let formatDetector = DocumentFormatDetector()
        let detectedFormat = formatDetector.detectFormat(text: analysisText).format
        if let override = pageCountOverride, override > 0 {
            results.pageCount = override
        } else if detectedFormat == .screenplay {
            results.pageCount = estimateScreenplayPageCount(text: text)
        } else {
            results.pageCount = max(1, (results.wordCount + 249) / 250)
        }

        // Plot point analysis
        let plotDetector = PlotPointDetector()
        results.plotAnalysis = plotDetector.detectPlotPoints(text: analysisText, wordCount: results.wordCount)

        // Character arc analysis
        // Characters must come ONLY from the Character Library.
        let characterNames = CharacterLibrary.shared.analysisCharacterKeys

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

        // Poetry insights (template-specific; does not require Character Library)
        if StyleCatalog.shared.isPoetryTemplate {
            results.poetryInsights = generatePoetryInsights(text: analysisText)
        } else {
            results.poetryInsights = nil
        }

        return results
    }

    // MARK: - Poetry Analysis

    private func poetryBodyLines(from text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // Drop obvious title/author header if present: a few short lines followed by a blank line.
        if let firstBlank = rawLines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
           firstBlank > 0 && firstBlank <= 5 {
            let header = rawLines[0..<firstBlank]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if header.count >= 1 && header.count <= 3 && header.allSatisfy({ ($0 as NSString).length <= 80 }) {
                rawLines.removeSubrange(0...firstBlank)
            }
        }

        // Fallback header detection (no blank line): strip 1–3 short header lines if the body is long enough.
        let trimmedNonEmpty = rawLines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if trimmedNonEmpty.count >= 8 {
            func isHeaderCandidate(_ line: String) -> Bool {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return false }
                if trimmed.count > 60 { return false }
                if trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ".,;:!?")) != nil { return false }
                return true
            }

            var headerLineIndexes: [Int] = []
            for (idx, line) in rawLines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                if isHeaderCandidate(line), headerLineIndexes.count < 3 {
                    headerLineIndexes.append(idx)
                    continue
                }
                break
            }

            if !headerLineIndexes.isEmpty {
                let headerCount = headerLineIndexes.count
                if headerCount <= 3 {
                    // Remove contiguous header lines at the top.
                    let lastHeaderIndex = headerLineIndexes.last ?? -1
                    if lastHeaderIndex >= 0 {
                        rawLines.removeSubrange(0...lastHeaderIndex)
                    }
                }
            }
        }

        return rawLines
    }

    private func generatePoetryInsights(text: String) -> PoetryInsights {
        let rawLines = poetryBodyLines(from: text)

        // Build stanzas as contiguous non-empty line blocks.
        var stanzas: [[String]] = []
        var current: [String] = []
        for line in rawLines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !current.isEmpty {
                    stanzas.append(current)
                    current = []
                }
                continue
            }
            current.append(line)
        }
        if !current.isEmpty { stanzas.append(current) }

        let lines = stanzas.flatMap { $0 }

        // Formal/technical
        let lineLengths: [Int] = lines.map { ($0.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).length }
        let averageLineLength = lineLengths.isEmpty ? 0 : Int(round(Double(lineLengths.reduce(0, +)) / Double(lineLengths.count)))
        let stdDev = standardDeviation(lineLengths.map(Double.init))

        let punctuationEnd = CharacterSet(charactersIn: ".,;:!?\"'”)”»—–")
        let enjambedCount: Int = lines.reduce(0) { acc, line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return acc }
            if let last = trimmed.unicodeScalars.last, punctuationEnd.contains(last) {
                return acc
            }
            return acc + 1
        }
        let enjambmentRate = lines.isEmpty ? 0.0 : Double(enjambedCount) / Double(lines.count)

        let caesuraCount: Int = lines.reduce(0) { acc, line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return acc }
            // crude: dash/semicolon/colon/comma in the middle of the line
            let mid = trimmed.index(trimmed.startIndex, offsetBy: max(0, trimmed.count / 2))
            let left = trimmed[..<mid]
            let right = trimmed[mid...]
            if (left.contains("—") || left.contains(":") || left.contains(";") || left.contains(",")) && right.trimmingCharacters(in: .whitespacesAndNewlines).count > 2 {
                return acc + 1
            }
            return acc
        }
        let caesuraRate = lines.isEmpty ? 0.0 : Double(caesuraCount) / Double(lines.count)

        let rhymeSchemeByStanza: [String] = stanzas.map { stanza in
            var keyToLetter: [String: Character] = [:]
            var nextLetterScalar = UnicodeScalar("A").value
            var scheme: [Character] = []

            for line in stanza {
                let endKey = rhymeKey(for: line)
                if endKey.isEmpty {
                    scheme.append("-" )
                    continue
                }
                if let existing = keyToLetter[endKey] {
                    scheme.append(existing)
                } else {
                    let letter = Character(UnicodeScalar(nextLetterScalar)!)
                    nextLetterScalar += 1
                    keyToLetter[endKey] = letter
                    scheme.append(letter)
                }
            }
            return String(scheme)
        }

        let stopwords = poetryStopwords
        let tokensByLine: [[String]] = lines.map { tokenizeWords($0) }

        // Repetition (content words)
        var wordCounts: [String: Int] = [:]
        for tokens in tokensByLine {
            for w in tokens {
                if stopwords.contains(w) { continue }
                if w.count <= 2 { continue }
                wordCounts[w, default: 0] += 1
            }
        }
        let notableRepetitions = topCountedItems(from: wordCounts, limit: 8, minCount: 2)

        // Anaphora: repeated first 1-2 words at line starts.
        var startPhraseCounts: [String: Int] = [:]
        for tokens in tokensByLine {
            let leading = tokens.filter { !stopwords.contains($0) }
            if let first = leading.first {
                startPhraseCounts[first, default: 0] += 1
            }
            if leading.count >= 2 {
                let phrase = leading[0] + " " + leading[1]
                startPhraseCounts[phrase, default: 0] += 1
            }
        }
        let notableAnaphora = topCountedItems(from: startPhraseCounts, limit: 6, minCount: 2)

        let alliterationExamples = findAlliterationExamples(lines: lines, limit: 6)

        let formal = PoetryInsights.FormalTechnical(
            lineCount: lines.count,
            stanzaCount: stanzas.count,
            averageLineLength: averageLineLength,
            lineLengthStdDev: stdDev,
            enjambmentRate: enjambmentRate,
            caesuraRate: caesuraRate,
            rhymeSchemeByStanza: rhymeSchemeByStanza,
            notableRepetitions: notableRepetitions,
            notableAnaphora: notableAnaphora,
            alliterationExamples: alliterationExamples
        )

        // Imagery & sensory
        let imagery = analyzeImagery(tokensByLine: tokensByLine)

        // Voice & rhetoric
        let voice = analyzeVoiceAndRhetoric(lines: lines, tokensByLine: tokensByLine)

        let stanzaLineCounts = stanzas.map { $0.count }

        // Emotional trajectory
        let emotion = analyzePoetryEmotion(
            lines: lines,
            tokensByLine: tokensByLine,
            stanzaLineCounts: stanzaLineCounts,
            candidateVoltaLine: voice.candidateVoltaLine
        )

        // Motifs
        let motif = analyzeMotifs(tokensByLine: tokensByLine)

        // Macro structure
        let longest = stanzaLineCounts.enumerated().max(by: { $0.element < $1.element })?.offset
        let shortest = stanzaLineCounts.enumerated().min(by: { $0.element < $1.element })?.offset
        let structure = PoetryInsights.MacroStructure(stanzaLineCounts: stanzaLineCounts, longestStanzaIndex: longest, shortestStanzaIndex: shortest)

        // Writer-oriented craft lenses
        let writers = buildWritersAnalysis(
            lines: lines,
            stanzas: stanzas,
            tokensByLine: tokensByLine,
            formal: formal,
            imagery: imagery,
            voice: voice,
            emotion: emotion,
            motif: motif
        )

        return PoetryInsights(formal: formal, imagery: imagery, voice: voice, emotion: emotion, motif: motif, structure: structure, writers: writers)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }

    private func rhymeKey(for line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let pieces = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let last = pieces.last else { return "" }
        let cleaned = last
            .lowercased()
            .replacingOccurrences(of: "[^a-z']", with: "", options: .regularExpression)
        guard !cleaned.isEmpty else { return "" }
        if cleaned.count <= 3 { return cleaned }
        return String(cleaned.suffix(3))
    }

    private var poetryStopwords: Set<String> {
        [
            "the", "a", "an", "and", "or", "but", "if", "then", "so", "than", "as",
            "to", "of", "in", "on", "at", "by", "for", "from", "with", "without", "into", "over", "under",
            "is", "are", "was", "were", "be", "been", "being", "do", "did", "does", "have", "has", "had",
            "i", "me", "my", "mine", "you", "your", "yours", "we", "us", "our", "ours", "he", "him", "his", "she", "her", "hers", "they", "them", "their", "theirs",
            "this", "that", "these", "those", "it", "its", "not", "no", "yes", "all", "any", "some",
            "there", "here", "where", "when", "why", "how", "what", "who", "whom",
            "up", "down", "out", "off", "again", "once", "very", "just", "only", "even"
        ]
    }

    private func tokenizeWords(_ line: String) -> [String] {
        let lower = line.lowercased()
        return lower
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func topCountedItems(from counts: [String: Int], limit: Int, minCount: Int) -> [PoetryInsights.CountedItem] {
        counts
            .filter { $0.value >= minCount }
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                return a.key < b.key
            }
            .prefix(limit)
            .map { PoetryInsights.CountedItem(text: $0.key, count: $0.value) }
    }

    private func findAlliterationExamples(lines: [String], limit: Int) -> [String] {
        func initialSound(_ word: String) -> String? {
            let cleaned = word.lowercased().replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
            guard let first = cleaned.first else { return nil }
            return String(first)
        }

        var examples: [String] = []
        for (idx, line) in lines.enumerated() {
            let words = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            var runChar: String?
            var runLen = 0
            var best: (String, Int)? = nil

            for w in words {
                guard let c = initialSound(w) else { continue }
                if c == runChar {
                    runLen += 1
                } else {
                    if let rc = runChar, runLen >= 2 {
                        if best == nil || runLen > best!.1 { best = (rc, runLen) }
                    }
                    runChar = c
                    runLen = 1
                }
            }
            if let rc = runChar, runLen >= 2 {
                if best == nil || runLen > best!.1 { best = (rc, runLen) }
            }
            if let best {
                examples.append("Line \(idx + 1): repeated initial '\(best.0)' (\(best.1)×)")
            }
            if examples.count >= limit { break }
        }
        return examples
    }

    private func buildWritersAnalysis(
        lines: [String],
        stanzas: [[String]],
        tokensByLine: [[String]],
        formal: PoetryInsights.FormalTechnical,
        imagery: PoetryInsights.ImagerySensory,
        voice: PoetryInsights.VoiceRhetoric,
        emotion: PoetryInsights.EmotionalTrajectory,
        motif: PoetryInsights.ThemeMotif
    ) -> PoetryInsights.WritersAnalysis {
        let stop = poetryStopwords

        enum PoetryFormContext {
            case stanzaicNarrativeBalladLike
            case stanzaicLyric
            case freeVerseOrOpenForm
            case mixedOrUnclear
        }

        func isABABOrABCBQuatrain(_ scheme: String) -> Bool {
            guard scheme.count == 4 else { return false }
            let chars = Array(scheme)
            // Treat "-" (unknown rhyme key) as non-matching.
            if chars.contains("-") { return false }

            // ABAB: 1=3 and 2=4, and A != B
            if chars[0] == chars[2] && chars[1] == chars[3] && chars[0] != chars[1] { return true }

            // ABCB: 2=4, and 1 != 2, 3 != 2
            if chars[1] == chars[3] && chars[0] != chars[1] && chars[2] != chars[1] { return true }

            return false
        }

        func inferFormContext(
            mode: PoetryInsights.PoetryMode,
            stanzas: [[String]],
            formal: PoetryInsights.FormalTechnical
        ) -> (context: PoetryFormContext, note: String?) {
            guard !stanzas.isEmpty else { return (.mixedOrUnclear, nil) }

            let stanzaCount = stanzas.count
            let counts = stanzas.map { $0.count }
            let quatrains = counts.filter { $0 == 4 }.count
            let sextets = counts.filter { $0 == 6 }.count
            let stanzaicRatio = Double(quatrains + sextets) / Double(stanzaCount)

            let quatrainSchemes = formal.rhymeSchemeByStanza.filter { $0.count == 4 }
            let balladQuatrains = quatrainSchemes.filter(isABABOrABCBQuatrain).count
            let balladQuatrainRatio = quatrainSchemes.isEmpty ? 0.0 : Double(balladQuatrains) / Double(quatrainSchemes.count)

            // Heuristic: long + mostly stanzaic + some alternating-rhyme quatrains => ballad-like narrative.
            let isLong = formal.lineCount >= 80 || formal.stanzaCount >= 10
            if isLong && stanzaicRatio >= 0.60 && (mode == .narrative || mode == .hybrid) && balladQuatrainRatio >= 0.25 {
                return (
                    .stanzaicNarrativeBalladLike,
                    "Form context: likely stanzaic narrative (ballad-like). Many line-ending stats (enjambment/hard-stops) are partly explained by quatrain/sextet structure—interpret them as constraints before choices."
                )
            }

            // Stanzaic but not clearly narrative.
            if stanzaicRatio >= 0.60 {
                return (
                    .stanzaicLyric,
                    "Form context: stanzaic structure detected. Some metrics (enjambment/hard-stops) will skew toward closure because stanzas create regular landing pads."
                )
            }

            // Open form proxy: no consistent stanzaic block + higher enjambment.
            if formal.stanzaCount <= 2 || formal.enjambmentRate >= 0.55 {
                return (
                    .freeVerseOrOpenForm,
                    "Form context: open-form / free-verse leaning. Line breaks are doing more semantic work here, so enjambment cues are more likely to be stylistic choices."
                )
            }

            return (.mixedOrUnclear, nil)
        }

        func formatCounted(_ items: ArraySlice<PoetryInsights.CountedItem>, limit: Int) -> String {
            items.prefix(limit).map { "\($0.text) (\($0.count)×)" }.joined(separator: ", ")
        }

        func pct(_ value: Double) -> String { "≈\(Int(round(value * 100)))%" }

        // --- Mode classification (very lightweight heuristic)
        let modeResult = classifyPoetryMode(lines: lines, tokensByLine: tokensByLine)

        // --- Form context (helps avoid over-interpreting metrics that are form-driven)
        let formContext = inferFormContext(mode: modeResult.mode, stanzas: stanzas, formal: formal)

        // --- Line ending behavior
        var openBreaks = 0
        var hardStops = 0
        var dashEndings = 0
        var questionEndings = 0
        var exclamationEndings = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let last = trimmed.last
            switch last {
            case "?": questionEndings += 1; hardStops += 1
            case "!": exclamationEndings += 1; hardStops += 1
            case ".": hardStops += 1
            case "—", "–": dashEndings += 1
            case ",", ";", ":": hardStops += 1
            default:
                openBreaks += 1
            }
        }
        let totalLines = max(1, lines.count)
        let openBreakRate = Double(openBreaks) / Double(totalLines)
        let hardStopRate = Double(hardStops) / Double(totalLines)

        // --- Exposition markers (compression proxy)
        let expositionMarkers: Set<String> = [
            "because", "therefore", "thus", "hence", "since", "means", "meaning", "explains", "explain",
            "define", "definition", "conclude", "conclusion", "implies", "imply"
        ]
        var expositionCount = 0
        for tokens in tokensByLine {
            for t in tokens {
                if expositionMarkers.contains(t) { expositionCount += 1 }
            }
        }

        // --- Opening/ending echo
        let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
        let lastLine = lines.last(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
        let firstTokens = Set(tokenizeWords(firstLine).filter { !stop.contains($0) && $0.count > 2 })
        let lastTokens = Set(tokenizeWords(lastLine).filter { !stop.contains($0) && $0.count > 2 })
        let unionCount = max(1, firstTokens.union(lastTokens).count)
        let overlap = Double(firstTokens.intersection(lastTokens).count) / Double(unionCount)

        // --- Motifs at the end
        let lastStanzaTokens: Set<String> = {
            guard let lastStanza = stanzas.last else { return [] }
            let toks = lastStanza.flatMap { tokenizeWords($0) }
            return Set(toks.filter { !stop.contains($0) && $0.count > 2 })
        }()
        let endingMotifs = motif.topMotifs
            .prefix(6)
            .map { $0.text }
            .filter { lastStanzaTokens.contains($0) }

        // --- Pressure Points
        var pressure: [String] = []

        if let note = formContext.note {
            pressure.append(note)
        }

        if formal.enjambmentRate >= 0.6 {
            pressure.append("High enjambment (\(pct(formal.enjambmentRate))): the poem delays closure; use this to carry tension without explaining it.")
        } else if formal.enjambmentRate <= 0.3 {
            switch formContext.context {
            case .stanzaicNarrativeBalladLike, .stanzaicLyric:
                pressure.append("Low enjambment (\(pct(formal.enjambmentRate))): expected in stanzaic forms where rhyme and cadence reward clean landings. If you want extra propulsion, use a few strategic run-on lines—but treat it as a pacing tool, not a rule-break for its own sake.")
            default:
                pressure.append("Low enjambment (\(pct(formal.enjambmentRate))): lines land cleanly. If you want a spike of forward-leaning pressure, try a few deliberate run-on lines (and notice how that changes breath and urgency).")
            }
        } else {
            pressure.append("Mixed closure (enjambment \(pct(formal.enjambmentRate))): you can control when the reader is allowed to " +
                            "know something by tightening or loosening line endings.")
        }

        if formal.caesuraRate >= 0.25 {
            pressure.append("Frequent mid-line pauses (caesura \(pct(formal.caesuraRate))): internal pivots are part of the music—great for reversals and rethinks.")
        }

        if formal.averageLineLength > 0 {
            let variability = (formal.lineLengthStdDev / Double(max(1, formal.averageLineLength)))
            if variability >= 0.35 {
                pressure.append("Line lengths vary a lot (σ/μ ≈ \(String(format: "%.2f", variability))): form is already doing emotional modulation for you.")
            }
        }

        if !formal.notableAnaphora.isEmpty {
            let top = formatCounted(formal.notableAnaphora.prefix(2), limit: 2)
            switch formContext.context {
            case .stanzaicNarrativeBalladLike:
                pressure.append("Refrain/anaphora signal: \(top). In ballad-like narration, repetition is often the engine (memory, inevitability, moral insistence). If you want emphasis, vary the refrain slightly at the turning point rather than fully breaking it.")
            default:
                pressure.append("You establish a rule early (anaphora): \(top). Consider varying it once for emphasis.")
            }
        }

        // --- Line Energy
        var lineEnergy: [String] = []
        lineEnergy.append("Open line breaks: \(pct(openBreakRate)); hard stops: \(pct(hardStopRate)). Line breaks are the poem’s timing edits (heuristic signal).")
        if dashEndings > 0 {
            lineEnergy.append("Dash endings (\(dashEndings)) keep meaning suspended—use them to deny closure or force rereads.")
        }
        if questionEndings > 0 {
            lineEnergy.append("Questions (\(questionEndings)) inject uncertainty—good for pressure without plot.")
        }
        if let volta = voice.candidateVoltaLine {
            switch formContext.context {
            case .stanzaicNarrativeBalladLike:
                lineEnergy.append("Candidate turn: line \(volta). In stanzaic narrative, a turn often lands at a stanza boundary or on a repeated line—consider marking it with a refrained phrase, a tonal gear-shift, or a suddenly plainer sentence.")
            default:
                lineEnergy.append("Candidate turn: line \(volta). If you want a pivot, tighten syntax right before it, then break pattern at the turn.")
            }
        }

        // --- Image Logic
        func dominantSenses(for tokens: [[String]]) -> String {
            let slice = analyzeImagery(tokensByLine: tokens)
            let dom = slice.dominantSenses.map { $0.rawValue }
            return dom.isEmpty ? "(none detected)" : dom.joined(separator: ", ")
        }

        var imageLogic: [String] = []
        if !lines.isEmpty {
            let third = max(1, lines.count / 3)
            let first = Array(tokensByLine.prefix(third))
            let middle = Array(tokensByLine.dropFirst(third).prefix(third))
            let last = Array(tokensByLine.suffix(max(1, lines.count - 2 * third)))
            imageLogic.append("Dominant sensory cues by section (start → middle → end): \(dominantSenses(for: first)) → \(dominantSenses(for: middle)) → \(dominantSenses(for: last)) (lexical/heuristic, interpretive).")
        }
        if !imagery.dominantSenses.isEmpty {
            let overall = imagery.dominantSenses.map { $0.rawValue }.joined(separator: ", ")
            imageLogic.append("Overall dominant sensory cues: \(overall) (based on detected sensory words).")
        }
        if !motif.topMotifs.isEmpty {
            let top = formatCounted(motif.topMotifs.prefix(6), limit: 6)
            imageLogic.append("Recurring image-words (motifs): \(top). Let order do the thinking—arrange these to escalate, soften, or turn uncanny.")
        }

        // --- Voice Management
        var voiceMgmt: [String] = []
        voiceMgmt.append("Address mode: \(voice.likelyAddressMode). Pronouns (1st/2nd/3rd): \(voice.firstPersonPronouns)/\(voice.secondPersonPronouns)/\(voice.thirdPersonPronouns).")
        if formContext.context == .stanzaicNarrativeBalladLike {
            voiceMgmt.append("Note: framed/narrative address is common in ballad-like poems (a speaker tells an event to a listener). Pronoun counts alone can mislabel this as " +
                             "\"lyric reflection\"—treat this as a delivery stance, not a persona diagnosis.")
        }
        if !voice.modality.isEmpty {
            let items = formatCounted(voice.modality.prefix(4), limit: 4)
            voiceMgmt.append("Modality pressure (must/should/never/etc.): \(items). Use certainty to create authority—or remove it to create vulnerability.")
        }
        if !voice.hedges.isEmpty {
            let items = formatCounted(voice.hedges.prefix(4), limit: 4)
            voiceMgmt.append("Hedges (maybe/seems/etc.): \(items). Strategic hedging can imply fear, irony, or self-protection.")
        }
        if voice.exclamations == 0 && voice.questions == 0 {
            voiceMgmt.append("Low overt rhetoric (no ?/! endings): tone reads controlled. That restraint can intensify disturbing content.")
        }

        // --- Emotional Arc
        func excerpt(lineNumber: Int, maxLen: Int = 80) -> String? {
            let idx = lineNumber - 1
            guard idx >= 0 && idx < lines.count else { return nil }
            let raw = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            if raw.count <= maxLen { return raw }
            let cutIdx = raw.index(raw.startIndex, offsetBy: maxLen)
            return String(raw[..<cutIdx]) + "…"
        }

        var emotionalArc: [String] = []

        if modeResult.mode == .narrative || formContext.context == .stanzaicNarrativeBalladLike {
            emotionalArc.append("Affect curve is a lexical estimate (word-based). In narrative poems it often tracks event intensity or moral dread more than a speaker’s interior mood—use it as instrumentation, not a critical verdict.")
        }

        let isLong = lines.count >= 80 || stanzas.count >= 10
        if isLong, !emotion.stanzaScores.isEmpty {
            if let peakStanza = emotion.peakStanza { emotionalArc.append("Peak intensity around stanza \(peakStanza).") }
            if let troughStanza = emotion.troughStanza { emotionalArc.append("Lowest point around stanza \(troughStanza).") }
            if !emotion.notableShiftStanzas.isEmpty {
                let shifts = emotion.notableShiftStanzas.prefix(6).map(String.init).joined(separator: ", ")
                emotionalArc.append("Major emotional turns by stanza: \(shifts).")
            }
            if let peak = emotion.peakLine, let ex = excerpt(lineNumber: peak) {
                emotionalArc.append("Example near the peak (line \(peak)): \"\(ex)\"")
            }
            if let trough = emotion.troughLine, let ex = excerpt(lineNumber: trough) {
                emotionalArc.append("Example near the low point (line \(trough)): \"\(ex)\"")
            }
        } else {
            if let peak = emotion.peakLine { emotionalArc.append("Peak intensity around line \(peak).") }
            if let trough = emotion.troughLine { emotionalArc.append("Lowest point around line \(trough).") }
            if !emotion.notableShiftLines.isEmpty {
                let shifts = emotion.notableShiftLines.prefix(6).map(String.init).joined(separator: ", ")
                emotionalArc.append("Notable emotional turns near lines: \(shifts).")
            }
            if let peak = emotion.peakLine, let ex = excerpt(lineNumber: peak) {
                emotionalArc.append("Example near the peak: \"\(ex)\"")
            }
        }

        let endWindow = emotion.lineScores.suffix(3)
        let endAvg = endWindow.isEmpty ? 0.0 : (endWindow.reduce(0, +) / Double(endWindow.count))
        let endingPunct = lastLine.trimmingCharacters(in: .whitespacesAndNewlines).last
        let endingJob: String
        switch endingPunct {
        case "?": endingJob = "Ends in suspension (question)."
        case "!": endingJob = "Ends with a surge (exclamation)."
        case "—", "–": endingJob = "Ends in refusal/suspension (dash)."
        default:
            if endAvg >= 0.2 { endingJob = "Ends with emotional lift." }
            else if endAvg <= -0.2 { endingJob = "Ends in darkening/unease." }
            else { endingJob = "Ends without clear resolution (steady state)." }
        }
        emotionalArc.append(endingJob)

        // --- Compression Choices
        var compression: [String] = []
        if expositionCount <= 1 {
            compression.append("Low explanation markers: the poem relies on implication more than reasoning.")
        } else {
            switch formContext.context {
            case .stanzaicNarrativeBalladLike:
                compression.append("Explanation markers detected (\(expositionCount)). In ballad/parable modes, explicit causality and reiteration can be part of the ethic (moral insistence). If it drags, try compressing one explanatory aside or moving explanation into a repeated line—avoid removing clarity that’s doing thematic work.")
            default:
                compression.append("Explanation markers detected (\(expositionCount))—if the poem feels over-explained, try compressing one causal bridge (keep the logic, reduce the connective tissue).")
            }
        }
        let avgLineLen = formal.averageLineLength
        if avgLineLen > 0 {
            if avgLineLen <= 35 {
                compression.append("Short lines (avg \(avgLineLen) chars) concentrate meaning; silence is already doing work.")
            } else if avgLineLen >= 70 {
                compression.append("Longer lines (avg \(avgLineLen) chars) read more prose-like; consider strategic cuts to increase pressure.")
            }
        }

        // --- Ending Strategy
        var ending: [String] = []
        if overlap >= 0.18 {
            ending.append("Ending echoes the opening (shared keywords overlap ≈ \(String(format: "%.0f", overlap * 100))%). Echoes make rereads inevitable.")
        } else {
            ending.append("Ending resists the opening (low keyword overlap). Resistive endings can reframe the first line without mirroring it.")
        }
        let lowerLastLine = lastLine.lowercased()
        let isCount = max(0, lowerLastLine.components(separatedBy: " is ").count - 1)
        if isCount >= 2 {
            ending.append("Ending pivots to aphorism (repeated “is” claims), which can override motif cues.")
        }
        if !endingMotifs.isEmpty {
            ending.append("Ending includes established motif tokens: \(endingMotifs.prefix(3).joined(separator: ", ")).")
        }
        let directionWords: Set<String> = ["toward", "into", "beyond", "away", "home", "forward", "out", "through"]
        let lastLineTokens = Set(tokenizeWords(lastLine))
        if !directionWords.intersection(lastLineTokens).isEmpty {
            ending.append("The last line is directional (points somewhere). Endings that point often feel stronger than endings that conclude.")
        }

        return PoetryInsights.WritersAnalysis(
            mode: modeResult.mode,
            modeRationale: modeResult.rationale,
            pressurePoints: pressure,
            lineEnergy: lineEnergy,
            imageLogic: imageLogic,
            voiceManagement: voiceMgmt,
            emotionalArc: emotionalArc,
            compressionChoices: compression,
            endingStrategy: ending
        )
    }

    private func classifyPoetryMode(lines: [String], tokensByLine: [[String]]) -> (mode: PoetryInsights.PoetryMode, rationale: String) {
        // Intentionally heuristic and writer-facing (not a scholarly taxonomy).
        // Key goal: avoid calling contemplative/ekphrastic poems “narrative” just because they use common verbs.

        let narrativeMarkers: Set<String> = [
            // temporal sequence
            "then", "when", "after", "before", "suddenly", "later", "once", "while", "until",
            // action/event verbs (very small sample)
            "walk", "walked", "run", "ran", "went", "go", "came", "come", "turned", "turn", "took", "take", "gave", "give", "made", "make",
            // report speech tends to imply scene
            "said", "say", "told", "tell", "asked", "ask"
        ]

        let addressMarkers: Set<String> = [
            "you", "your", "yours", "thou", "thee", "thy", "thine", "ye", "o", "oh"
        ]

        let contemplationVerbs: Set<String> = [
            "think", "thought", "know", "knew", "see", "saw", "seem", "seems", "remember", "imagine", "wonder", "ask", "tell", "consider"
        ]

        let abstractMarkers: Set<String> = [
            "truth", "beauty", "time", "eternity", "forever", "still", "silence", "mind", "soul", "idea", "meaning"
        ]

        var actionScore = 0
        var reflectionScore = 0
        var addressScore = 0
        var pastTenseScore = 0

        for tokens in tokensByLine {
            for t in tokens {
                if narrativeMarkers.contains(t) { actionScore += 1 }
                if addressMarkers.contains(t) { addressScore += 1 }
                if contemplationVerbs.contains(t) { reflectionScore += 1 }
                if abstractMarkers.contains(t) { reflectionScore += 1 }
                if t.hasSuffix("ed") && t.count > 3 { pastTenseScore += 1 }
            }
        }

        // Dialogue-ish punctuation can push narrative a bit.
        let quoteCount = lines.reduce(0) { $0 + ($1.contains("\"") ? 1 : 0) }
        actionScore += min(6, quoteCount)
        actionScore += min(8, pastTenseScore)

        let questionCount = lines.reduce(0) { $0 + ($1.contains("?") ? 1 : 0) }
        // Questions are a strong contemplative signal.
        let contemplationScore = reflectionScore + (addressScore / 2) + (questionCount * 2)

        // Decide
        if actionScore >= contemplationScore + 10 {
            return (.narrative, "Leans narrative: action/sequence signals dominate (events/scenes implied).")
        }

        if contemplationScore >= actionScore + 10 {
            // Explicitly tell the writer what “happens” in this mode.
            return (
                .contemplative,
                "Leans contemplative: direct address/questions/ideas outweigh event markers. Plot may stay static; what changes is the speaker’s stance or understanding."
            )
        }

        // If neither dominates, fall back to lyric vs hybrid.
        let lyricScore = reflectionScore + addressScore
        if lyricScore >= actionScore + 4 {
            return (.lyric, "Leans lyric: voice and interior pressure outweigh event markers.")
        }
        return (.hybrid, "Hybrid: voice cues and event cues are both present.")
    }

    private func analyzeImagery(tokensByLine: [[String]]) -> PoetryInsights.ImagerySensory {
        let visual: Set<String> = ["see", "saw", "look", "looked", "light", "bright", "dark", "color", "shadow", "glow", "shimmer", "spark", "glitter", "eyes"]
        let auditory: Set<String> = ["hear", "heard", "sound", "sing", "song", "voice", "whisper", "shout", "silence", "echo", "rumble", "buzz"]
        let tactile: Set<String> = ["touch", "feel", "felt", "cold", "warm", "hot", "soft", "hard", "rough", "smooth", "skin", "bone"]
        let olfactory: Set<String> = ["smell", "scent", "odor", "fragrant", "musty", "stale", "fresh", "acrid", "perfume"]
        let gustatory: Set<String> = ["taste", "tasted", "sweet", "sour", "bitter", "salt", "salty", "honey", "tongue"]
        let kinesthetic: Set<String> = ["run", "ran", "walk", "walked", "move", "moved", "fall", "fell", "rise", "rising", "turn", "lean", "tremble", "shiver"]

        var counts: [PoetryInsights.Sense: Int] = Dictionary(uniqueKeysWithValues: PoetryInsights.Sense.allCases.map { ($0, 0) })
        var tokenCounts: [String: Int] = [:]

        for tokens in tokensByLine {
            for t in tokens {
                if visual.contains(t) { counts[.visual, default: 0] += 1; tokenCounts[t, default: 0] += 1 }
                else if auditory.contains(t) { counts[.auditory, default: 0] += 1; tokenCounts[t, default: 0] += 1 }
                else if tactile.contains(t) { counts[.tactile, default: 0] += 1; tokenCounts[t, default: 0] += 1 }
                else if olfactory.contains(t) { counts[.olfactory, default: 0] += 1; tokenCounts[t, default: 0] += 1 }
                else if gustatory.contains(t) { counts[.gustatory, default: 0] += 1; tokenCounts[t, default: 0] += 1 }
                else if kinesthetic.contains(t) { counts[.kinesthetic, default: 0] += 1; tokenCounts[t, default: 0] += 1 }
            }
        }

        let ranked = counts.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key.rawValue < b.key.rawValue
        }
        let dominant = ranked.filter { $0.value > 0 }.prefix(2).map { $0.key }

        let topTokens = topCountedItems(from: tokenCounts, limit: 8, minCount: 1)
        return PoetryInsights.ImagerySensory(countsBySense: counts, dominantSenses: dominant, topSensoryTokens: topTokens)
    }

    private func analyzeVoiceAndRhetoric(lines: [String], tokensByLine: [[String]]) -> PoetryInsights.VoiceRhetoric {
        let first: Set<String> = ["i", "me", "my", "mine", "myself"]
        let second: Set<String> = ["you", "your", "yours", "yourself"]
        let third: Set<String> = ["he", "him", "his", "she", "her", "hers", "they", "them", "their", "theirs"]

        let narrativeVerbs: Set<String> = [
            "said", "say", "told", "tell", "asked", "ask", "went", "go", "came", "come", "took", "take", "made", "make",
            "saw", "see", "heard", "hear", "did", "do", "had", "have", "was", "were", "fell", "fall", "rose", "rise"
        ]

        let hedgeWords: Set<String> = ["maybe", "perhaps", "seems", "seemed", "almost", "nearly", "kind", "sort", "possibly"]
        let modalityWords: Set<String> = ["must", "should", "ought", "need", "can't", "cannot", "won't", "never", "always"]
        let voltaCues: Set<String> = ["but", "yet", "however", "though", "although", "instead", "still", "then", "so", "therefore"]

        var firstCount = 0
        var secondCount = 0
        var thirdCount = 0
        var questions = 0
        var exclamations = 0
        var hedges: [String: Int] = [:]
        var modality: [String: Int] = [:]
        var candidateVoltaLine: Int? = nil
        var narrativeVerbHits = 0
        var quoteishLines = 0

        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix("?") { questions += 1 }
            if trimmed.hasSuffix("!") { exclamations += 1 }
            if trimmed.contains("\"") || trimmed.contains("“") || trimmed.contains("”") { quoteishLines += 1 }

            let tokens = tokensByLine[idx]
            for t in tokens {
                if first.contains(t) { firstCount += 1 }
                if second.contains(t) { secondCount += 1 }
                if third.contains(t) { thirdCount += 1 }
                if hedgeWords.contains(t) { hedges[t, default: 0] += 1 }
                if modalityWords.contains(t) { modality[t, default: 0] += 1 }
                if narrativeVerbs.contains(t) { narrativeVerbHits += 1 }
            }
            if candidateVoltaLine == nil {
                if tokens.contains(where: { voltaCues.contains($0) }) {
                    candidateVoltaLine = idx + 1
                }
            }
        }

        let hedgesTop = topCountedItems(from: hedges, limit: 6, minCount: 1)
        let modalityTop = topCountedItems(from: modality, limit: 6, minCount: 1)

        let likelyMode: String
        if secondCount > firstCount && secondCount > 0 {
            likelyMode = "Address (speaker → you)"
        } else if thirdCount > max(firstCount, secondCount) && (narrativeVerbHits >= 6 || quoteishLines >= 2) {
            likelyMode = "Narrative / storytelling voice (speaker → scene)"
        } else if firstCount > 0 {
            likelyMode = "First-person stance (speaker-centered)"
        } else {
            likelyMode = "Observational / descriptive"
        }

        return PoetryInsights.VoiceRhetoric(
            firstPersonPronouns: firstCount,
            secondPersonPronouns: secondCount,
            thirdPersonPronouns: thirdCount,
            questions: questions,
            exclamations: exclamations,
            hedges: hedgesTop,
            modality: modalityTop,
            likelyAddressMode: likelyMode,
            candidateVoltaLine: candidateVoltaLine
        )
    }

    private func analyzePoetryEmotion(
        lines: [String],
        tokensByLine: [[String]],
        stanzaLineCounts: [Int],
        candidateVoltaLine: Int?
    ) -> PoetryInsights.EmotionalTrajectory {
        let positive: Set<String> = ["love", "loved", "light", "bright", "warm", "hope", "joy", "gentle", "tender", "laugh", "smile", "grace", "bloom"]
        let negative: Set<String> = ["dark", "cold", "fear", "grief", "sad", "sorrow", "hate", "anger", "alone", "lonely", "hurt", "loss", "die", "dead", "empty"]
        let intensifiers: Set<String> = ["very", "so", "too", "utterly", "completely", "always", "never"]

        var scores: [Double] = []
        scores.reserveCapacity(lines.count)

        for (idx, line) in lines.enumerated() {
            let tokens = tokensByLine[idx]
            var pos = 0
            var neg = 0
            var amp = 0
            for t in tokens {
                if positive.contains(t) { pos += 1 }
                if negative.contains(t) { neg += 1 }
                if intensifiers.contains(t) { amp += 1 }
            }
            let denom = max(1, pos + neg)
            var score = Double(pos - neg) / Double(denom)
            if line.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("!") {
                score = max(-1.0, min(1.0, score * 1.15))
            }
            if amp > 0 {
                score = max(-1.0, min(1.0, score * (1.0 + min(0.25, Double(amp) * 0.05))))
            }
            scores.append(score)
        }

        let peak = scores.enumerated().max(by: { $0.element < $1.element })?.offset
        let trough = scores.enumerated().min(by: { $0.element < $1.element })?.offset

        // Aggregate to stanza scores using stanza boundaries.
        var stanzaScores: [Double] = []
        stanzaScores.reserveCapacity(stanzaLineCounts.count)
        var cursor = 0
        for count in stanzaLineCounts {
            guard count > 0 else { continue }
            let end = min(scores.count, cursor + count)
            if cursor >= scores.count { break }
            let slice = scores[cursor..<end]
            let avg = slice.isEmpty ? 0.0 : slice.reduce(0, +) / Double(slice.count)
            stanzaScores.append(avg)
            cursor = end
        }

        let peakStanza = stanzaScores.enumerated().max(by: { $0.element < $1.element })?.offset
        let troughStanza = stanzaScores.enumerated().min(by: { $0.element < $1.element })?.offset

        var deltas: [Double] = []
        if scores.count >= 2 {
            for i in 1..<scores.count {
                deltas.append(abs(scores[i] - scores[i - 1]))
            }
        }
        let volatility = deltas.isEmpty ? 0.0 : deltas.reduce(0, +) / Double(deltas.count)

        // Notable shifts: top 3 delta lines
        let shiftLines = deltas.enumerated()
            .sorted(by: { $0.element > $1.element })
            .prefix(3)
            .map { $0.offset + 1 }
            .sorted()

        // Notable stanza shifts (use stanza-level averages so long poems don't devolve into noise).
        var stanzaShiftDeltas: [Double] = []
        if stanzaScores.count >= 2 {
            stanzaShiftDeltas.reserveCapacity(stanzaScores.count - 1)
            for i in 1..<stanzaScores.count {
                stanzaShiftDeltas.append(abs(stanzaScores[i] - stanzaScores[i - 1]))
            }
        }
        let notableShiftStanzas: [Int] = stanzaShiftDeltas.enumerated()
            .sorted(by: { $0.element > $1.element })
            .prefix(3)
            .map { $0.offset + 1 }
            .sorted()

        // If we have a volta cue line, prefer highlighting it.
        var notableShiftLines = shiftLines
        if let volta = candidateVoltaLine, !notableShiftLines.contains(volta) {
            notableShiftLines = (notableShiftLines + [volta]).sorted()
        }

        // If we have a volta cue line, prefer highlighting its stanza as well.
        var notableShiftStanzasAdjusted = notableShiftStanzas
        if let volta = candidateVoltaLine {
            var lineCursor = 0
            var voltaStanza: Int? = nil
            for (idx, count) in stanzaLineCounts.enumerated() {
                let startLine = lineCursor + 1
                let endLine = lineCursor + count
                if volta >= startLine && volta <= endLine {
                    voltaStanza = idx + 1
                    break
                }
                lineCursor += count
            }
            if let stanza = voltaStanza, !notableShiftStanzasAdjusted.contains(stanza) {
                notableShiftStanzasAdjusted = (notableShiftStanzasAdjusted + [stanza]).sorted()
            }
        }

        return PoetryInsights.EmotionalTrajectory(
            lineScores: scores,
            stanzaScores: stanzaScores,
            peakLine: peak.map { $0 + 1 },
            troughLine: trough.map { $0 + 1 },
            peakStanza: peakStanza.map { $0 + 1 },
            troughStanza: troughStanza.map { $0 + 1 },
            volatility: volatility,
            notableShiftLines: notableShiftLines,
            notableShiftStanzas: notableShiftStanzasAdjusted
        )
    }

    private func analyzeMotifs(tokensByLine: [[String]]) -> PoetryInsights.ThemeMotif {
        let stop = poetryStopwords
        var counts: [String: Int] = [:]
        var bigrams: [String: Int] = [:]

        for tokens in tokensByLine {
            let content = tokens.filter { !stop.contains($0) && $0.count > 2 }
            for t in content { counts[t, default: 0] += 1 }
            if content.count >= 2 {
                for i in 0..<(content.count - 1) {
                    let bg = content[i] + " " + content[i + 1]
                    bigrams[bg, default: 0] += 1
                }
            }
        }

        let topMotifs = topCountedItems(from: counts, limit: 10, minCount: 2)
        let repeatedPhrases = topCountedItems(from: bigrams, limit: 6, minCount: 2)
        return PoetryInsights.ThemeMotif(topMotifs: topMotifs, repeatedPhrases: repeatedPhrases)
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

        let totalWords = countWords(text)
        guard totalWords > 0 else { return 0 }

        let dialogueSegments = extractDialogue(from: text)
        guard !dialogueSegments.isEmpty else { return 0 }

        let dialogueWords = dialogueSegments.reduce(0) { $0 + countWords($1) }
        return Int((Double(dialogueWords) / Double(totalWords)) * 100)
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
        if StyleCatalog.shared.isScreenplayTemplate {
            let segments = extractScreenplayDialogueSegments(from: text)
            if !segments.isEmpty {
                return segments
            }
        }

        guard text.contains("\"") || text.contains("“") || text.contains("”") else { return [] }

        var dialogueSegments: [String] = []
        var currentDialogue = ""
        var inDialogue = false

        for char in text {
            if char == "\"" || char == "“" || char == "”" {
                if inDialogue {
                    // End of dialogue
                    let trimmed = currentDialogue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        dialogueSegments.append(trimmed)
                    }
                    currentDialogue = ""
                }
                inDialogue.toggle()
            } else if inDialogue {
                currentDialogue.append(char)
            }
        }

        return dialogueSegments
    }

    private func extractScreenplayDialogueSegments(from text: String) -> [String] {
        let rawLines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map { String($0) }
        var lines = rawLines
        while let last = lines.last, last.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            lines.removeLast()
        }

        var segments: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if isScreenplayCharacterCue(line) {
                index += 1
                var buffer: [String] = []

                while index < lines.count {
                    let nextLine = lines[index]
                    let trimmed = nextLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                    if trimmed.isEmpty {
                        index += 1
                        break
                    }

                    if isScreenplayCharacterCue(trimmed) || isScreenplaySceneHeading(trimmed) || isScreenplayTransition(trimmed) {
                        break
                    }

                    buffer.append(trimmed)
                    index += 1
                }

                let combined = buffer.joined(separator: " ").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !combined.isEmpty {
                    segments.append(combined)
                }
                continue
            }

            index += 1
        }

        return segments
    }

    private func isScreenplaySceneHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let upper = trimmed.uppercased()
        return upper.range(of: "^(INT\\.|EXT\\.|INT/EXT|EXT/INT|INT\\s|EXT\\s)", options: .regularExpression) != nil
    }

    private func isScreenplayTransition(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let upper = trimmed.uppercased()
        if upper.hasSuffix(":") { return true }
        let prefixes = [
            "CUT TO", "FADE IN", "FADE OUT", "SMASH CUT", "DISSOLVE TO",
            "MATCH CUT", "JUMP CUT", "WIPE TO", "FADE TO", "BACK TO"
        ]
        return prefixes.contains(where: { upper.hasPrefix($0) })
    }

    private func isScreenplayCharacterCue(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let upper = trimmed.uppercased()
        guard upper == trimmed else { return false }
        if isScreenplaySceneHeading(upper) || isScreenplayTransition(upper) { return false }
        if upper.count > 40 { return false }
        if upper.contains(":") { return false }
        if upper.range(of: "[A-Z]", options: .regularExpression) == nil { return false }
        return upper.range(of: "^[A-Z0-9 .()'\"-]+$", options: .regularExpression) != nil
    }

    private func estimateScreenplayPageCount(text: String) -> Int {
        let rawLines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var lines = rawLines.map { String($0) }

        while let last = lines.last, last.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            lines.removeLast()
        }

        let lineCount = max(1, lines.count)
        return max(1, Int(ceil(Double(lineCount) / 55.0)))
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
        let libraryNames = Set(CharacterLibrary.shared.characters.map { $0.nickname })

        // Find capitalized words (potential names)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var nameCounts: [String: Int] = [:]

        // Common words to exclude - only used for non-library characters
        let excludeWords: Set<String> = [
            "The", "A", "An", "He", "She", "They", "I", "We", "You",
            "But", "And", "Or", "If", "When", "Where", "Why", "How",
            "Chapter", "Part", "Section", "Act",
            // Decision–Belief Loop / analysis headings (avoid contaminating character-only charts)
            "Pressure", "Belief", "Beliefs", "Decision", "Decisions", "Outcome", "Outcomes",
            "Consequence", "Consequences", "Shift", "Shifts", "Evidence", "Counterpressure",
            "Framework", "Loop", "Loops", "Matrix", "Matrices", "Arc", "Arcs",
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
        // Validate that all character names exist in the Character Library
        let library = CharacterLibrary.shared
        let validCharacterNames: [String]

        DebugLog.log("📊 analyzeCharacterArcs: Input characterNames = \(characterNames)")
        DebugLog.log("📊 analyzeCharacterArcs: Library has \(library.characters.count) characters")

        if !library.characters.isEmpty {
            let libraryKeys = library.analysisCharacterKeys
            DebugLog.log("📊 analyzeCharacterArcs: Library analysis keys = \(libraryKeys)")
            validCharacterNames = libraryValidatedCharacterNames(from: characterNames)
            DebugLog.log("📊 analyzeCharacterArcs: Valid character names after filtering = \(validCharacterNames)")
        } else {
            // Allow screenplay/extracted character names to proceed without a library.
            validCharacterNames = characterNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            DebugLog.log("📊 analyzeCharacterArcs: No library characters, using provided names = \(validCharacterNames)")
        }

        // If no valid characters after filtering, return empty results
        guard !validCharacterNames.isEmpty else {
            DebugLog.log("📊 analyzeCharacterArcs: No valid characters, returning empty arrays")
            return ([], [], [])
        }

        let analyzer = DecisionBeliefLoopAnalyzer()

        // Analyze text and populate Decision-Belief Loop with actual detected patterns
        let loops = analyzer.analyzeLoops(text: text, characterNames: validCharacterNames, outlineEntries: outlineEntries, pageMapping: pageMapping)
        let interactions = analyzer.analyzeInteractions(text: text, characterNames: validCharacterNames)
        let presence = analyzer.analyzePresenceByChapter(text: text, characterNames: validCharacterNames, outlineEntries: outlineEntries)

        DebugLog.log("📊 analyzeCharacterArcs: Returning \(loops.count) loops, \(interactions.count) interactions, \(presence.count) presence entries")

        return (loops, interactions, presence)
    }

    func generateBeliefShiftMatrices(text: String, characterNames: [String], outlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = nil) -> [BeliefShiftMatrix] {
        let validCharacterNames = libraryValidatedCharacterNames(from: characterNames)
        guard !validCharacterNames.isEmpty else { return [] }

        let library = CharacterLibrary.shared

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
                let orderedEntries = effectiveEntries.sorted { $0.range.location < $1.range.location }
                chapters = orderedEntries.enumerated().map { index, entry in
                    // Clamp outline-derived ranges to avoid substring out-of-bounds crashes.
                    let startLocation = min(entry.range.location, fullText.length)
                    let endLocation: Int
                    if index < orderedEntries.count - 1 {
                        endLocation = orderedEntries[index + 1].range.location
                    } else {
                        endLocation = fullText.length
                    }
                    let clampedEnd = min(endLocation, fullText.length)
                    let length = max(0, clampedEnd - startLocation)
                    let chapterRange = NSRange(location: startLocation, length: length)
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

        // Real analysis: Extract beliefs, evidence, and counterpressures from text
        let beliefIndicators = ["believe", "think", "thought", "realize", "realized", "understand", "know", "trust", "faith", "value", "values", "principle", "principles", "convinced", "certain", "sure", "feel", "felt", "want", "wanted", "need", "needed", "hope", "hoped", "fear", "feared", "swore", "vowed", "promised", "resolved"]
        let evidenceIndicators = ["because", "shows", "demonstrates", "proves", "revealed", "acted", "chose", "decided", "refused"]
        let counterpressureIndicators = ["but", "however", "challenged", "questioned", "opposed", "confronted", "despite", "although", "forced", "pressured"]

        func aliases(for analysisKey: String) -> [String] {
            guard !analysisKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else { return [] }
            if let profile = library.characters.first(where: { $0.analysisKey == analysisKey }) {
                var values: [String] = [analysisKey]
                let nick = profile.nickname.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !nick.isEmpty { values.append(nick) }
                return Array(Set(values)).filter { !$0.isEmpty }
            }
            return [analysisKey]
        }

        func aliasRegexes(for aliases: [String]) -> [NSRegularExpression] {
            aliases.compactMap {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: $0) + "\\b"
                return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            }
        }

        func matchesAnyAlias(_ regexes: [NSRegularExpression], in text: String) -> Bool {
            let range = NSRange(text.startIndex..., in: text)
            for regex in regexes {
                if regex.firstMatch(in: text, range: range) != nil {
                    return true
                }
            }
            return false
        }

        for characterName in validCharacterNames {
            var entries: [BeliefShiftMatrix.BeliefEntry] = []

            let characterAliases = aliases(for: characterName)
            let chapterAliasRegexes = aliasRegexes(for: characterAliases)

            // Sample chapters for analysis.
            // For screenplays (many scenes), sparse sampling misses characters.
            let maxChaptersToScan = min(chapters.count, 18)
            let sampleIndices: [Int]
            if chapters.count <= maxChaptersToScan {
                sampleIndices = Array(0..<chapters.count)
            } else if maxChaptersToScan <= 1 {
                sampleIndices = [0]
            } else {
                let step = Double(chapters.count - 1) / Double(maxChaptersToScan - 1)
                var idxs: [Int] = []
                var seen: Set<Int> = []
                for i in 0..<maxChaptersToScan {
                    let idx = min(chapters.count - 1, max(0, Int(round(Double(i) * step))))
                    if seen.insert(idx).inserted {
                        idxs.append(idx)
                    }
                }
                sampleIndices = idxs
            }

            let maxEntriesPerCharacter = 8

            for index in sampleIndices {
                let chapter = chapters[index]

                // Only analyze chapters where character appears
                guard matchesAnyAlias(chapterAliasRegexes, in: chapter.text) else {
                    continue
                }

                // Extract belief statement
                let belief = extractBeliefStatement(from: chapter.text, aliases: characterAliases, indicators: beliefIndicators)
                guard !belief.isEmpty else { continue }

                // Extract supporting evidence
                let evidence = extractEvidence(from: chapter.text, aliases: characterAliases, indicators: evidenceIndicators)

                // Extract counterpressure
                let counterpressure = extractCounterpressure(from: chapter.text, aliases: characterAliases, indicators: counterpressureIndicators)

                let entry = BeliefShiftMatrix.BeliefEntry(
                    chapter: chapter.number,
                    chapterPage: 0,
                    coreBelief: belief,
                    evidence: evidence.isEmpty ? "Character's actions reflect this belief" : evidence,
                    evidencePage: 0,
                    counterpressure: counterpressure.isEmpty ? "Circumstances test this perspective" : counterpressure,
                    counterpressurePage: 0
                )

                entries.append(entry)

                if entries.count >= maxEntriesPerCharacter {
                    break
                }
            }

            if entries.isEmpty {
                if let fallbackChapter = chapters.first(where: { matchesAnyAlias(chapterAliasRegexes, in: $0.text) }) {
                    let rawBelief = extractBeliefStatement(from: fallbackChapter.text, aliases: characterAliases, indicators: beliefIndicators)
                    let belief = rawBelief.isEmpty ? "Belief implied by character actions" : rawBelief
                    let evidence = extractEvidence(from: fallbackChapter.text, aliases: characterAliases, indicators: evidenceIndicators)
                    let counterpressure = extractCounterpressure(from: fallbackChapter.text, aliases: characterAliases, indicators: counterpressureIndicators)

                    entries.append(
                        BeliefShiftMatrix.BeliefEntry(
                            chapter: fallbackChapter.number,
                            chapterPage: 0,
                            coreBelief: belief,
                            evidence: evidence.isEmpty ? "Character's actions reflect this belief" : evidence,
                            evidencePage: 0,
                            counterpressure: counterpressure.isEmpty ? "Circumstances test this perspective" : counterpressure,
                            counterpressurePage: 0
                        )
                    )
                }
            }

            // Always add a matrix for valid library characters, even if entries are sparse.
            matrices.append(BeliefShiftMatrix(characterName: characterName, entries: entries))
        }

        return matrices
    }

    private func extractBeliefStatement(from text: String, aliases: [String], indicators: [String]) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let aliasRegexes: [NSRegularExpression] = aliases.compactMap {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: $0) + "\\b"
            return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }

        func sentenceMatchesAnyAlias(_ sentence: String) -> Bool {
            let range = NSRange(sentence.startIndex..., in: sentence)
            for regex in aliasRegexes {
                if regex.firstMatch(in: sentence, range: range) != nil {
                    return true
                }
            }
            return false
        }

        var firstAliasSentence: String?

        for sentence in sentences {
            let lower = sentence.lowercased()
            guard sentenceMatchesAnyAlias(sentence) else { continue }

            if firstAliasSentence == nil {
                firstAliasSentence = sentence
            }

            for indicator in indicators {
                if lower.contains(indicator) {
                    return sentence.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120).description
                }
            }
        }
        if let fallback = firstAliasSentence {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120).description
        }
        return ""
    }

    private func extractEvidence(from text: String, aliases: [String], indicators: [String]) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let aliasRegexes: [NSRegularExpression] = aliases.compactMap {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: $0) + "\\b"
            return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }

        func sentenceMatchesAnyAlias(_ sentence: String) -> Bool {
            let range = NSRange(sentence.startIndex..., in: sentence)
            for regex in aliasRegexes {
                if regex.firstMatch(in: sentence, range: range) != nil {
                    return true
                }
            }
            return false
        }

        var firstAliasSentence: String?
        var firstIndicatorSentence: String?

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()

            if firstIndicatorSentence == nil {
                for indicator in indicators {
                    if lower.contains(indicator) {
                        firstIndicatorSentence = trimmed
                        break
                    }
                }
            }

            let matchesAlias = sentenceMatchesAnyAlias(sentence)
            if matchesAlias, firstAliasSentence == nil {
                firstAliasSentence = trimmed
            }

            guard matchesAlias else { continue }
            for indicator in indicators {
                if lower.contains(indicator) {
                    return trimmed.prefix(120).description
                }
            }
        }
        if let fallback = firstIndicatorSentence ?? firstAliasSentence {
            return fallback.prefix(120).description
        }
        return ""
    }

    private func extractCounterpressure(from text: String, aliases: [String], indicators: [String]) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let aliasRegexes: [NSRegularExpression] = aliases.compactMap {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: $0) + "\\b"
            return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }

        func sentenceMatchesAnyAlias(_ sentence: String) -> Bool {
            let range = NSRange(sentence.startIndex..., in: sentence)
            for regex in aliasRegexes {
                if regex.firstMatch(in: sentence, range: range) != nil {
                    return true
                }
            }
            return false
        }

        var firstAliasSentence: String?
        var firstIndicatorSentence: String?

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()

            if firstIndicatorSentence == nil {
                for indicator in indicators {
                    if lower.contains(indicator) {
                        firstIndicatorSentence = trimmed
                        break
                    }
                }
            }

            let matchesAlias = sentenceMatchesAnyAlias(sentence)
            if matchesAlias, firstAliasSentence == nil {
                firstAliasSentence = trimmed
            }

            guard matchesAlias else { continue }
            for indicator in indicators {
                if lower.contains(indicator) {
                    return trimmed.prefix(120).description
                }
            }
        }
        if let fallback = firstIndicatorSentence ?? firstAliasSentence {
            return fallback.prefix(120).description
        }
        return ""
    }

    func generateDecisionConsequenceChains(text: String, characterNames: [String], outlineEntries: [DecisionBeliefLoopAnalyzer.OutlineEntry]? = nil) -> [DecisionConsequenceChain] {
        let validCharacterNames = libraryValidatedCharacterNames(from: characterNames)
        guard !validCharacterNames.isEmpty else { return [] }

        let library = CharacterLibrary.shared

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
                let orderedEntries = effectiveEntries.sorted { $0.range.location < $1.range.location }
                chapters = orderedEntries.enumerated().map { index, entry in
                    // Clamp outline-derived ranges to avoid substring out-of-bounds crashes.
                    let startLocation = min(entry.range.location, fullText.length)
                    let endLocation: Int
                    if index < orderedEntries.count - 1 {
                        endLocation = orderedEntries[index + 1].range.location
                    } else {
                        endLocation = fullText.length
                    }
                    let clampedEnd = min(endLocation, fullText.length)
                    let length = max(0, clampedEnd - startLocation)
                    let chapterRange = NSRange(location: startLocation, length: length)
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

        // Real analysis: Extract decisions and consequences from text
        let decisionIndicators = ["decided", "chose", "choose", "selected", "agreed", "refused", "accepted", "rejected", "committed"]
        let outcomeIndicators = ["resulted", "consequence", "outcome", "happened", "led to", "caused", "as a result", "therefore", "thus"]
        let effectIndicators = ["changed", "shaped", "influenced", "affected", "transformed", "learned", "realized", "became"]

        func aliases(for analysisKey: String) -> [String] {
            let trimmed = analysisKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            if let profile = library.characters.first(where: { $0.analysisKey == analysisKey }) {
                var values: [String] = [analysisKey]
                let nick = profile.nickname.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !nick.isEmpty { values.append(nick) }
                return Array(Set(values)).filter { !$0.isEmpty }
            }
            return [analysisKey]
        }

        func aliasRegexes(for aliases: [String]) -> [NSRegularExpression] {
            aliases.compactMap {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: $0) + "\\b"
                return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            }
        }

        func matchesAnyAlias(_ regexes: [NSRegularExpression], in text: String) -> Bool {
            let range = NSRange(text.startIndex..., in: text)
            for regex in regexes {
                if regex.firstMatch(in: text, range: range) != nil {
                    return true
                }
            }
            return false
        }

        for characterName in validCharacterNames {
            var entries: [DecisionConsequenceChain.ChainEntry] = []

            // Scan enough chapters to actually find decisions, but cap work for large documents.
            let maxChaptersToScan = min(chapters.count, 18)
            let chapterIndices: [Int]
            if chapters.count <= maxChaptersToScan {
                chapterIndices = Array(0..<chapters.count)
            } else if maxChaptersToScan <= 1 {
                chapterIndices = [0]
            } else {
                let step = Double(chapters.count - 1) / Double(maxChaptersToScan - 1)
                var idxs: [Int] = []
                var seen: Set<Int> = []
                for i in 0..<maxChaptersToScan {
                    let idx = min(chapters.count - 1, max(0, Int(round(Double(i) * step))))
                    if seen.insert(idx).inserted {
                        idxs.append(idx)
                    }
                }
                chapterIndices = idxs
            }

            let maxEntriesPerCharacter = 6
            let characterAliases = aliases(for: characterName)
            let chapterAliasRegexes = aliasRegexes(for: characterAliases)

            for index in chapterIndices {
                let chapter = chapters[index]

                // Only analyze chapters where character appears (allow nickname/aliases).
                guard matchesAnyAlias(chapterAliasRegexes, in: chapter.text) else { continue }

                // Extract decision
                let decision = extractDecision(from: chapter.text, character: characterName, indicators: decisionIndicators)
                guard !decision.isEmpty else { continue }

                // Extract immediate outcome
                let immediateOutcome = extractOutcome(from: chapter.text, character: characterName, indicators: outcomeIndicators)

                // Extract long-term effect
                let longTermEffect = extractEffect(from: chapter.text, character: characterName, indicators: effectIndicators)

                let entry = DecisionConsequenceChain.ChainEntry(
                    chapter: chapter.number,
                    chapterPage: 0,
                    decision: decision,
                    decisionPage: 0,
                    immediateOutcome: immediateOutcome.isEmpty ? "Direct consequences unfold" : immediateOutcome,
                    immediateOutcomePage: 0,
                    longTermEffect: longTermEffect.isEmpty ? "Character trajectory shifts" : longTermEffect,
                    longTermEffectPage: 0
                )

                entries.append(entry)

                if entries.count >= maxEntriesPerCharacter {
                    break
                }
            }

            // Always include the character so the popout shows the full cast.
            // If we couldn't find an explicit "decision" keyword match, emit a single placeholder entry.
            if entries.isEmpty {
                let fallbackChapter = chapters.first?.number ?? 1
                entries.append(
                    DecisionConsequenceChain.ChainEntry(
                        chapter: fallbackChapter,
                        chapterPage: 0,
                        decision: "No explicit decision keyword found",
                        decisionPage: 0,
                        immediateOutcome: "Direct consequences unfold",
                        immediateOutcomePage: 0,
                        longTermEffect: "Character trajectory shifts",
                        longTermEffectPage: 0
                    )
                )
            }
            chains.append(DecisionConsequenceChain(characterName: characterName, entries: entries))
        }

        return chains
    }

    private func extractDecision(from text: String, character: String, indicators: [String]) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for sentence in sentences {
            let lower = sentence.lowercased()
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: character.lowercased()) + "\\b"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  regex.firstMatch(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) != nil else {
                continue
            }

            for indicator in indicators {
                if lower.contains(indicator) {
                    return sentence.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120).description
                }
            }
        }
        return ""
    }

    private func extractOutcome(from text: String, character: String, indicators: [String]) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for sentence in sentences {
            let lower = sentence.lowercased()
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: character.lowercased()) + "\\b"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  regex.firstMatch(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) != nil else {
                continue
            }

            for indicator in indicators {
                if lower.contains(indicator) {
                    return sentence.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120).description
                }
            }
        }
        return ""
    }

    private func extractEffect(from text: String, character: String, indicators: [String]) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for sentence in sentences {
            let lower = sentence.lowercased()
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: character.lowercased()) + "\\b"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  regex.firstMatch(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) != nil else {
                continue
            }

            for indicator in indicators {
                if lower.contains(indicator) {
                    return sentence.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120).description
                }
            }
        }
        return ""
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

