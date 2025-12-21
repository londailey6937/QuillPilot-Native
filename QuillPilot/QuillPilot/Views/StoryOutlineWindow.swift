//
//  StoryOutlineWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class StoryOutlineWindowController: NSWindowController {

    private var scrollView: NSScrollView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Story Outline"
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
        loadOutlineContent()
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

        // Create text view for outline content - EDITABLE
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width - 40, height: 0))
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 30, height: 30)
        textView.autoresizingMask = [.width]
        textView.isRichText = true
        textView.allowsUndo = true

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

    private func loadOutlineContent() {
        guard let scrollView = scrollView,
              let textView = scrollView.documentView as? NSTextView else { return }

        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        // Title
        content.append(makeTitle("The CoOp", color: titleColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Part I
        content.append(makeHeading("Part I: The Idealist", color: headingColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("1. Introduction", color: headingColor))
        content.append(makeBody("""
• Introduce Alex as a member of the CoOp, a collective of like-minded scientists, engineers, and assassins overseeing and protecting democracy.
• Establish Alex's commitment to preserving democratic ideals even through morally gray means.
• Show early signs of his dedication to a secretive mission.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("2. The Recruitment", color: headingColor))
        content.append(makeBody("""
• Flashback to Alex's recruitment by the Agency. Show Alex as a talented and intelligent American who starts working for the Agency.
• Reveal the nature of his mission: to protect the state at all costs, including targeted assassinations.
• Highlight his internal struggle with this mission due to its political motivations.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("3. Training and Infiltration", color: headingColor))
        content.append(makeBody("""
• Flashback to Alex's intense training, honing his skills in espionage, combat, and deception.
• Show his gradual infiltration into the Agency (government), working undercover.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("4. The Double Life", color: headingColor))
        content.append(makeBody("""
• Fast forward to Alex's current life, where he appears to be an ordinary citizen.
• Showcase his compartmentalization of emotions and actions, maintaining a façade of normalcy.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Part II
        content.append(makeHeading("Part II: The CoOp", color: headingColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("5. Mission One: The Senator", color: headingColor))
        content.append(makeBody("""
• Alex is assigned his first mission: eliminate a senator threatening to expose classified information.
• Describe the meticulous planning and execution of the operation.
• Depict Alex's inner turmoil as he carries out the assassination.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("6. The Web of Intrigue", color: headingColor))
        content.append(makeBody("""
• Introduce key characters within the covert agency, including mentors, handlers, and fellow operatives.
• Reveal the agency's global reach and the extent of its operations.
• Show the escalating tensions in the world and within the agency.
• Introduce Walter, who pilfers silver from a refinery to use as a bargaining chip with a foreign agent.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("7. The Mask Slips", color: headingColor))
        content.append(makeBody("""
• Alex faces unexpected consequences as his actions have repercussions on his personal life.
• Explore his strained relationships with loved ones who begin to sense his hidden life.
• Highlight the toll this double life takes on Alex's mental and emotional well-being.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Part III
        content.append(makeHeading("Part III: The Conscience", color: headingColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("8. Mission Two: The Journalist", color: headingColor))
        content.append(makeBody("""
• Alex is assigned to eliminate an investigative journalist on the verge of exposing classified operations.
• Show the journalist's dedication to truth and ethics, making Alex question his mission.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("9. The Crisis of Conscience", color: headingColor))
        content.append(makeBody("""
• Alex's growing internal conflict intensifies.
• Flashbacks reveal his initial idealism and the erosion of his values over time.
• He begins to question the agency's true motives and the ethics of his actions.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("10. Alliances and Betrayals", color: headingColor))
        content.append(makeBody("""
• Alex forms an unlikely alliance with an insider in the agency who shares his doubts.
• Explore the risks of betrayal and the complexity of navigating a world of secrets and lies.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Part IV
        content.append(makeHeading("Part IV: The Revelation", color: headingColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("11. The Revelation", color: headingColor))
        content.append(makeBody("""
• The agency's ultimate objective is unveiled, posing a grave threat to democracy itself.
• Alex faces a moral crossroads as he grapples with the realization of the agency's true intentions.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("12. The Whistleblower", color: headingColor))
        content.append(makeBody("""
• Alex decides to expose the agency's conspiracy, regardless of the personal consequences.
• Show the intricate plan to reveal the truth to the world while evading the agency's relentless pursuit.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Part V
        content.append(makeHeading("Part V: The End Game", color: headingColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("13. The Escape", color: headingColor))
        content.append(makeBody("""
• Alex goes on the run, pursued by his former colleagues.
• Detail his efforts to stay one step ahead while collaborating with allies from his past.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("14. The Showdown", color: headingColor))
        content.append(makeBody("""
• A dramatic confrontation between Alex and the agency unfolds, leading to a high-stakes climax.
• Explore themes of loyalty, sacrifice, and the price of redemption.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("15. Resolution", color: headingColor))
        content.append(makeBody("""
• The aftermath of Alex's actions and the impact on the government, his loved ones, and democracy itself.
• Conclude the novel with a reflection on the complex interplay between personal ideals and national security.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        // Part VI
        content.append(makeHeading("Part VI: The Epilogue", color: headingColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("16. The Legacy", color: headingColor))
        content.append(makeBody("""
• Offer a glimpse into the aftermath of Alex's revelations and the enduring impact on society.
• Leave the reader with lingering questions about the moral complexities of safeguarding democracy in a world of secrets.
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeBody("""
Throughout the novel, "The CoOp" delves into the moral dilemmas faced by its protagonist, Alex, as he navigates a world of secrecy, espionage, and political intrigue. The story explores the blurred lines between patriotism, morality, and the pursuit of justice in a contemporary context, challenging readers to consider the consequences of choices made in the name of preserving democratic ideals.
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
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeSubheading(_ text: String, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func makeBody(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
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
