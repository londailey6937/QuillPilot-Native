# QuillPilot Native macOS App

A powerful native macOS writing application with advanced story analysis, plot visualization, and character arc tracking.

## ✨ Features

### 📝 Core Writing

- **Native Text Editing**: Rock-solid NSTextView with undo/redo
- **Rich Text Formatting**: Bold, italic, fonts, colors
- **Document Management**: New, open, save, save as
- **Split View Interface**: Editor + analysis sidebar

### 📊 Advanced Analysis

- **Real-time Writing Analysis**:
  - Paragraph length and pacing
  - Passive voice detection
  - Adverb and weak verb identification
  - Sensory detail tracking
  - Cliché and filter word detection
  - Sentence variety scoring
  - Reading level calculation

### 💬 Dialogue Quality Analysis (10 Metrics)

Based on professional writing tips:

1. **Depth**: Checks for subtext vs. surface statements
2. **Repetition**: Identifies repeated phrases
3. **Filler Words**: Counts "uh", "um", "well"
4. **Monotony**: Detects same voice across characters
5. **Predictability**: Finds clichéd dialogue
6. **Character Growth**: Ensures purposeful dialogue
7. **Exposition**: Flags info-dumping
8. **Conflict**: Checks for tension and disagreement
9. **Emotional Resonance**: Analyzes emotional impact
10. **Pacing**: Measures sentence length variation

### 📈 Plot Point Visualization (NEW!)

- **Tension Arc Graph**: See story tension throughout manuscript
- **Plot Beat Detection**: Automatic identification of:
  - Inciting Incident
  - Rising Action
  - Pinch Points
  - Midpoint
  - Crisis
  - Climax
  - Resolution
- **Structure Score**: 0-100% rating of story structure
- **Interactive Charts**: Click plot points to jump to location in editor
- **Missing Beats Warning**: Identifies gaps in story structure

### 👥 Character Arc Tracking (NEW!)

Three powerful visualization modes:

1. **Emotional Journey Charts**:

   - Line graphs showing sentiment over time
   - Track positive/negative emotional states
   - Arc type detection (Positive/Negative/Flat/Transformational)
   - Arc strength scoring (0-100%)

2. **Character Network Graph**:

   - Bar charts of character co-appearances
   - Relationship strength calculation
   - Identify under-developed relationships

3. **Presence Heatmap**:
   - Grid showing character mentions per chapter
   - Color-coded intensity
   - Spot characters who disappear
   - Balance protagonist screen time

### 🎨 Story Construction Tools

- **Character Library**: Detailed character profiles
- **Theme Explorer**: Define and reference story themes
- **Story Outline**: Multi-part story structure template
- **Locations**: Document primary and secondary settings
- **Story Directions**: Explore multiple narrative possibilities

### 📚 Help & Documentation

- **QuillPilot Help**: Comprehensive feature guide
- **Dialogue Writing Tips**: 10 professional tips with examples

## 🖥️ System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel processor
- 4GB RAM minimum (8GB recommended for large manuscripts)
- ~100MB disk space

## 🚀 Quick Start

### Building from Source

1. **Clone the repository**:

   ```bash
   git clone https://github.com/londailey6937/QuillPilot-Native.git
   cd QuillPilot
   ```

2. **Build with Swift Package Manager**:

   ```bash
   swift build -c release
   ```

3. **Run the app**:
   ```bash
   swift run
   ```

### Using Xcode

1. Open `QuillPilot.xcodeproj` in Xcode
2. Select "QuillPilot" scheme
3. Build and run (⌘R)

## 📖 Usage Guide

### Writing Your Story

1. **Create a new document** or open existing
2. **Define your characters** in Character Library (Navigator → 👥 Characters)
3. **Set your theme** (Navigator → 🎭 Theme)
4. **Map locations** (Navigator → 📍 Locations)
5. **Explore story directions** (Navigator → 🔀 Story Directions)
6. **Write your manuscript** in the editor

### Analyzing Your Work

1. Open the right-side Analysis panel and click one of the icons:
   - **📊 Analysis**: Basic metrics and writing quality
   - **📖 Plot Structure**: Plot/structure visualization
   - **👥 Characters**: Character-focused tools
2. If results aren’t available yet, QuillPilot runs analysis automatically when you open an analysis view.
3. Use the popout windows to explore results.

### Understanding Visualizations

#### Plot Points Tab

- View tension arc across your story
- See detected story structure beats
- Check structure score (aim for 80%+)
- Click any plot point to jump to that location

#### Character Arcs Tab

- Switch between 3 chart types using segment control
- **Emotional Journey**: Track each character's sentiment
- **Character Network**: See who appears with whom
- **Presence Heatmap**: View character distribution by chapter

### Getting Help

- **Help Menu** → "QuillPilot Help": Feature documentation
- **Help Menu** → "Dialogue Writing Tips": Writing guidance
- **docs/** folder: Detailed guides and implementation docs

## 📁 Project Structure

```
QuillPilot/
├── Sources/
│   └── AppDelegate.swift              # App entry point
├── Controllers/
│   ├── MainWindowController.swift     # Main window + toolbar
│   ├── SplitViewController.swift      # Split view management
│   ├── EditorViewController.swift     # Text editor
│   ├── AnalysisViewController.swift   # Analysis display
│   └── CharacterLibraryViewController.swift
├── Models/
│   ├── AnalysisEngine.swift           # Text analysis engine
│   ├── PlotAnalysis.swift             # Plot point detection
│   ├── CharacterArcAnalysis.swift     # Character arc tracking
│   └── CharacterLibrary.swift         # Character data model
├── Views/
│   ├── PlotVisualizationView.swift    # Plot charts (Swift Charts)
│   ├── CharacterArcVisualizationView.swift  # Character charts
│   ├── DialogueTipsWindow.swift       # Help documentation
│   ├── LocationsWindow.swift          # Location templates
│   ├── StoryDirectionsWindow.swift    # Story direction templates
│   └── (11 view files total)
├── Utilities/
│   ├── ThemeManager.swift             # Color themes
│   └── StyleCatalog.swift             # Text styles
├── Extensions/
│   └── NSColor+Hex.swift              # Color utilities
├── Resources/
│   ├── Info.plist
│   ├── character_library.json         # Sample characters
│   └── docs/                          # Story content
└── docs/
    ├── VISUALIZATION_USER_GUIDE.md    # User guide for graphs
    ├── AI_STORY_GENERATION_IMPLEMENTATION.md  # AI feature plan
    └── AI_AND_ANALYSIS_FEATURES.md    # Feature specifications
```

## 🏗️ Architecture

- **Pattern**: Model-View-Controller (MVC)
- **UI Framework**: AppKit (native macOS)
- **Text Engine**: NSTextView (bulletproof, native)
- **Visualization**: SwiftUI + Swift Charts (macOS 13+)
- **Analysis**: Custom algorithms + NLP patterns
- **Threading**: Background analysis, main thread UI

## 🔬 Technical Details

### Analysis Algorithms

- **Tension Detection**: 100+ tension/action/revelation words
- **Sentiment Analysis**: 300+ emotion words with polarity
- **Plot Structure**: Heuristic-based beat detection
- **Character Tracking**: Name extraction + context analysis

### Performance

- Analysis: ~1-5 seconds for 50K words
- Visualization: Real-time rendering with Swift Charts
- Memory: Efficient text processing, <200MB for large documents

### Data Privacy

- All analysis happens on-device
- No data sent to servers
- No tracking or telemetry
- Character library stored locally

## 🚧 Coming Soon

### AI Story Generation

- Local AI models (MLX Swift)
- Cloud AI options (OpenAI, Claude)
- Generate stories from story elements
- See `docs/AI_STORY_GENERATION_IMPLEMENTATION.md`

### Additional Features

- Export visualizations as images
- Compare multiple drafts
- Scene-level analysis
- Dialogue network graphs
- Pacing visualization

## 🤝 Contributing

This is currently a personal project. Feature requests and bug reports welcome via GitHub Issues.

## 📄 License

Copyright © 2025 QuillPilot Team. All rights reserved.

## 🙏 Acknowledgments

- Dialogue tips based on professional writing resources
- Plot structure inspired by Save the Cat and Hero's Journey
- Character arc theory based on narrative psychology

---

**Built with ❤️ for writers who love data**

- Native text editing stability
- Analysis engine architecture
- UI layout matching web version
- Brand consistency

Future enhancements:

- Document persistence
- Export to DOCX/PDF
- More analysis features
- Preferences/settings
- Auto-save functionality

## Color Scheme

Matches QuillPilot web app:

- Primary Orange: #ef8432
- Navy: #2c3e50
- Cream Background: #fef5e7
- Light Cream: #fffaf3

## License

Copyright © 2025 QuillPilot. All rights reserved.
