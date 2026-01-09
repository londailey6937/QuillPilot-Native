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
        createTab(title: "� Why QuillPilot?", identifier: "why")
        createTab(title: "📊 Analysis Tools", identifier: "analysis")
        createTab(title: "👥 Character Features", identifier: "characters")
        createTab(title: "📖 Plot & Structure", identifier: "plot")
        createTab(title: "🎬 Scenes", identifier: "scenes")
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
        loadWhyTab()
        loadAnalysisTab()
        loadCharactersTab()
        loadPlotTab()
        loadScenesTab()
        loadShortcutsTab()
    }

        // MARK: - Tab: Why QuillPilot?

    private func loadWhyTab() {
        guard textViews.count > 0 else { return }
        let textView = textViews[0]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Why QuillPilot?", color: titleColor))
        content.append(makeBody("""
QuillPilot is a writing environment that prioritizes how words feel on the page, not just how they're organized in a project. It's designed for experienced fiction writers who already understand story structure and want tools that enhance execution, not manage exploration.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("What Makes QuillPilot Different", color: headingColor))
        content.append(makeNewline())

        content.append(makeHeading("Output-First Writing", color: headingColor))
        content.append(makeBody("""
What you see is what you submit. No compile step. No export-format-revise cycle.

For professional novelists, this changes how you judge pacing, feel paragraph density, evaluate dialogue rhythm, and spot visual monotony. The manuscript you write is the manuscript you send.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Typography as a Writing Tool", color: headingColor))
        content.append(makeBody("""
Good typography reduces cognitive load, improves rereading accuracy, and makes structural problems visible earlier.

QuillPilot treats typography as part of thinking on the page—not output polish. Professional templates (Baskerville, Garamond, Hoefler Text) give your manuscript submission-quality presentation while you draft.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Integrated Narrative Intelligence", color: headingColor))
        content.append(makeBody("""
Your analysis tools don't live in spreadsheets or notebooks—they surface structure automatically:

• Belief shift tracking across character arcs
• Tension curve visualization over time
• Relationship evolution mapping
• Scene-level decision consequence chains
• Emotional trajectory analysis

QuillPilot replaces the external bookkeeping that serious novelists already maintain, making patterns visible without breaking your writing flow.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Who QuillPilot Is For", color: headingColor))
        content.append(makeNewline())

        content.append(makeHeading("Choose QuillPilot if you:", color: headingColor))
        content.append(makeBody("""
• Write primarily novels or screenplays
• Already understand story structure
• Care how the page looks while you write
• Want insight, not organization
• Submit to agents or publishers regularly
• Prefer writing in a finished-looking manuscript
• Value execution refinement over project management
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("QuillPilot is NOT trying to:", color: headingColor))
        content.append(makeBody("""
• Manage research PDFs or web archives
• Handle citations or footnotes
• Compile into multiple output formats
• Serve as a universal project manager
• Replace Scrivener's binder system

These are legitimate needs—but they're not what QuillPilot optimizes for.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("The Real Comparison", color: headingColor))
        content.append(makeBody("""
Many professional fiction writers use:
• Scrivener for planning, research, and complex projects
• QuillPilot for drafting and final manuscripts

QuillPilot replaces the moment when you export from project management tools and say: "Okay, now let me make this look and read right."

If that's the moment you care about most, QuillPilot wins.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Writer Seniority Matters", color: headingColor))
        content.append(makeBody("""
QuillPilot feels "simpler" because it assumes you already know how to write. It doesn't teach story structure—it helps you execute it precisely and consistently.

Early-stage writers benefit from tools that help them think in chunks and move things around.

Mid-to-late career fiction writers benefit from tools that refine execution, maintain consistency, and reduce cognitive overhead.

QuillPilot is for the latter.
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
Open analysis from the right-side Analysis panel:
• Click 📊 (Analysis) to open the main analysis popout
• Click 📖 (Plot Structure) for plot/structure visualizations
• Click 👥 (Characters) for character-focused tools

If results aren’t available yet, QuillPilot runs analysis automatically the first time you open any analysis view.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Built-in macOS Writing Tools (Apple)", color: headingColor))
        content.append(makeBody("""
Some Macs include system-provided Writing Tools (sometimes shown as Proofread, Rewrite, Summarize, etc.). If you see this panel while editing, it’s provided by macOS — not by QuillPilot.

How to use it:
• Select text in the editor
• Control-click (or right-click) the selection
• Choose Writing Tools, then pick an option (Proofread, Rewrite, Summarize, etc.)

Availability depends on your macOS version, device support, language/region, and whether the feature is enabled in System Settings.
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
Character analysis lives in the right-side Analysis panel (👥). If results aren’t available yet, QuillPilot runs analysis automatically when you open a character tool.
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

Access: Right panel → 👥 Characters → 📈 Emotional Trajectory

Features:
• Multi-character overlay with color coding
• Four emotional metrics:
  - Confidence (Low to High)
  - Hope vs Despair
  - Control vs Chaos
  - Attachment vs Isolation

• Continuous line plots showing progression
• Dropdown to switch between metrics
• X-axis = progress through the document (0% → 100%)
• Y-axis = the selected metric (top = higher, bottom = lower)
• Solid lines = surface behavior (what the character shows)
• Dashed lines = subtext/internal state (what they feel or believe underneath)

How to interpret the curves:
• Look for changes (rises/drops), not exact numbers.
• Sudden shifts often indicate a turning point, revelation, or setback.
• Crossovers between characters (or between a character’s surface vs subtext) often indicate conflict, reversal, or a masked emotional state.
• Small vertical separation between lines can be visual spacing to reduce overlap—treat the overall trend as the signal.

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

Access: Right panel → 👥 Characters → 📊 Decision-Belief Loops

What the framework is tracking (per chapter):
• Pressure — new forces acting on the character (conflict, dilemma, constraint)
• Belief in Play — the value/worldview being tested
• Decision — the choice made because of (or against) that belief
• Outcome — the immediate result of that decision
• Belief Shift — how the belief changes (reinforced, refined, reversed)

How to use it (fast):
1) Start with your protagonist.
2) Scan for rows with 2+ empty cells.
3) Open that chapter/scene and ask: “What is the pressure? What is the choice? What does it cost?”
4) Revise, then re-run analysis.

Empty cells: what they usually mean (and how to address them)

Pressure is empty
• Meaning: the chapter may be low-conflict, transitional, or the character isn’t under new constraints.
• Fix: add a clear complication (deadline, obstacle, ultimatum, temptation, new information) that forces tradeoffs.

Belief in Play is empty
• Meaning: the chapter may show events but not the character’s values/assumptions driving interpretation.
• Fix: surface the belief via (a) a stated principle, (b) an internal line of reasoning, or (c) a choice that clearly implies a value (“I won’t do X even if…”).

Decision is empty
• Meaning: the character may be reacting, being carried by plot, or the choice isn’t explicit.
• Fix: convert “things happen” into “they choose”: give the character a fork (A vs B), then commit to an action with a verb that changes the situation.

Outcome is empty
• Meaning: decisions may not be producing visible consequences on-page.
• Fix: show the immediate result (pushback, fallout, gain/loss, relationship change, new problem created). If the consequence is delayed, add a small immediate ripple.

Belief Shift is empty
• Meaning: the character’s worldview may be unchanged (which can be fine in setup chapters), or the story isn’t showing reflection/learning.
• Fix: add a moment where the character updates their model of the world: a realization, rationalization, doubt, or a stated new rule going forward.

Important note:
Not every chapter needs all five elements. Too many empty cells across many chapters, however, usually correlates with flat arcs, passive protagonists, or consequences that aren’t dramatized.

Character Arc Timeline (legend):
• Chapters are shown as labels (rows or "Ch #").
• Dots appear when an element is detected in that chapter.
• Dot colors help you classify what kind of change is happening (they are not chapter colors).
• Dashed connectors typically indicate a likely regression/negative shift between chapters.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📋 Belief Shift Matrix", color: headingColor))
        content.append(makeBody("""
Table format tracking character belief evolution through chapters.

Access: Right panel → 👥 Characters → 📋 Belief Shift Matrix

Columns:
• Chapter - Where the belief appears
• Core Belief - Character's worldview at that point
• Evidence - Actions/decisions reflecting the belief
• Counterpressure - Forces challenging the belief

How this ties to the Decision–Belief Loop:
• Counterpressure ≈ Pressure (the force pushing against the belief)
• Evidence ≈ Decision + Outcome (what they did, and what happened because of it)
• Changes across rows ≈ Belief Shift (how the belief updates over time)

How to use it (fast):
1) Pick one character.
2) Read down the Core Belief column and ask: “Is this belief changing in a believable way?”
3) For any row that feels "hand-wavy", jump to that chapter and strengthen either the Evidence (action) or the Counterpressure (stress test).
4) Re-run analysis and confirm the row reads like cause → effect.

Empty cells: what they usually mean (and how to address them)

Core Belief is empty
• Meaning: the chapter may not reveal what the character thinks is true/important.
• Fix: add a line of principle, a value-laden choice, or a reaction that implies the belief (“I don’t trust X”, “People always…”, “I won’t…”).

Evidence is empty
• Meaning: the belief is stated/assumed but not demonstrated through action.
• Fix: add a decision with a visible cost, or show a concrete behavior that expresses the belief (avoid purely explanatory narration).

Counterpressure is empty
• Meaning: the belief is not being challenged, so it can’t meaningfully evolve.
• Fix: introduce an opposing force: a person contradicts it, reality disproves it, the character faces a dilemma where the belief causes harm, or a new constraint makes the belief harder to live by.

Many rows are empty
• Meaning: your manuscript may have character moments, but not enough on-page causality (pressure → choice → consequence → revised belief).
• Fix: use the Decision–Belief Loop view to identify where the chain breaks, then revise the scene to add the missing link(s).

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

Access: Right panel → 👥 Characters → ⛓️ Decision-Consequence Chains

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

Access: Right panel → 👥 Characters → 🤝 Character Interactions

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

Access: Right panel → 👥 Characters → 📍 Character Presence

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
        content.append(makeNewline())

        content.append(makeHeading("🔗 Relationship Evolution Maps", color: headingColor))
        content.append(makeBody("""
Network diagram visualizing character relationships and their evolution.

Access: Right panel → 👥 Characters → 🔗 Relationship Evolution Maps

Visual Elements:
• Nodes = Characters (size = emotional investment %)
• Lines = Relationships (thickness = trust/conflict strength)
• Green lines = Trust relationships
• Red/Orange lines = Conflict relationships
• Gray lines = Neutral relationships
• Arrows = Power direction between characters

How to Read:
• Larger nodes = Characters with more emotional investment
• Thicker lines = Stronger relationships (positive or negative)
• Arrow direction shows who holds more power/influence
• Hover percentages show exact investment values

Interactive Features:
• Drag nodes to rearrange the layout
• Nodes snap to reasonable positions
• Edges follow as you move nodes

Great for:
• Mentor/rival dynamics - See power imbalances
• Romance arcs - Track trust building or breaking
• Ensemble casts - Balance relationship networks
• Finding isolated characters
• Identifying missing relationship development
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🎭 Internal vs External Alignment", color: headingColor))
        content.append(makeBody("""
Track the gap between who characters are inside and how they act.

Access: Right panel → 👥 Characters → 🎭 Internal vs External Alignment

Two Parallel Tracks:
• Purple line = Inner Truth (what they feel/believe)
• Teal line = Outer Behavior (what they show/do)

Gap Interpretation:
• Wide gap = Denial, repression, or masking
• Narrow gap = Authenticity or integration
• Gap closing = Character becoming more authentic OR collapsing

Fill Color Meanings:
• Red fill = Gap widening (Denial/Repression)
• Yellow fill = Gap stabilizing (Coping)
• Green fill = Gap closing (Integration)
• Orange fill = Gap closing (Collapse - negative outcome)
• Gray fill = Gap fluctuating

Gap Trend Badge:
• Widening (Denial/Repression) - Character increasingly masking
• Stabilizing (Coping) - Character maintaining a consistent mask
• Closing (Integration) - Character becoming more authentic
• Closing (Collapse) - Character's facade breaking down negatively
• Fluctuating - Inconsistent pattern

Especially useful for:
• Unreliable narrators - Track their inner vs presented self
• Restrained prose - Visualize what's unsaid
• Characters who "say the right thing" while feeling opposite
• Psychological complexity and subtext
• Identifying moments of breakthrough or breakdown

Character Selection:
• Click character names at bottom to switch between characters
• Compare different characters' alignment patterns
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📝 Language Drift Analysis", color: headingColor))
        content.append(makeBody("""
Track how character's language changes — reveals unconscious growth.

Access: Right panel → 👥 Characters → 📝 Language Drift Analysis

Five Metrics Tracked:

1. Pronouns (I vs We)
   • Purple line = "I/my/mine" usage
   • Teal line = "we/our/us" usage
   • I → We shift = Community growth, connection
   • We → I shift = Isolation, independence

2. Modal Verbs (Must vs Choose)
   • Red line = Obligation modals (must, have to, need to, should)
   • Green line = Choice modals (choose, can, could, want to)
   • Must → Choose = Growing agency and autonomy
   • Choose → Must = Increasing external pressure

3. Emotional Vocabulary
   • Single pink line showing emotional word density
   • Increasing = Character opening up emotionally
   • Decreasing = Character becoming guarded

4. Sentence Length
   • Single indigo line (normalized 0-100%)
   • Longer sentences = More complex, deliberate thought
   • Shorter sentences = Urgency, certainty, or stress

5. Certainty Level
   • Single orange line
   • Higher = More "know/certain/always/definitely"
   • Lower = More "maybe/perhaps/might/wonder"
   • Rising certainty = Growing confidence
   • Falling certainty = Increasing doubt

Drift Summary Badges:
• I → We / We → I - Pronoun shift detected
• Must → Choose / Choose → Must - Modal shift detected
• More Certain / Less Certain - Certainty trend
• Increasing / Decreasing / Stable - Emotional trend
• Longer / Shorter / Stable - Sentence trend

This analysis is computational and often reveals:
• Growth patterns you didn't consciously plan
• Voice consistency issues across chapters
• Psychological shifts in character mindset
• Authentic emotional arc development

Interactive Features:
• Click metric tabs to switch between views
• Click character names to switch characters
• Badges highlight significant shifts
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
Access: Right panel → 📖 Plot Structure → Plot Points

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

        content.append(makeHeading("🎚️ Understanding Tension", color: headingColor))
        content.append(makeBody("""
What the % means
• Tension is normalized per story (0–100%) from sentence/beat-level signals: stakes, conflict verbs, reversals, momentum, and peril vocabulary.
• 25% = low relative tension for THIS manuscript, not an industry standard; 75% = high pressure relative to your own quietest passages.

How the curve is built
• We score each segment, smooth spikes, and clamp to keep extreme outliers from flattening the rest.
• Novel view auto-tightens the Y-axis to your data so quiet fiction doesn’t hug the bottom; screenplays default to the full 0–100 range for clearer pacing spikes.

Reading the graph
• Look for rises: conflicts, reveals, and reversals should trend upward into the midpoint and act turns.
• Look for resets: valleys after climaxes show aftermath; long flat stretches can indicate low narrative momentum.
• Use the beat markers: hover or click a beat to jump to that section and confirm the tension change is earned in the prose.

Common checks
• Novel: If the curve lives under 30%, add micro-conflicts or sharper reversals; aim for a visible slope into midpoint and crisis.
• Screenplay: Ensure pinch points and climax sit clearly above the mid-line; if peaks clip near 100%, the chart adds headroom so labels stay readable.
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

    // MARK: - Tab 5: Scenes

    private func loadScenesTab() {
                guard textViews.count > 4 else { return }
                let textView = textViews[4]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Scene Management", color: titleColor))
        content.append(makeBody("""
Scenes provide a semantic spine for your story—organizational metadata that helps you track, analyze, and navigate your manuscript without touching the text itself.

Access: Click 🎬 Scenes in the Navigator panel (right sidebar)

IMPORTANT: Scenes are created manually, NOT extracted from your document. You create each scene by clicking the + button and filling in the details. This gives you complete control over how you organize your story structure.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🚀 Quick Start: Creating Your First Scene", color: headingColor))
        content.append(makeBody("""
1. Click 🎬 Scenes in the Navigator panel (right sidebar)
2. In the Scene List window, click the + button
3. A new scene appears titled "New Scene"
4. Double-click the scene (or select it and click ℹ︎)
5. The Scene Inspector opens—fill in the details:
   • Give it a meaningful title
   • Choose the scene's intent (Setup, Conflict, etc.)
   • Add POV character, location, characters present
   • Fill in Goal, Conflict, and Outcome
   • Add any notes for yourself
6. Click Save
7. The scene is now in your list!

Scenes are saved automatically and persist between sessions.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🎬 What Are Scenes?", color: headingColor))
        content.append(makeBody("""
Scenes in QuillPilot are metadata containers—they track information ABOUT your story without storing or modifying your actual text. Think of them as index cards for your manuscript.

Each scene can track:
• Title - A memorable name for the scene
• Intent - The scene's narrative purpose
• Status - Draft, Revised, Polished, Final, or Needs Work
• POV Character - Who's telling this scene
• Location - Where the scene takes place
• Time - When the scene occurs
• Characters - Who appears in this scene
• Goal - What the POV character wants
• Conflict - What opposes the goal
• Outcome - Success, failure, or complication
• Summary - Brief description of events
• Notes - Your working notes and reminders

IMPORTANT: Scenes are 100% optional. They're designed for writers who want organizational tools without forcing structure on anyone during drafting.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📋 Scene List Window", color: headingColor))
        content.append(makeBody("""
The Scene List shows all your scenes in order with key information at a glance.

To Open:
1. Click 🎬 Scenes in the Navigator panel
2. The Scene List window appears
3. Click "+" to add a new scene
4. Double click the new scene to open the new scene window
5. Re-title the new scene; complete the fields, and click Save

Scene List Features:
• Each row shows status icon, title, intent, and order number
• Double-click any scene to open the Inspector
• Drag and drop scenes to reorder them
• Use + button to add new scenes
• Use − button to delete selected scene
• Use ℹ︎ button to open Inspector for selected scene

The footer shows your scene count (e.g., "5 scenes")
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🔍 Filtering Scenes", color: headingColor))
        content.append(makeBody("""
Use the filter bar at the top of the Scene List to find specific scenes quickly.

Two Filter Dropdowns:

1. Status Filter
   • All States - Show everything
   • ✏️ Draft - First-pass scenes
   • 📝 Revised - Scenes you've edited
   • ✨ Polished - Nearly finished scenes
   • ✅ Final - Locked and complete
   • ⚠️ Needs Work - Flagged for attention

2. Intent Filter
   • All Intents - Show everything
   • Setup, Conflict, Resolution
   • Transition, Climax, Denouement
   • Exposition, Rising Action, Falling Action

Filter Behavior:
• When filtering, the count shows "3/10 scenes" format
• Drag-drop reordering is disabled during filtering
• Order numbers show original position, not filtered position
• Clear filters by selecting "All States" and "All Intents"

Filtering Use Cases:
• Find all scenes that need work
• Review only climax/resolution scenes
• Check POV balance across scenes
• Focus on specific story phases
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📝 Scene Inspector", color: headingColor))
        content.append(makeBody("""
The Inspector is where you edit all scene metadata in detail.

To Open:
• Double-click a scene in the list
• Or select a scene and click the ℹ︎ button

Inspector Sections:

Basic Information:
• Title - Give your scene a memorable name
• Intent - Choose from dropdown (Setup, Conflict, etc.)
• Status - Track revision progress
• POV - Point of view character
• Location - Where the scene happens
• Time - Time of day or period
• Characters - Comma-separated list of who appears

Dramatic Elements:
These fields help you track the core dramatic structure:

• Goal - What does the POV character want in this scene?
  Example: "Find the hidden letter before midnight"

• Conflict - What opposes the goal?
  Example: "The house is guarded and the letter is locked away"

• Outcome - How does it resolve?
  Examples: "Yes, but..." / "No, and..." / "Complication"

These three fields (Goal/Conflict/Outcome) are the heart of scene-level dramatic structure. Every scene should ideally have all three.

Notes Section:
• Freeform text area for any scene notes
• Working thoughts, research, reminders
• Not visible anywhere but the Inspector

Save/Cancel:
• Click Save to apply changes
• Click Cancel or press Escape to discard
• Press Enter/Return to save quickly
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🎯 Scene Intent Types", color: headingColor))
        content.append(makeBody("""
Intent describes the narrative PURPOSE of a scene. Choose the one that best fits:

• Setup - Establishes characters, setting, or stakes
  Use for: Opening scenes, introducing new elements

• Exposition - Delivers necessary background information
  Use for: World-building, backstory revelations

• Rising Action - Builds tension toward a peak
  Use for: Middle-act complications, escalating stakes

• Conflict - Direct confrontation or opposition
  Use for: Arguments, battles, obstacles faced

• Climax - Peak tension, point of no return
  Use for: The big scene, maximum stakes

• Falling Action - Immediate aftermath of climax
  Use for: Processing what happened, regrouping

• Resolution - Wrapping up story threads
  Use for: Conclusions, new equilibrium

• Transition - Moving between story elements
  Use for: Time jumps, location changes, breathers

• Denouement - Final wrap-up after resolution
  Use for: Epilogue-style scenes, final character moments

Tip: Most scenes have one PRIMARY intent, even if they serve multiple purposes. Pick the dominant one.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📊 Revision States", color: headingColor))
        content.append(makeBody("""
Track where each scene is in your revision process:

✏️ Draft
• First pass, getting ideas down
• Don't worry about polish
• Focus on story logic

📝 Revised
• Second or later pass
• Major changes made
• Story logic improved

✨ Polished
• Line-editing complete
• Prose refined
• Nearly publication-ready

✅ Final
• Locked and complete
• Don't touch unless necessary
• Ready for submission/publication

⚠️ Needs Work
• Flagged for attention
• Something's wrong
• Return to this scene

Workflow Tip:
1. All scenes start as Draft
2. After story revisions → Revised
3. After line editing → Polished
4. After final review → Final
5. Use Needs Work as a flag, not a stage
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("🔄 Reordering Scenes", color: headingColor))
        content.append(makeBody("""
Scenes can be reordered by drag and drop:

1. Click and hold on a scene row
2. Drag up or down to new position
3. A gap appears showing where scene will drop
4. Release to complete the move

Reordering Notes:
• Scene order numbers update automatically
• Drag-drop is disabled when filters are active
• Order represents your intended story sequence
• Reordering doesn't affect your actual document

This is useful for:
• Planning restructuring before editing
• Experimenting with scene order
• Tracking parallel timelines
• Maintaining scene sequence independently of document
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("💡 Best Practices", color: headingColor))
        content.append(makeBody("""
Scenes work best when used intentionally:

✅ Do:
• Add scenes as you outline or after first draft
• Use Goal/Conflict/Outcome consistently
• Update status as you revise
• Use Notes for self-reminders
• Filter to focus your revision sessions
• Trust the metadata—it won't touch your text

❌ Don't:
• Feel obligated to fill every field
• Use scenes if you don't find them helpful
• Expect scenes to auto-detect from your document
• Over-engineer—keep it useful, not bureaucratic

Scenes as Scaffolding:
Think of scenes as construction scaffolding—they help you build and maintain your story structure, but they're not part of the final product. Use them when helpful, ignore them when not.

When Scenes Help Most:
• Complex plots with many threads
• Multiple POV characters
• Long revision processes
• Outlining before or after drafting
• Tracking what needs work
• Planning structural changes
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("❓ FAQ", color: headingColor))
        content.append(makeBody("""
Q: How do I create scenes from my existing manuscript?
A: Scenes are NOT created from your document text. You create them manually by clicking + in the Scene List. Think of scenes as your planning layer—YOU decide what each scene is and fill in the metadata. This separation is intentional: your manuscript text is sacred and never touched by the scene system.

Q: Can I copy text from my editor into a scene?
A: Scenes don't store text—only metadata ABOUT the scene (title, POV, goal, conflict, etc.). If you want to track what happens in a scene, use the Summary field to write a brief description. The actual prose stays in your editor where it belongs.

Q: Do scenes connect to my actual document text?
A: No. Scenes are metadata only—they never read or modify your manuscript text. They're organizational tools that exist alongside your document.

Q: Will my document break if I delete scenes?
A: No. Scenes are completely independent. Delete all of them and your manuscript is unaffected.

Q: Do scenes save with my document?
A: Scenes are saved in a separate JSON file. They persist between sessions.

Q: What's the difference between scenes and the outline?
A: The Outline (📖) is auto-generated from your document's heading styles. Scenes (🎬) are manually created metadata. They serve different purposes.

Q: Should I use scenes during drafting?
A: That's up to you. Some writers outline with scenes first, others add them after drafting. Scenes are designed to be optional at every stage.

Q: How many scenes should I have?
A: As many as your story needs. A 80,000-word novel might have 40-80 scenes, but there's no rule. Use what's useful.
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Tab 6: Keyboard Shortcuts

    private func loadShortcutsTab() {
                guard textViews.count > 5 else { return }
                let textView = textViews[5]
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
⌘⇧S - Save As (choose new location/format)
⌘P - Print
⌘W - Close window

Note: Auto-save runs every 30 seconds for saved documents.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📦 Working Format: RTFD (Recommended)", color: headingColor))
        content.append(makeBody("""
RTFD is a macOS-native rich-text format stored as a package (a folder that looks like a single file). It preserves text styling and embedded images reliably, and is usually the best choice while drafting in QuillPilot.

For sharing, collaboration, or cross-platform editing, exporting is often better than distributing your working RTFD. Use Export to generate Word (.docx), OpenDocument (.odt), PDF, HTML, or plain text depending on where the document needs to go.
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

        content.append(makeHeading("✨ Typography", color: headingColor))
        content.append(makeBody("""
QuillPilot includes professional typography features:

Automatic Features:
• Ligatures - Automatically enabled for serif fonts (fi, fl, ff, ffi, ffl)
• Smart Quotes - Converts straight quotes to curly quotes
• Smart Dashes - Converts double/triple hyphens to en/em dashes

Format > Typography Menu:
• Apply Drop Cap - Create a decorative large initial letter (3 lines tall)
• Use Old-Style Numerals - Enable elegant lowercase-style numbers (OpenType)
• Apply Optical Kerning - Adjust letter spacing for better visual balance

These features work best with professional fonts like Times New Roman, Georgia, Baskerville, Garamond, Palatino, and Hoefler Text.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("📚 Style Templates", color: headingColor))
        content.append(makeBody("""
Templates in QuillPilot are complete style sets (Body Text, headings, chapter formats, TOC/Index styles, etc.) tuned around a specific typeface.

Current templates:
• Minion Pro
• Arial
• Times New Roman
• Calibre
• Inter
• Helvetica
• Screenplay
• Baskerville Classic
• Garamond Elegant
• Palatino
• Hoefler Text
• Bradley Hand (Script)
• Snell Roundhand (Script)

How to switch templates:
1. Use the Template dropdown in the toolbar
2. Your selection is saved automatically
3. Style names and previews update instantly for the selected template

Notes:
• Switching templates changes which style definitions are available; it doesn’t automatically rewrite existing paragraphs unless you apply styles.
• TOC/Index insertion uses your current template’s typography.
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
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 20

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text + "\n\n", attributes: attributes)
    }

    private func makeHeading(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 6

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text + "\n", attributes: attributes)
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
