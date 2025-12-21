//
//  DialogueTipsWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class DialogueTipsWindowController: NSWindowController {

    private var scrollView: NSScrollView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dialogue Writing Tips"
        window.minSize = NSSize(width: 600, height: 500)

        // Center the window
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 800) / 2
            let y = (screenFrame.height - 700) / 2
            window.setFrame(NSRect(x: x, y: y, width: 800, height: 700), display: true)
        }

        self.init(window: window)
        setupUI()
        loadDialogueTips()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true

        // Create scroll view
        scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        // Create text view for tips
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width - 40, height: 0))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 30, height: 30)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        window.contentView = contentView

        applyTheme(textView)
    }

    private func applyTheme(_ textView: NSTextView) {
        let theme = ThemeManager.shared.currentTheme
        textView.backgroundColor = theme.pageAround
        textView.textColor = theme.textColor
        scrollView.backgroundColor = theme.pageAround
    }

    private func loadDialogueTips() {
        guard let scrollView = scrollView,
              let textView = scrollView.documentView as? NSTextView else { return }

        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        // Title
        content.append(makeTitle("💬 Writing Better Dialogue", color: titleColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Introduction
        content.append(makeBody("""
Dialogue can be considered "basic and thin" for several reasons. Here are the most common issues and how to fix them:
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 1: Lack of Depth
        content.append(makeHeading("1. Lack of Depth", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
When characters only say exactly what they mean without any subtext or nuance, it can make the dialogue feel shallow.

✓ Good Example:
"Everything's fine," she said, not meeting his eyes.

✗ Avoid:
"I am upset with you because you forgot my birthday."

Tip: Let characters hide emotions, use subtext, and leave things unsaid. What characters don't say is often more powerful than what they do say.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 2: Repetition
        content.append(makeHeading("2. Repetition", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
Reiterating the same ideas or phrases can drain the dialogue of any weight or importance.

✗ Avoid:
"I'm scared. Really scared. I've never been this scared before."

✓ Better:
"I'm scared." Her voice cracked. "I've never felt like this before."

Tip: Say it once, say it well. Use action and description to reinforce emotions rather than repeating them.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 3: Overuse of Filler
        content.append(makeHeading("3. Overuse of Filler", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
Excessive use of filler words like "uh," "um," "well," etc., can dilute the impact of the dialogue.

✗ Avoid:
"Well, um, I was thinking, you know, that maybe we could, like, go to the movies?"

✓ Better:
"Want to catch a movie?"

Tip: Use filler words sparingly and only when characterizing nervous or uncertain speech patterns. Most dialogue should be cleaner than real conversation.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 4: Monotony
        content.append(makeHeading("4. Monotony", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
If all characters have the same speaking style or voice, the dialogue can be boring and uninformative.

✗ Avoid:
"Hello, John. How are you today?" Mary said.
"I am well, Mary. Thank you for asking," John said.

✓ Better:
"Hey." John nodded.
"You look tired," Mary said, studying his face.

Tip: Give each character a distinct voice through word choice, sentence length, formality level, and speech patterns. A teenager speaks differently than a professor.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 5: Predictability
        content.append(makeHeading("5. Predictability", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
When dialogue follows very predictable patterns or uses clichéd phrases, it lacks originality.

✗ Avoid Clichés:
• "We need to talk."
• "It's not what it looks like!"
• "I can explain everything."
• "This isn't over."

✓ Better:
Create fresh, character-specific lines that feel authentic to your story and characters.

Tip: If you've heard it in a movie or read it in another book, find a new way to say it.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 6: No Character Growth or Plot Advancement
        content.append(makeHeading("6. No Character Growth or Plot Advancement", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
Good dialogue often reveals something new about a character or advances the plot in some way. "Thin" dialogue does neither.

✗ Avoid Filler Conversation:
"Nice weather today."
"Yes, it is quite pleasant."

✓ Better:
"Nice weather for a funeral," she said, buttoning her coat.

Tip: Every line of dialogue should serve a purpose—reveal character, advance plot, create tension, or provide essential information. If it doesn't, cut it.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 7: Over-Exposition
        content.append(makeHeading("7. Over-Exposition", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
Dialogue that is used purely to convey information in a very straightforward manner can be dull and unengaging.

✗ Avoid Info-Dumping:
"As you know, Bob, we've been working on this project for three years, and the deadline is next Tuesday. The client, Mr. Johnson from Acme Corp, is expecting the full report with all the data we collected from the 500 survey participants."

✓ Better:
"Three years of work. One week left."
"Johnson's going to want every detail."

Tip: Break up information naturally. Show through action when possible. Let readers discover information gradually.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 8: Lack of Conflict or Tension
        content.append(makeHeading("8. Lack of Conflict or Tension", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
Engaging dialogue often includes some level of disagreement, tension, or conflict. Without this, the dialogue may lack dynamism.

✗ Avoid Too Much Agreement:
"That's a good idea."
"Thank you. I think so too."
"We should definitely do that."

✓ Better:
"That's a terrible idea."
"Got a better one?"
She didn't.

Tip: Characters should want different things. Even allies can disagree on methods. Conflict creates interest.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 9: No Emotional Resonance
        content.append(makeHeading("9. No Emotional Resonance", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
If the dialogue doesn't evoke any emotion or reaction in the reader, it might not be serving its purpose effectively.

✗ Avoid Flat Delivery:
"My brother died," he said.
"That's sad," she said.

✓ Better:
"My brother died." He stared at his hands.
She reached across the table but stopped short of touching him.

Tip: Use action, beats, and subtext to convey emotion. Let the white space speak. Sometimes what isn't said carries more weight.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Tip 10: Lack of Pacing
        content.append(makeHeading("10. Lack of Pacing", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
Dialogue that doesn't vary its rhythm can be less engaging. Good dialogue often mixes long, complex sentences with short, impactful ones to create a dynamic pace.

✗ Avoid Monotonous Rhythm:
"I think we should go to the store. We need to buy milk. We also need bread. And maybe some eggs too."

✓ Better:
"We need milk."
"And bread. And eggs. Basically, we need to go shopping."
"Fine."

Tip: Vary sentence length. Use fragments. Short bursts of dialogue during tense scenes. Longer speeches when a character needs to explain or persuade.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Conclusion
        content.append(makeHeading("Summary", color: headingColor))
        content.append(makeNewline())
        content.append(makeBody("""
Improving these aspects can make dialogue more engaging, revealing, and true to life. Remember:

• Use subtext and nuance
• Avoid repetition and filler words
• Give each character a unique voice
• Create fresh, unpredictable lines
• Make every line count
• Show, don't tell (avoid exposition dumps)
• Include conflict and tension
• Evoke emotion through action and subtext
• Vary pacing with sentence length

QuillPilot's dialogue analysis tool checks for all these issues and provides feedback to help you refine your dialogue.
""", color: bodyColor))

        textView.textStorage?.setAttributedString(content)

        // Size to fit
        textView.sizeToFit()
    }

    // MARK: - Helper Methods

    private func makeTitle(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeHeading(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeBody(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 8

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeNewline() -> NSAttributedString {
        return NSAttributedString(string: "\n")
    }
}
