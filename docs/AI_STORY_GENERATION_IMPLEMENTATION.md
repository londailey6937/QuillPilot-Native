# AI Story Generation Implementation Guide

## Overview

This document outlines the implementation plan for AI-powered story generation in QuillPilot. The AI system will use all defined story elements (characters, theme, locations, story directions, outline) to generate complete story drafts.

## Feature Design

### User Interface

1. **New Navigator Button**: "✨ AI Story Gen" button in Navigator panel
2. **Generation Window**: Modal window with:
   - Preview of story elements being used
   - AI provider selection (Local / Cloud)
   - Generation settings (length, style, tone)
   - Progress indicator during generation
   - Preview and accept/reject options

### AI Provider Options

#### Option 1: Local AI (Recommended for Privacy)

- **Technology**: MLX Swift framework or llama.cpp bindings
- **Models**: Small language models (3-7B parameters)
  - Mistral 7B Instruct
  - Llama 3 8B Instruct
  - Phi-3 Mini (3.8B)
- **Pros**:
  - Complete privacy (no data leaves device)
  - No API costs
  - Works offline
  - Fast on Apple Silicon Macs
- **Cons**:
  - Requires model download (3-7GB)
  - Limited to shorter stories
  - Quality depends on model size
  - macOS 13+ with Apple Silicon recommended

#### Option 2: Cloud AI (Better Quality)

- **Providers**:
  - OpenAI GPT-4 / GPT-4 Turbo
  - Anthropic Claude 3.5 Sonnet
  - Google Gemini Pro
- **Pros**:
  - Higher quality output
  - Can generate longer content
  - No local storage needed
- **Cons**:
  - Requires API key (user provides)
  - Costs per generation
  - Privacy concerns (data sent to cloud)
  - Requires internet connection

### Data Flow

```
Story Elements → Prompt Engineering → AI Model → Generated Story → Editor
```

1. **Gather Elements**:

   - Character profiles from Character Library
   - Theme from Theme window
   - Story structure from Story Outline
   - Locations from Locations window
   - Plot directions from Story Directions window

2. **Prompt Construction**:

   - System prompt: Define role as creative writing assistant
   - Context: Inject all story elements
   - Instructions: Specify format, style, length
   - Constraints: Maintain consistency with provided elements

3. **Generation**:

   - Stream output in real-time for better UX
   - Show progress during generation
   - Allow cancellation mid-generation

4. **Post-Processing**:
   - Format the generated text
   - Insert into editor at cursor position or replace selection
   - Run immediate analysis on generated content

## Implementation Plan

### Phase 1: UI Components (1 week)

- [ ] Create `AIStoryGenerationWindow.swift`
- [ ] Add "AI Story Gen" button to Navigator
- [ ] Design settings panel (provider, length, style)
- [ ] Create progress view with streaming support
- [ ] Add preview/accept/reject workflow

### Phase 2: Story Element Collection (3 days)

- [ ] Create `StoryElementsCollector.swift` to gather all inputs
- [ ] Parse Character Library JSON
- [ ] Extract theme text from Theme window
- [ ] Get outline structure
- [ ] Collect locations and story directions
- [ ] Validate that required elements exist

### Phase 3: Prompt Engineering (1 week)

- [ ] Create `StoryPromptBuilder.swift`
- [ ] Design system prompts for different story types
- [ ] Implement context injection for characters
- [ ] Add location and setting descriptions
- [ ] Include plot structure guidance
- [ ] Create templates for different styles (thriller, romance, sci-fi)

### Phase 4: Local AI Integration (2 weeks)

- [ ] Evaluate MLX Swift vs llama.cpp
- [ ] Implement model downloader
- [ ] Create `LocalAIEngine.swift` wrapper
- [ ] Handle model loading and caching
- [ ] Implement streaming generation
- [ ] Add temperature/top-p controls
- [ ] Handle memory management for large models

### Phase 5: Cloud AI Integration (1 week)

- [ ] Create `CloudAIEngine.swift` protocol
- [ ] Implement OpenAI API client
- [ ] Implement Anthropic Claude client
- [ ] Add API key management (Keychain storage)
- [ ] Handle rate limiting and retries
- [ ] Implement streaming for better UX

### Phase 6: Generation Pipeline (1 week)

- [ ] Create `StoryGenerator.swift` coordinator
- [ ] Implement generation workflow
- [ ] Add real-time progress updates
- [ ] Handle errors gracefully
- [ ] Implement cancellation support
- [ ] Add generation history/cache

### Phase 7: Post-Processing (3 days)

- [ ] Format generated text (paragraphs, dialogue)
- [ ] Apply QuillPilot theme styling
- [ ] Insert into editor with undo support
- [ ] Trigger automatic analysis
- [ ] Show generation statistics

## Technical Specifications

### StoryElementsCollector

```swift
struct StoryElements {
    var characters: [Character]
    var theme: String
    var outline: StoryOutline
    var locations: [Location]
    var storyDirections: [StoryDirection]
}

class StoryElementsCollector {
    func collectAllElements() -> StoryElements?
    func validateElements(_ elements: StoryElements) -> Bool
}
```

### Prompt Builder

```swift
struct GenerationSettings {
    var length: StoryLength // Short/Medium/Long
    var style: WritingStyle // Descriptive/Concise/Poetic
    var tone: Tone // Dramatic/Humorous/Dark
    var provider: AIProvider // Local/OpenAI/Claude
}

class StoryPromptBuilder {
    func buildPrompt(
        elements: StoryElements,
        settings: GenerationSettings
    ) -> String
}
```

### AI Engine Protocol

```swift
protocol AIEngine {
    func generate(
        prompt: String,
        settings: GenerationSettings,
        onProgress: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    )

    func cancel()
    func isAvailable() -> Bool
}
```

## Example Prompt Template

```
You are a creative writing assistant helping to generate a story based on specific elements provided by the writer.

THEME:
{theme_text}

CHARACTERS:
{character_profiles}

LOCATIONS:
{location_descriptions}

STORY DIRECTION:
{plot_direction}

OUTLINE:
{story_structure}

TASK: Write a compelling story section that:
1. Incorporates the characters with their defined traits
2. Reflects the thematic elements
3. Uses the specified locations appropriately
4. Follows the outlined story structure
5. Maintains consistency with the provided direction
6. Is approximately {length} words
7. Uses a {style} writing style with a {tone} tone

Begin the story:
```

## Safety and Quality Controls

### Input Validation

- Ensure minimum required elements exist
- Warn if key elements are missing
- Suggest completing Character Library first

### Output Validation

- Check for coherence
- Verify character names match library
- Ensure locations are used correctly
- Flag potential inconsistencies

### User Controls

- Preview before accepting
- Edit generation settings
- Regenerate with different parameters
- Partial acceptance (take parts, reject others)

## Privacy Considerations

### Local AI

- All processing on-device
- No data transmission
- Models stored locally
- Complete user control

### Cloud AI

- Clear warning about data transmission
- User must explicitly provide API key
- Option to review data being sent
- Disclosure in privacy policy
- Allow disabling cloud option entirely

## Cost Estimation

### Development Time

- **Total**: 6-8 weeks
- Local AI focus: 4 weeks
- Cloud AI focus: 2 weeks
- Testing and refinement: 2 weeks

### User Costs

- **Local AI**: $0 (one-time model download, free)
- **Cloud AI**:
  - OpenAI: ~$0.01-0.03 per 1000 words
  - Claude: ~$0.015-0.04 per 1000 words
  - User pays directly via their API key

## Future Enhancements

### V2 Features

- Fine-tuned models on specific genres
- Multi-chapter generation planning
- Character dialogue generator (isolated)
- Scene expansion tool
- Rewrite suggestions
- Style transfer (rewrite in different style)

### Advanced Features

- Collaborative AI editing (back-and-forth)
- Plot hole detection and fixing
- Character consistency checking
- Automatic world-building expansion
- Genre-specific templates

## Dependencies

### Required Frameworks

- `Foundation` (built-in)
- `AppKit` (built-in)
- MLX Swift or llama.cpp (for local AI)
- `URLSession` (for cloud AI APIs)

### Optional Enhancements

- `NaturalLanguage` framework for quality checking
- `Combine` for reactive updates
- `CryptoKit` for API key encryption

## Testing Strategy

### Unit Tests

- Prompt builder correctness
- Element collection validation
- API client error handling

### Integration Tests

- Full generation pipeline
- UI workflow
- Model loading/unloading

### User Testing

- Generation quality assessment
- Performance on various Mac configurations
- User experience feedback
- Privacy concern verification

## Rollout Plan

### Beta Release

1. Local AI only
2. Limited to shorter stories (2000-5000 words)
3. Gather user feedback
4. Iterate on prompt quality

### Full Release

1. Add cloud AI options
2. Support longer generation
3. Multiple style presets
4. Advanced settings

## Risks and Mitigation

### Quality Concerns

- **Risk**: Generated stories may be low quality
- **Mitigation**: Allow regeneration, provide editing tools, set expectations

### Performance Issues

- **Risk**: Local models too slow on older Macs
- **Mitigation**: Detect hardware, recommend cloud for older devices

### Privacy Concerns

- **Risk**: Users uncomfortable with cloud AI
- **Mitigation**: Default to local, clear warnings, privacy-first design

### API Costs

- **Risk**: Users surprised by cloud API costs
- **Mitigation**: Show cost estimates, require explicit API key entry

## Success Metrics

- Generation speed < 30 seconds for 1000 words
- User satisfaction > 80%
- Acceptance rate of generated content > 50%
- Privacy concerns < 10% of users
- Performance good on Macs from 2020+

---

## Next Steps

To begin implementation:

1. Decide on local AI framework (MLX Swift recommended)
2. Create AIStoryGenerationWindow.swift
3. Implement StoryElementsCollector
4. Build prompt templates
5. Integrate with Navigator panel
6. Test with real story elements

This feature will transform QuillPilot from an analysis tool into a full writing assistant!
