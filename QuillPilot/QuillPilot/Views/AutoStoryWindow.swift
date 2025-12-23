//
//  AutoStoryWindow.swift
//  QuillPilot
//
//  AI-powered story generation using characters, locations, and themes
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

class AutoStoryWindowController: NSWindowController {

    private var scrollView: NSScrollView!
    private var generateButton: NSButton!
    private var statusLabel: NSTextField!
    private var progressIndicator: NSProgressIndicator!
    private var lengthSlider: NSSlider!
    private var lengthLabel: NSTextField!
    private var apiSelector: NSPopUpButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "✨ Auto Story Generator"
        window.minSize = NSSize(width: 700, height: 600)

        // Center the window
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 800) / 2
            let y = (screenFrame.height - 700) / 2
            window.setFrame(NSRect(x: x, y: y, width: 800, height: 700), display: true)
        }

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true

        let theme = ThemeManager.shared.currentTheme
        contentView.layer?.backgroundColor = theme.pageAround.cgColor

        // Control panel at top
        let controlPanel = NSView(frame: NSRect(x: 0, y: contentView.bounds.height - 180, width: contentView.bounds.width, height: 180))
        controlPanel.autoresizingMask = [.width, .minYMargin]
        controlPanel.wantsLayer = true
        controlPanel.layer?.backgroundColor = theme.pageAround.cgColor

        // Title
        let titleLabel = NSTextField(labelWithString: "AI Story Generator")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = theme.textColor
        titleLabel.frame = NSRect(x: 20, y: 140, width: 300, height: 25)
        controlPanel.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Generate stories using your characters, locations, and theme")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = theme.textColor.withAlphaComponent(0.7)
        subtitleLabel.frame = NSRect(x: 20, y: 115, width: 500, height: 20)
        controlPanel.addSubview(subtitleLabel)

        // API Selector
        let apiLabel = NSTextField(labelWithString: "AI Provider:")
        apiLabel.font = NSFont.systemFont(ofSize: 12)
        apiLabel.textColor = theme.textColor
        apiLabel.frame = NSRect(x: 20, y: 80, width: 100, height: 20)
        apiLabel.alignment = .right
        controlPanel.addSubview(apiLabel)

        apiSelector = NSPopUpButton(frame: NSRect(x: 130, y: 77, width: 200, height: 25))
        apiSelector.addItems(withTitles: [
            "Local Generation (Basic)",
            "Claude (API Key Required)",
            "ChatGPT (API Key Required)"
        ])
        apiSelector.selectItem(at: 0)
        controlPanel.addSubview(apiSelector)

        // Length Slider
        let lengthLabelTitle = NSTextField(labelWithString: "Story Length:")
        lengthLabelTitle.font = NSFont.systemFont(ofSize: 12)
        lengthLabelTitle.textColor = theme.textColor
        lengthLabelTitle.frame = NSRect(x: 20, y: 45, width: 100, height: 20)
        lengthLabelTitle.alignment = .right
        controlPanel.addSubview(lengthLabelTitle)

        lengthSlider = NSSlider(frame: NSRect(x: 130, y: 45, width: 200, height: 20))
        lengthSlider.minValue = 1
        lengthSlider.maxValue = 3
        lengthSlider.intValue = 2
        lengthSlider.numberOfTickMarks = 3
        lengthSlider.allowsTickMarkValuesOnly = true
        lengthSlider.target = self
        lengthSlider.action = #selector(lengthChanged)
        controlPanel.addSubview(lengthSlider)

        lengthLabel = NSTextField(labelWithString: "Medium (~1000 words)")
        lengthLabel.font = NSFont.systemFont(ofSize: 11)
        lengthLabel.textColor = theme.textColor
        lengthLabel.frame = NSRect(x: 340, y: 45, width: 150, height: 20)
        controlPanel.addSubview(lengthLabel)

        // Generate Button
        generateButton = NSButton(title: "Generate Story", target: self, action: #selector(generateStory))
        generateButton.frame = NSRect(x: 20, y: 10, width: 150, height: 30)
        generateButton.bezelStyle = .rounded
        controlPanel.addSubview(generateButton)

        // Status Label
        statusLabel = NSTextField(labelWithString: "Ready to generate")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = theme.textColor.withAlphaComponent(0.6)
        statusLabel.frame = NSRect(x: 180, y: 15, width: 400, height: 20)
        statusLabel.isBezeled = false
        statusLabel.isEditable = false
        statusLabel.drawsBackground = false
        controlPanel.addSubview(statusLabel)

        // Progress Indicator
        progressIndicator = NSProgressIndicator(frame: NSRect(x: 590, y: 15, width: 20, height: 20))
        progressIndicator.style = .spinning
        progressIndicator.isHidden = true
        controlPanel.addSubview(progressIndicator)

        contentView.addSubview(controlPanel)

        // Divider
        let divider = NSBox(frame: NSRect(x: 0, y: contentView.bounds.height - 181, width: contentView.bounds.width, height: 1))
        divider.boxType = .separator
        divider.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(divider)

        // Create scroll view for generated story
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width, height: contentView.bounds.height - 181))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        // Create text view for story output - EDITABLE
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width - 40, height: 0))
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 30, height: 30)
        textView.autoresizingMask = [.width]
        textView.isRichText = true
        textView.allowsUndo = true
        textView.backgroundColor = theme.pageAround
        textView.textColor = theme.textColor
        textView.font = NSFont.systemFont(ofSize: 13)

        // Set initial placeholder text
        textView.string = "Generated story will appear here.\n\nClick 'Generate Story' to create a story using your characters, locations, and theme."

        scrollView.documentView = textView
        scrollView.backgroundColor = theme.pageAround
        contentView.addSubview(scrollView)

        window.contentView = contentView
    }

    @objc private func lengthChanged() {
        let length = lengthSlider.intValue
        switch length {
        case 1:
            lengthLabel.stringValue = "Short (~500 words)"
        case 2:
            lengthLabel.stringValue = "Medium (~1000 words)"
        case 3:
            lengthLabel.stringValue = "Long (~2000 words)"
        default:
            lengthLabel.stringValue = "Medium (~1000 words)"
        }
    }

    @objc private func generateStory() {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Disable button and show progress
        generateButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        statusLabel.stringValue = "Generating story..."

        // Get the selected API provider
        let selectedProvider = apiSelector.indexOfSelectedItem
        let targetWords = [500, 1000, 2000][Int(lengthSlider.intValue) - 1]

        // Generate story based on provider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let story: String

            switch selectedProvider {
            case 0: // Local Generation
                story = self?.generateLocalStory(targetWords: targetWords) ?? "Error generating story"
            case 1: // Claude
                story = self?.generateClaudeStory(targetWords: targetWords) ?? "Claude API key not configured. Please add your API key."
            case 2: // ChatGPT
                story = self?.generateChatGPTStory(targetWords: targetWords) ?? "ChatGPT API key not configured. Please add your API key."
            default:
                story = "Unknown provider selected"
            }

            DispatchQueue.main.async {
                textView.string = story
                self?.generateButton.isEnabled = true
                self?.progressIndicator.stopAnimation(nil)
                self?.progressIndicator.isHidden = true
                self?.statusLabel.stringValue = "Story generated successfully"
            }
        }
    }

    private func generateLocalStory(targetWords: Int) -> String {
        // Gather data from the app
        let characters = gatherCharacters()
        let locations = gatherLocations()
        let theme = gatherTheme()

        var story = ""

        // Title
        story += "# Generated Story\n\n"

        // Story based on gathered data
        if !theme.isEmpty {
            story += "Theme: \(theme)\n\n"
        }

        story += "---\n\n"

        // Introduction
        if !characters.isEmpty && !locations.isEmpty {
            let mainChar = characters.first ?? "the protagonist"
            let mainLoc = locations.first ?? "an unknown place"
            story += "In \(mainLoc), \(mainChar) begins their journey. "
        } else {
            story += "The story begins in a world of mystery and wonder. "
        }

        // Build narrative using characters and locations
        story += "The air was thick with anticipation, and every shadow seemed to hold a secret.\n\n"

        if characters.count > 1 {
            story += "Among the key figures in this tale were \(characters.dropFirst().joined(separator: ", ")). "
            story += "Each played a crucial role in the unfolding events.\n\n"
        }

        // Middle section
        story += "As the story progressed, challenges emerged that tested everyone involved. "
        if !theme.isEmpty {
            story += "The underlying theme of \(theme) became increasingly relevant, "
            story += "shaping decisions and revealing the true nature of each character.\n\n"
        } else {
            story += "The characters were forced to confront their deepest fears and greatest hopes.\n\n"
        }

        // Include locations
        if locations.count > 1 {
            story += "The journey took them through \(locations.dropFirst().joined(separator: ", ")), "
            story += "each location presenting its own unique obstacles and opportunities.\n\n"
        }

        // Climax
        story += "The turning point came when everything they had worked for hung in the balance. "
        story += "Choices made in that moment would echo through the rest of their lives.\n\n"

        // Resolution
        story += "In the end, the story found its resolution. The characters, changed by their experiences, "
        story += "moved forward with new understanding and purpose. "

        if !theme.isEmpty {
            story += "The theme of \(theme) had been woven throughout, "
            story += "providing a deeper meaning to their journey.\n\n"
        }

        // Closing
        story += "And so, this chapter closes, but the echoes of this tale continue, "
        story += "reminding us of the power of story and the resilience of the human spirit."

        return story
    }

    private func generateClaudeStory(targetWords: Int) -> String {
        // TODO: Implement Claude API integration
        // For now, return a placeholder message
        return """
        Claude API Integration (Coming Soon)

        To use Claude for story generation:
        1. Obtain an API key from Anthropic (https://console.anthropic.com/)
        2. Configure your API key in QuillPilot settings
        3. Select Claude from the provider dropdown

        Claude will generate sophisticated narratives using your characters, locations, and theme.

        For now, please use the Local Generation option.
        """
    }

    private func generateChatGPTStory(targetWords: Int) -> String {
        // TODO: Implement ChatGPT API integration
        // For now, return a placeholder message
        return """
        ChatGPT API Integration (Coming Soon)

        To use ChatGPT for story generation:
        1. Obtain an API key from OpenAI (https://platform.openai.com/)
        2. Configure your API key in QuillPilot settings
        3. Select ChatGPT from the provider dropdown

        ChatGPT will generate creative narratives using your characters, locations, and theme.

        For now, please use the Local Generation option.
        """
    }

    // MARK: - Data Gathering Helpers

    private func gatherCharacters() -> [String] {
        // Try to access Character Library
        let library = CharacterLibrary.shared
        return library.characters.map { $0.fullName }
    }

    private func gatherLocations() -> [String] {
        // TODO: Access locations from the locations window/storage
        // For now, return empty or sample data
        return ["the grand city", "the dark forest", "the ancient temple"]
    }

    private func gatherTheme() -> String {
        // TODO: Access theme from theme window/storage
        // For now, return a default
        return "redemption and second chances"
    }

    // MARK: - Helper Methods for Attributed Text

    private func makeTitle(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 20),
                .foregroundColor: color
            ]
        )
    }

    private func makeHeading(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 14),
                .foregroundColor: color
            ]
        )
    }

    private func makeBody(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: color
            ]
        )
    }

    private func makeNewline() -> NSAttributedString {
        NSAttributedString(string: "\n")
    }
}
