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

            if chapterEntries.isEmpty {
                // No chapter-level entries, treat entire document as one chapter
                chapters = [(text: text, number: 1, startPos: 0)]
            } else {
                var result: [(text: String, number: Int, startPos: Int)] = []
                let fullText = text as NSString

                for (index, entry) in chapterEntries.enumerated() {
                    let startLocation = entry.range.location
                    let endLocation: Int

                    // Determine end of chapter
                    if index < chapterEntries.count - 1 {
                        // End at next chapter start
                        endLocation = chapterEntries[index + 1].range.location
                    } else {
                        // Last chapter goes to end of document
                        endLocation = fullText.length
                    }

                    let chapterRange = NSRange(location: startLocation, length: endLocation - startLocation)
                    let chapterText = fullText.substring(with: chapterRange)

                    result.append((text: chapterText, number: index + 1, startPos: startLocation))
                }

                chapters = result
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
        var presenceData: [CharacterPresence] = []

        // Get chapters using outline or fall back to regex
        let chapters: [(text: String, number: Int)]
        if let entries = outlineEntries, !entries.isEmpty {
            let chapterEntries = entries.filter { $0.level == 1 }
            if chapterEntries.isEmpty {
                chapters = [(text: text, number: 1)]
            } else {
                let fullText = text as NSString
                chapters = chapterEntries.enumerated().map { index, entry in
                    let startLocation = entry.range.location
                    let endLocation: Int
                    if index < chapterEntries.count - 1 {
                        endLocation = chapterEntries[index + 1].range.location
                    } else {
                        endLocation = fullText.length
                    }
                    let chapterRange = NSRange(location: startLocation, length: endLocation - startLocation)
                    return (text: fullText.substring(with: chapterRange), number: index + 1)
                }
            }
        } else {
            let chapterTexts = splitIntoChapters(text: text)
            chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1) }
        }

        for characterName in characterNames {
            var presence = CharacterPresence(characterName: characterName)

            for chapter in chapters {
                let mentions = countMentions(of: characterName, in: chapter.text)
                if mentions > 0 {
                    presence.chapterPresence[chapter.number] = mentions
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
