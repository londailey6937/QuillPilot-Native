//
//  DocumentationWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import WebKit

class DocumentationWindowController: NSWindowController {

    private var tabView: NSTabView!
    private var scrollViews: [NSScrollView] = []
    private var textViews: [NSTextView] = []

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuillPilot Help"
        window.minSize = NSSize(width: 700, height: 500)

        self.init(window: window)
        setupUI()
        loadDocumentation()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true

        // Create tab view
        tabView = NSTabView(frame: contentView.bounds)
        tabView.autoresizingMask = [.width, .height]
        tabView.tabViewType = .topTabsBezelBorder

        // Create tabs
        createTab(title: "📝 Getting Started", identifier: "start")
        createTab(title: "📊 Analysis Tools", identifier: "analysis")
        createTab(title: "👥 Character Features", identifier: "characters")
        createTab(title: "📖 Plot & Structure", identifier: "plot")
        createTab(title: "⌨️ Shortcuts", identifier: "shortcuts")

        contentView.addSubview(tabView)
        window.contentView = contentView

        applyTheme()
    }

    private func createTab(title: String, identifier: String) {
        let tabViewItem = NSTabViewItem(identifier: identifier)
        tabViewItem.label = title

        let scrollView = NSScrollView(frame: tabView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: scrollView.bounds.width - 40, height: 0))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        tabViewItem.view = scrollView

        tabView.addTabViewItem(tabViewItem)
        scrollViews.append(scrollView)
        textViews.append(textView)
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme
        for (index, textView) in textViews.enumerated() {
            textView.backgroundColor = theme.pageAround
            textView.textColor = theme.textColor
            scrollViews[index].backgroundColor = theme.pageAround
        }
    }

    private func loadDocumentation() {
        loadStartTab()
        loadAnalysisTab()
        loadCharactersTab()
        loadPlotTab()
        loadShortcutsTab()
    }

    // MARK: - Tab 1: Getting Started

    private func loadStartTab() {
        guard textViews.count > 0 else { return }
        let textView = textViews[0]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Welcome to QuillPilot", color: titleColor))
        content.append(makeBody("""
QuillPilot is a professional writing application designed for novelists, screenwriters, and authors. It combines powerful editing tools with advanced manuscript analysis.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🎨 Format Painter", color: headingColor))
        content.append(makeBody("""
Copy formatting from one text selection and apply it to another.

How to use:
1. Select text with the formatting you want to copy
2. Click the Format Painter button (🖌️) in the toolbar
3. The cursor changes to indicate Format Painter is active
4. Click or drag to select the text where you want to apply the formatting
5. The formatting is applied automatically

What it copies:
• Font family and size
• Bold, italic, underline
• Text color
• Paragraph alignment
• Line spacing and indentation
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("✍️ Paragraph Styles", color: headingColor))
        content.append(makeBody("""
Apply professional formatting with one click using the Styles dropdown.

Fiction Styles:
• Book Title, Author Name, Chapter Title
• Body Text, Body Text – No Indent
• Dialogue, Internal Thought
• Scene Break, Epigraph, and more

Non-Fiction Styles:
• Heading 1, 2, 3
• Body Text, Block Quote
• Callout, Sidebar
• Figure/Table Captions

Customize styles: Click the ⚙️ button next to Styles to open the Style Editor.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🔍 Find & Replace", color: headingColor))
        content.append(makeBody("""
Quickly find and replace text throughout your document.

1. Click the 🔍 button in the toolbar
2. Enter text to find
3. (Optional) Enter replacement text
4. Choose options:
   • Case sensitive
   • Whole words only

Buttons:
• Previous/Next - Navigate through matches
• Replace - Replace current selection
• Replace All - Replace all at once

The replacement preserves your text formatting.
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Tab 2: Analysis Tools

    private func loadAnalysisTab() {
        guard textViews.count > 1 else { return }
        let textView = textViews[1]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Document Analysis Features", color: titleColor))
        content.append(makeBody("""
Click "Analyze Document" in the toolbar to generate real-time feedback on your writing.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📊 Basic Metrics", color: headingColor))
        content.append(makeBody("""
• Word Count - Total words in your document
• Sentence Count - Number of sentences
• Paragraph Count - Number of paragraphs
• Reading Level - Flesch-Kincaid grade level
• Average Sentence Length - Words per sentence
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📝 Writing Quality", color: headingColor))
        content.append(makeBody("""
Passive Voice Detection
• Shows percentage of passive constructions
• Highlights "was," "were," "been" patterns
• Target: Keep below 10% for most genres

Adverb Usage
• Counts -ly adverbs
• Shows examples and locations
• Helps strengthen verb choices

Weak Verbs
• Detects: is, was, get, make, etc.
• Suggests stronger alternatives
• Context matters—not all are bad

Clichés & Overused Phrases
• Identifies common clichés
• "low-hanging fruit," "think outside the box"
• Helps keep writing fresh

Filter Words
• Perception words that distance readers
• saw, felt, thought, realized, wondered
• Show, don't tell principle

Sensory Details
• Balance of sight, sound, touch, taste, smell
• Shows sensory distribution chart
• Helps immerse readers
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📖 Sentence Variety", color: headingColor))
        content.append(makeBody("""
Visual graph showing distribution of:
• Short sentences (1-10 words)
• Medium sentences (11-20 words)
• Long sentences (21-30 words)
• Very long sentences (31+ words)

Good variety = engaging rhythm
Too uniform = monotonous reading
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("💬 Dialogue Analysis", color: headingColor))
        content.append(makeBody("""
10 comprehensive metrics for dialogue quality:

Filler Word Percentage - um, uh, like, you know
Repetition Detection - overused phrases in dialogue
Clichéd Phrases - avoid predictable dialogue
Exposition Levels - info-dumping in conversation
Conflict Presence - tension and disagreement
Pacing Variety - rhythm of exchanges
Tag Variety - "said" alternatives
Subtext Quality - what's unsaid
Authenticity Score - sounds like real speech
Balance - distribution among characters
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Tab 3: Character Features

    private func loadCharactersTab() {
        guard textViews.count > 2 else { return }
        let textView = textViews[2]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Character Analysis Tools", color: titleColor))
        content.append(makeBody("""
Access character analysis from the right panel Navigator (👥) or after running "Analyze Document."
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("👥 Character Library", color: headingColor))
        content.append(makeBody("""
Central repository for all character information.

Location: Click 👥 in the Navigator panel

Features:
• Create detailed character profiles
• Store physical descriptions
• Track character roles (Protagonist, Antagonist, Supporting, Minor)
• Document motivations and backstory
• Add character relationships
• Define character arcs

To use:
1. Click 👥 Characters in Navigator
2. Opens dedicated Character Library window
3. Add/Edit/Delete characters
4. Saved automatically as JSON
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📈 Emotional Trajectory", color: headingColor))
        content.append(makeBody("""
Visualize character emotional states throughout your story.

Access: Analyze Document → Characters tab → 📈 Emotional Trajectory

Features:
• Multi-character overlay with color coding
• Four emotional metrics:
  - Confidence (Low to High)
  - Hope vs Despair
  - Control vs Chaos
  - Attachment vs Isolation

• Continuous line plots showing progression
• Dropdown to switch between metrics
• Solid lines = Surface behavior (what character shows)
• Dashed lines = Subtext (internal emotional state)

How Subtext Works:
The first character (typically protagonist) shows TWO lines:
• Solid line - External appearance and behavior
• Dashed line - Hidden feelings and true emotional state

Example: Character may appear confident (solid line high) while internally feeling uncertain (dashed line low). This gap shows emotional complexity and hidden struggles.

The phase shift and negative offset reveal:
• Hidden insecurity behind confidence
• More pessimism than shown outwardly
• Less control than projected
• Greater isolation than appears

This visualization helps identify:
• Character emotional arcs
• Moments of crisis and growth
• Discrepancy between appearance and reality
• Opportunities for revealing subtext in prose
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📊 Decision-Belief Loops", color: headingColor))
        content.append(makeBody("""
Tracks how character decisions reinforce or challenge their beliefs.

Access: Analyze Document → Characters tab → 📊 Decision-Belief Loops

Shows:
• Key character decisions in the story
• Underlying beliefs driving those decisions
• Whether decisions strengthen or weaken beliefs
• Pattern of character growth or stagnation

Useful for:
• Ensuring character development
• Identifying stuck characters
• Planning character arc progression
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📋 Belief Shift Matrix", color: headingColor))
        content.append(makeBody("""
Table format tracking character belief evolution through chapters.

Access: Analyze Document → Characters tab → 📋 Belief Shift Matrix

Columns:
• Chapter - Where the belief appears
• Core Belief - Character's worldview at that point
• Evidence - Actions/decisions reflecting the belief
• Counterpressure - Forces challenging the belief

Evolution Quality Badge:
• Logical Evolution - Clear pressures causing belief shifts
• Developing - Some belief shifts occurring
• Unchanging - Beliefs remain static
• Insufficient Data - Not enough entries to assess

Perfect for:
• Theme-driven fiction where evolution must be logical
• Literary fiction emphasizing internal change
• Ensuring character growth isn't just emotional
• Planning belief arc progression
• Identifying weak character development
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("⛓️ Decision-Consequence Chains", color: headingColor))
        content.append(makeBody("""
Maps choices, not traits. Ensures growth comes from action, not narration.

Access: Analyze Document → Characters tab → ⛓️ Decision-Consequence Chains

Structure:
• Chapter → Decision → Immediate Outcome → Long-term Effect

Shows visual flow arrows connecting each decision to its consequences.

Agency Assessment Badge:
• Active Protagonist - Character drives the story
• Developing - Good balance of action and consequence
• Reactive - Some agency, needs strengthening
• Passive - Character reacts, doesn't act (warning)
• Insufficient Data - Not enough entries to assess

Use when:
• You want to ensure growth comes from action, not narration
• You're diagnosing passive protagonists
• Planning causal evolution maps
• Tracking how character is shaped by agency
• Identifying where character needs more active choices

Perfect for ensuring your protagonist is making decisions that matter
and those decisions have real, lasting consequences on their journey.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🤝 Character Interactions", color: headingColor))
        content.append(makeBody("""
Analyzes relationships and scenes between characters.

Access: Analyze Document → Characters tab → 🤝 Character Interactions

Features:
• Network graph of character relationships
• Frequency of interactions
• Strength of relationships (0-100%)
• Identifies isolated characters
• Shows relationship dynamics

Helps with:
• Balancing character screen time
• Finding missing relationship development
• Ensuring subplot integration
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📍 Character Presence", color: headingColor))
        content.append(makeBody("""
Heat map showing which characters appear in which chapters.

Access: Analyze Document → Characters tab → 📍 Character Presence

Displays:
• Grid: Rows = Characters, Columns = Chapters
• Color intensity = mention frequency
• Numbers show exact count per chapter
• Sorted by total presence

Use cases:
• Spot characters who disappear mid-story
• Balance POV distribution
• Plan chapter focus
• Ensure consistent character presence
• Track subplot threads
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Tab 4: Plot & Structure

    private func loadPlotTab() {
        guard textViews.count > 3 else { return }
        let textView = textViews[3]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Plot Structure Analysis", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("📖 Plot Points Visualization", color: headingColor))
        content.append(makeBody("""
Access: Analyze Document → 📊 Graphs tab → Plot Points

Features:
• Tension Arc - Line graph showing story tension over time
• 9 Key Story Beats - Automatically detected plot points
• Structure Score - Overall rating (0-100%)
• Missing Beats Warning - Identifies structural gaps

The 9 Key Plot Points:
🎬 Inciting Incident (~12%) - Event that kicks off the story
📈 Rising Action (~20%) - Building tension and stakes
⚡️ First Pinch Point (~37%) - First major obstacle
🔄 Midpoint (~50%) - Major revelation or turning point
⚡️ Second Pinch Point (~62%) - Second major challenge
💥 Crisis (~75%) - Point of no return
🔥 Climax (~88%) - Highest tension, final confrontation
📉 Falling Action (~93%) - Immediate aftermath
✨ Resolution (~98%) - Story conclusion

Interactive Features:
• Click any plot point to jump to that location in your editor
• Hover over points to see tension level and position
• View detailed beat information in the list below

Tension Calculation:
The analyzer looks for:
• Action words: grabbed, attacked, ran, fired
• Tension words: danger, fear, urgent, desperate
• Revelation words: discovered, realized, betrayal, secret

Structure Score Guide:
90-100%: Excellent structure, all beats present
70-89%: Good structure, minor improvements possible
50-69%: Adequate structure, some beats may be weak
Below 50%: Consider restructuring
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📊 Story Outline", color: headingColor))
        content.append(makeBody("""
Access: Click 📖 in Navigator panel

Features:
• Hierarchical outline based on your styles
• Chapter, section, and scene organization
• Click any entry to navigate to that section
• Live updates as you write
• Uses Chapter Title, Heading styles

Perfect for:
• Quick navigation in long manuscripts
• Structural overview
• Finding specific scenes
• Reorganization planning
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🗺️ Locations & Directions", color: headingColor))
        content.append(makeBody("""
Track settings and story progression.

Locations (🗺️ in Navigator):
• Create location profiles
• Add descriptions and details
• Track scenes set in each location
• Maintain setting consistency

Story Directions (🧭 in Navigator):
• Define story direction and goals
• Track thematic elements
• Document narrative throughlines
• Plan story progression
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Tab 5: Keyboard Shortcuts

    private func loadShortcutsTab() {
        guard textViews.count > 4 else { return }
        let textView = textViews[4]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Keyboard Shortcuts", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("📄 File Operations", color: headingColor))
        content.append(makeBody("""
⌘N - New document
⌘O - Open document
⌘S - Save document
⌘P - Print
⌘W - Close window
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("✂️ Editing", color: headingColor))
        content.append(makeBody("""
⌘Z - Undo
⌘⇧Z - Redo
⌘X - Cut
⌘C - Copy
⌘V - Paste
⌘A - Select All
⌘F - Find & Replace
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📝 Formatting", color: headingColor))
        content.append(makeBody("""
⌘B - Bold
⌘I - Italic
⌘U - Underline
⌘T - Font panel
⌘[ - Align left
⌘] - Align right
⌘\\ - Align center
⌘E - Center text
⌘{ - Decrease indent
⌘} - Increase indent
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🔍 Navigation", color: headingColor))
        content.append(makeBody("""
⌘↑ - Move to beginning of document
⌘↓ - Move to end of document
⌘← - Move to beginning of line
⌘→ - Move to end of line
⌥← - Move backward one word
⌥→ - Move forward one word

Add ⇧ (Shift) to select while moving
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🪟 Window Management", color: headingColor))
        content.append(makeBody("""
⌘M - Minimize window
⌘` - Cycle through windows
⌘? - Show this help (QuillPilot Help)
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("💡 Tips", color: headingColor))
        content.append(makeBody("""
• Use ⌥ (Option) with arrow keys for word-by-word navigation
• Combine ⇧ (Shift) with navigation for precise selections
• Format Painter (🖌️) works great with keyboard selections
• Press Enter in Find dialog to find next match
• Use ⌘F to quickly search your document
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Helper Methods

    private func makeTitle(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text + "\n\n", attributes: attributes)
    }

    private func makeHeading(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text + "\n\n", attributes: attributes)
    }

    private func makeBody(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeNewline() -> NSAttributedString {
        return NSAttributedString(string: "\n")
    }
}
