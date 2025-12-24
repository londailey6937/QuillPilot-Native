import Foundation

// MARK: - Scene Intent
/// Describes the narrative purpose of a scene
enum SceneIntent: String, Codable, CaseIterable {
    case setup = "Setup"
    case conflict = "Conflict"
    case resolution = "Resolution"
    case transition = "Transition"
    case climax = "Climax"
    case denouement = "Denouement"
    case exposition = "Exposition"
    case risingAction = "Rising Action"
    case fallingAction = "Falling Action"

    var description: String {
        switch self {
        case .setup: return "Establishes setting, characters, or situation"
        case .conflict: return "Introduces or escalates tension"
        case .resolution: return "Resolves a conflict or subplot"
        case .transition: return "Bridges between major story beats"
        case .climax: return "The peak of dramatic tension"
        case .denouement: return "Aftermath and wrap-up"
        case .exposition: return "Provides background information"
        case .risingAction: return "Builds toward the climax"
        case .fallingAction: return "Events following the climax"
        }
    }
}

// MARK: - Revision State
/// Tracks the editorial status of a scene
enum RevisionState: String, Codable, CaseIterable {
    case draft = "Draft"
    case revised = "Revised"
    case polished = "Polished"
    case final = "Final"
    case needsWork = "Needs Work"

    var icon: String {
        switch self {
        case .draft: return "📝"
        case .revised: return "✏️"
        case .polished: return "✨"
        case .final: return "✅"
        case .needsWork: return "⚠️"
        }
    }
}

// MARK: - Scene Model
/// A scene is a discrete unit of narrative with its own metadata.
/// IMPORTANT: This model stores metadata ONLY. It does NOT store or access
/// the main editor's text content to avoid any risk of corrupting the document.
struct Scene: Identifiable, Codable {
    let id: UUID
    var order: Int
    var title: String
    var summary: String
    var notes: String

    // Narrative metadata
    var intent: SceneIntent
    var revisionState: RevisionState
    var pointOfView: String
    var location: String
    var timeOfDay: String
    var characters: [String]

    // Scene goal and conflict (core dramatic elements)
    var goal: String           // What the POV character wants in this scene
    var conflict: String       // What opposes the goal
    var outcome: String        // How the scene resolves (success/failure/complication)

    // Timestamps
    var createdAt: Date
    var modifiedAt: Date

    // Word count target (optional goal)
    var targetWordCount: Int?

    // Chapter assignment (nil = unassigned)
    var chapterId: UUID?

    init(
        id: UUID = UUID(),
        order: Int,
        title: String = "Untitled Scene",
        summary: String = "",
        notes: String = "",
        intent: SceneIntent = .setup,
        revisionState: RevisionState = .draft,
        pointOfView: String = "",
        location: String = "",
        timeOfDay: String = "",
        characters: [String] = [],
        goal: String = "",
        conflict: String = "",
        outcome: String = "",
        targetWordCount: Int? = nil,
        chapterId: UUID? = nil
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.summary = summary
        self.notes = notes
        self.intent = intent
        self.revisionState = revisionState
        self.pointOfView = pointOfView
        self.location = location
        self.timeOfDay = timeOfDay
        self.characters = characters
        self.goal = goal
        self.conflict = conflict
        self.outcome = outcome
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.targetWordCount = targetWordCount
        self.chapterId = chapterId
    }

    mutating func touch() {
        modifiedAt = Date()
    }
}

// MARK: - Scene Extensions
extension Scene {
    /// Returns a display string for the scene's status
    var statusDisplay: String {
        "\(revisionState.icon) \(revisionState.rawValue)"
    }

    /// Returns a brief description combining title and intent
    var briefDescription: String {
        if summary.isEmpty {
            return "\(title) (\(intent.rawValue))"
        }
        return summary
    }
}
