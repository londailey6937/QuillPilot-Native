//
//  PlotAnalysis.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation

// MARK: - Document Format

enum DocumentFormat: String {
    case novel = "Novel"
    case screenplay = "Screenplay"

    var description: String {
        switch self {
        case .novel:
            return "Novel structure prioritizes meaning over motion, with elastic units and interior change."
        case .screenplay:
            return "Screenplay structure prioritizes motion that creates meaning, with fixed units and visual causality."
        }
    }
}

// MARK: - Plot Point Types

/// Novel-specific plot point types (architectural structure)
enum NovelPlotPointType: String, CaseIterable {
    case openingState = "Opening State"
    case incitingDisruption = "Inciting Disruption"
    case firstCommitment = "First Commitment"
    case progressiveComplications = "Progressive Complications"
    case midpointReversal = "Midpoint Reversal"
    case escalatingCosts = "Escalating Costs"
    case crisis = "Crisis / Lowest Point"
    case finalChoice = "Final Choice"
    case climax = "Climax"
    case aftermath = "Aftermath"

    var emoji: String {
        switch self {
        case .openingState: return "🌅"
        case .incitingDisruption: return "💥"
        case .firstCommitment: return "🚪"
        case .progressiveComplications: return "🌊"
        case .midpointReversal: return "🔄"
        case .escalatingCosts: return "⚡️"
        case .crisis: return "🕳️"
        case .finalChoice: return "⚖️"
        case .climax: return "🔥"
        case .aftermath: return "✨"
        }
    }

    var expectedPosition: Double {
        switch self {
        case .openingState: return 0.02
        case .incitingDisruption: return 0.12
        case .firstCommitment: return 0.25
        case .progressiveComplications: return 0.35
        case .midpointReversal: return 0.50
        case .escalatingCosts: return 0.62
        case .crisis: return 0.75
        case .finalChoice: return 0.85
        case .climax: return 0.92
        case .aftermath: return 0.98
        }
    }

    var analysisQuestion: String {
        switch self {
        case .openingState:
            return "What worldview and tonal contract does this establish?"
        case .incitingDisruption:
            return "Does this force a choice, not just reveal information?"
        case .firstCommitment:
            return "Is this a clear turn where the protagonist acts?"
        case .progressiveComplications:
            return "What changes internally in this span?"
        case .midpointReversal:
            return "Does this change what success looks like?"
        case .escalatingCosts:
            return "Does every gain create a new, worse problem?"
        case .crisis:
            return "Is this unfixable by the old belief?"
        case .finalChoice:
            return "Is there internal reconciliation with belief?"
        case .climax:
            return "Does meaning crystallize here?"
        case .aftermath:
            return "Does this echo and transform the opening state?"
        }
    }

    var failureDescription: String {
        switch self {
        case .openingState:
            return "Weak or unclear tonal contract with the reader"
        case .incitingDisruption:
            return "Late plot ignition or passive discovery"
        case .firstCommitment:
            return "Hesitation without commitment"
        case .progressiveComplications:
            return "Excessive inertia or over-indulgent introspection"
        case .midpointReversal:
            return "Thematic diffusion - no redefinition of success"
        case .escalatingCosts:
            return "Moral complexity doesn't increase"
        case .crisis:
            return "Crisis could be solved by old belief"
        case .finalChoice:
            return "No internal reconciliation"
        case .climax:
            return "Meaning doesn't crystallize"
        case .aftermath:
            return "No resonance with opening"
        }
    }
}

/// Screenplay-specific plot point types (mechanical structure)
enum ScreenplayPlotPointType: String, CaseIterable {
    case openingImage = "Opening Image"
    case incitingIncident = "Inciting Incident"
    case lockIn = "Lock In (End Act I)"
    case firstSequence = "First Sequence"
    case risingComplications = "Rising Complications"
    case midpointReversal = "Midpoint Reversal"
    case badGuysClose = "Bad Guys Close In"
    case allIsLost = "All Is Lost"
    case darkNight = "Dark Night of Soul"
    case thirdActBreak = "Third Act Break"
    case finale = "Finale"
    case closingImage = "Closing Image"

    var emoji: String {
        switch self {
        case .openingImage: return "🎬"
        case .incitingIncident: return "💥"
        case .lockIn: return "🔒"
        case .firstSequence: return "📈"
        case .risingComplications: return "🌊"
        case .midpointReversal: return "🔄"
        case .badGuysClose: return "👥"
        case .allIsLost: return "💀"
        case .darkNight: return "🌑"
        case .thirdActBreak: return "⚡️"
        case .finale: return "🔥"
        case .closingImage: return "🎞️"
        }
    }

    var expectedPosition: Double {
        switch self {
        case .openingImage: return 0.01
        case .incitingIncident: return 0.10
        case .lockIn: return 0.25
        case .firstSequence: return 0.30
        case .risingComplications: return 0.40
        case .midpointReversal: return 0.50
        case .badGuysClose: return 0.60
        case .allIsLost: return 0.75
        case .darkNight: return 0.80
        case .thirdActBreak: return 0.85
        case .finale: return 0.95
        case .closingImage: return 0.99
        }
    }

    /// Page number in a 120-page screenplay
    var expectedPage: Int {
        return Int(expectedPosition * 120)
    }

    var analysisQuestion: String {
        switch self {
        case .openingImage:
            return "Is there a visible contradiction or unease?"
        case .incitingIncident:
            return "Is this external, observable, and does it change the situation?"
        case .lockIn:
            return "Does the protagonist clearly act, not just decide?"
        case .firstSequence:
            return "Does each scene advance plot, escalate stakes, and end with a turn?"
        case .risingComplications:
            return "Does each scene have a visible objective and turn?"
        case .midpointReversal:
            return "Is this a visible reversal (victory→defeat, safety→danger)?"
        case .badGuysClose:
            return "Are options visibly narrowing?"
        case .allIsLost:
            return "Is the protagonist situationally trapped or stripped of power?"
        case .darkNight:
            return "Is there a moment of reflection before action?"
        case .thirdActBreak:
            return "Is there a decisive action under pressure?"
        case .finale:
            return "Is there clear physical or strategic resolution?"
        case .closingImage:
            return "Does this mirror the opening with changed behavior?"
        }
    }

    var failureDescription: String {
        switch self {
        case .openingImage:
            return "No visual hook or contradiction"
        case .incitingIncident:
            return "Internal/invisible inciting incident"
        case .lockIn:
            return "Passive protagonist - no clear action"
        case .firstSequence:
            return "Scenes without visible turns"
        case .risingComplications:
            return "Repetitive scenes without escalation"
        case .midpointReversal:
            return "Midpoint sag - no power shift"
        case .badGuysClose:
            return "Stakes remain static"
        case .allIsLost:
            return "Protagonist not truly trapped"
        case .darkNight:
            return "Missing emotional beat"
        case .thirdActBreak:
            return "Third-act solution not earned visually"
        case .finale:
            return "Invisible stakes in resolution"
        case .closingImage:
            return "No visual bookend"
        }
    }
}

// MARK: - Universal Plot Point Wrapper

struct PlotPoint {
    let type: String              // Raw type name
    let emoji: String
    let wordPosition: Int
    let percentagePosition: Double
    let tensionLevel: Double
    let description: String
    let analysisQuestion: String
    let suggestedImprovement: String?
    let isScreenplayPoint: Bool

    // Novel-specific initializer
    init(novelType: NovelPlotPointType, wordPosition: Int, percentagePosition: Double, tensionLevel: Double, description: String, suggestedImprovement: String?) {
        self.type = novelType.rawValue
        self.emoji = novelType.emoji
        self.wordPosition = wordPosition
        self.percentagePosition = percentagePosition
        self.tensionLevel = tensionLevel
        self.description = description
        self.analysisQuestion = novelType.analysisQuestion
        self.suggestedImprovement = suggestedImprovement
        self.isScreenplayPoint = false
    }

    // Screenplay-specific initializer
    init(screenplayType: ScreenplayPlotPointType, wordPosition: Int, percentagePosition: Double, tensionLevel: Double, description: String, suggestedImprovement: String?) {
        self.type = screenplayType.rawValue
        self.emoji = screenplayType.emoji
        self.wordPosition = wordPosition
        self.percentagePosition = percentagePosition
        self.tensionLevel = tensionLevel
        self.description = description
        self.analysisQuestion = screenplayType.analysisQuestion
        self.suggestedImprovement = suggestedImprovement
        self.isScreenplayPoint = true
    }
}

struct TensionPoint {
    let position: Double      // 0.0-1.0 in story
    let tensionLevel: Double  // 0.0-1.0
    let wordPosition: Int
}

// MARK: - Plot Analysis Result

struct PlotAnalysis {
    var documentFormat: DocumentFormat = .novel
    var plotPoints: [PlotPoint] = []
    var overallTensionCurve: [TensionPoint] = []
    var structureScore: Int = 0  // 0-100
    var missingPoints: [String] = []  // Raw type names
    var structuralIssues: [StructuralIssue] = []
    var formatConfidence: Double = 0.5  // 0-1, how confident we are about the format

    // Novel-specific metrics
    var internalChangeScore: Int = 0     // How well internal change is tracked
    var thematicResonance: Int = 0       // How well themes echo through structure
    var narrativeMomentum: Int = 0       // Reader engagement across long spans

    // Screenplay-specific metrics
    var visualCausalityScore: Int = 0    // How well cause-effect chains are visible
    var sceneEfficiency: Int = 0         // Would cutting scenes break causality?
    var pacingScore: Int = 0             // Minute-by-minute tension management
    var estimatedRuntime: Int = 0        // Estimated minutes based on page count
}

struct StructuralIssue {
    let severity: IssueSeverity
    let category: IssueCategory
    let description: String
    let suggestion: String
    let affectedRange: (start: Double, end: Double)  // Position in story

    enum IssueSeverity: String {
        case minor = "Minor"
        case moderate = "Moderate"
        case major = "Major"
    }

    enum IssueCategory: String {
        // Novel-specific
        case excessiveInertia = "Excessive Inertia"
        case overIndulgentIntrospection = "Over-Indulgent Introspection"
        case thematicDiffusion = "Thematic Diffusion"
        case latePlotIgnition = "Late Plot Ignition"
        case cognitiveOverload = "Cognitive Overload"

        // Screenplay-specific
        case repetitiveScenes = "Repetitive Scenes"
        case passiveProtagonist = "Passive Protagonist"
        case midpointSag = "Midpoint Sag"
        case invisibleStakes = "Invisible Stakes"
        case unearnedResolution = "Unearned Resolution"
        case paceProblems = "Pacing Problems"
    }
}

// MARK: - Format Detector

class DocumentFormatDetector {

    // Screenplay formatting indicators
    private static let screenplayPatterns: [(pattern: String, weight: Double)] = [
        // Scene headings (sluglines)
        ("(?m)^(INT\\.|EXT\\.|INT/EXT\\.|I/E\\.)", 3.0),
        ("(?m)^(INTERIOR|EXTERIOR)", 2.5),
        ("(?m)^[A-Z][A-Z\\s]+\\s*-\\s*(DAY|NIGHT|CONTINUOUS|LATER|MORNING|EVENING|DAWN|DUSK)", 3.0),

        // Character cues (centered uppercase names before dialogue)
        ("(?m)^\\s{20,}[A-Z][A-Z\\s]+\\s*$", 2.0),
        ("(?m)^[A-Z]{2,}\\s*\\(V\\.O\\.\\)|\\(O\\.S\\.\\)|\\(CONT'D\\)", 3.0),

        // Parentheticals
        ("(?m)^\\s*\\([a-z][^)]+\\)\\s*$", 2.0),

        // Transitions
        ("(?m)^(FADE IN:|FADE OUT\\.|FADE TO:|CUT TO:|DISSOLVE TO:|SMASH CUT:|MATCH CUT:)", 3.0),

        // Action lines (short paragraphs typical of screenplays)
        ("(?m)^[A-Z][^.!?]{10,80}[.!?]\\s*$", 0.5),

        // Courier font spacing patterns (lots of whitespace)
        ("\\n{2,}", 0.3)
    ]

    // Novel formatting indicators
    private static let novelPatterns: [(pattern: String, weight: Double)] = [
        // Chapter headings
        ("(?i)chapter\\s+\\d+|chapter\\s+[a-z]+", 2.5),
        ("(?i)^part\\s+(one|two|three|four|five|\\d+)", 2.0),

        // Long paragraphs (typical of prose)
        ("(?m)^[A-Z][^\\n]{200,}", 2.0),

        // Internal thought patterns
        ("(?i)\\b(thought|wondered|realized|felt|believed|remembered|imagined)\\b", 1.5),
        ("(?i)\\b(she thought|he thought|I thought)\\b", 2.0),

        // Dialogue tags with description
        ("(?i)\\b(said|asked|replied|whispered|shouted|murmured)\\b\\s*,", 1.5),

        // Prose indicators
        ("(?i)\\b(the\\s+\\w+\\s+was|it\\s+was\\s+a)\\b", 0.5),

        // Narrative description
        ("(?i)\\b(his|her)\\s+(eyes|face|voice|heart|hands)\\s+(were|was|seemed)", 1.5),

        // Time transitions typical of novels
        ("(?i)\\b(the next morning|hours later|days passed|years ago|that night)\\b", 1.5)
    ]

    func detectFormat(text: String) -> (format: DocumentFormat, confidence: Double) {
        guard text.count > 500 else {
            return (.novel, 0.5)  // Default to novel for short texts
        }

        var screenplayScore: Double = 0
        var novelScore: Double = 0

        // Check screenplay patterns
        for (pattern, weight) in DocumentFormatDetector.screenplayPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.numberOfMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                screenplayScore += Double(matches) * weight
            }
        }

        // Check novel patterns
        for (pattern, weight) in DocumentFormatDetector.novelPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.numberOfMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                novelScore += Double(matches) * weight
            }
        }

        // Additional heuristics

        // Average paragraph length (screenplays have shorter paragraphs)
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !paragraphs.isEmpty {
            let avgLength = paragraphs.reduce(0) { $0 + $1.count } / paragraphs.count
            if avgLength < 150 {
                screenplayScore += 3.0
            } else if avgLength > 300 {
                novelScore += 3.0
            }
        }

        // Line length variance (screenplays have more consistent short lines)
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        if !lines.isEmpty {
            let lengths = lines.map { $0.count }
            let avgLineLength = lengths.reduce(0, +) / lengths.count
            if avgLineLength < 60 {
                screenplayScore += 2.0
            } else if avgLineLength > 80 {
                novelScore += 2.0
            }
        }

        // Word count per page estimate
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let pageCount = paragraphs.count > 0 ? max(1, text.count / 3000) : 1  // Rough page estimate
        let wordsPerPage = wordCount / pageCount

        // Screenplays typically have 150-200 words per page, novels 250-300
        if wordsPerPage < 220 {
            screenplayScore += 2.0
        } else if wordsPerPage > 240 {
            novelScore += 2.0
        }

        // Normalize and calculate confidence
        let total = screenplayScore + novelScore
        guard total > 0 else {
            return (.novel, 0.5)
        }

        let screenplayProbability = screenplayScore / total

        if screenplayProbability > 0.6 {
            return (.screenplay, min(1.0, screenplayProbability))
        } else if screenplayProbability < 0.4 {
            return (.novel, min(1.0, 1.0 - screenplayProbability))
        } else {
            // Ambiguous - default to novel
            return (.novel, 0.5)
        }
    }
}

// MARK: - Plot Point Detector

class PlotPointDetector {

    // Shared tension indicators
    private static let tensionWords: Set<String> = [
        "danger", "threat", "fear", "scared", "terrified", "panic",
        "urgent", "desperate", "crisis", "disaster", "catastrophe",
        "attack", "fight", "battle", "conflict", "struggle",
        "death", "dying", "killed", "murder", "blood",
        "trapped", "cornered", "helpless", "doomed",
        "explode", "explosion", "crash", "collide",
        "scream", "yell", "shout", "cry",
        "chase", "pursue", "flee", "escape", "run"
    ]

    private static let actionVerbs: Set<String> = [
        "grabbed", "lunged", "attacked", "struck", "hit",
        "ran", "raced", "sprinted", "dashed", "rushed",
        "jumped", "leaped", "dove", "ducked",
        "threw", "hurled", "smashed", "crashed",
        "fired", "shot", "aimed", "pulled"
    ]

    private static let revelationWords: Set<String> = [
        "realized", "discovered", "understood", "revealed",
        "truth", "secret", "hidden", "concealed",
        "betrayal", "lie", "deception", "trick"
    ]

    // Novel-specific: Internal change indicators
    private static let internalChangeWords: Set<String> = [
        "believed", "understood", "realized", "accepted", "rejected",
        "forgave", "regretted", "doubted", "trusted", "feared",
        "hoped", "despaired", "resolved", "questioned", "embraced",
        "abandoned", "confronted", "acknowledged", "denied"
    ]

    // Novel-specific: Thematic resonance words
    private static let thematicWords: Set<String> = [
        "meaning", "purpose", "truth", "justice", "love", "loss",
        "identity", "freedom", "power", "sacrifice", "redemption",
        "betrayal", "loyalty", "honor", "duty", "choice"
    ]

    // Screenplay-specific: Visual action words
    private static let visualActionWords: Set<String> = [
        "sees", "watches", "looks", "stares", "glances",
        "enters", "exits", "walks", "runs", "stands",
        "grabs", "throws", "pushes", "pulls", "slams",
        "opens", "closes", "turns", "moves", "stops"
    ]

    // Screenplay-specific: Scene transition words
    private static let sceneTransitionWords: Set<String> = [
        "later", "meanwhile", "continuous", "morning", "night",
        "day", "evening", "dawn", "dusk", "same"
    ]

    private let formatDetector = DocumentFormatDetector()

    func detectPlotPoints(text: String, wordCount: Int) -> PlotAnalysis {
        var analysis = PlotAnalysis()

        // Detect document format
        let (format, confidence) = formatDetector.detectFormat(text: text)
        analysis.documentFormat = format
        analysis.formatConfidence = confidence

        // Analyze tension throughout the story
        analysis.overallTensionCurve = analyzeTensionCurve(text: text, wordCount: wordCount, format: format)

        // Detect format-specific plot points
        switch format {
        case .novel:
            analysis.plotPoints = identifyNovelPlotPoints(tensionCurve: analysis.overallTensionCurve, text: text, wordCount: wordCount)
            analysis.missingPoints = findMissingNovelPoints(found: analysis.plotPoints)
            analysis.structuralIssues = detectNovelStructuralIssues(text: text, plotPoints: analysis.plotPoints, tensionCurve: analysis.overallTensionCurve)

            // Calculate novel-specific metrics
            analysis.internalChangeScore = calculateInternalChangeScore(text: text)
            analysis.thematicResonance = calculateThematicResonance(text: text)
            analysis.narrativeMomentum = calculateNarrativeMomentum(tensionCurve: analysis.overallTensionCurve)

        case .screenplay:
            analysis.plotPoints = identifyScreenplayPlotPoints(tensionCurve: analysis.overallTensionCurve, text: text, wordCount: wordCount)
            analysis.missingPoints = findMissingScreenplayPoints(found: analysis.plotPoints)
            analysis.structuralIssues = detectScreenplayStructuralIssues(text: text, plotPoints: analysis.plotPoints, tensionCurve: analysis.overallTensionCurve, wordCount: wordCount)

            // Calculate screenplay-specific metrics
            analysis.visualCausalityScore = calculateVisualCausality(text: text)
            analysis.sceneEfficiency = calculateSceneEfficiency(text: text, wordCount: wordCount)
            analysis.pacingScore = calculateScreenplayPacing(tensionCurve: analysis.overallTensionCurve)
            analysis.estimatedRuntime = estimateRuntime(wordCount: wordCount, format: format)
        }

        // Calculate overall structure score
        analysis.structureScore = calculateStructureScore(
            plotPoints: analysis.plotPoints,
            missingPoints: analysis.missingPoints,
            issues: analysis.structuralIssues,
            format: format
        )

        return analysis
    }

    // MARK: - Tension Analysis

    private func analyzeTensionCurve(text: String, wordCount: Int, format: DocumentFormat) -> [TensionPoint] {
        guard wordCount > 0 else { return [] }

        var tensionPoints: [TensionPoint] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Sample interval varies by format
        // Screenplays need finer granularity (minute-by-minute)
        let sampleInterval: Int
        switch format {
        case .screenplay:
            sampleInterval = max(50, min(200, wordCount / 20))  // More frequent sampling
        case .novel:
            sampleInterval = max(100, min(500, wordCount / 10))
        }

        var currentWordCount = 0
        var windowWords: [String] = []

        for (index, word) in words.enumerated() {
            windowWords.append(word.lowercased())

            // Keep window at ~100 words
            if windowWords.count > 100 {
                windowWords.removeFirst()
            }

            currentWordCount = index + 1

            // Sample tension at intervals
            if currentWordCount % sampleInterval == 0 || currentWordCount == words.count {
                let tension = calculateWindowTension(words: windowWords, format: format)
                let position = Double(currentWordCount) / Double(wordCount)

                tensionPoints.append(TensionPoint(
                    position: position,
                    tensionLevel: tension,
                    wordPosition: currentWordCount
                ))
            }
        }

        return tensionPoints
    }

    private func calculateWindowTension(words: [String], format: DocumentFormat) -> Double {
        var tensionScore = 0.0

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)

            // Universal tension words
            if PlotPointDetector.tensionWords.contains(cleanWord) {
                tensionScore += 0.3
            }
            if PlotPointDetector.actionVerbs.contains(cleanWord) {
                tensionScore += 0.2
            }
            if PlotPointDetector.revelationWords.contains(cleanWord) {
                tensionScore += 0.25
            }

            // Format-specific tension modifiers
            switch format {
            case .screenplay:
                // Visual actions increase tension in screenplays
                if PlotPointDetector.visualActionWords.contains(cleanWord) {
                    tensionScore += 0.15
                }
            case .novel:
                // Internal change words contribute to tension in novels
                if PlotPointDetector.internalChangeWords.contains(cleanWord) {
                    tensionScore += 0.15
                }
            }
        }

        // Normalize to 0-1 range
        return min(1.0, tensionScore / 3.0)
    }

    // MARK: - Novel Plot Point Detection

    private func identifyNovelPlotPoints(tensionCurve: [TensionPoint], text: String, wordCount: Int) -> [PlotPoint] {
        var plotPoints: [PlotPoint] = []

        guard tensionCurve.count > 5 else { return plotPoints }

        // Find tension peaks and valleys
        for i in 1..<(tensionCurve.count - 1) {
            let prev = tensionCurve[i - 1]
            let current = tensionCurve[i]
            let next = tensionCurve[i + 1]

            // Detect peaks (high points)
            if current.tensionLevel > prev.tensionLevel &&
               current.tensionLevel > next.tensionLevel &&
               current.tensionLevel > 0.4 {

                let type = determineNovelPointType(position: current.position, isPeak: true)
                let point = PlotPoint(
                    novelType: type,
                    wordPosition: current.wordPosition,
                    percentagePosition: current.position,
                    tensionLevel: current.tensionLevel,
                    description: type.analysisQuestion,
                    suggestedImprovement: nil
                )
                plotPoints.append(point)
            }

            // Detect valleys before climbs (setup moments)
            if current.tensionLevel < prev.tensionLevel &&
               next.tensionLevel > current.tensionLevel &&
               next.tensionLevel - current.tensionLevel > 0.25 {

                let type = determineNovelPointType(position: current.position, isPeak: false)
                let point = PlotPoint(
                    novelType: type,
                    wordPosition: current.wordPosition,
                    percentagePosition: current.position,
                    tensionLevel: current.tensionLevel,
                    description: "Setup before tension increase",
                    suggestedImprovement: nil
                )
                plotPoints.append(point)
            }
        }

        // Ensure key story beats
        ensureNovelKeyBeats(&plotPoints, tensionCurve: tensionCurve)

        return plotPoints.sorted { $0.wordPosition < $1.wordPosition }
    }

    private func determineNovelPointType(position: Double, isPeak: Bool) -> NovelPlotPointType {
        if position < 0.05 {
            return .openingState
        } else if position < 0.18 {
            return .incitingDisruption
        } else if position < 0.30 {
            return .firstCommitment
        } else if position < 0.45 {
            return .progressiveComplications
        } else if position < 0.55 {
            return .midpointReversal
        } else if position < 0.70 {
            return .escalatingCosts
        } else if position < 0.82 {
            return .crisis
        } else if position < 0.90 {
            return .finalChoice
        } else if position < 0.96 {
            return .climax
        } else {
            return .aftermath
        }
    }

    private func ensureNovelKeyBeats(_ plotPoints: inout [PlotPoint], tensionCurve: [TensionPoint]) {
        let foundTypes = Set(plotPoints.map { $0.type })
        let keyTypes: [NovelPlotPointType] = [.incitingDisruption, .midpointReversal, .crisis, .climax]

        for keyType in keyTypes {
            if !foundTypes.contains(keyType.rawValue) {
                let expectedPos = keyType.expectedPosition
                let closestPoint = tensionCurve.min { point1, point2 in
                    abs(point1.position - expectedPos) < abs(point2.position - expectedPos)
                }

                if let point = closestPoint {
                    let plotPoint = PlotPoint(
                        novelType: keyType,
                        wordPosition: point.wordPosition,
                        percentagePosition: point.position,
                        tensionLevel: point.tensionLevel,
                        description: "Expected \(keyType.rawValue)",
                        suggestedImprovement: keyType.failureDescription
                    )
                    plotPoints.append(plotPoint)
                }
            }
        }
    }

    private func findMissingNovelPoints(found: [PlotPoint]) -> [String] {
        let foundTypes = Set(found.map { $0.type })
        return NovelPlotPointType.allCases
            .filter { !foundTypes.contains($0.rawValue) }
            .map { $0.rawValue }
    }

    // MARK: - Screenplay Plot Point Detection

    private func identifyScreenplayPlotPoints(tensionCurve: [TensionPoint], text: String, wordCount: Int) -> [PlotPoint] {
        var plotPoints: [PlotPoint] = []

        guard tensionCurve.count > 5 else { return plotPoints }

        // Screenplays need sharper tension detection (visible causality)
        for i in 1..<(tensionCurve.count - 1) {
            let prev = tensionCurve[i - 1]
            let current = tensionCurve[i]
            let next = tensionCurve[i + 1]

            // Detect sharp peaks (screenplay beats are more defined)
            let isPeak = current.tensionLevel > prev.tensionLevel &&
                         current.tensionLevel > next.tensionLevel &&
                         current.tensionLevel > 0.45

            // Detect reversals (sudden changes in direction)
            let isReversal = abs(current.tensionLevel - prev.tensionLevel) > 0.3 ||
                             abs(next.tensionLevel - current.tensionLevel) > 0.3

            if isPeak || isReversal {
                let type = determineScreenplayPointType(position: current.position, isPeak: isPeak)
                let point = PlotPoint(
                    screenplayType: type,
                    wordPosition: current.wordPosition,
                    percentagePosition: current.position,
                    tensionLevel: current.tensionLevel,
                    description: type.analysisQuestion,
                    suggestedImprovement: nil
                )
                plotPoints.append(point)
            }
        }

        // Ensure key screenplay beats
        ensureScreenplayKeyBeats(&plotPoints, tensionCurve: tensionCurve)

        return plotPoints.sorted { $0.wordPosition < $1.wordPosition }
    }

    private func determineScreenplayPointType(position: Double, isPeak: Bool) -> ScreenplayPlotPointType {
        if position < 0.05 {
            return .openingImage
        } else if position < 0.15 {
            return .incitingIncident
        } else if position < 0.28 {
            return .lockIn
        } else if position < 0.38 {
            return .firstSequence
        } else if position < 0.48 {
            return .risingComplications
        } else if position < 0.55 {
            return .midpointReversal
        } else if position < 0.68 {
            return .badGuysClose
        } else if position < 0.78 {
            return .allIsLost
        } else if position < 0.83 {
            return .darkNight
        } else if position < 0.90 {
            return .thirdActBreak
        } else if position < 0.97 {
            return .finale
        } else {
            return .closingImage
        }
    }

    private func ensureScreenplayKeyBeats(_ plotPoints: inout [PlotPoint], tensionCurve: [TensionPoint]) {
        let foundTypes = Set(plotPoints.map { $0.type })
        // Screenplays have more rigid beat requirements
        let keyTypes: [ScreenplayPlotPointType] = [.openingImage, .incitingIncident, .lockIn, .midpointReversal, .allIsLost, .finale, .closingImage]

        for keyType in keyTypes {
            if !foundTypes.contains(keyType.rawValue) {
                let expectedPos = keyType.expectedPosition
                let closestPoint = tensionCurve.min { point1, point2 in
                    abs(point1.position - expectedPos) < abs(point2.position - expectedPos)
                }

                if let point = closestPoint {
                    let plotPoint = PlotPoint(
                        screenplayType: keyType,
                        wordPosition: point.wordPosition,
                        percentagePosition: point.position,
                        tensionLevel: point.tensionLevel,
                        description: "Expected at ~\(keyType.expectedPage) pages",
                        suggestedImprovement: keyType.failureDescription
                    )
                    plotPoints.append(plotPoint)
                }
            }
        }
    }

    private func findMissingScreenplayPoints(found: [PlotPoint]) -> [String] {
        let foundTypes = Set(found.map { $0.type })
        return ScreenplayPlotPointType.allCases
            .filter { !foundTypes.contains($0.rawValue) }
            .map { $0.rawValue }
    }

    // MARK: - Structural Issue Detection

    private func detectNovelStructuralIssues(text: String, plotPoints: [PlotPoint], tensionCurve: [TensionPoint]) -> [StructuralIssue] {
        var issues: [StructuralIssue] = []

        // Check for excessive inertia (long stretches of low tension)
        var lowTensionStreak = 0
        var streakStart: Double = 0
        for point in tensionCurve {
            if point.tensionLevel < 0.2 {
                if lowTensionStreak == 0 {
                    streakStart = point.position
                }
                lowTensionStreak += 1
            } else {
                if lowTensionStreak > 5 {
                    issues.append(StructuralIssue(
                        severity: lowTensionStreak > 10 ? .major : .moderate,
                        category: .excessiveInertia,
                        description: "Extended low-tension passage detected. Beautiful but potentially stagnant.",
                        suggestion: "Consider adding micro-conflicts, revelations, or thematic tensions to maintain reader engagement.",
                        affectedRange: (start: streakStart, end: point.position)
                    ))
                }
                lowTensionStreak = 0
            }
        }

        // Check for late plot ignition
        let firstSignificantPoint = plotPoints.first { $0.tensionLevel > 0.4 }
        if let first = firstSignificantPoint, first.percentagePosition > 0.20 {
            issues.append(StructuralIssue(
                severity: first.percentagePosition > 0.30 ? .major : .moderate,
                category: .latePlotIgnition,
                description: "Plot ignition appears late at \(Int(first.percentagePosition * 100))%.",
                suggestion: "Consider introducing the inciting disruption earlier to hook readers.",
                affectedRange: (start: 0, end: first.percentagePosition)
            ))
        }

        // Check for thematic diffusion (no clear midpoint shift)
        let midpointArea = tensionCurve.filter { $0.position >= 0.45 && $0.position <= 0.55 }
        if !midpointArea.isEmpty {
            let midpointVariance = calculateVariance(midpointArea.map { $0.tensionLevel })
            if midpointVariance < 0.02 {
                issues.append(StructuralIssue(
                    severity: .moderate,
                    category: .thematicDiffusion,
                    description: "Midpoint lacks clear reversal or redefinition of success.",
                    suggestion: "The midpoint should change what victory looks like for the protagonist.",
                    affectedRange: (start: 0.45, end: 0.55)
                ))
            }
        }

        return issues
    }

    private func detectScreenplayStructuralIssues(text: String, plotPoints: [PlotPoint], tensionCurve: [TensionPoint], wordCount: Int) -> [StructuralIssue] {
        var issues: [StructuralIssue] = []

        // Check for repetitive tension patterns (scenes without turns)
        var flatStreak = 0
        var streakStart: Double = 0
        for i in 1..<tensionCurve.count {
            let diff = abs(tensionCurve[i].tensionLevel - tensionCurve[i-1].tensionLevel)
            if diff < 0.05 {
                if flatStreak == 0 {
                    streakStart = tensionCurve[i-1].position
                }
                flatStreak += 1
            } else {
                if flatStreak > 3 {
                    issues.append(StructuralIssue(
                        severity: flatStreak > 6 ? .major : .moderate,
                        category: .repetitiveScenes,
                        description: "Sequence of scenes without visible turns detected.",
                        suggestion: "Each scene must turn—someone gains or loses leverage. Would cutting these scenes break causality?",
                        affectedRange: (start: streakStart, end: tensionCurve[i].position)
                    ))
                }
                flatStreak = 0
            }
        }

        // Check for midpoint sag
        let beforeMidpoint = tensionCurve.filter { $0.position >= 0.40 && $0.position < 0.50 }
        let afterMidpoint = tensionCurve.filter { $0.position >= 0.50 && $0.position <= 0.60 }

        if !beforeMidpoint.isEmpty && !afterMidpoint.isEmpty {
            let beforeAvg = beforeMidpoint.reduce(0) { $0 + $1.tensionLevel } / Double(beforeMidpoint.count)
            let afterAvg = afterMidpoint.reduce(0) { $0 + $1.tensionLevel } / Double(afterMidpoint.count)

            if afterAvg < beforeAvg * 0.9 {
                issues.append(StructuralIssue(
                    severity: .major,
                    category: .midpointSag,
                    description: "Tension decreases after midpoint instead of escalating.",
                    suggestion: "Midpoint should be a visible reversal that raises stakes and accelerates toward the climax.",
                    affectedRange: (start: 0.50, end: 0.60)
                ))
            }
        }

        // Check for passive protagonist (no clear action beats)
        let actionPoints = plotPoints.filter { $0.tensionLevel > 0.5 }
        if actionPoints.count < 3 {
            issues.append(StructuralIssue(
                severity: .moderate,
                category: .passiveProtagonist,
                description: "Few high-tension action beats detected.",
                suggestion: "Protagonist must make visible choices under pressure. Actions reveal character—dialogue alone cannot.",
                affectedRange: (start: 0, end: 1)
            ))
        }

        // Check pacing (estimated runtime)
        let estimatedMinutes = estimateRuntime(wordCount: wordCount, format: .screenplay)
        if estimatedMinutes < 85 || estimatedMinutes > 130 {
            issues.append(StructuralIssue(
                severity: estimatedMinutes < 70 || estimatedMinutes > 150 ? .major : .minor,
                category: .paceProblems,
                description: "Estimated runtime: ~\(estimatedMinutes) minutes. Feature films typically run 90-120 minutes.",
                suggestion: estimatedMinutes < 85 ? "Consider expanding sequences or adding subplots." : "Consider tightening scenes—each must justify its screen time.",
                affectedRange: (start: 0, end: 1)
            ))
        }

        return issues
    }

    // MARK: - Format-Specific Metrics

    private func calculateInternalChangeScore(text: String) -> Int {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var score = 0

        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if PlotPointDetector.internalChangeWords.contains(clean) {
                score += 1
            }
        }

        // Normalize to 0-100
        let normalized = min(100, score * 2)
        return normalized
    }

    private func calculateThematicResonance(text: String) -> Int {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var themeOccurrences: [String: Int] = [:]

        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if PlotPointDetector.thematicWords.contains(clean) {
                themeOccurrences[clean, default: 0] += 1
            }
        }

        // Good resonance = themes that appear multiple times throughout
        let recurringThemes = themeOccurrences.filter { $0.value >= 3 }.count
        return min(100, recurringThemes * 15)
    }

    private func calculateNarrativeMomentum(tensionCurve: [TensionPoint]) -> Int {
        guard tensionCurve.count > 2 else { return 50 }

        // Check for overall upward trend with variation
        var increases = 0
        var decreases = 0

        for i in 1..<tensionCurve.count {
            if tensionCurve[i].tensionLevel > tensionCurve[i-1].tensionLevel {
                increases += 1
            } else {
                decreases += 1
            }
        }

        // Good momentum = more increases than decreases, but with some variation
        let ratio = Double(increases) / Double(increases + decreases)
        let variationBonus = (decreases > 0 && increases > 0) ? 10 : 0

        return min(100, Int(ratio * 80) + variationBonus)
    }

    private func calculateVisualCausality(text: String) -> Int {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var score = 0

        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if PlotPointDetector.visualActionWords.contains(clean) {
                score += 1
            }
        }

        // Normalize based on text length
        let wordsPerAction = Double(words.count) / max(1, Double(score))

        // Good visual causality = action word every ~20-50 words
        if wordsPerAction < 20 {
            return 100  // Very visual
        } else if wordsPerAction < 50 {
            return 80
        } else if wordsPerAction < 100 {
            return 60
        } else {
            return 40  // Too prose-like for screenplay
        }
    }

    private func calculateSceneEfficiency(text: String, wordCount: Int) -> Int {
        // Count scene breaks (INT./EXT. or double line breaks in screenplays)
        let scenePattern = "(?i)(INT\\.|EXT\\.|INT/EXT\\.)"
        let sceneCount: Int

        if let regex = try? NSRegularExpression(pattern: scenePattern, options: []) {
            sceneCount = regex.numberOfMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        } else {
            sceneCount = 0
        }

        guard sceneCount > 0 else { return 50 }

        // Average words per scene (screenplay scenes should be ~150-300 words / 1-2 pages)
        let wordsPerScene = wordCount / sceneCount

        if wordsPerScene >= 100 && wordsPerScene <= 300 {
            return 90  // Good scene length
        } else if wordsPerScene < 100 {
            return 60  // Scenes too short
        } else if wordsPerScene <= 500 {
            return 70  // Scenes a bit long
        } else {
            return 40  // Scenes way too long for screenplay
        }
    }

    private func calculateScreenplayPacing(tensionCurve: [TensionPoint]) -> Int {
        guard tensionCurve.count > 5 else { return 50 }

        // Good screenplay pacing = clear escalation with defined beats
        var score = 50

        // Check for clear act breaks (tension changes at 25%, 75%)
        let act1End = tensionCurve.first { $0.position >= 0.23 && $0.position <= 0.27 }
        let act2End = tensionCurve.first { $0.position >= 0.73 && $0.position <= 0.77 }

        if let a1 = act1End, a1.tensionLevel > 0.4 {
            score += 15  // Good act 1 break
        }
        if let a2 = act2End, a2.tensionLevel > 0.6 {
            score += 15  // Good act 2 break
        }

        // Check for escalation in final third
        let finalThird = tensionCurve.filter { $0.position >= 0.75 }
        if !finalThird.isEmpty {
            let avgFinalTension = finalThird.reduce(0) { $0 + $1.tensionLevel } / Double(finalThird.count)
            if avgFinalTension > 0.6 {
                score += 20
            }
        }

        return min(100, score)
    }

    private func estimateRuntime(wordCount: Int, format: DocumentFormat) -> Int {
        switch format {
        case .screenplay:
            // Screenplay: ~150-180 words per page, 1 page ≈ 1 minute
            let pages = wordCount / 165
            return max(1, pages)
        case .novel:
            // Novel: reading time estimate (200-250 wpm average reader)
            return max(1, wordCount / 225)
        }
    }

    // MARK: - Structure Score Calculation

    private func calculateStructureScore(plotPoints: [PlotPoint], missingPoints: [String], issues: [StructuralIssue], format: DocumentFormat) -> Int {
        var score = 100

        // Penalty for missing key beats
        let penaltyPerMissing: Int
        switch format {
        case .screenplay:
            penaltyPerMissing = 8  // Screenplays are more rigid
        case .novel:
            penaltyPerMissing = 6  // Novels have more flexibility
        }
        score -= missingPoints.count * penaltyPerMissing

        // Penalty for structural issues
        for issue in issues {
            switch issue.severity {
            case .minor: score -= 3
            case .moderate: score -= 7
            case .major: score -= 12
            }
        }

        // Bonus for good tension variation
        let tensions = plotPoints.map { $0.tensionLevel }
        if tensions.count > 2 {
            let variance = calculateVariance(tensions)
            if variance > 0.05 {
                score += 10
            }
        }

        return max(0, min(100, score))
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}
