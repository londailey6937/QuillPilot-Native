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
        var pressurePage: Int = 0
        var beliefInPlay: String    // Which core belief is being tested?
        var beliefPage: Int = 0
        var decision: String        // What choice does the character make because of that belief?
        var decisionPage: Int = 0
        var outcome: String         // What happens immediately because of the decision?
        var outcomePage: Int = 0
        var beliefShift: String     // How does the belief change after the outcome?
        var beliefShiftPage: Int = 0

        init(chapter: Int, pressure: String = "", pressurePage: Int = 0, beliefInPlay: String = "", beliefPage: Int = 0, decision: String = "", decisionPage: Int = 0, outcome: String = "", outcomePage: Int = 0, beliefShift: String = "", beliefShiftPage: Int = 0) {
            self.chapter = chapter
            self.pressure = pressure
            self.pressurePage = pressurePage
            self.beliefInPlay = beliefInPlay
            self.beliefPage = beliefPage
            self.decision = decision
            self.decisionPage = decisionPage
            self.outcome = outcome
            self.outcomePage = outcomePage
            self.beliefShift = beliefShift
            self.beliefShiftPage = beliefShiftPage
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

// MARK: - Belief / Value Shift Matrix

/// Tracks what a character believes at different story points
/// Ideal for theme-driven and literary fiction where evolution is logical, not just emotional
struct BeliefShiftMatrix {
    let characterName: String
    var entries: [BeliefEntry] = []

    /// A single belief snapshot at a specific story point
    struct BeliefEntry: Identifiable {
        let id = UUID()
        let chapter: Int
        var chapterPage: Int = 0
        var coreBelief: String          // What does the character believe at this point?
        var evidence: String            // What shows this belief in action?
        var evidencePage: Int = 0
        var counterpressure: String     // What challenges or tests this belief?
        var counterpressurePage: Int = 0

        init(chapter: Int, chapterPage: Int = 0, coreBelief: String = "", evidence: String = "", evidencePage: Int = 0, counterpressure: String = "", counterpressurePage: Int = 0) {
            self.chapter = chapter
            self.chapterPage = chapterPage
            self.coreBelief = coreBelief
            self.evidence = evidence
            self.evidencePage = evidencePage
            self.counterpressure = counterpressure
            self.counterpressurePage = counterpressurePage
        }
    }

    /// Analyze belief evolution quality
    var evolutionQuality: EvolutionQuality {
        guard entries.count >= 2 else { return .insufficient }

        let uniqueBeliefs = Set(entries.map { $0.coreBelief.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        let hasCounterpressures = entries.filter { !$0.counterpressure.isEmpty }.count

        // If beliefs never change
        if uniqueBeliefs.count == 1 {
            return .unchanging
        }

        // If there's clear evolution with pressures
        if uniqueBeliefs.count >= 2 && hasCounterpressures >= entries.count / 2 {
            return .logical
        }

        // Some evolution
        if uniqueBeliefs.count >= 2 {
            return .developing
        }

        return .developing
    }

    enum EvolutionQuality: String {
        case insufficient = "Insufficient Data"
        case unchanging = "Unchanging - Beliefs static"
        case developing = "Developing - Some belief shifts"
        case logical = "Logical Evolution - Clear pressures and shifts"
    }
}

// MARK: - Decision-Consequence Chains

/// Decision-Consequence Chains map choices, not traits.
/// Ensures growth comes from action, not narration.
/// Perfect for diagnosing passive protagonists.

struct DecisionConsequenceChain {
    let characterName: String
    var entries: [ChainEntry]

    struct ChainEntry: Identifiable {
        let id = UUID()
        let chapter: Int
        let chapterPage: Int
        let decision: String           // What choice does the character make?
        let decisionPage: Int
        let immediateOutcome: String   // What happens right after?
        let immediateOutcomePage: Int
        let longTermEffect: String     // How does this shape the character going forward?
        let longTermEffectPage: Int

        init(chapter: Int, chapterPage: Int = 0, decision: String = "", decisionPage: Int = 0,
             immediateOutcome: String = "", immediateOutcomePage: Int = 0,
             longTermEffect: String = "", longTermEffectPage: Int = 0) {
            self.chapter = chapter
            self.chapterPage = chapterPage
            self.decision = decision
            self.decisionPage = decisionPage
            self.immediateOutcome = immediateOutcome
            self.immediateOutcomePage = immediateOutcomePage
            self.longTermEffect = longTermEffect
            self.longTermEffectPage = longTermEffectPage
        }
    }

    /// Assess if the character is actively driving the story or passive
    var agencyScore: AgencyAssessment {
        guard entries.count >= 2 else { return .insufficient }

        let decisionsWithOutcomes = entries.filter { !$0.decision.isEmpty && !$0.immediateOutcome.isEmpty }.count
        let decisionsWithLongTermEffects = entries.filter { !$0.longTermEffect.isEmpty }.count

        let outcomeRatio = Double(decisionsWithOutcomes) / Double(entries.count)
        let effectRatio = Double(decisionsWithLongTermEffects) / Double(entries.count)

        if outcomeRatio >= 0.75 && effectRatio >= 0.5 {
            return .activeProtagonist
        } else if outcomeRatio >= 0.5 && effectRatio >= 0.3 {
            return .developing
        } else if outcomeRatio >= 0.25 {
            return .reactive
        } else {
            return .passive
        }
    }

    enum AgencyAssessment: String {
        case insufficient = "Insufficient Data"
        case passive = "Passive - Character reacts, doesn't act"
        case reactive = "Reactive - Some agency, needs strengthening"
        case developing = "Developing - Good balance of action"
        case activeProtagonist = "Active Protagonist - Drives the story"
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

// MARK: - Relationship Evolution Map

struct RelationshipEvolutionData {
    var nodes: [RelationshipNodeData] = []
    var edges: [RelationshipEdgeData] = []
}

struct RelationshipNodeData {
    let character: String
    let emotionalInvestment: Double // 0.0 to 1.0
    let positionX: Double // 0.0 to 1.0
    let positionY: Double // 0.0 to 1.0
}

struct RelationshipEdgeData {
    let from: String
    let to: String
    let trustLevel: Double // -1.0 (conflict) to 1.0 (trust)
    let powerDirection: String // "balanced", "fromToTo", "toToFrom"
    var evolution: [RelationshipEvolutionPoint] = []
}

struct RelationshipEvolutionPoint {
    let chapter: Int
    let trustLevel: Double
    let description: String
}

// MARK: - Internal vs External Alignment

/// Track the gap between who characters are inside and how they act
/// Two parallel tracks: Inner truth, Outer behavior
struct InternalExternalAlignmentData {
    var characterAlignments: [CharacterAlignmentData] = []
}

struct CharacterAlignmentData {
    let characterName: String
    var dataPoints: [AlignmentDataPoint] = []
    var gapTrend: String = "fluctuating" // "widening", "stabilizing", "closing", "collapsing", "fluctuating"
}

struct AlignmentDataPoint {
    let chapter: Int
    let innerTruth: Double      // 0.0 to 1.0 - inner emotional/belief state
    let outerBehavior: Double   // 0.0 to 1.0 - external presentation
    let innerLabel: String      // Description of inner state
    let outerLabel: String      // Description of outer behavior
}

// MARK: - Language Drift Analysis

/// Track how character's language changes over the story
/// Reveals unconscious growth patterns
struct LanguageDriftData {
    var characterDrifts: [CharacterLanguageDrift] = []
}

struct CharacterLanguageDrift {
    let characterName: String
    var metrics: [LanguageMetricsData] = []
    var driftSummary: DriftSummaryData = DriftSummaryData()
}

struct LanguageMetricsData {
    let chapter: Int
    let pronounI: Double          // "I" usage (0-1 normalized)
    let pronounWe: Double         // "we" usage (0-1 normalized)
    let modalMust: Double         // obligation modals: must, have to, need to
    let modalChoice: Double       // choice modals: choose, can, could, want to
    let emotionalDensity: Double  // emotional words per sentence
    let avgSentenceLength: Double // average words per sentence (normalized 0-1)
    let certaintyScore: Double    // certainty indicators (0-1)
}

struct DriftSummaryData {
    var pronounShift: String = "Stable"      // "I → We", "We → I", "Stable"
    var modalShift: String = "Stable"        // "Obligation → Choice", etc.
    var emotionalTrend: String = "Stable"    // "Increasing", "Decreasing", "Stable"
    var sentenceTrend: String = "Stable"     // "Longer", "Shorter", "Stable"
    var certaintyTrend: String = "Stable"    // "More Certain", "Less Certain", "Stable"
}

// MARK: - Decision-Belief Loop Analyzer

class DecisionBeliefLoopAnalyzer {

    // Store outline entries for accurate page number calculation
    private var outlineEntries: [OutlineEntry]?

    // Store page mapping for accurate character-position-to-page lookups
    private var pageMapping: [(location: Int, page: Int)]?

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
    /// - Parameters:
    ///   - text: Full document text
    ///   - characterNames: List of character names to analyze
    ///   - outlineEntries: Optional outline entries from document (Chapter Number, Chapter Title, Heading 1-3). If nil, falls back to regex detection.
    ///   - pageMapping: Optional character-position-to-page mapping for accurate page lookups
    func analyzeLoops(text: String, characterNames: [String], outlineEntries: [OutlineEntry]? = nil, pageMapping: [(location: Int, page: Int)]? = nil) -> [DecisionBeliefLoop] {
        // Store outline entries and page mapping for page calculation
        self.outlineEntries = outlineEntries
        self.pageMapping = pageMapping

        if let mapping = pageMapping {
            NSLog("📄 Decision-Belief Loop: Using page mapping with \(mapping.count) entries")
        }

        let chapters: [(text: String, number: Int, startPos: Int)]

        // Use outline entries if available, otherwise fall back to regex detection
        if let entries = outlineEntries, !entries.isEmpty {
            print("📖 Decision-Belief Loop: Using \(entries.count) outline entries for chapter detection")
            entries.prefix(3).forEach { entry in
                print("  Chapter: '\(entry.title)' level=\(entry.level) range=\(entry.range)")
            }
            // Filter for level 1 entries (Chapter Number, Chapter Title, Heading 1)
            let chapterEntries = entries.filter { $0.level == 1 }
            let effectiveEntries: [OutlineEntry]
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
                var result: [(text: String, number: Int, startPos: Int)] = []
                let fullText = text as NSString

                for (index, entry) in effectiveEntries.enumerated() {
                    let startLocation = entry.range.location
                    let endLocation: Int

                    // Determine end of chapter
                    if index < effectiveEntries.count - 1 {
                        // End at next chapter start
                        endLocation = effectiveEntries[index + 1].range.location
                    } else {
                        // Last chapter goes to end of document
                        endLocation = fullText.length
                    }

                    let chapterRange = NSRange(location: startLocation, length: endLocation - startLocation)
                    let chapterText = fullText.substring(with: chapterRange)

                    result.append((text: chapterText, number: index + 1, startPos: startLocation))
                }

                chapters = result
            } else {
                // No outline structure found - treat entire document as one chapter
                chapters = [(text: text, number: 1, startPos: 0)]
            }
        } else {
            // Fall back to regex-based chapter detection
            print("⚠️ Decision-Belief Loop: No outline entries, falling back to regex chapter detection")
            let chapterTexts = splitIntoChapters(text: text)
            var startPos = 0
            chapters = chapterTexts.enumerated().map { index, chapterText in
                let result = (text: chapterText, number: index + 1, startPos: startPos)
                startPos += chapterText.count
                return result
            }
        }

        var loops: [DecisionBeliefLoop] = []
        print("👥 Analyzing \(characterNames.count) characters: \(characterNames.joined(separator: ", "))")

        for characterName in characterNames {
            var loop = DecisionBeliefLoop(characterName: characterName)

            for chapter in chapters {
                // Only analyze chapters where the character appears
                guard chapter.text.lowercased().contains(characterName.lowercased()) else {
                    continue
                }

                // Extract elements from the chapter in narrative order (pressure → belief → decision → outcome → shift)
                let (pressure, pressurePage, pressurePos) = extractPressureWithPosition(from: chapter.text, character: characterName, allCharacters: characterNames, startPos: chapter.startPos, fullText: text)
                let (belief, beliefPage, beliefPos) = extractBeliefWithPosition(from: chapter.text, character: characterName, allCharacters: characterNames, startPos: chapter.startPos, fullText: text, afterPosition: pressurePos)
                let (decision, decisionPage, decisionPos) = extractDecisionWithPosition(from: chapter.text, character: characterName, allCharacters: characterNames, startPos: chapter.startPos, fullText: text, afterPosition: beliefPos)
                let (outcome, outcomePage, outcomePos) = extractOutcomeWithPosition(from: chapter.text, character: characterName, allCharacters: characterNames, startPos: chapter.startPos, fullText: text, afterPosition: decisionPos)
                let (shift, shiftPage, _) = extractBeliefShiftWithPosition(from: chapter.text, character: characterName, allCharacters: characterNames, startPos: chapter.startPos, fullText: text, afterPosition: outcomePos)

                let entry = DecisionBeliefLoop.LoopEntry(
                    chapter: chapter.number,
                    pressure: pressure,
                    pressurePage: pressurePage,
                    beliefInPlay: belief,
                    beliefPage: beliefPage,
                    decision: decision,
                    decisionPage: decisionPage,
                    outcome: outcome,
                    outcomePage: outcomePage,
                    beliefShift: shift,
                    beliefShiftPage: shiftPage
                )

                loop.entries.append(entry)
            }

            loops.append(loop)
        }

        return loops
    }

    /// Outline entry structure matching EditorViewController.OutlineEntry
    struct OutlineEntry {
        let title: String
        let level: Int
        let range: NSRange
        let page: Int?
    }

    private func extractPressureWithPosition(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String) -> (String, Int, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            let lower = sentence.lowercased()
            // Look for pressure indicators
            for word in pressureWords {
                if lower.contains(word) {
                    let absolutePos = startPos + positions[index]
                    let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
                    return (cleanExtract(sentence), pageNum, positions[index])
                }
            }

            // Look for question marks (dilemma)
            if sentence.contains("?") {
                let absolutePos = startPos + positions[index]
                let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
                return (cleanExtract(sentence), pageNum, positions[index])
            }
        }

        return ("", 0, -1)
    }

    private func extractBeliefWithPosition(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String, afterPosition: Int) -> (String, Int, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            // Skip if this sentence appears before the previous element
            if afterPosition >= 0 && positions[index] <= afterPosition {
                continue
            }

            let lower = sentence.lowercased()
            // Look for belief indicators
            for word in beliefWords {
                if lower.contains(word) {
                    let absolutePos = startPos + positions[index]
                    let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
                    return (cleanExtract(sentence), pageNum, positions[index])
                }
            }
        }

        return ("", 0, -1)
    }

    private func extractDecisionWithPosition(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String, afterPosition: Int) -> (String, Int, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            // Skip if this sentence appears before the previous element
            if afterPosition >= 0 && positions[index] <= afterPosition {
                continue
            }

            let lower = sentence.lowercased()
            // Look for decision indicators
            for word in decisionWords {
                if lower.contains(word) {
                    let absolutePos = startPos + positions[index]
                    let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
                    return (cleanExtract(sentence), pageNum, positions[index])
                }
            }
        }

        return ("", 0, -1)
    }

    private func extractOutcomeWithPosition(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String, afterPosition: Int) -> (String, Int, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            // Skip if this sentence appears before the previous element
            if afterPosition >= 0 && positions[index] <= afterPosition {
                continue
            }

            let lower = sentence.lowercased()
            // Look for outcome indicators
            for word in outcomeWords {
                if lower.contains(word) {
                    let absolutePos = startPos + positions[index]
                    let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
                    return (cleanExtract(sentence), pageNum, positions[index])
                }
            }
        }

        return ("", 0, -1)
    }

    private func extractBeliefShiftWithPosition(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String, afterPosition: Int) -> (String, Int, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 3)

        // Look for words indicating change
        let changeWords = ["realized", "learned", "understood", "saw", "discovered",
                          "changed", "shifted", "no longer", "now", "finally"]

        for (index, sentence) in sentences.enumerated() {
            // Skip if this sentence appears before the previous element
            if afterPosition >= 0 && positions[index] <= afterPosition {
                continue
            }

            let lower = sentence.lowercased()
            for word in changeWords {
                if lower.contains(word) {
                    let absolutePos = startPos + positions[index]
                    let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
                    return (cleanExtract(sentence), pageNum, positions[index])
                }
            }
        }

        return ("", 0, -1)
    }

    // Keep old functions for compatibility (deprecated)
    private func extractPressure(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String) -> (String, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            let lower = sentence.lowercased()
            // Look for pressure indicators
            for word in pressureWords {
                if lower.contains(word) {
                    let pageNum = calculatePageNumber(position: startPos + positions[index], in: fullText)
                    return (cleanExtract(sentence), pageNum)
                }
            }

            // Look for question marks (dilemma)
            if sentence.contains("?") {
                let pageNum = calculatePageNumber(position: startPos + positions[index], in: fullText)
                return (cleanExtract(sentence), pageNum)
            }
        }

        return ("", 0)
    }

    private func extractBelief(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String) -> (String, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            let lower = sentence.lowercased()
            // Look for belief indicators
            for word in beliefWords {
                if lower.contains(word) {
                    let pageNum = calculatePageNumber(position: startPos + positions[index], in: fullText)
                    return (cleanExtract(sentence), pageNum)
                }
            }
        }

        return ("", 0)
    }

    private func extractDecision(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String) -> (String, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            let lower = sentence.lowercased()
            // Look for decision indicators
            for word in decisionWords {
                if lower.contains(word) {
                    let pageNum = calculatePageNumber(position: startPos + positions[index], in: fullText)
                    return (cleanExtract(sentence), pageNum)
                }
            }
        }

        return ("", 0)
    }

    private func extractOutcome(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String) -> (String, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            let lower = sentence.lowercased()
            // Look for outcome indicators
            for word in outcomeWords {
                if lower.contains(word) {
                    let pageNum = calculatePageNumber(position: startPos + positions[index], in: fullText)
                    return (cleanExtract(sentence), pageNum)
                }
            }
        }

        return ("", 0)
    }

    private func extractBeliefShift(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String) -> (String, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 3)

        // Look for words indicating change
        let changeWords = ["realized", "learned", "understood", "saw", "discovered",
                          "changed", "shifted", "no longer", "now", "finally"]

        for (index, sentence) in sentences.enumerated() {
            let lower = sentence.lowercased()
            for word in changeWords {
                if lower.contains(word) {
                    let pageNum = calculatePageNumber(position: startPos + positions[index], in: fullText)
                    return (cleanExtract(sentence), pageNum)
                }
            }
        }

        return ("", 0)
    }

    private func getSentencesAbout(character: String, in text: String, allCharacters: [String], proximity: Int) -> ([String], [Int]) {
        let allSentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var relevantSentences: [String] = []
        var positions: [Int] = []
        var currentPos = 0

        for (index, sentence) in allSentences.enumerated() {
            // Only include sentences that specifically mention this character
            // AND don't strongly focus on another character
            if sentence.lowercased().contains(character.lowercased()) {
                // Skip if sentence strongly focuses on another character
                // (another character appears before this character in the sentence)
                if !isAboutOtherCharacter(sentence, targetCharacter: character, allCharacters: allCharacters) {
                    relevantSentences.append(sentence)
                    positions.append(currentPos)

                    // Include immediately adjacent sentences for context (but only if they don't mention other characters)
                    if index > 0 && !relevantSentences.contains(allSentences[index - 1]) {
                        let prevSentence = allSentences[index - 1]
                        if !containsOtherCharacter(prevSentence, excluding: character, allCharacters: allCharacters) {
                            relevantSentences.insert(prevSentence, at: relevantSentences.count - 1)
                            positions.insert(currentPos - prevSentence.count - 1, at: positions.count - 1)
                        }
                    }
                }
            }
            currentPos += sentence.count + 1 // +1 for the separator
        }

        return (relevantSentences, positions)
    }

    private func isAboutOtherCharacter(_ sentence: String, targetCharacter: String, allCharacters: [String]) -> Bool {
        // Check if sentence is primarily about another character
        // by seeing if another character appears as the subject (appears first or near the beginning)
        let lowerSentence = sentence.lowercased()
        let targetLower = targetCharacter.lowercased()

        // Find the position of the target character in the sentence
        guard let targetRange = lowerSentence.range(of: targetLower) else {
            return false
        }
        let targetPosition = lowerSentence.distance(from: lowerSentence.startIndex, to: targetRange.lowerBound)

        // Check if any other character appears significantly before the target character
        for character in allCharacters {
            let characterLower = character.lowercased()
            if characterLower == targetLower {
                continue
            }

            if let otherRange = lowerSentence.range(of: characterLower) {
                let otherPosition = lowerSentence.distance(from: lowerSentence.startIndex, to: otherRange.lowerBound)

                // If another character appears at least 10 characters before the target,
                // it's likely the subject of the sentence
                if otherPosition < targetPosition - 10 {
                    return true
                }
            }
        }

        return false
    }

    private func containsOtherCharacter(_ text: String, excluding: String, allCharacters: [String]) -> Bool {
        // Check if text mentions any other character from the character list
        let lowerText = text.lowercased()
        let excludingLower = excluding.lowercased()

        for character in allCharacters {
            let characterLower = character.lowercased()
            if characterLower != excludingLower && lowerText.contains(characterLower) {
                return true
            }
        }
        return false
    }

    private func calculatePageNumber(position: Int, in text: String) -> Int {
        // Use page mapping for accurate page numbers if available
        if let mapping = pageMapping, !mapping.isEmpty {
            // Find the two mapping entries that bracket this position
            var precedingEntry: (location: Int, page: Int)?
            var followingEntry: (location: Int, page: Int)?

            for entry in mapping {
                if entry.location <= position {
                    precedingEntry = entry
                } else if followingEntry == nil {
                    followingEntry = entry
                    break
                }
            }

            // If we have both entries, interpolate
            if let preceding = precedingEntry, let following = followingEntry {
                let charsBetween = following.location - preceding.location
                let charsFromPreceding = position - preceding.location

                if charsBetween > 0 {
                    let ratio = Double(charsFromPreceding) / Double(charsBetween)
                    let pagesBetween = following.page - preceding.page
                    let interpolatedPage = preceding.page + Int(round(ratio * Double(pagesBetween)))
                    return max(preceding.page, min(following.page, interpolatedPage))
                }
                return preceding.page
            }

            // Use preceding entry if that's all we have
            if let preceding = precedingEntry {
                return preceding.page
            }

            // Use following entry if that's all we have
            if let following = followingEntry {
                return following.page
            }
        }

        // Fall back to word count estimation if no page mapping available
        let textUpToPosition = String(text.prefix(position))
        let wordCount = textUpToPosition.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        return max(1, (wordCount / 250) + 1)
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
    func analyzePresenceByChapter(text: String, characterNames: [String], outlineEntries: [OutlineEntry]? = nil) -> [CharacterPresence] {
        NSLog("📊 analyzePresenceByChapter: Starting with \(characterNames.count) characters")
        NSLog("📊 analyzePresenceByChapter: Character names = \(characterNames)")
        NSLog("📊 analyzePresenceByChapter: Text length = \(text.count) characters")
        NSLog("📊 analyzePresenceByChapter: Outline entries count = \(outlineEntries?.count ?? 0)")

        var presenceData: [CharacterPresence] = []

        // Get chapters using outline or fall back to regex
        let chapters: [(text: String, number: Int)]
        if let entries = outlineEntries {
            // If caller provided outline entries, treat them as source of truth when available;
            // otherwise, fall back to regex detection so we never return empty data silently.
            if entries.isEmpty {
                NSLog("⚠️ analyzePresenceByChapter: Outline entries empty, falling back to regex detection")
                let chapterTexts = splitIntoChapters(text: text)
                chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1) }
                NSLog("📊 analyzePresenceByChapter: Regex detected \(chapters.count) chapters")
            } else {
                // Look for level 1 entries (chapters) first - these are the main chapter divisions
                let chapterEntries = entries.filter { $0.level == 1 }
                var effectiveEntries: [OutlineEntry] = []
                if !chapterEntries.isEmpty {
                    effectiveEntries = chapterEntries
                } else {
                    // Only fallback to level 0 (parts/acts) if no chapters found; otherwise use regex
                    let level0Entries = entries.filter { $0.level == 0 }
                    if !level0Entries.isEmpty {
                        effectiveEntries = level0Entries
                    }
                }

                if effectiveEntries.isEmpty {
                    NSLog("⚠️ analyzePresenceByChapter: No usable outline entries, falling back to regex detection")
                    let chapterTexts = splitIntoChapters(text: text)
                    chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1) }
                    NSLog("📊 analyzePresenceByChapter: Regex detected \(chapters.count) chapters")
                } else {
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
                        return (text: fullText.substring(with: chapterRange), number: index + 1)
                    }
                }
            }
        } else {
            // No outline provided; fall back to regex detection
            NSLog("📊 analyzePresenceByChapter: No outline entries, using regex detection")
            let chapterTexts = splitIntoChapters(text: text)
            chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1) }
            NSLog("📊 analyzePresenceByChapter: Regex detected \(chapters.count) chapters")
        }

        NSLog("📊 analyzePresenceByChapter: Total chapters detected = \(chapters.count)")

        for characterName in characterNames {
            var presence = CharacterPresence(characterName: characterName)
            NSLog("📊 analyzePresenceByChapter: Analyzing presence for character '\(characterName)'")

            for chapter in chapters {
                let mentions = countMentions(of: characterName, in: chapter.text)
                if mentions > 0 {
                    presence.chapterPresence[chapter.number] = mentions
                    NSLog("📊 analyzePresenceByChapter: Character '\(characterName)' has \(mentions) mentions in chapter \(chapter.number)")
                }
            }

            if presence.chapterPresence.isEmpty {
                NSLog("⚠️ analyzePresenceByChapter: Character '\(characterName)' has NO mentions in any chapter")
            } else {
                NSLog("✅ analyzePresenceByChapter: Character '\(characterName)' found in \(presence.chapterPresence.count) chapters")
            }
            presenceData.append(presence)
        }

        NSLog("📊 analyzePresenceByChapter: Returning \(presenceData.count) presence entries")
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
        // Use word boundaries to avoid false positives (e.g., "Alex" in "Alexander")
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: characterName) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return 0
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        return matches.count
    }

    // MARK: - Relationship Evolution Map Generation

    func generateRelationshipEvolutionData(from text: String, characterNames: [String]) -> RelationshipEvolutionData {
        guard characterNames.count >= 2 else {
            return RelationshipEvolutionData()
        }

        let chapters = splitIntoChapters(text: text)
        var evolutionData = RelationshipEvolutionData()

        // Generate nodes with positions and emotional investment
        let gridSize = Int(ceil(sqrt(Double(characterNames.count))))
        for (index, character) in characterNames.enumerated() {
            let row = index / gridSize
            let col = index % gridSize

            // Position in grid (with some randomization for visual interest)
            let baseX = (Double(col) + 0.5) / Double(gridSize)
            let baseY = (Double(row) + 0.5) / Double(gridSize)

            // Add slight randomization
            let randomX = Double.random(in: -0.1...0.1) / Double(gridSize)
            let randomY = Double.random(in: -0.1...0.1) / Double(gridSize)

            let posX = max(0.1, min(0.9, baseX + randomX))
            let posY = max(0.1, min(0.9, baseY + randomY))

            // Calculate emotional investment based on presence in text
            let totalMentions = countMentions(of: character, in: text)
            let maxMentions = characterNames.map { countMentions(of: $0, in: text) }.max() ?? 1
            let investment = Double(totalMentions) / Double(maxMentions)

            evolutionData.nodes.append(RelationshipNodeData(
                character: character,
                emotionalInvestment: investment,
                positionX: posX,
                positionY: posY
            ))
        }

        // Generate edges between characters
        for i in 0..<characterNames.count {
            for j in (i+1)..<characterNames.count {
                let char1 = characterNames[i]
                let char2 = characterNames[j]

                // Build regexes for word boundary matching
                let pattern1 = "\\b" + NSRegularExpression.escapedPattern(for: char1) + "\\b"
                let pattern2 = "\\b" + NSRegularExpression.escapedPattern(for: char2) + "\\b"
                guard let regex1 = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive),
                      let regex2 = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive) else { continue }

                // Analyze relationship evolution across chapters
                var evolutionPoints: [RelationshipEvolutionPoint] = []
                var overallTrust: Double = 0.0

                for (chapterIndex, chapter) in chapters.enumerated() {
                    let chapterNum = chapterIndex + 1
                    let sentences = chapter.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.isEmpty }

                    var trustScore: Double = 0.0
                    var interactionCount = 0

                    // Analyze sentences mentioning both characters
                    for sentence in sentences {
                        let range = NSRange(sentence.startIndex..., in: sentence)
                        let hasChar1 = regex1.firstMatch(in: sentence, options: [], range: range) != nil
                        let hasChar2 = regex2.firstMatch(in: sentence, options: [], range: range) != nil

                        if hasChar1 && hasChar2 {
                            interactionCount += 1
                            let lowerSentence = sentence.lowercased()

                            // Positive relationship indicators
                            let positiveWords = ["help", "support", "agree", "together", "friend", "ally", "trust", "love", "care"]
                            let negativeWords = ["fight", "argue", "hate", "enemy", "against", "betray", "distrust", "conflict", "oppose"]

                            for word in positiveWords {
                                if lowerSentence.contains(word) {
                                    trustScore += 0.1
                                }
                            }

                            for word in negativeWords {
                                if lowerSentence.contains(word) {
                                    trustScore -= 0.1
                                }
                            }
                        }
                    }

                    if interactionCount > 0 {
                        // Normalize trust score
                        let normalizedTrust = max(-1.0, min(1.0, trustScore / Double(interactionCount)))
                        overallTrust += normalizedTrust

                        let description = normalizedTrust > 0 ? "Positive interaction" : normalizedTrust < 0 ? "Conflict" : "Neutral"

                        evolutionPoints.append(RelationshipEvolutionPoint(
                            chapter: chapterNum,
                            trustLevel: normalizedTrust,
                            description: description
                        ))
                    }
                }

                // Only add edge if characters interact
                if !evolutionPoints.isEmpty {
                    let avgTrust = overallTrust / Double(evolutionPoints.count)

                    // Determine power direction (simplified heuristic)
                    let char1Mentions = countMentions(of: char1, in: text)
                    let char2Mentions = countMentions(of: char2, in: text)

                    let powerDirection: String
                    if abs(char1Mentions - char2Mentions) < 3 {
                        powerDirection = "balanced"
                    } else if char1Mentions > char2Mentions {
                        powerDirection = "fromToTo"
                    } else {
                        powerDirection = "toToFrom"
                    }

                    evolutionData.edges.append(RelationshipEdgeData(
                        from: char1,
                        to: char2,
                        trustLevel: avgTrust,
                        powerDirection: powerDirection,
                        evolution: evolutionPoints
                    ))
                }
            }
        }

        return evolutionData
    }

    // MARK: - Internal vs External Alignment Generation

    /// Generate internal vs external alignment data for characters
    /// Tracks the gap between inner truth and outer behavior
    func generateInternalExternalAlignment(from text: String, characterNames: [String], outlineEntries: [OutlineEntry]? = nil) -> InternalExternalAlignmentData {
        guard !characterNames.isEmpty else {
            return InternalExternalAlignmentData()
        }

        var alignmentData = InternalExternalAlignmentData()

        // Get chapters using outline or fall back to regex
        let chapters: [(text: String, number: Int)]
        if let entries = outlineEntries, !entries.isEmpty {
            // Look for level 1 entries (chapters) first
            let chapterEntries = entries.filter { $0.level == 1 }
            let effectiveEntries: [OutlineEntry]
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
                    return (text: fullText.substring(with: chapterRange), number: index + 1)
                }
            } else {
                // No outline structure found - use regex detection
                let chapterTexts = splitIntoChapters(text: text)
                chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1) }
            }
        } else {
            let chapterTexts = splitIntoChapters(text: text)
            chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1) }
        }
        guard !chapters.isEmpty else { return alignmentData }

        // Inner state indicators (what characters feel/think)
        let innerStateWords: [String: Double] = [
            // Negative inner states
            "felt": 0.0, "thought": 0.0, "wondered": 0.0, "feared": -0.3,
            "doubted": -0.2, "worried": -0.3, "dreaded": -0.4, "wished": 0.0,
            "hoped": 0.3, "believed": 0.0, "knew": 0.2, "sensed": 0.0,
            "realized": 0.1, "understood": 0.2, "secretly": -0.2, "inside": 0.0,
            "heart": 0.0, "soul": 0.0, "truly": 0.0, "really": 0.0,
            "actually": 0.0, "honestly": 0.0, "genuinely": 0.2,
            // Emotional words
            "afraid": -0.4, "anxious": -0.3, "nervous": -0.2, "uncertain": -0.2,
            "conflicted": -0.2, "torn": -0.3, "confused": -0.2, "lonely": -0.4,
            "guilty": -0.4, "ashamed": -0.4, "regretted": -0.3, "mourned": -0.3,
            "happy": 0.4, "content": 0.3, "peaceful": 0.4, "confident": 0.3,
            "proud": 0.3, "relieved": 0.3, "grateful": 0.4, "loved": 0.5
        ]

        // Outer behavior indicators (what characters do/say)
        let outerBehaviorWords: [String: Double] = [
            // Actions that may mask inner state
            "smiled": 0.3, "laughed": 0.4, "nodded": 0.2, "agreed": 0.2,
            "said": 0.0, "spoke": 0.0, "replied": 0.0, "answered": 0.0,
            "pretended": -0.3, "acted": 0.0, "appeared": 0.0, "seemed": 0.0,
            "showed": 0.0, "displayed": 0.0, "maintained": 0.0, "kept": 0.0,
            "hid": -0.3, "concealed": -0.3, "masked": -0.3, "suppressed": -0.3,
            "composed": 0.2, "calm": 0.2, "steady": 0.2, "controlled": 0.1,
            "professional": 0.2, "polite": 0.2, "cheerful": 0.3, "friendly": 0.3,
            "cold": -0.2, "distant": -0.2, "formal": 0.0, "stiff": -0.1,
            "frowned": -0.2, "scowled": -0.3, "glared": -0.3, "shouted": -0.3,
            "cried": -0.3, "sobbed": -0.4, "screamed": -0.4, "yelled": -0.3
        ]

        for characterName in characterNames { // All characters from library
            var characterAlignment = CharacterAlignmentData(characterName: characterName)
            var gapValues: [Double] = []

            // Build regex for word boundary matching
            let characterPattern = "\\b" + NSRegularExpression.escapedPattern(for: characterName) + "\\b"
            let characterRegex = try? NSRegularExpression(pattern: characterPattern, options: .caseInsensitive)

            for chapter in chapters {
                // Find sentences containing the character
                let sentences = chapter.text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                var innerScores: [Double] = []
                var outerScores: [Double] = []
                var innerDescription = ""
                var outerDescription = ""

                for sentence in sentences {
                    // Use word boundary match
                    guard let regex = characterRegex else { continue }
                    let range = NSRange(sentence.startIndex..., in: sentence)
                    guard regex.firstMatch(in: sentence, options: [], range: range) != nil else { continue }
                    let lowerSentence = sentence.lowercased()

                    // Check for inner state words
                    for (word, baseScore) in innerStateWords {
                        if lowerSentence.contains(word) {
                            // Adjust score based on context
                            var score = 0.5 + baseScore
                            if lowerSentence.contains("not ") || lowerSentence.contains("n't ") {
                                score = 1.0 - score // Negate
                            }
                            innerScores.append(score)

                            // Capture description
                            if innerDescription.isEmpty && baseScore != 0 {
                                innerDescription = word.capitalized
                            }
                        }
                    }

                    // Check for outer behavior words
                    for (word, baseScore) in outerBehaviorWords {
                        if lowerSentence.contains(word) {
                            var score = 0.5 + baseScore
                            if lowerSentence.contains("not ") || lowerSentence.contains("n't ") {
                                score = 1.0 - score
                            }
                            outerScores.append(score)

                            if outerDescription.isEmpty && baseScore != 0 {
                                outerDescription = word.capitalized
                            }
                        }
                    }
                }

                // Calculate average inner and outer scores for this chapter
                let avgInner = innerScores.isEmpty ? 0.5 : innerScores.reduce(0, +) / Double(innerScores.count)
                let avgOuter = outerScores.isEmpty ? 0.5 : outerScores.reduce(0, +) / Double(outerScores.count)

                // Only add data point if we have meaningful data
                if !innerScores.isEmpty || !outerScores.isEmpty {
                    let dataPoint = AlignmentDataPoint(
                        chapter: chapter.number,
                        innerTruth: min(1.0, max(0.0, avgInner)),
                        outerBehavior: min(1.0, max(0.0, avgOuter)),
                        innerLabel: innerDescription.isEmpty ? "Neutral" : innerDescription,
                        outerLabel: outerDescription.isEmpty ? "Neutral" : outerDescription
                    )
                    characterAlignment.dataPoints.append(dataPoint)
                    gapValues.append(abs(avgInner - avgOuter))
                }
            }

            // Determine gap trend
            if gapValues.count >= 2 {
                let firstHalf = Array(gapValues.prefix(gapValues.count / 2))
                let secondHalf = Array(gapValues.suffix(gapValues.count / 2))

                let avgFirstHalf = firstHalf.reduce(0, +) / Double(firstHalf.count)
                let avgSecondHalf = secondHalf.reduce(0, +) / Double(secondHalf.count)

                let change = avgSecondHalf - avgFirstHalf

                // Check if closing toward authenticity or collapse
                let lastPoints = characterAlignment.dataPoints.suffix(2)
                let isCollapse = lastPoints.allSatisfy { $0.innerTruth < 0.3 && $0.outerBehavior < 0.3 }

                if change > 0.1 {
                    characterAlignment.gapTrend = "widening"
                } else if change < -0.1 {
                    characterAlignment.gapTrend = isCollapse ? "collapsing" : "closing"
                } else if abs(change) <= 0.1 && gapValues.max()! - gapValues.min()! < 0.2 {
                    characterAlignment.gapTrend = "stabilizing"
                } else {
                    characterAlignment.gapTrend = "fluctuating"
                }
            }

            if !characterAlignment.dataPoints.isEmpty {
                alignmentData.characterAlignments.append(characterAlignment)
            }
        }

        return alignmentData
    }

    // MARK: - Language Drift Analysis Generation

    /// Generate language drift analysis for characters
    /// Tracks pronouns, modal verbs, emotional vocabulary, sentence length, certainty
    func generateLanguageDriftAnalysis(from text: String, characterNames: [String], outlineEntries: [OutlineEntry]? = nil) -> LanguageDriftData {
        guard !characterNames.isEmpty else {
            return LanguageDriftData()
        }

        var driftData = LanguageDriftData()

        // Get chapters using outline or fall back to regex
        let chapters: [(text: String, number: Int)]
        if let entries = outlineEntries, !entries.isEmpty {
            // Look for level 1 entries (chapters) first
            let chapterEntries = entries.filter { $0.level == 1 }
            let effectiveEntries: [OutlineEntry]
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
                    return (text: fullText.substring(with: chapterRange), number: index + 1)
                }
            } else {
                // No outline structure found - use regex detection
                let chapterTexts = splitIntoChapters(text: text)
                chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1) }
            }
        } else {
            let chapterTexts = splitIntoChapters(text: text)
            chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1) }
        }
        guard !chapters.isEmpty else { return driftData }

        // Pronoun patterns
        let iPronounPattern = "\\b(I|I'm|I've|I'll|I'd|my|mine|myself)\\b"
        let wePronounPattern = "\\b(we|we're|we've|we'll|we'd|our|ours|ourselves|us)\\b"

        // Modal verb patterns
        let mustModals = ["must", "have to", "need to", "should", "ought to", "required"]
        let choiceModals = ["choose", "can", "could", "want to", "decide", "prefer", "wish", "hope"]

        // Emotional vocabulary
        let emotionalWords = Set([
            "love", "hate", "fear", "joy", "anger", "sad", "happy", "worried", "excited",
            "terrified", "delighted", "furious", "anxious", "hopeful", "desperate", "elated",
            "miserable", "thrilled", "devastated", "ecstatic", "heartbroken", "relieved",
            "frustrated", "grateful", "bitter", "proud", "ashamed", "guilty", "jealous",
            "lonely", "content", "nervous", "confident", "insecure", "passionate", "indifferent"
        ])

        // Certainty indicators
        let certainWords = ["know", "certain", "sure", "definitely", "absolutely", "clearly", "obviously", "undoubtedly", "always", "never", "must be", "will"]
        let uncertainWords = ["maybe", "perhaps", "might", "possibly", "probably", "seems", "appears", "think", "believe", "guess", "wonder", "could be", "not sure"]

        for characterName in characterNames {
            var characterDrift = CharacterLanguageDrift(characterName: characterName)
            var allMetrics: [LanguageMetricsData] = []

            for chapter in chapters {
                // Find dialogue and narration related to this character
                let sentences = chapter.text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                var characterSentences: [String] = []

                // Use word boundary matching to avoid false positives
                let characterPattern = "\\b" + NSRegularExpression.escapedPattern(for: characterName) + "\\b"
                let characterRegex = try? NSRegularExpression(pattern: characterPattern, options: .caseInsensitive)

                for sentence in sentences {
                    if let regex = characterRegex {
                        let range = NSRange(sentence.startIndex..., in: sentence)
                        if regex.firstMatch(in: sentence, options: [], range: range) != nil {
                            characterSentences.append(sentence)
                        }
                    }
                }

                guard !characterSentences.isEmpty else { continue }

                let combinedText = characterSentences.joined(separator: " ")
                let lowerText = combinedText.lowercased()
                let wordCount = combinedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count

                // Count pronouns
                let iCount = countMatches(pattern: iPronounPattern, in: combinedText)
                let weCount = countMatches(pattern: wePronounPattern, in: combinedText)
                let totalPronouns = max(iCount + weCount, 1)

                // Count modal verbs
                var mustCount = 0
                var choiceCount = 0
                for modal in mustModals {
                    mustCount += lowerText.components(separatedBy: modal).count - 1
                }
                for modal in choiceModals {
                    choiceCount += lowerText.components(separatedBy: modal).count - 1
                }
                let totalModals = max(mustCount + choiceCount, 1)

                // Count emotional words
                var emotionalCount = 0
                let words = lowerText.components(separatedBy: .whitespacesAndNewlines)
                for word in words {
                    let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                    if emotionalWords.contains(cleanWord) {
                        emotionalCount += 1
                    }
                }

                // Count certainty
                var certainCount = 0
                var uncertainCount = 0
                for word in certainWords {
                    certainCount += lowerText.components(separatedBy: word).count - 1
                }
                for word in uncertainWords {
                    uncertainCount += lowerText.components(separatedBy: word).count - 1
                }
                let totalCertainty = max(certainCount + uncertainCount, 1)

                // Calculate average sentence length
                let avgSentenceLength = Double(wordCount) / Double(max(characterSentences.count, 1))
                let normalizedSentenceLength = min(1.0, avgSentenceLength / 30.0) // Normalize to 30 words max

                let metrics = LanguageMetricsData(
                    chapter: chapter.number,
                    pronounI: Double(iCount) / Double(totalPronouns),
                    pronounWe: Double(weCount) / Double(totalPronouns),
                    modalMust: Double(mustCount) / Double(totalModals),
                    modalChoice: Double(choiceCount) / Double(totalModals),
                    emotionalDensity: min(1.0, Double(emotionalCount) / Double(max(characterSentences.count, 1)) / 2.0),
                    avgSentenceLength: normalizedSentenceLength,
                    certaintyScore: Double(certainCount) / Double(totalCertainty)
                )

                allMetrics.append(metrics)
            }

            characterDrift.metrics = allMetrics

            // Calculate drift summary
            if allMetrics.count >= 2 {
                let firstHalf = Array(allMetrics.prefix(allMetrics.count / 2))
                let secondHalf = Array(allMetrics.suffix(allMetrics.count / 2))

                // Pronoun shift
                let avgIFirst = firstHalf.map { $0.pronounI }.reduce(0, +) / Double(firstHalf.count)
                let avgISecond = secondHalf.map { $0.pronounI }.reduce(0, +) / Double(secondHalf.count)
                let avgWeFirst = firstHalf.map { $0.pronounWe }.reduce(0, +) / Double(firstHalf.count)
                let avgWeSecond = secondHalf.map { $0.pronounWe }.reduce(0, +) / Double(secondHalf.count)

                if avgIFirst > avgWeFirst && avgWeSecond > avgISecond {
                    characterDrift.driftSummary.pronounShift = "I → We"
                } else if avgWeFirst > avgIFirst && avgISecond > avgWeSecond {
                    characterDrift.driftSummary.pronounShift = "We → I"
                } else {
                    characterDrift.driftSummary.pronounShift = "Stable"
                }

                // Modal shift
                let avgMustFirst = firstHalf.map { $0.modalMust }.reduce(0, +) / Double(firstHalf.count)
                let avgMustSecond = secondHalf.map { $0.modalMust }.reduce(0, +) / Double(secondHalf.count)
                let avgChoiceFirst = firstHalf.map { $0.modalChoice }.reduce(0, +) / Double(firstHalf.count)
                let avgChoiceSecond = secondHalf.map { $0.modalChoice }.reduce(0, +) / Double(secondHalf.count)

                if avgMustFirst > avgChoiceFirst && avgChoiceSecond > avgMustSecond {
                    characterDrift.driftSummary.modalShift = "Must → Choose"
                } else if avgChoiceFirst > avgMustFirst && avgMustSecond > avgChoiceSecond {
                    characterDrift.driftSummary.modalShift = "Choose → Must"
                } else {
                    characterDrift.driftSummary.modalShift = "Stable"
                }

                // Emotional trend
                let avgEmotionalFirst = firstHalf.map { $0.emotionalDensity }.reduce(0, +) / Double(firstHalf.count)
                let avgEmotionalSecond = secondHalf.map { $0.emotionalDensity }.reduce(0, +) / Double(secondHalf.count)

                if avgEmotionalSecond - avgEmotionalFirst > 0.1 {
                    characterDrift.driftSummary.emotionalTrend = "Increasing"
                } else if avgEmotionalFirst - avgEmotionalSecond > 0.1 {
                    characterDrift.driftSummary.emotionalTrend = "Decreasing"
                } else {
                    characterDrift.driftSummary.emotionalTrend = "Stable"
                }

                // Sentence length trend
                let avgSentenceFirst = firstHalf.map { $0.avgSentenceLength }.reduce(0, +) / Double(firstHalf.count)
                let avgSentenceSecond = secondHalf.map { $0.avgSentenceLength }.reduce(0, +) / Double(secondHalf.count)

                if avgSentenceSecond - avgSentenceFirst > 0.1 {
                    characterDrift.driftSummary.sentenceTrend = "Longer"
                } else if avgSentenceFirst - avgSentenceSecond > 0.1 {
                    characterDrift.driftSummary.sentenceTrend = "Shorter"
                } else {
                    characterDrift.driftSummary.sentenceTrend = "Stable"
                }

                // Certainty trend
                let avgCertaintyFirst = firstHalf.map { $0.certaintyScore }.reduce(0, +) / Double(firstHalf.count)
                let avgCertaintySecond = secondHalf.map { $0.certaintyScore }.reduce(0, +) / Double(secondHalf.count)

                if avgCertaintySecond - avgCertaintyFirst > 0.1 {
                    characterDrift.driftSummary.certaintyTrend = "More Certain"
                } else if avgCertaintyFirst - avgCertaintySecond > 0.1 {
                    characterDrift.driftSummary.certaintyTrend = "Less Certain"
                } else {
                    characterDrift.driftSummary.certaintyTrend = "Stable"
                }
            }

            if !characterDrift.metrics.isEmpty {
                driftData.characterDrifts.append(characterDrift)
            }
        }

        return driftData
    }

    private func countMatches(pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return 0
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, options: [], range: range)
    }
}
