# AI Story Generation & Advanced Analysis Features

## Overview

This document outlines the design and implementation plan for AI-powered story generation and advanced narrative analysis features in QuillPilot.

---

## 1. AI Story Generation

### Feature Description

Generate complete story drafts based on user-defined story elements:

- Characters from Character Library
- Story Theme
- Story Outline structure
- Locations
- Potential Story Directions

### Implementation Approach

#### Option A: Local AI Integration (Recommended for Privacy)

```swift
// Use Apple's MLX or similar local models
class AIStoryGenerator {
    func generateStory(
        characters: [Character],
        theme: String,
        outline: StoryOutline,
        locations: [Location],
        directions: [StoryDirection]
    ) async throws -> String {
        // Generate prompts from story elements
        // Use local LLM to generate narrative
    }
}
```

#### Option B: Cloud AI Integration (OpenAI, Anthropic, etc.)

```swift
class CloudAIGenerator {
    func generateStory(elements: StoryElements) async throws -> String {
        // API integration with user's API key
        // Structured prompt engineering
    }
}
```

### UI Design

- **Location**: New "Generate Story" button in Navigator panel (🤖 icon)
- **Dialog**: Preview/edit generation settings before creating
- **Progress**: Show generation progress in real-time
- **Output**: Generated story appears in main editor with option to accept/regenerate

### Security Considerations

- User-provided API keys (stored in macOS Keychain)
- Option to use local models only (no internet required)
- Clear warnings about data being sent to external services

---

## 2. Dialogue Analysis Enhancement

### Current Dialogue Tips (from The Silent Operator_Dialogue.docx)

**10 Common Issues with Thin Dialogue:**

1. **Lack of Depth** - Characters say exactly what they mean without subtext
2. **Repetition** - Reiterating same ideas drains importance
3. **Overuse of Filler** - Excessive "uh," "um," "well" dilutes impact
4. **Monotony** - All characters sound the same
5. **Predictability** - Clichéd phrases lack originality
6. **No Character Growth** - Dialogue doesn't reveal character or advance plot
7. **Over-Exposition** - Pure information dumps are dull
8. **Lack of Conflict/Tension** - No disagreement or dynamism
9. **No Emotional Resonance** - Doesn't evoke reader reaction
10. **Lack of Pacing** - No rhythm variation between long and short sentences

### Proposed Analysis Features

#### Dialogue Quality Metrics

```swift
struct DialogueAnalysis {
    var hasSubtext: Bool              // Detects indirect communication
    var uniqueVoices: Int             // Counts distinct character voices
    var emotionalResonance: Double    // 0.0-1.0 sentiment variation
    var pacingVariety: Double         // Sentence length variation
    var tensionLevel: Double          // Conflict indicators
    var expositionRatio: Double       // Info-dump vs natural reveal
    var fillerWordCount: Int          // "uh", "um", "well", etc.
}
```

#### Implementation

- **Parser**: Extract dialogue from text (between quotes)
- **Analyzer**: Apply NLP techniques to measure each metric
- **Visualizer**: Charts showing dialogue quality over chapters
- **Suggestions**: Actionable tips for improvement

---

## 3. Character Arc Analysis with Graphs

### Feature Description

Visualize character development and interactions across story sections (chapters for manuscripts; scenes/acts for screenplays).

### Visualization Types

#### A. Character Arc Graph (Line Chart)

```
Emotional State
     ^
High |     *Character A
     |    / \              *
     |   /   \            /
     |  /     \    ___   /
Mid  | /       \  /   \ /
     |/         \/     *
Low  *__________Act 1___Act 2___Act 3___> Timeline
```

**Tracks:**

- Emotional state progression
- Character agency/power level
- Moral alignment shifts
- Relationship dynamics

#### B. Character Interaction Network (Force-Directed Graph)

```
      Alex
     /  |  \
    /   |   \
Victoria |  Raymond
    \   |   /
     \  |  /
      Allison
```

**Shows:**

- Connection strength (line thickness)
- Interaction frequency (node size)
- Relationship type (line color: ally, enemy, neutral)
- Scene co-occurrence

#### C. Character Presence Heatmap

```
          Ch1  Ch2  Ch3  Ch4  Ch5
Alex      ███  ███  ██   ███  ███
Viktor    ██   -    ███  ██   ███
Allison   █    ██   ███  ██   ██
```

**Displays:**

- Screen time per section (intensity)
- Character availability patterns
- Subplot tracking

**Notes:**

- Character analysis is driven by the Character Library (major characters only) so analysis windows stay in sync with your cast list.

### Implementation

```swift
class CharacterArcAnalyzer {
    func analyzeCharacterArcs(
        text: String,
        characters: [Character],
        chapters: [Chapter]
    ) -> [CharacterArc] {
        // 1. Parse text and identify character mentions
        // 2. Sentiment analysis for each character scene
        // 3. Track relationships and interactions
        // 4. Calculate arc metrics
    }
}

struct CharacterArc {
    let character: Character
    let emotionalJourney: [EmotionalState]  // per act/chapter
    let interactions: [Interaction]         // with other characters
    let growthMetrics: GrowthMetrics
}

// Visualization using Swift Charts (macOS 13+)
struct CharacterArcView: View {
    let arcs: [CharacterArc]

    var body: some View {
        Chart(arcs) { arc in
            LineMark(
                x: .value("Act", arc.act),
                y: .value("Emotional State", arc.emotion)
            )
            .foregroundStyle(by: .value("Character", arc.character.name))
        }
    }
}
```

---

## 4. Plot Point Analysis with Graphs

### Feature Description

Identify and visualize key plot moments using narrative structure analysis.

### Plot Point Types

- **Inciting Incident** - Story begins
- **Rising Action** - Tension builds
- **Midpoint** - Major revelation
- **Crisis** - Lowest point
- **Climax** - Peak action
- **Resolution** - Conclusion

### Visualization: Story Tension Arc

```
Tension
   ^
   |                    Climax
   |                     /\
   |                    /  \
   |          Midpoint /    \
   |            /\    /      \
   |           /  \  /        \
   |   Rising /    \/          \ Falling
   |    /\   /    Crisis        \ Action
   |   /  \ /                    \
   |  /    X                      \
   | /   Pinch                     \
   |/                               \___
   +-------------------------------------> Timeline
  Inc.  1/4   Mid   3/4  Climax  End
```

### Detection Methods

```swift
class PlotPointDetector {
    func detectPlotPoints(text: String) -> [PlotPoint] {
        // 1. Sentiment analysis (emotional peaks/valleys)
        // 2. Action density (verb frequency)
        // 3. Conflict markers (tension words)
        // 4. Scene changes (location/time shifts)
        // 5. Character involvement (convergence points)
    }
}

struct PlotPoint {
    let type: PlotPointType
    let location: TextRange      // where in document
    let tensionLevel: Double     // 0.0-1.0
    let description: String       // auto-generated summary
    let suggestedImprovement: String?
}

enum PlotPointType {
    case incitingIncident
    case risingAction
    case pinchPoint1
    case midpoint
    case pinchPoint2
    case crisis
    case climax
    case fallingAction
    case resolution
}
```

### Interactive Features

- **Click plot point** → Jump to location in editor
- **Drag to adjust** → Suggest edits to strengthen structure
- **Add manual markers** → Override detection
- **Compare to templates** → Three-act, Hero's Journey, Save the Cat

---

## 5. Implementation Priorities

### Phase 1: Foundation (Current Sprint)

- ✅ Create Locations window
- ✅ Create Story Directions window
- ✅ Extract dialogue tips document
- [ ] Enhance AnalysisEngine with dialogue analysis

### Phase 2: Dialogue Analysis

- [ ] Implement dialogue extraction parser
- [ ] Add dialogue quality metrics
- [ ] Create dialogue analysis view
- [ ] Integrate tips into analysis results

### Phase 3: Character Arc Visualization

- [ ] Character mention detection
- [ ] Sentiment analysis per character
- [ ] Interaction tracking
- [ ] Graph visualization (Swift Charts)

### Phase 4: Plot Point Detection

- [ ] Tension analysis algorithm
- [ ] Plot point detection
- [ ] Story structure visualization
- [ ] Comparison with story templates

### Phase 5: AI Story Generation

- [ ] Design generation UI
- [ ] Implement local AI option
- [ ] Implement cloud AI option
- [ ] Add safety/privacy controls

---

## 6. Technical Dependencies

### Required Frameworks

```swift
import NaturalLanguage    // Sentiment analysis, NER
import Charts             // Data visualization
import CreateML           // Custom ML models (optional)
import CryptoKit          // API key encryption
```

### Optional Cloud Services

- OpenAI GPT-4 (story generation)
- Anthropic Claude (story generation)
- Cohere (embeddings for similarity)

### Data Storage

```swift
// Character arc data
struct CharacterArcCache: Codable {
    let documentID: UUID
    let lastAnalyzed: Date
    let arcs: [CharacterArc]
}

// Plot point cache
struct PlotAnalysisCache: Codable {
    let documentID: UUID
    let lastAnalyzed: Date
    let points: [PlotPoint]
}
```

---

## 7. User Workflow Examples

### Workflow 1: AI Story Generation

1. User fills out Character Library
2. User defines Theme
3. User creates Story Outline
4. User adds Locations
5. User explores Story Directions
6. User clicks "Generate Story" button
7. System creates prompt from all elements
8. AI generates draft story
9. Draft appears in editor for review/editing

### Workflow 2: Character Arc Analysis

1. User writes/imports manuscript
2. User clicks "Analyze Character Arcs" button
3. System identifies characters from library
4. System tracks character through story
5. Graph shows emotional journey per character
6. User clicks data point → jumps to scene
7. User adjusts scene based on insights

### Workflow 3: Dialogue Enhancement

1. System analyzes dialogue during regular analysis
2. Highlights problematic dialogue sections
3. Shows specific issues (e.g., "Too much filler")
4. Suggests improvements based on dialogue tips
5. User reviews and applies suggestions
6. Re-analyze to see improvements

---

## 8. Next Steps & Questions

### Questions for Decision

1. **AI Provider**: Local models only, cloud API, or both?
2. **Privacy**: Store analysis locally or offer cloud sync?
3. **Pricing**: Free tier limits? Premium features?
4. **Open Source**: Use open-source NLP libraries or build custom?

### Recommended Approach

- Start with **dialogue analysis** (most immediate value)
- Add **plot point visualization** (visual appeal)
- Build **character arc graphs** (unique differentiator)
- Finally add **AI generation** (complex, requires careful design)

### Timeline Estimate

- Dialogue analysis: 2-3 weeks
- Plot points: 2-3 weeks
- Character arcs: 3-4 weeks
- AI generation: 4-6 weeks

**Total: ~3-4 months for full feature set**

---

## Appendix: Dialogue Analysis Implementation

### Example Code Structure

```swift
// In AnalysisEngine.swift
extension AnalysisEngine {
    func analyzeDialogue(_ text: String) -> DialogueAnalysis {
        let dialogueSegments = extractDialogue(from: text)

        return DialogueAnalysis(
            hasSubtext: detectSubtext(in: dialogueSegments),
            uniqueVoices: countUniqueVoices(in: dialogueSegments),
            emotionalResonance: measureEmotionalRange(in: dialogueSegments),
            pacingVariety: calculatePacingVariety(in: dialogueSegments),
            tensionLevel: assessTension(in: dialogueSegments),
            expositionRatio: calculateExpositionRatio(in: dialogueSegments),
            fillerWordCount: countFillerWords(in: dialogueSegments)
        )
    }

    private func extractDialogue(from text: String) -> [DialogueSegment] {
        // Parse text for quoted dialogue
        // Return array of dialogue with speaker attribution
    }

    private func countFillerWords(in segments: [DialogueSegment]) -> Int {
        let fillers = ["uh", "um", "well", "like", "you know", "actually"]
        // Count occurrences
    }

    // ... other analysis methods
}
```

This structure extends the existing AnalysisEngine with dialogue-specific analysis capabilities.
