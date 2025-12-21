//
//  PlotAnalysis.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation

// MARK: - Plot Point Types

enum PlotPointType: String, CaseIterable {
    case incitingIncident = "Inciting Incident"
    case risingAction = "Rising Action"
    case pinchPoint1 = "First Pinch Point"
    case midpoint = "Midpoint"
    case pinchPoint2 = "Second Pinch Point"
    case crisis = "Crisis"
    case climax = "Climax"
    case fallingAction = "Falling Action"
    case resolution = "Resolution"

    var emoji: String {
        switch self {
        case .incitingIncident: return "🎬"
        case .risingAction: return "📈"
        case .pinchPoint1: return "⚡️"
        case .midpoint: return "🔄"
        case .pinchPoint2: return "⚡️"
        case .crisis: return "💥"
        case .climax: return "🔥"
        case .fallingAction: return "📉"
        case .resolution: return "✨"
        }
    }

    var expectedPosition: Double {
        // Approximate position in story (0.0-1.0)
        switch self {
        case .incitingIncident: return 0.12
        case .risingAction: return 0.20
        case .pinchPoint1: return 0.37
        case .midpoint: return 0.50
        case .pinchPoint2: return 0.62
        case .crisis: return 0.75
        case .climax: return 0.88
        case .fallingAction: return 0.93
        case .resolution: return 0.98
        }
    }
}

struct PlotPoint {
    let type: PlotPointType
    let wordPosition: Int          // Position in document (word count)
    let percentagePosition: Double  // 0.0-1.0 position in story
    let tensionLevel: Double        // 0.0-1.0
    let description: String
    let suggestedImprovement: String?
}

struct PlotAnalysis {
    var plotPoints: [PlotPoint] = []
    var overallTensionCurve: [TensionPoint] = []
    var structureScore: Int = 0  // 0-100
    var missingPoints: [PlotPointType] = []
}

struct TensionPoint {
    let position: Double      // 0.0-1.0 in story
    let tensionLevel: Double  // 0.0-1.0
    let wordPosition: Int
}

// MARK: - Plot Point Detector

class PlotPointDetector {

    // Tension indicators
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

    func detectPlotPoints(text: String, wordCount: Int) -> PlotAnalysis {
        var analysis = PlotAnalysis()

        // Analyze tension throughout the story
        analysis.overallTensionCurve = analyzeTensionCurve(text: text, wordCount: wordCount)

        // Detect specific plot points
        analysis.plotPoints = identifyPlotPoints(tensionCurve: analysis.overallTensionCurve, wordCount: wordCount)

        // Check structure completeness
        let foundTypes = Set(analysis.plotPoints.map { $0.type })
        analysis.missingPoints = PlotPointType.allCases.filter { !foundTypes.contains($0) }

        // Calculate structure score
        analysis.structureScore = calculateStructureScore(
            plotPoints: analysis.plotPoints,
            missingPoints: analysis.missingPoints
        )

        return analysis
    }

    private func analyzeTensionCurve(text: String, wordCount: Int) -> [TensionPoint] {
        guard wordCount > 0 else { return [] }

        var tensionPoints: [TensionPoint] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Sample tension every 500 words
        let sampleInterval = 500
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
                let tension = calculateWindowTension(words: windowWords)
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

    private func calculateWindowTension(words: [String]) -> Double {
        var tensionScore = 0.0

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)

            if PlotPointDetector.tensionWords.contains(cleanWord) {
                tensionScore += 0.3
            }
            if PlotPointDetector.actionVerbs.contains(cleanWord) {
                tensionScore += 0.2
            }
            if PlotPointDetector.revelationWords.contains(cleanWord) {
                tensionScore += 0.25
            }
        }

        // Normalize to 0-1 range (assuming max ~10 tension words per 100-word window)
        return min(1.0, tensionScore / 3.0)
    }

    private func identifyPlotPoints(tensionCurve: [TensionPoint], wordCount: Int) -> [PlotPoint] {
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
               current.tensionLevel > 0.5 {

                let type = determinePointType(position: current.position, isPeak: true)
                let point = PlotPoint(
                    type: type,
                    wordPosition: current.wordPosition,
                    percentagePosition: current.position,
                    tensionLevel: current.tensionLevel,
                    description: "High tension point detected",
                    suggestedImprovement: nil
                )
                plotPoints.append(point)
            }

            // Detect valleys (low points before climbs)
            if current.tensionLevel < prev.tensionLevel &&
               next.tensionLevel > current.tensionLevel &&
               next.tensionLevel - current.tensionLevel > 0.3 {

                let type = determinePointType(position: current.position, isPeak: false)
                if type == .incitingIncident || type == .crisis {
                    let point = PlotPoint(
                        type: type,
                        wordPosition: current.wordPosition,
                        percentagePosition: current.position,
                        tensionLevel: current.tensionLevel,
                        description: "Calm before the storm",
                        suggestedImprovement: nil
                    )
                    plotPoints.append(point)
                }
            }
        }

        // Ensure we have key story beats even if not detected
        ensureKeyBeats(&plotPoints, tensionCurve: tensionCurve)

        return plotPoints.sorted { $0.wordPosition < $1.wordPosition }
    }

    private func determinePointType(position: Double, isPeak: Bool) -> PlotPointType {
        // Map position to likely plot point type
        if position < 0.15 {
            return .incitingIncident
        } else if position < 0.30 {
            return .risingAction
        } else if position < 0.45 {
            return .pinchPoint1
        } else if position < 0.55 {
            return .midpoint
        } else if position < 0.70 {
            return .pinchPoint2
        } else if position < 0.80 {
            return .crisis
        } else if position < 0.95 {
            return .climax
        } else {
            return isPeak ? .climax : .resolution
        }
    }

    private func ensureKeyBeats(_ plotPoints: inout [PlotPoint], tensionCurve: [TensionPoint]) {
        let foundTypes = Set(plotPoints.map { $0.type })
        let keyTypes: [PlotPointType] = [.incitingIncident, .midpoint, .climax]

        for keyType in keyTypes {
            if !foundTypes.contains(keyType) {
                // Add placeholder at expected position
                let expectedPos = keyType.expectedPosition
                let closestPoint = tensionCurve.min { point1, point2 in
                    abs(point1.position - expectedPos) < abs(point2.position - expectedPos)
                }

                if let point = closestPoint {
                    let plotPoint = PlotPoint(
                        type: keyType,
                        wordPosition: point.wordPosition,
                        percentagePosition: point.position,
                        tensionLevel: point.tensionLevel,
                        description: "Expected \(keyType.rawValue)",
                        suggestedImprovement: "Consider strengthening this story beat"
                    )
                    plotPoints.append(plotPoint)
                }
            }
        }
    }

    private func calculateStructureScore(plotPoints: [PlotPoint], missingPoints: [PlotPointType]) -> Int {
        var score = 100

        // Penalty for missing key beats
        score -= missingPoints.count * 10

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
