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

    /// Optional metadata used for screenplay Act aggregation.
    /// Keys are chapter/scene indexes (1-based) and values are act numbers (1-based).
    var chapterToAct: [Int: Int] = [:]
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

    // Cache sentence/line units to avoid repeated splitting on large texts
    private struct TextUnitsCacheKey: Hashable {
        let length: Int
        let hash: Int
    }

    private struct TextUnitsCacheEntry {
        let isScreenplay: Bool
        let lineUnits: [(unit: String, pos: Int)]
        let sentenceUnits: [(unit: String, pos: Int)]
    }

    private var textUnitsCache: [TextUnitsCacheKey: TextUnitsCacheEntry] = [:]
    private var textUnitsCacheOrder: [TextUnitsCacheKey] = []
    private let textUnitsCacheLimit = 6

    // Cache mention regexes for character aliases
    private var mentionRegexCache: [String: [NSRegularExpression]] = [:]

    // Pressure indicators (conflict, dilemma, force)
    private let pressureWords = [
        "must", "need", "forced", "threatened", "danger", "risk", "challenge", "problem",
        "confronted", "demanded", "urgent", "crisis", "deadline", "pressure", "choice",
        "conflict", "struggle", "dilemma", "torn", "caught", "trapped"
    ]

    // Decision indicators
    // Decision indicators - expanded for better coverage
    private let decisionWords = [
        "decided", "chose", "choose", "picked", "selected", "agreed", "refused",
        "accepted", "rejected", "committed", "promised", "vowed", "resolved",
        "determined", "opted", "went with", "settled on", "made up", "mind",
        "would", "wouldn't", "will", "won't", "going to", "not going to",
        "took", "grabbed", "reached for", "stepped", "turned", "walked",
        "ran", "left", "stayed", "followed", "confronted", "avoided",
        "told", "said yes", "said no", "nodded", "shook", "head"
    ]

    // Outcome indicators - expanded for better coverage
    private let outcomeWords = [
        "resulted", "consequence", "outcome", "happened", "led to", "caused",
        "because of", "as a result", "therefore", "thus", "success", "failed",
        "worked", "backfired", "paid off", "cost", "gained", "lost",
        "then", "suddenly", "immediately", "moment later", "next",
        "discovered", "found", "saw", "heard", "felt", "noticed",
        "was", "were", "had", "became", "turned out", "ended up",
        "realized", "understood", "knew", "recognized", "hit", "struck"
    ]

    // Belief/value words - expanded for better coverage
    private let beliefWords = [
        "believe", "think", "thought", "realize", "understand", "see", "know",
        "trust", "faith", "doubt", "sure", "certain", "convinced", "learned",
        "always", "never", "should", "wrong", "right", "value",
        "felt", "knew", "assumed", "expected", "hoped", "feared",
        "wanted", "needed", "wished", "dreamed", "imagined",
        "couldn't", "wouldn't", "mustn't", "had to", "supposed to",
        "matter", "important", "meant", "meant to", "deserved"
    ]

    private enum LoopStage {
        case pressure
        case belief
        case decision
        case outcome
        case shift
    }

    private func detectStageHeading(_ line: String) -> LoopStage? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let lower = trimmed.lowercased()

        // Accept common variants; allow optional colon.
        func isHeading(_ names: [String]) -> Bool {
            for n in names {
                if lower == n { return true }
                if lower == n + ":" { return true }
                if lower.hasPrefix(n + ":") { return true }
            }
            return false
        }

        if isHeading(["pressure", "counterpressure"]) { return .pressure }
        if isHeading(["beliefs in play", "belief in play", "beliefs", "belief"]) { return .belief }
        if isHeading(["decisions", "decision"]) { return .decision }
        if isHeading(["outcome", "outcomes", "consequence", "consequences"]) { return .outcome }
        if isHeading(["belief shift", "belief shifts", "shift", "shifts"]) { return .shift }
        return nil
    }

    private func extractCharacterSpecificValue(from sectionText: String, character: String) -> String {
        let trimmed = sectionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        let aliases = characterAliases(for: character)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Prefer explicit attribution lines: "AVA: ...", "Ava — ...", "Ava - ..."
        for line in lines {
            for alias in aliases {
                let pattern = "^" + NSRegularExpression.escapedPattern(for: alias) + "\\s*[:\\u2014\\-]\\s*(.+)$"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(line.startIndex..<line.endIndex, in: line)
                    if let m = regex.firstMatch(in: line, options: [], range: range), m.numberOfRanges >= 2,
                       let r = Range(m.range(at: 1), in: line) {
                        return String(line[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        // Otherwise, use the whole section as-is (keeps structured summaries usable).
        if lines.count == 1 {
            return lines[0]
        }
        return lines.joined(separator: " ")
    }

    private func pressureBlockRanges(in chapterText: String) -> [NSRange] {
        let ns = chapterText as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let pattern = "(?im)^\\s*pressure\\s*:?.*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let matches = regex.matches(in: chapterText, options: [], range: fullRange)
        if matches.isEmpty { return [] }

        var ranges: [NSRange] = []
        ranges.reserveCapacity(matches.count)
        for (idx, m) in matches.enumerated() {
            let start = m.range.location
            let end: Int
            if idx < matches.count - 1 {
                end = matches[idx + 1].range.location
            } else {
                end = ns.length
            }
            if end > start {
                ranges.append(NSRange(location: start, length: end - start))
            }
        }
        return ranges
    }

    private func extractStructuredLoopEntries(
        chapterText: String,
        chapterNumber: Int,
        chapterStartPos: Int,
        fullText: String,
        character: String
    ) -> [DecisionBeliefLoop.LoopEntry] {
        let ns = chapterText as NSString
        let blocks = pressureBlockRanges(in: chapterText)
        guard !blocks.isEmpty else { return [] }

        var entries: [DecisionBeliefLoop.LoopEntry] = []
        entries.reserveCapacity(blocks.count)

        for blockRange in blocks {
            let blockText = ns.substring(with: blockRange)
            let blockStartInChapter = blockRange.location

            var sections: [LoopStage: String] = [:]
            var sectionFirstPos: [LoopStage: Int] = [:]

            var currentStage: LoopStage?
            let blockNS = blockText as NSString
            blockNS.enumerateSubstrings(in: NSRange(location: 0, length: blockNS.length), options: [.byLines]) { substring, range, _, _ in
                guard let substring else { return }
                let line = substring.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty { return }

                if let stage = self.detectStageHeading(line) {
                    currentStage = stage
                    return
                }

                guard let stage = currentStage else { return }
                if sections[stage] == nil { sections[stage] = "" }
                if sections[stage]?.isEmpty == true {
                    // Capture the first position where this section has actual content.
                    sectionFirstPos[stage] = blockStartInChapter + range.location
                    sections[stage] = line
                } else {
                    sections[stage] = (sections[stage] ?? "") + "\n" + line
                }
            }

            let pressureText = extractCharacterSpecificValue(from: sections[.pressure] ?? "", character: character)
            let beliefText = extractCharacterSpecificValue(from: sections[.belief] ?? "", character: character)
            let decisionText = extractCharacterSpecificValue(from: sections[.decision] ?? "", character: character)
            let outcomeText = extractCharacterSpecificValue(from: sections[.outcome] ?? "", character: character)
            let shiftText = extractCharacterSpecificValue(from: sections[.shift] ?? "", character: character)

            // Require at least a meaningful loop skeleton.
            if pressureText.isEmpty && decisionText.isEmpty && outcomeText.isEmpty && shiftText.isEmpty {
                continue
            }

            func page(for stage: LoopStage) -> Int {
                guard let relPos = sectionFirstPos[stage] else { return 0 }
                let absolutePos = chapterStartPos + relPos
                return calculatePageNumber(position: absolutePos, in: fullText)
            }

            let entry = DecisionBeliefLoop.LoopEntry(
                chapter: chapterNumber,
                pressure: cleanExtract(pressureText),
                pressurePage: page(for: .pressure),
                beliefInPlay: cleanExtract(beliefText),
                beliefPage: page(for: .belief),
                decision: cleanExtract(decisionText),
                decisionPage: page(for: .decision),
                outcome: cleanExtract(outcomeText),
                outcomePage: page(for: .outcome),
                beliefShift: cleanExtract(shiftText),
                beliefShiftPage: page(for: .shift)
            )

            entries.append(entry)
        }

        return entries
    }

    private func extractPressureWithPosition(from text: String, character: String, allCharacters: [String], startPos: Int, fullText: String, afterPosition: Int) -> (String, Int, Int) {
        let (sentences, positions) = getSentencesAbout(character: character, in: text, allCharacters: allCharacters, proximity: 2)

        for (index, sentence) in sentences.enumerated() {
            if afterPosition >= 0 && positions[index] <= afterPosition {
                continue
            }

            let lower = sentence.lowercased()
            for word in pressureWords {
                if lower.contains(word) {
                    let absolutePos = startPos + positions[index]
                    let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
                    return (cleanExtract(sentence), pageNum, positions[index])
                }
            }

            if sentence.contains("?") {
                let absolutePos = startPos + positions[index]
                let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
                return (cleanExtract(sentence), pageNum, positions[index])
            }
        }
        return ("", 0, -1)
    }

    private func extractHeuristicLoopEntries(
        chapterText: String,
        chapterNumber: Int,
        chapterStartPos: Int,
        fullText: String,
        character: String,
        allCharacters: [String]
    ) -> [DecisionBeliefLoop.LoopEntry] {
        var entries: [DecisionBeliefLoop.LoopEntry] = []

        var cursor = -1
        var safety = 0
        while safety < 25 {
            safety += 1

            var (pressure, pressurePage, pressurePos) = extractPressureWithPosition(from: chapterText, character: character, allCharacters: allCharacters, startPos: chapterStartPos, fullText: fullText, afterPosition: cursor)

            // If no pressure signal, allow other loop elements to drive the entry.
            let afterForBelief = max(cursor, pressurePos)
            let (belief, beliefPage, beliefPos) = extractBeliefWithPosition(from: chapterText, character: character, allCharacters: allCharacters, startPos: chapterStartPos, fullText: fullText, afterPosition: afterForBelief)
            let (decision, decisionPage, decisionPos) = extractDecisionWithPosition(from: chapterText, character: character, allCharacters: allCharacters, startPos: chapterStartPos, fullText: fullText, afterPosition: max(afterForBelief, beliefPos))
            let (outcome, outcomePage, outcomePos) = extractOutcomeWithPosition(from: chapterText, character: character, allCharacters: allCharacters, startPos: chapterStartPos, fullText: fullText, afterPosition: max(max(afterForBelief, beliefPos), decisionPos))
            let (shift, shiftPage, shiftPos) = extractBeliefShiftWithPosition(from: chapterText, character: character, allCharacters: allCharacters, startPos: chapterStartPos, fullText: fullText, afterPosition: max(max(max(afterForBelief, beliefPos), decisionPos), outcomePos))

            if (pressure.isEmpty || pressurePos < 0) {
                let (sentences, positions) = getSentencesAbout(character: character, in: chapterText, allCharacters: allCharacters, proximity: 2)
                if let first = sentences.first, let pos = positions.first {
                    pressure = cleanExtract(first)
                    pressurePos = pos
                    let absolutePos = chapterStartPos + pos
                    pressurePage = calculatePageNumber(position: absolutePos, in: fullText)
                }
            }

            // If we only found pressure and nothing else, skip to avoid pure noise.
            let hasAnySignal = !belief.isEmpty || !decision.isEmpty || !outcome.isEmpty || !shift.isEmpty
            if !hasAnySignal {
                let nextPos = [pressurePos, beliefPos, decisionPos, outcomePos, shiftPos].filter { $0 >= 0 }.min() ?? -1
                if nextPos < 0 { break }
                cursor = max(cursor, nextPos + 1)
                continue
            }

            let entry = DecisionBeliefLoop.LoopEntry(
                chapter: chapterNumber,
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
            entries.append(entry)

            let nextCursor = [pressurePos, beliefPos, decisionPos, outcomePos, shiftPos].max() ?? cursor
            if nextCursor <= cursor {
                cursor += 1
            } else {
                cursor = nextCursor
            }
        }

        return entries
    }

    // MARK: - Character Aliases (for interaction detection)

    /// Returns canonical + any nicknames/aliases from Character Library (if present).
    /// This is critical for interactions: texts often use short forms (e.g., "Alex") while the library uses full names.
    private func characterAliases(for canonical: String) -> [String] {
        var aliases: [String] = [canonical]
        let trimmedCanonical = canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCanonical.isEmpty { return aliases }

        let library = CharacterLibrary.shared

        // Add first name as a safe-ish alias when the library key is a multi-word full name.
        let parts = trimmedCanonical.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if parts.count >= 2, let first = parts.first, first.count >= 3 {
            aliases.append(first)
        }

        // Add nickname/fullName-derived aliases (if present)
        if let profile = library.analysisEligibleCharacters.first(where: {
            ($0.analysisKey ?? "").caseInsensitiveCompare(trimmedCanonical) == .orderedSame
        }) {
            let nick = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if !nick.isEmpty, nick.caseInsensitiveCompare(trimmedCanonical) != .orderedSame {
                aliases.append(nick)
            }

            let full = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !full.isEmpty {
                aliases.append(full)

                // Include significant tokens from the full name so prose that uses last names still matches.
                let titleTokens: Set<String> = [
                    "mr", "mrs", "ms", "miss", "dr", "prof", "professor",
                    "chief", "capt", "captain", "officer", "detective", "sgt", "sergeant",
                    "agent", "inspector", "superintendent", "lieutenant", "lt", "colonel", "col",
                    "major", "gen", "general", "sir", "madam"
                ]

                let tokens = full.split(whereSeparator: { $0.isWhitespace }).map {
                    String($0).trimmingCharacters(in: .punctuationCharacters)
                }

                for token in tokens {
                    let key = token.lowercased()
                    guard !token.isEmpty else { continue }
                    guard token.count >= 3 else { continue }
                    guard !titleTokens.contains(key) else { continue }
                    aliases.append(token)
                }
            }
        }

        // De-dupe while preserving order.
        var seen = Set<String>()
        var unique: [String] = []
        for a in aliases {
            let key = a.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            unique.append(a)
        }
        return unique
    }

    private func buildMentionRegexes(for aliases: [String]) -> [NSRegularExpression] {
        let normalized = aliases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }

        let cacheKey = normalized.joined(separator: "|")
        if let cached = mentionRegexCache[cacheKey] {
            return cached
        }

        var regexes: [NSRegularExpression] = []
        regexes.reserveCapacity(normalized.count)
        for alias in normalized {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: alias) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                regexes.append(regex)
            }
        }
        mentionRegexCache[cacheKey] = regexes
        return regexes
    }

    private func containsAny(_ regexes: [NSRegularExpression], in text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regexes.contains(where: { $0.firstMatch(in: text, options: [], range: range) != nil })
    }

    private func countMentions(ofAny aliases: [String], in text: String) -> Int {
        aliases.reduce(0) { partial, alias in
            partial + countMentions(of: alias, in: text)
        }
    }

    // MARK: - Stable layout helpers

    private func fnv1a64(_ string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return hash
    }

    private func stableJitter(for key: String, gridSize: Int) -> (Double, Double) {
        // Deterministic jitter in [-0.1, 0.1] scaled by grid size.
        let h1 = fnv1a64(key.lowercased() + "|x")
        let h2 = fnv1a64(key.lowercased() + "|y")
        let unit1 = Double(h1 % 10_000) / 10_000.0
        let unit2 = Double(h2 % 10_000) / 10_000.0
        let jitterX = (unit1 * 0.2 - 0.1) / Double(max(1, gridSize))
        let jitterY = (unit2 * 0.2 - 0.1) / Double(max(1, gridSize))
        return (jitterX, jitterY)
    }

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
            DebugLog.log("📄 Decision-Belief Loop: Using page mapping with \(mapping.count) entries")
        }

        let chapters: [(text: String, number: Int, startPos: Int)]

        // Use outline entries if available, otherwise fall back to regex detection
        if let entries = outlineEntries, !entries.isEmpty {
            entries.prefix(3).forEach { entry in
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
                let orderedEntries = effectiveEntries.sorted { $0.range.location < $1.range.location }

                for (index, entry) in orderedEntries.enumerated() {
                    // Clamp outline-derived ranges to avoid substring out-of-bounds crashes.
                    let startLocation = min(entry.range.location, fullText.length)
                    let endLocation: Int

                    // Determine end of chapter
                    if index < orderedEntries.count - 1 {
                        // End at next chapter start
                        endLocation = orderedEntries[index + 1].range.location
                    } else {
                        // Last chapter goes to end of document
                        endLocation = fullText.length
                    }

                    let clampedEnd = min(endLocation, fullText.length)
                    let length = max(0, clampedEnd - startLocation)
                    let chapterRange = NSRange(location: startLocation, length: length)
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
            let chapterTexts = splitIntoChapters(text: text)
            var startPos = 0
            chapters = chapterTexts.enumerated().map { index, chapterText in
                let result = (text: chapterText, number: index + 1, startPos: startPos)
                startPos += chapterText.count
                return result
            }
        }

        var loops: [DecisionBeliefLoop] = []

        for characterName in characterNames {
            var loop = DecisionBeliefLoop(characterName: characterName)
            let aliases = characterAliases(for: characterName)
            let aliasRegexes = buildMentionRegexes(for: aliases)

            for chapter in chapters {
                // Only analyze chapters where the character appears (word-boundary match)
                guard containsAny(aliasRegexes, in: chapter.text) else {
                    continue
                }

                // Prefer explicit section-style loops if present (supports multiple loops per chapter).
                let structured = extractStructuredLoopEntries(
                    chapterText: chapter.text,
                    chapterNumber: chapter.number,
                    chapterStartPos: chapter.startPos,
                    fullText: text,
                    character: characterName
                )

                if !structured.isEmpty {
                    loop.entries.append(contentsOf: structured)
                } else {
                    let heuristic = extractHeuristicLoopEntries(
                        chapterText: chapter.text,
                        chapterNumber: chapter.number,
                        chapterStartPos: chapter.startPos,
                        fullText: text,
                        character: characterName,
                        allCharacters: characterNames
                    )
                    loop.entries.append(contentsOf: heuristic)
                }
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

        var fallbackIndex: Int?

        for (index, sentence) in sentences.enumerated() {
            let lower = sentence.lowercased()
            if fallbackIndex == nil {
                fallbackIndex = index
            }
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

        if let index = fallbackIndex {
            let absolutePos = startPos + positions[index]
            let pageNum = calculatePageNumber(position: absolutePos, in: fullText)
            return (cleanExtract(sentences[index]), pageNum, positions[index])
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

    private func isLikelyScreenplay(_ text: String) -> Bool {
        if text.range(of: "(?m)^(INT\\.|EXT\\.)", options: .regularExpression) != nil { return true }
        if text.range(of: "(?m)^(INT\\./EXT\\.|EXT\\./INT\\.)", options: .regularExpression) != nil { return true }
        if text.contains("\nINT.") || text.contains("\nEXT.") { return true }
        return false
    }

    private func cachedUnits(for text: String) -> TextUnitsCacheEntry {
        let key = TextUnitsCacheKey(length: text.count, hash: text.hashValue)
        if let cached = textUnitsCache[key] {
            touchCacheKey(key)
            return cached
        }

        let screenplay = isLikelyScreenplay(text)
        let entry: TextUnitsCacheEntry
        if screenplay {
            let lineUnits = extractLineUnitsWithPositions(from: text)
            entry = TextUnitsCacheEntry(isScreenplay: true, lineUnits: lineUnits, sentenceUnits: [])
        } else {
            let sentenceUnits = extractSentenceUnitsWithPositions(from: text)
            entry = TextUnitsCacheEntry(isScreenplay: false, lineUnits: [], sentenceUnits: sentenceUnits)
        }

        textUnitsCache[key] = entry
        touchCacheKey(key)
        return entry
    }

    private func touchCacheKey(_ key: TextUnitsCacheKey) {
        if let idx = textUnitsCacheOrder.firstIndex(of: key) {
            textUnitsCacheOrder.remove(at: idx)
        }
        textUnitsCacheOrder.append(key)
        if textUnitsCacheOrder.count > textUnitsCacheLimit {
            let evict = textUnitsCacheOrder.removeFirst()
            textUnitsCache.removeValue(forKey: evict)
        }
    }

    private func extractLineUnitsWithPositions(from text: String) -> [(unit: String, pos: Int)] {
        let ns = text as NSString
        var units: [(unit: String, pos: Int)] = []
        units.reserveCapacity(256)

        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byLines]) { substring, range, _, _ in
            guard let substring else { return }
            let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return }
            units.append((trimmed, range.location))
        }
        return units
    }

    private func extractSentenceUnitsWithPositions(from text: String) -> [(unit: String, pos: Int)] {
        // Splits on . ! ? and newlines, while preserving accurate UTF-16 positions.
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let pattern = "[^\\.\\!\\?\\n]+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return extractLineUnitsWithPositions(from: text)
        }
        let matches = regex.matches(in: text, options: [], range: fullRange)
        var units: [(unit: String, pos: Int)] = []
        units.reserveCapacity(matches.count)
        for m in matches {
            let raw = ns.substring(with: m.range)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            units.append((trimmed, m.range.location))
        }
        return units
    }

    private func isSpeakerCueLine(_ line: String, aliases: [String]) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.count > 45 { return false }

        let upper = trimmed.uppercased()
        if upper.hasPrefix("INT.") || upper.hasPrefix("EXT.") || upper.hasPrefix("INT./EXT.") || upper.hasPrefix("EXT./INT.") { return false }
        if upper == "FADE IN" || upper == "FADE OUT" { return false }
        if trimmed != upper { return false }

        let aliasUppers = aliases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }

        for aliasUpper in aliasUppers {
            if upper == aliasUpper { return true }
            if upper.hasPrefix(aliasUpper + "(") { return true }
            if upper.hasPrefix(aliasUpper + " (") { return true }
            if upper.hasPrefix(aliasUpper + ":") { return true }
        }
        return false
    }

    private func getSentencesAbout(character: String, in text: String, allCharacters: [String], proximity: Int) -> ([String], [Int]) {
        let targetAliases = characterAliases(for: character)
        let targetRegexes = buildMentionRegexes(for: targetAliases)

        let otherCharacters = allCharacters.filter { $0.caseInsensitiveCompare(character) != .orderedSame }
        let otherRegexes: [NSRegularExpression] = otherCharacters
            .flatMap { buildMentionRegexes(for: characterAliases(for: $0)) }

        let cached = cachedUnits(for: text)

        if cached.isScreenplay {
            // Attribute dialogue lines to the current character when a speaker cue is detected.
            // This prevents intermingling characters' loops while still letting the character reference others.
            let lineUnits = cached.lineUnits
            var relevant: [(String, Int)] = []
            relevant.reserveCapacity(64)

            var inTargetDialogue = false
            for (unit, pos) in lineUnits {
                if isSpeakerCueLine(unit, aliases: targetAliases) {
                    inTargetDialogue = true
                    continue
                }

                if inTargetDialogue {
                    let isOtherSpeaker = otherCharacters.contains(where: { isSpeakerCueLine(unit, aliases: characterAliases(for: $0)) })
                    if isOtherSpeaker {
                        inTargetDialogue = false
                    } else {
                        relevant.append((unit, pos))
                        continue
                    }
                }

                // Narrative/action lines: only include lines that mention the target but not other characters.
                let hasTarget = containsAny(targetRegexes, in: unit)
                let hasOther = containsAny(otherRegexes, in: unit)
                if hasTarget && !hasOther {
                    relevant.append((unit, pos))
                }
            }

            var seenPos = Set<Int>()
            var sentences: [String] = []
            var positions: [Int] = []
            for (s, p) in relevant.sorted(by: { $0.1 < $1.1 }) {
                if seenPos.contains(p) { continue }
                seenPos.insert(p)
                sentences.append(s)
                positions.append(p)
            }

            // Fallback: if we found nothing with the strict filter, allow lines that mention the target
            // even if other characters are present. This restores behavior for dense dialogue scenes.
            if sentences.isEmpty {
                let fallback = lineUnits.filter { containsAny(targetRegexes, in: $0.unit) }
                for (unit, pos) in fallback {
                    if seenPos.contains(pos) { continue }
                    seenPos.insert(pos)
                    sentences.append(unit)
                    positions.append(pos)
                }
            }
            return (sentences, positions)
        }

        // Non-screenplay: sentence-like units with accurate positions.
        let units = cached.sentenceUnits
        var relevantSentences: [String] = []
        var positions: [Int] = []
        relevantSentences.reserveCapacity(64)
        positions.reserveCapacity(64)

        for (unit, pos) in units {
            let hasTarget = containsAny(targetRegexes, in: unit)
            let hasOther = containsAny(otherRegexes, in: unit)
            if hasTarget && !hasOther {
                relevantSentences.append(unit)
                positions.append(pos)
            }
        }

        // Fallback: if no sentences survived the strict filter, include any sentence that mentions
        // the target. This prevents empty loops in multi-character prose.
        if relevantSentences.isEmpty {
            for (unit, pos) in units {
                if containsAny(targetRegexes, in: unit) {
                    relevantSentences.append(unit)
                    positions.append(pos)
                }
            }
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
        DebugLog.log("📊 analyzePresenceByChapter: Starting with \(characterNames.count) characters")
        DebugLog.log("📊 analyzePresenceByChapter: Character names = \(characterNames)")
        DebugLog.log("📊 analyzePresenceByChapter: Text length = \(text.count) characters")
        DebugLog.log("📊 analyzePresenceByChapter: Outline entries count = \(outlineEntries?.count ?? 0)")

        var presenceData: [CharacterPresence] = []

        // Get chapters/scenes using outline or fall back to regex
        let chapters: [(text: String, number: Int, startLocation: Int)]
        var chapterToAct: [Int: Int] = [:]
        if let entries = outlineEntries {
            // If caller provided outline entries, treat them as source of truth when available;
            // otherwise, fall back to regex detection so we never return empty data silently.
            if entries.isEmpty {
                DebugLog.log("⚠️ analyzePresenceByChapter: Outline entries empty, falling back to regex detection")
                let chapterTexts = splitIntoChapters(text: text)
                chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1, startLocation: 0) }
                DebugLog.log("📊 analyzePresenceByChapter: Regex detected \(chapters.count) chapters")
            } else {
                // Prefer outline entries that actually represent chapters/scenes.
                // `buildOutlineEntries()` can include level-1 headings for TOC/Index/etc; those should not drive chapter splits.
                let orderedAll = entries.sorted { $0.range.location < $1.range.location }

                func isNonStoryHeading(_ title: String) -> Bool {
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if t.isEmpty { return true }
                    let exact = [
                        "TABLE OF CONTENTS",
                        "CONTENTS",
                        "INDEX",
                        "GLOSSARY",
                        "APPENDIX",
                        "BIBLIOGRAPHY",
                        "ACKNOWLEDGMENTS",
                        "ACKNOWLEDGEMENTS"
                    ]
                    if exact.contains(t) { return true }
                    if t.hasPrefix("TABLE OF CONTENTS") { return true }
                    if t.hasPrefix("CONTENTS") { return true }
                    if t.hasPrefix("INDEX") { return true }
                    if t.hasPrefix("GLOSSARY") { return true }
                    return false
                }

                let level1Entries = orderedAll.filter { $0.level == 1 && !isNonStoryHeading($0.title) }
                let level0Entries = orderedAll.filter { $0.level == 0 }

                func looksLikeScreenplaySlugline(_ title: String) -> Bool {
                    let upper = title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    guard !upper.isEmpty else { return false }
                    let prefixes = ["INT.", "EXT.", "INT/EXT.", "EXT/INT.", "I/E.", "EST."]
                    return prefixes.contains(where: { upper.hasPrefix($0) })
                }

                func looksLikeChapterHeading(_ title: String) -> Bool {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return false }
                    let upper = trimmed.uppercased()

                    // Common prose markers.
                    if upper.hasPrefix("CHAPTER") { return true }
                    if upper == "PROLOGUE" || upper == "EPILOGUE" { return true }
                    if upper.hasPrefix("PART ") { return true }

                    // Numeric-only headings ("1" / "1."), and simple roman numerals.
                    if trimmed.range(of: "^\\d+\\.?$", options: .regularExpression) != nil { return true }
                    if trimmed.range(of: "^(?i)(I|II|III|IV|V|VI|VII|VIII|IX|X)\\.?$", options: .regularExpression) != nil { return true }
                    return false
                }

                let sluglineEntries = level1Entries.filter { looksLikeScreenplaySlugline($0.title) }
                let chapterLikeEntries = level1Entries.filter { looksLikeChapterHeading($0.title) }

                var effectiveEntries: [OutlineEntry] = []
                if sluglineEntries.count >= 2, sluglineEntries.count >= Int(Double(level1Entries.count) * 0.5) {
                    // Screenplay: drive presence by sluglines.
                    effectiveEntries = sluglineEntries
                } else if chapterLikeEntries.count >= 2 {
                    // Prose: drive presence by chapter-like headings.
                    effectiveEntries = chapterLikeEntries
                } else if !level1Entries.isEmpty {
                    // Fallback: keep prior behavior when we can't confidently detect chapter-like entries.
                    effectiveEntries = level1Entries
                } else if !level0Entries.isEmpty {
                    effectiveEntries = level0Entries
                }

                if effectiveEntries.isEmpty {
                    DebugLog.log("⚠️ analyzePresenceByChapter: No usable outline entries, falling back to regex detection")
                    let chapterTexts = splitIntoChapters(text: text)
                    chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1, startLocation: 0) }
                    DebugLog.log("📊 analyzePresenceByChapter: Regex detected \(chapters.count) chapters")
                } else {
                    let fullText = text as NSString
                    let orderedEntries = effectiveEntries.sorted { $0.range.location < $1.range.location }

                    func parseExplicitNumber(from title: String) -> Int? {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return nil }

                        // "Chapter 12" -> 12
                        if let regex = try? NSRegularExpression(pattern: "(?i)^chapter\\s+(\\d+)") {
                            let range = NSRange(trimmed.startIndex..., in: trimmed)
                            if let match = regex.firstMatch(in: trimmed, options: [], range: range), match.numberOfRanges >= 2 {
                                let capRange = match.range(at: 1)
                                if let r = Range(capRange, in: trimmed) {
                                    return Int(trimmed[r])
                                }
                            }
                        }

                        // "12" / "12." -> 12
                        if trimmed.range(of: "^\\d+\\.?$", options: .regularExpression) != nil {
                            let digits = trimmed.filter { $0.isNumber }
                            return Int(digits)
                        }

                        return nil
                    }

                    var nextFallbackNumber = 1
                    var usedNumbers = Set<Int>()

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

                        // Prefer explicit numbering when present in titles (e.g. "Chapter 3"), but fall back to sequential.
                        let explicit = parseExplicitNumber(from: entry.title)
                        let number: Int
                        if let explicit, !usedNumbers.contains(explicit) {
                            number = explicit
                            usedNumbers.insert(explicit)
                        } else {
                            while usedNumbers.contains(nextFallbackNumber) { nextFallbackNumber += 1 }
                            number = nextFallbackNumber
                            usedNumbers.insert(number)
                            nextFallbackNumber += 1
                        }

                        return (text: fullText.substring(with: chapterRange), number: number, startLocation: startLocation)
                    }

                    // If the outline contains ACT headings (level 0) and chapters/scenes are level 1,
                    // build a chapter/scene -> act mapping for accurate aggregation.
                    let actEntries = entries.filter { $0.level == 0 }.sorted { $0.range.location < $1.range.location }
                    let sceneEntries = effectiveEntries

                    func parseActNumber(from title: String) -> Int? {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        guard t.hasPrefix("ACT") else { return nil }
                        let cleaned = t.replacingOccurrences(of: ".", with: " ")
                            .replacingOccurrences(of: ":", with: " ")
                            .replacingOccurrences(of: "-", with: " ")
                        let parts = cleaned.split(whereSeparator: { $0.isWhitespace })
                        guard parts.count >= 2 else { return nil }
                        let token = String(parts[1])
                        switch token {
                        case "I", "1": return 1
                        case "II", "2": return 2
                        case "III", "3": return 3
                        case "IV", "4": return 4
                        case "V", "5": return 5
                        default:
                            if let n = Int(token) { return n }
                            return nil
                        }
                    }

                    if !actEntries.isEmpty, sceneEntries.count >= 2 {
                        // Build an ordered list of act markers with usable act numbers.
                        let numberedActs: [(start: Int, act: Int)] = actEntries.compactMap { entry in
                            guard let act = parseActNumber(from: entry.title) else { return nil }
                            return (start: entry.range.location, act: act)
                        }.sorted { $0.start < $1.start }

                        if !numberedActs.isEmpty {
                            // Map by chronological order of the effective entries, not by any explicit title numbering.
                            let orderedScenes = sceneEntries.sorted { $0.range.location < $1.range.location }
                            for (index, scene) in orderedScenes.enumerated() {
                                let sceneStart = scene.range.location
                                // Find the last act marker at or before this scene.
                                var act = numberedActs.first?.act ?? 1
                                for marker in numberedActs {
                                    if marker.start <= sceneStart {
                                        act = marker.act
                                    } else {
                                        break
                                    }
                                }
                                // Use sequential scene indexes for the act map to match how we label in the chart.
                                chapterToAct[index + 1] = act
                            }
                        }
                    }
                }
            }
        } else {
            // No outline provided; fall back to regex detection
            DebugLog.log("📊 analyzePresenceByChapter: No outline entries, using regex detection")
            let chapterTexts = splitIntoChapters(text: text)
            chapters = chapterTexts.enumerated().map { (text: $1, number: $0 + 1, startLocation: 0) }
            DebugLog.log("📊 analyzePresenceByChapter: Regex detected \(chapters.count) chapters")
        }

        DebugLog.log("📊 analyzePresenceByChapter: Total chapters detected = \(chapters.count)")

        let library = CharacterLibrary.shared

        func presenceAliases(for canonicalName: String) -> [String] {
            let canonical = canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !canonical.isEmpty else { return [] }

            var aliases: [String] = [canonical]

            if let profile = library.analysisEligibleCharacters.first(where: {
                ($0.analysisKey ?? "").caseInsensitiveCompare(canonical) == .orderedSame
            }) {
                let nick = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                if !nick.isEmpty, nick.caseInsensitiveCompare(canonical) != .orderedSame {
                    aliases.append(nick)
                }
            }

            // De-dupe while preserving order.
            var seen = Set<String>()
            var unique: [String] = []
            for a in aliases {
                let key = a.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                unique.append(a)
            }
            return unique
        }

        for characterName in characterNames {
            var presence = CharacterPresence(characterName: characterName)
            if !chapterToAct.isEmpty {
                presence.chapterToAct = chapterToAct
            }
            DebugLog.log("📊 analyzePresenceByChapter: Analyzing presence for character '\(characterName)'")

            let aliases = presenceAliases(for: characterName)
            if aliases.count > 1 {
                DebugLog.log("📊 analyzePresenceByChapter: Using aliases for '\(characterName)': \(aliases)")
            }

            var mentionsByChapter: [Int: Int] = [:]
            var totalMentions = 0
            for chapter in chapters {
                let mentions = aliases.reduce(0) { partial, alias in
                    partial + countMentions(of: alias, in: chapter.text)
                }
                mentionsByChapter[chapter.number] = mentions
                totalMentions += mentions
            }

            // Only include characters that appear at least once, but include 0s for chapters/scenes
            // so the x-axis can show all chapters/scenes even when a character is absent in a section.
            if totalMentions > 0 {
                for chapter in chapters {
                    let mentions = mentionsByChapter[chapter.number] ?? 0
                    presence.chapterPresence[chapter.number] = mentions
                    if mentions > 0 {
                        DebugLog.log("📊 analyzePresenceByChapter: Character '\(characterName)' has \(mentions) mentions in chapter \(chapter.number)")
                    }
                }
            }

            if presence.chapterPresence.isEmpty {
                DebugLog.log("⚠️ analyzePresenceByChapter: Character '\(characterName)' has NO mentions in any chapter")
            } else {
                DebugLog.log("✅ analyzePresenceByChapter: Character '\(characterName)' found in \(presence.chapterPresence.count) chapters")
            }
            presenceData.append(presence)
        }

        DebugLog.log("📊 analyzePresenceByChapter: Returning \(presenceData.count) presence entries")
        return presenceData
    }

    /// Analyze character interactions for relationship strength
    func analyzeInteractions(text: String, characterNames: [String]) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Prefer structural segmentation when possible (chapters), otherwise fall back to word-window sections.
        // Using only exact Character Library keys is too brittle; alias-aware detection is required.
        var sections: [String] = splitIntoChapters(text: text)
        if sections.count <= 1 {
            // Finer granularity for documents without explicit chapter markers.
            sections = splitIntoSections(text: text, wordsPerSection: 800)
        }

        // Check each pair of characters
        for i in 0..<characterNames.count {
            for j in (i+1)..<characterNames.count {
                let char1 = characterNames[i]
                let char2 = characterNames[j]

                let aliases1 = characterAliases(for: char1)
                let aliases2 = characterAliases(for: char2)
                let regexes1 = buildMentionRegexes(for: aliases1)
                let regexes2 = buildMentionRegexes(for: aliases2)

                var interaction = CharacterInteraction(
                    character1: char1,
                    character2: char2
                )

                // Check each section for co-appearances
                for (sectionIndex, section) in sections.enumerated() {
                    let hasChar1 = containsAny(regexes1, in: section)
                    let hasChar2 = containsAny(regexes2, in: section)

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

        var chapters = splitIntoChapters(text: text)
        if chapters.count <= 1 {
            // If no chapters are detected, we still want evolution over time.
            chapters = splitIntoSections(text: text, wordsPerSection: 1500)
        }
        var evolutionData = RelationshipEvolutionData()

        // Generate nodes with positions and emotional investment
        let gridSize = Int(ceil(sqrt(Double(characterNames.count))))
        for (index, character) in characterNames.enumerated() {
            let row = index / gridSize
            let col = index % gridSize

            // Position in grid (with some randomization for visual interest)
            let baseX = (Double(col) + 0.5) / Double(gridSize)
            let baseY = (Double(row) + 0.5) / Double(gridSize)

            // Add slight *deterministic* jitter so maps are stable across runs/machines.
            let (randomX, randomY) = stableJitter(for: character, gridSize: gridSize)

            let posX = max(0.1, min(0.9, baseX + randomX))
            let posY = max(0.1, min(0.9, baseY + randomY))

            // Calculate emotional investment based on presence in text (alias-aware)
            let totalMentions = countMentions(ofAny: characterAliases(for: character), in: text)
            let maxMentions = characterNames
                .map { countMentions(ofAny: characterAliases(for: $0), in: text) }
                .max() ?? 1
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

                // Alias-aware mention detection
                let regexes1 = buildMentionRegexes(for: characterAliases(for: char1))
                let regexes2 = buildMentionRegexes(for: characterAliases(for: char2))
                if regexes1.isEmpty || regexes2.isEmpty { continue }

                // Analyze relationship evolution across chapters
                var evolutionPoints: [RelationshipEvolutionPoint] = []
                var overallTrust: Double = 0.0

                for (chapterIndex, chapter) in chapters.enumerated() {
                    let chapterNum = chapterIndex + 1
                    let sentences = chapter.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.isEmpty }

                    var sentenceScores: [Double] = []
                    sentenceScores.reserveCapacity(4)

                    // Analyze sentences mentioning both characters
                    for sentence in sentences {
                        let hasChar1 = containsAny(regexes1, in: sentence)
                        let hasChar2 = containsAny(regexes2, in: sentence)
                        if !(hasChar1 && hasChar2) { continue }

                        let tokens = sentence
                            .lowercased()
                            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
                            .map(String.init)
                        if tokens.isEmpty { continue }

                        // Heuristic signal words (writer-facing, not a definitive NLP model)
                        let positive: Set<String> = [
                            "help", "helps", "helped", "support", "supports", "supported", "protect", "protects", "protected",
                            "save", "saves", "saved", "thank", "thanks", "thanked", "forgive", "forgives", "forgave",
                            "together", "friend", "friends", "ally", "allies", "trust", "trusted", "care", "cared", "love", "loved"
                        ]
                        let negative: Set<String> = [
                            "fight", "fights", "fought", "argue", "argues", "argued", "hate", "hated", "enemy", "enemies",
                            "against", "betray", "betrayed", "distrust", "distrusted", "conflict", "oppose", "opposed",
                            "threaten", "threatened", "attack", "attacked", "accuse", "accused", "blame", "blamed",
                            "lie", "lied", "deceive", "deceived"
                        ]
                        let negators: Set<String> = ["not", "never", "no", "without"]

                        var posHits = 0
                        var negHits = 0
                        for (idx, tok) in tokens.enumerated() {
                            if positive.contains(tok) {
                                // crude negation handling: "not trust" counts negative
                                let windowStart = max(0, idx - 2)
                                let hasNegation = tokens[windowStart..<idx].contains(where: { negators.contains($0) })
                                if hasNegation { negHits += 1 } else { posHits += 1 }
                            } else if negative.contains(tok) {
                                negHits += 1
                            }
                        }

                        // Convert to a bounded per-sentence trust signal in [-1, 1]
                        let raw = Double(posHits - negHits)
                        let sentenceScore = max(-1.0, min(1.0, raw / 3.0))
                        sentenceScores.append(sentenceScore)
                    }

                    if !sentenceScores.isEmpty {
                        let avg = sentenceScores.reduce(0, +) / Double(sentenceScores.count)
                        let normalizedTrust = max(-1.0, min(1.0, avg))
                        overallTrust += normalizedTrust

                        let description: String
                        if normalizedTrust >= 0.25 {
                            description = "Trust-building cues (keyword-based)"
                        } else if normalizedTrust <= -0.25 {
                            description = "Conflict cues (keyword-based)"
                        } else {
                            description = "Mixed/neutral cues (keyword-based)"
                        }

                        evolutionPoints.append(RelationshipEvolutionPoint(chapter: chapterNum, trustLevel: normalizedTrust, description: description))
                    }
                }

                // Only add edge if characters interact
                if !evolutionPoints.isEmpty {
                    let avgTrust = overallTrust / Double(evolutionPoints.count)

                    // Determine power direction (simplified heuristic)
                    let char1Mentions = countMentions(ofAny: characterAliases(for: char1), in: text)
                    let char2Mentions = countMentions(ofAny: characterAliases(for: char2), in: text)

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
