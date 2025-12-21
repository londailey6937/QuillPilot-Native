# QuillPilot Visualization Features Guide

## Overview

QuillPilot now includes powerful visualization tools to help you understand your story structure, character arcs, and plot dynamics at a glance.

## Accessing Visualizations

1. Write or open your manuscript in the Editor
2. Click **"Analyze Document"** to run analysis
3. In the Analysis Panel, click the **"📊 Graphs"** tab
4. Choose between **Plot Points** and **Character Arcs** tabs

## Plot Point Visualization

### What It Shows

The Plot Point chart displays:

- **Tension Arc**: A line graph showing tension levels throughout your story
- **Plot Beats**: Key story structure points marked with icons
- **Story Structure Score**: Overall rating (0-100%) of your story structure

### Understanding Plot Points

#### Detected Plot Points:

- 🎬 **Inciting Incident** (~12%): Event that kicks off the story
- 📈 **Rising Action** (~20%): Building tension and stakes
- ⚡️ **First Pinch Point** (~37%): First major obstacle
- 🔄 **Midpoint** (~50%): Major revelation or turning point
- ⚡️ **Second Pinch Point** (~62%): Second major challenge
- 💥 **Crisis** (~75%): Point of no return
- 🔥 **Climax** (~88%): Highest tension, final confrontation
- 📉 **Falling Action** (~93%): Immediate aftermath
- ✨ **Resolution** (~98%): Story conclusion

### How Tension Is Calculated

The tension analyzer looks for:

- **Action words**: grabbed, attacked, ran, fired, etc.
- **Tension words**: danger, fear, urgent, desperate, etc.
- **Revelation words**: discovered, realized, betrayal, secret, etc.

### Structure Score Breakdown

- **90-100%**: Excellent structure, all beats present
- **70-89%**: Good structure, minor improvements possible
- **50-69%**: Adequate structure, some beats may be weak
- **Below 50%**: Consider restructuring

### Missing Plot Points

If key story beats are missing, you'll see warnings like:

```
⚠️ Potentially Missing Story Beats:
• Midpoint
• Climax
```

**What to do**: Review your story structure and consider adding scenes that fulfill these narrative functions.

### Interactive Features

- **Click any plot point** to jump to that location in your editor
- **Hover over points** to see details (tension level, position)
- **View the list** below the chart for detailed beat information

## Character Arc Visualization

### Three Chart Types

#### 1. 📈 Emotional Journey

Shows each character's emotional state throughout the story.

**What It Shows**:

- Line chart tracking sentiment (-1.0 to 1.0)
- Negative = sad, angry, fearful
- Positive = happy, hopeful, confident
- Each character gets a unique color

**Character Arc Types**:

- **Positive Arc**: Character improves/grows (hero's journey)
- **Negative Arc**: Character degrades/falls (tragedy)
- **Flat Arc**: Character stays consistent (moral anchor)
- **Transformational**: Major change in character

**Arc Strength**:

- 70-100%: Strong, pronounced character development
- 40-69%: Moderate development
- 0-39%: Weak arc, character may be static

**Metrics Shown**:

- Total mentions in manuscript
- Number of sections where character appears
- Arc type and strength percentage

#### 2. 🔗 Character Network

Shows which characters interact most frequently.

**What It Shows**:

- Bar chart of character pairs
- Number of co-appearances (scenes where both appear)
- Relationship strength (0-100%)

**Relationship Strength**:

- **60-100%**: Strong relationship (appear together often)
- **30-59%**: Moderate relationship
- **0-29%**: Weak relationship (rarely together)

**Use Cases**:

- Identify under-developed relationships
- Find characters who never interact
- Balance character screen time

#### 3. 📊 Character Presence Heatmap

Shows how often each character appears in each chapter.

**What It Shows**:

- Grid: Characters (rows) × Chapters (columns)
- Color intensity = mention frequency
- Numbers = exact mention count

**Color Scale**:

- **Dark blue**: High presence (many mentions)
- **Light blue**: Medium presence
- **Pale blue**: Low presence
- **Gray**: Character absent

**Use Cases**:

- Spot characters who disappear mid-story
- Balance protagonist screen time
- Identify chapters dominated by one character
- Plan multi-POV structures

## How Character Analysis Works

### Sentiment Detection

The analyzer looks for emotion words near character names:

- **Positive**: happy, joy, love, smile, hope, proud
- **Negative**: sad, angry, fear, cry, despair, rage

### Intensity Detection

Measures dramatic moments with words like:

- violent, explosive, desperate, frantic, urgent, critical

### Chapter Detection

Automatically identifies chapters by headers:

- "Chapter 1", "CHAPTER ONE", etc.
- Falls back to section-based analysis if no chapters found

## Best Practices

### For Plot Analysis

1. **Write at least 10,000 words** for meaningful tension analysis
2. **Include chapter breaks** for better structure detection
3. **Use varied vocabulary** (action verbs, tension words) for accurate detection
4. **Review missing beats** and consider adding scenes to fill gaps

### For Character Analysis

1. **Define characters** in the Character Library first
2. **Use character names consistently** throughout manuscript
3. **Write at least 5,000 words** for reliable arc tracking
4. **Include chapter markers** for heatmap accuracy
5. **Vary character emotions** for better arc detection

## Troubleshooting

### "No analysis data available"

- **Cause**: Haven't run document analysis yet
- **Solution**: Click "Analyze Document" first

### "No character data available"

- **Cause**: Character Library is empty
- **Solution**: Add characters to the library via Navigator → Characters

### Tension curve looks flat

- **Cause**: Not enough tension/action words in text
- **Solution**: Add more dramatic vocabulary, conflict, and stakes

### Character not showing in arcs

- **Cause**: Character name not in Character Library
- **Solution**: Ensure exact name match (case-sensitive)

### All chapters show as "Ch1"

- **Cause**: No chapter markers detected
- **Solution**: Add "Chapter X" headers in your manuscript

## Technical Details

### Performance

- Analysis runs on background thread (won't freeze UI)
- Large manuscripts (100K+ words) may take 5-10 seconds
- Character analysis faster with fewer characters

### Accuracy

- Plot detection uses heuristics (not AI) - best effort
- Sentiment analysis based on word lists (300+ emotion words)
- Results improve with more text and clearer structure

### Data Privacy

- All analysis happens on your device
- No data sent to servers
- Results stored temporarily in memory only

## Future Enhancements

Coming soon:

- **Export visualizations** as images
- **Compare multiple drafts** side-by-side
- **AI suggestions** for improving structure
- **Scene-level analysis** (more granular than chapters)
- **Dialogue network** (who talks to whom)
- **Pacing visualization** (words per scene)

## Tips for Better Results

### Plot Structure

- Study classic story structures (Three-Act, Hero's Journey)
- Use Save the Cat or other beat sheets as guides
- Ensure climax is near the end (85-90%)
- Build tension gradually with peaks and valleys

### Character Arcs

- Give main characters clear emotional journeys
- Show growth through actions, not just dialogue
- Vary each character's emotional state across chapters
- Create meaningful relationships between characters

### Writing for Analysis

- Use specific emotion and action words
- Include physical reactions (heart pounded, hands trembled)
- Show internal conflict through description
- Vary sentence structure for better pacing detection

---

## Quick Reference

### Plot Point Positions (Ideal)

| Beat              | Position | Purpose         |
| ----------------- | -------- | --------------- |
| Inciting Incident | 12%      | Hook            |
| First Pinch       | 37%      | Raise stakes    |
| Midpoint          | 50%      | Shift direction |
| Second Pinch      | 62%      | All seems lost  |
| Crisis            | 75%      | Decision point  |
| Climax            | 88%      | Final showdown  |
| Resolution        | 98%      | Wrap up         |

### Arc Strength Targets

- **Protagonist**: 70%+ (strong development)
- **Antagonist**: 50%+ (clear motivation)
- **Supporting**: 30%+ (some growth)
- **Minor**: Any (can be flat)

### Healthy Character Presence

- **Protagonist**: 70-90% of chapters
- **Main Characters**: 50-80%
- **Supporting**: 30-60%
- **Minor**: 10-30%

Enjoy your new storytelling insights! 📊✨
