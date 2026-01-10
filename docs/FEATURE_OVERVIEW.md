# QuillPilot Feature Overview

## 🎯 What You Can Do Now

### 1. Analyze Your Manuscript Structure

When you open an analysis view from the right-side Analysis panel (📊 / 📖 / 👥), QuillPilot provides THREE types of analysis:

#### A. Text Quality (📝 Outline tab)

- Word count, sentence count, paragraphs
- Passive voice detection
- Adverb usage
- Weak verbs and clichés
- **10 Dialogue Quality Metrics** (new!)
  - Filler word percentage
  - Repetition detection
  - Clichéd phrases
  - Exposition levels
  - Conflict presence
  - Pacing variety

#### B. Plot Structure (Right panel → 📖 Plot Structure → Plot Points)

**NEW FEATURE**: Visual story structure analysis

- See your **tension arc** as a line graph
- Automatically detect **9 key plot points**:
  - 🎬 Inciting Incident (~12%)
  - 📈 Rising Action (~20%)
  - ⚡️ First Pinch Point (~37%)
  - 🔄 Midpoint (~50%)
  - ⚡️ Second Pinch Point (~62%)
  - 💥 Crisis (~75%)
  - 🔥 Climax (~88%)
  - 📉 Falling Action (~93%)
  - ✨ Resolution (~98%)
- Get a **structure score** (0-100%)
- See **missing beats** warnings
- **Click any plot point** to jump to that location in your editor

#### C. Character Development (Right panel → 👥 Characters)

**NEW FEATURE**: Three powerful character visualizations

**Mode 1: Emotional Journey** 📈

- Line chart for each character showing sentiment over time
- Colors: Blue, Green, Orange, Purple, Pink, etc.
- Y-axis: -1.0 (negative) to +1.0 (positive emotions)
- X-axis: Story sections (chapters for manuscripts; scenes/acts for screenplays)
- Shows:
  - Arc Type: Positive/Negative/Flat/Transformational
  - Arc Strength: 0-100%
  - Total mentions in manuscript

**Mode 2: Character Network** 🔗

- Bar chart showing which characters appear together
- Sorted by frequency
- Relationship strength: 0-100%
- Identifies:
  - Strong relationships (appear together often)
  - Weak relationships (rarely interact)
  - Isolated characters

Notes:

- Character analysis is kept in sync with the Character Library and focuses on major characters.

**Mode 3: Presence Heatmap** 📊

- Grid: Rows = Characters, Columns = Sections
- Color intensity = mention frequency
- Numbers show exact count
- Helps you:
  - Spot characters who disappear
  - Balance screen time
  - Track POV distribution

Screenplays:

- Presence is organized by scene with an optional act view.

---

## 📖 How to Use It

### Step 1: Prepare Your Manuscript

```
1. Open or create your document
2. Define characters in Character Library (Navigator → 👥)
3. Write at least 5,000 words (more is better)
4. Use "Chapter 1", "Chapter 2" headers for manuscripts; for screenplays, use clear scene sluglines (INT./EXT.) and optional ACT I/II/III headings
```

### Step 2: Run Analysis

```
1. In the right-side Analysis panel, click 📊 (Analysis), 📖 (Plot Structure), or 👥 (Characters)
2. Wait 2-5 seconds (longer for huge manuscripts)
3. Results open in popout windows
```

### Step 3: Explore Visualizations

```
1. Click 📖 (Plot Structure) for plot visualizations
2. Click 👥 (Characters) for character visualizations
```

### Step 4: Navigate to Problem Areas

```
1. Click any plot point in the graph
2. Editor jumps to that word position
3. Review and improve that story beat
4. Re-analyze to see improvements
```

---

## 🎨 Visual Guide

### What the Plot Chart Looks Like

```
Tension Level (%)
100 │                    ╱╲ 🔥 Climax
    │                   ╱  ╲
 75 │              ╱╲  ╱    ╲
    │             ╱  ╲╱      ╲
 50 │         🔄 ╱            ╲
    │        ╱ ╲╱              ╲
 25 │    ╱╲╱                    ╲
    │🎬 ╱                        ╲ ✨
  0 │────────────────────────────────▶
    0%  12%  37%  50%  75%  88%  100%
         Story Progress (%)
```

### What Character Arcs Look Like

```
Emotional State
Positive (+1) │     ╱╲           Character A (blue)
              │    ╱  ╲╱╲
    Neutral   │───────────────── Character B (green)
              │  ╱          ╲
Negative (-1) │╲╱            ╲   Character C (orange)
              │
              └─────────────────▶
                Section 1...N
```

### What the Heatmap Looks Like

```
Character    │ Ch1 │ Ch2 │ Ch3 │ Ch4 │
─────────────┼─────┼─────┼─────┼─────┤
Alice        │ ███ │ ███ │  ▓  │ ███ │  (present in most)
Bob          │ ███ │  ▓  │  ░  │  ▓  │  (medium presence)
Charlie      │  ▓  │  ░  │     │     │  (appears early, fades)
Diana        │     │  ▓  │ ███ │ ███ │  (joins later)

█ = high mentions  ▓ = medium  ░ = low  ░ = absent
```

---

## 💡 Interpreting Results

### Plot Structure Score

- **90-100%**: Excellent! Strong three-act structure
- **70-89%**: Good structure, minor tweaks recommended
- **50-69%**: Adequate, but may feel unbalanced
- **Below 50%**: Consider restructuring major beats

### Character Arc Strength

- **70%+**: Strong development (protagonists should be here)
- **40-69%**: Moderate development (supporting characters)
- **0-39%**: Weak arc (flat characters, which can be intentional)

### Tension Levels

- **High (0.7-1.0)**: Action scenes, climactic moments
- **Medium (0.4-0.6)**: Rising tension, complications
- **Low (0.0-0.3)**: Quiet moments, setup, resolution

### Relationship Strength

- **60-100%**: Strong bond, frequent interaction
- **30-59%**: Moderate relationship, occasional scenes
- **0-29%**: Weak connection, rare interaction

---

## 🚀 Real-World Examples

### Example 1: Missing Midpoint

```
⚠️ Potentially Missing Story Beats:
• Midpoint

This means: Your story might lack a major revelation or
turning point at the 50% mark. Consider adding a twist,
betrayal, or major decision that changes the protagonist's
approach.
```

### Example 2: Flat Character Arc

```
Character: Bob
Arc Type: Flat Arc
Arc Strength: 15%

This means: Bob's emotional state doesn't change much
throughout the story. Is this intentional (mentor figure)
or should he have more development?
```

### Example 3: Disappearing Character

```
Heatmap shows:
Alice: High presence Ch 1-3, absent Ch 4-6

This means: Alice starts strong but vanishes. Did you
forget about her? Consider either:
1. Bring her back for the climax
2. Explain her absence in the story
```

### Example 4: Low Tension Arc

```
Your tension curve is relatively flat (never exceeds 40%)

This means: Story may feel slow or lacking stakes.
Consider adding:
- Higher conflict in Act 2
- More dramatic climax
- Clearer antagonist actions
```

---

## 📊 Recommended Targets

### For Thrillers/Action

- Tension curve should peak at 80%+ during climax
- Multiple smaller peaks throughout (action scenes)
- At least 5-6 plot points detected

### For Romance

- Character arcs: Protagonists should both show 60%+ strength
- Relationship strength: 80%+ co-appearance between leads
- Emotional journey: Both characters show transformation

### For Mystery

- Tension should build steadily with 2-3 major spikes
- Midpoint should be very pronounced (major clue/twist)
- Resolution should drop tension quickly after climax

### For Literary Fiction

- Character arc strength more important than tension
- Aim for 70%+ arc strength on protagonist
- Presence heatmap should show balanced character attention

---

## 🎓 Learning from the Graphs

### Question: "My climax is at 65% instead of 88%?"

**Answer**: Your story peaks too early. The final 35% may feel like aftermath. Consider:

- Moving the big reveal/battle later
- Adding a second, larger conflict
- Creating a false victory at 65%, real climax at 85%

### Question: "Character shows negative arc - is that bad?"

**Answer**: Not necessarily! Negative arcs are great for:

- Tragic stories
- Villain protagonists
- Cautionary tales
- But ensure it's intentional, not accidental

### Question: "Two main characters never appear together?"

**Answer**: This might be intentional (parallel plots) or a problem:

- If they should interact: Add scenes together
- If separate: Make sure their stories connect thematically

### Question: "My heatmap shows one character dominates all chapters?"

**Answer**: Could be intentional (single POV) or issue:

- Check if other characters feel like props
- Consider giving them more agency
- Balance screen time if ensemble cast

---

## 🔧 Technical Notes

### What Gets Analyzed

- ✅ Quoted dialogue
- ✅ Action words (ran, attacked, grabbed)
- ✅ Tension words (danger, fear, urgent)
- ✅ Emotion words (happy, sad, angry)
- ✅ Character name mentions
- ✅ Chapter headers
- ❌ Formatting (italics, bold)
- ❌ Comments/notes to self

### Analysis Limitations

- **Heuristic-based**: Not AI, uses word patterns
- **Context-blind**: Can't understand sarcasm/subtext
- **Name-dependent**: Characters must be in Character Library
- **English-only**: Emotion words are English language
- **Minimum length**: Needs 5,000+ words for accuracy

### Performance

- **Small docs** (< 10K words): < 1 second
- **Medium docs** (10-50K words): 2-3 seconds
- **Large docs** (50-100K words): 4-6 seconds
- **Huge docs** (100K+ words): 6-10 seconds

---

## 🎯 Quick Wins

### Improve Your Plot Score

1. **Add chapter breaks** with "Chapter X" headers
2. **Use action verbs** during important scenes
3. **Include tension words** in conflict moments
4. **Mark revelations** with words like "realized", "discovered"
5. **Build to climax** - make Act 3 most intense

### Improve Character Arcs

1. **Define characters** in Character Library first
2. **Use names consistently** throughout
3. **Show emotions** near character names
4. **Vary emotional states** across chapters
5. **Create character scenes** together for relationships

### Best Visualization Practices

1. **Write at least 10K words** before analyzing
2. **Use chapter markers** for heatmap
3. **Run analysis after major edits** to track changes
4. **Click plot points** to review those scenes
5. **Compare arcs** across characters for balance

---

## 🎉 Success Stories

### "My structure score went from 45% to 85%!"

What they did:

- Added a clear midpoint twist
- Moved climax from 70% to 88%
- Enhanced rising action with more obstacles

### "I discovered my antagonist had no arc!"

What they learned:

- Villain was one-dimensional
- Added backstory revealing motivation
- Arc strength improved from 12% to 68%

### "Character disappeared and I didn't notice!"

What the heatmap revealed:

- Side character introduced in Ch 1
- Completely absent in Ch 2-5
- No explanation given
- Fixed by either writing her out or bringing her back

---

**Need Help?** Check `docs/VISUALIZATION_USER_GUIDE.md` for detailed troubleshooting!

**Want AI Story Generation?** See `docs/AI_STORY_GENERATION_IMPLEMENTATION.md` for what's coming next!
