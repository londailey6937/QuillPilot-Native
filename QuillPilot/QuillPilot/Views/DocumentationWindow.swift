//
//  DocumentationWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import WebKit

class DocumentationWindowController: NSWindowController, NSWindowDelegate {

        private struct HelpHeadingLocation {
                let tabIdentifier: String
                let title: String
                let normalizedTitle: String
                let range: NSRange
        }

        private let helpHeadingAttributeKey = NSAttributedString.Key("QuillHelpHeading")

    private var tabView: NSTabView!
    private var scrollViews: [NSScrollView] = []
    private var textViews: [NSTextView] = []
        private var tabIdentifiers: [String] = []

        private var searchField: NSSearchField!
        private var headingIndex: [HelpHeadingLocation] = []

        private var headerView: NSView?
        private var tabBarScrollView: NSScrollView?
        private var tabBarStack: NSStackView?
        private var tabButtonsByIdentifier: [String: NSButton] = [:]
        private var themeObserver: NSObjectProtocol?
        private var keyDownMonitor: Any?

    convenience init() {
                let window = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 1180, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quill Pilot Help"
                window.minSize = NSSize(width: 900, height: 500)
                window.isReleasedWhenClosed = false

        self.init(window: window)
                window.delegate = self
        setupUI()
        loadDocumentation()

                keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                        guard let self,
                              let window = self.window,
                              window.isKeyWindow else { return event }
                        if event.modifierFlags.contains(.command),
                           let chars = event.charactersIgnoringModifiers,
                           chars.lowercased() == "w" {
                                window.performClose(nil)
                                return nil
                        }
                        return event
                }

                themeObserver = NotificationCenter.default.addObserver(
                        forName: .themeDidChange,
                        object: nil,
                        queue: .main
                ) { [weak self] _ in
                        self?.applyTheme()
                }
    }

        deinit {
                if let themeObserver {
                        NotificationCenter.default.removeObserver(themeObserver)
                }
                if let keyDownMonitor {
                        NSEvent.removeMonitor(keyDownMonitor)
                }
        }

        func windowWillClose(_ notification: Notification) {
                searchField?.stringValue = ""
                for view in textViews {
                        view.setSelectedRange(NSRange(location: 0, length: 0))
                }
        }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true

                // Header background (search strip)
                let header = NSView(frame: .zero)
                header.translatesAutoresizingMaskIntoConstraints = false
                header.wantsLayer = true
                contentView.addSubview(header)
                self.headerView = header

                // Help heading search
                searchField = NSSearchField(frame: .zero)
                searchField.placeholderString = "Search help headings…"
                searchField.sendsWholeSearchString = true
                searchField.target = self
                searchField.action = #selector(helpSearchSubmitted(_:))
                searchField.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(searchField)

        // Create tab view
                tabView = NSTabView(frame: .zero)
                tabView.translatesAutoresizingMaskIntoConstraints = false
        // Use a custom tab bar so light mode doesn't use the system accent blue.
        tabView.tabViewType = .noTabsNoBorder

        // Create tabs
        createTab(title: "About", identifier: "why")
        createTab(title: "📊 Analysis Tools", identifier: "analysis")
        createTab(title: "👥 Character Library", identifier: "characterLibrary")
        createTab(title: "👥 Character Analysis Tools", identifier: "characters")
        createTab(title: "📖 Plot & Structure", identifier: "plot")
        createTab(title: "🧭 Navigator", identifier: "navigator")
        createTab(title: "🎬 Scenes", identifier: "scenes")
        createTab(title: "🧰 Toolbar", identifier: "toolbar")
        createTab(title: "🎨 Typography & Styles", identifier: "typography")
        createTab(title: "📝 References & Notes", identifier: "referencesNotes")
        createTab(title: "⌨️ Shortcuts", identifier: "shortcuts")

        let tabBar = makeTabBar()
        contentView.addSubview(tabBar)

        contentView.addSubview(tabView)
        window.contentView = contentView

                NSLayoutConstraint.activate([
                        header.topAnchor.constraint(equalTo: contentView.topAnchor),
                        header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                        header.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                        header.heightAnchor.constraint(equalToConstant: 44),

                        searchField.centerYAnchor.constraint(equalTo: header.centerYAnchor),
                        searchField.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
                        searchField.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
                        searchField.heightAnchor.constraint(equalToConstant: 26),

                        tabBar.topAnchor.constraint(equalTo: header.bottomAnchor),
                        tabBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                        tabBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                        tabBar.heightAnchor.constraint(equalToConstant: 36),

                        tabView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
                        tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                        tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                        tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
                ])

        applyTheme()
    }

        private func makeTabBar() -> NSView {
                let scroller = NSScrollView(frame: .zero)
                scroller.translatesAutoresizingMaskIntoConstraints = false
                scroller.hasHorizontalScroller = true
                scroller.hasVerticalScroller = false
                scroller.autohidesScrollers = true
                scroller.scrollerStyle = .overlay
                scroller.drawsBackground = true
                scroller.borderType = .noBorder

                let clip = scroller.contentView
                clip.postsBoundsChangedNotifications = true

                let document = NSView(frame: .zero)
                document.translatesAutoresizingMaskIntoConstraints = false
                document.wantsLayer = true

                let stack = NSStackView()
                stack.orientation = .horizontal
                stack.alignment = .centerY
                stack.spacing = 8
                stack.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
                stack.translatesAutoresizingMaskIntoConstraints = false

                document.addSubview(stack)
                NSLayoutConstraint.activate([
                        stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
                        stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
                        stack.topAnchor.constraint(equalTo: document.topAnchor),
                        stack.bottomAnchor.constraint(equalTo: document.bottomAnchor)
                ])

                scroller.documentView = document

                tabBarScrollView = scroller
                tabBarStack = stack

                rebuildTabBarButtons()
                return scroller
        }

        private func rebuildTabBarButtons() {
                tabButtonsByIdentifier.removeAll(keepingCapacity: true)
                tabBarStack?.arrangedSubviews.forEach { v in
                        tabBarStack?.removeArrangedSubview(v)
                        v.removeFromSuperview()
                }

                guard let tabView else { return }
                for item in tabView.tabViewItems {
                        guard let identifier = item.identifier as? String else { continue }
                        let button = NSButton(title: item.label, target: self, action: #selector(tabButtonTapped(_:)))
                        button.bezelStyle = .rounded
                        button.isBordered = false
                        button.wantsLayer = true
                        button.layer?.cornerRadius = 8
                        button.translatesAutoresizingMaskIntoConstraints = false
                        button.setContentHuggingPriority(.required, for: .horizontal)
                        button.identifier = NSUserInterfaceItemIdentifier(identifier)
                        tabButtonsByIdentifier[identifier] = button
                        tabBarStack?.addArrangedSubview(button)
                }

                updateTabBarSelectionUI()
        }

        @objc private func tabButtonTapped(_ sender: NSButton) {
                guard let identifier = sender.identifier?.rawValue else { return }
                selectTab(identifier: identifier)
                updateTabBarSelectionUI()
        }

        private func updateTabBarSelectionUI() {
                guard let tabView else { return }
                let selectedIdentifier = tabView.selectedTabViewItem?.identifier as? String
                let theme = ThemeManager.shared.currentTheme

                for (identifier, button) in tabButtonsByIdentifier {
                        let isSelected = (identifier == selectedIdentifier)

                        // Border-only tabs (no filled backgrounds). Use border strength + title color
                        // to indicate selection, while keeping the Day theme's orange accent.
                        button.layer?.backgroundColor = NSColor.clear.cgColor
                        button.layer?.borderWidth = isSelected ? 2 : 1
                        button.layer?.borderColor = theme.pageBorder.withAlphaComponent(isSelected ? 1.0 : 0.55).cgColor

                        let titleColor: NSColor = theme.textColor
                        let font = NSFont.systemFont(ofSize: 12, weight: isSelected ? .bold : .semibold)
                        button.attributedTitle = NSAttributedString(
                                string: button.title,
                                attributes: [
                                        .foregroundColor: titleColor,
                                        .font: font
                                ]
                        )
                }
        }

    private func createTab(title: String, identifier: String) {
        let tabViewItem = NSTabViewItem(identifier: identifier)
        tabViewItem.label = title

                let scrollView = NSScrollView(frame: tabView.bounds)
                scrollView.autoresizingMask = [.width, .height]
                scrollView.hasVerticalScroller = true
                scrollView.hasHorizontalScroller = false
                scrollView.borderType = .noBorder

                let textView = NSTextView(frame: .zero)
                textView.isEditable = false
                textView.isSelectable = true
                textView.drawsBackground = true
                textView.textContainerInset = NSSize(width: 20, height: 20)
                textView.isHorizontallyResizable = false
                textView.isVerticallyResizable = true
                textView.autoresizingMask = [.width]
                textView.minSize = NSSize(width: 0, height: 0)
                textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
                textView.textContainer?.widthTracksTextView = true
                textView.textContainer?.heightTracksTextView = false
                textView.textContainer?.lineFragmentPadding = 0
                textView.translatesAutoresizingMaskIntoConstraints = true

                scrollView.documentView = textView
        tabViewItem.view = scrollView

                // Let NSTextView determine its height so scrolling works reliably.

        tabView.addTabViewItem(tabViewItem)
        scrollViews.append(scrollView)
        textViews.append(textView)
                tabIdentifiers.append(identifier)
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme

        // Window + header styling
        let isDarkMode = ThemeManager.shared.isDarkMode
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        window?.backgroundColor = theme.pageAround
        window?.contentView?.layer?.backgroundColor = theme.pageAround.cgColor

        headerView?.layer?.backgroundColor = theme.headerBackground.cgColor
        headerView?.layer?.borderWidth = 1
        headerView?.layer?.borderColor = theme.pageBorder.withAlphaComponent(0.35).cgColor

        tabBarScrollView?.backgroundColor = theme.pageBackground
        tabBarScrollView?.contentView.layer?.backgroundColor = theme.pageBackground.cgColor
        tabBarScrollView?.documentView?.wantsLayer = true
        tabBarScrollView?.documentView?.layer?.backgroundColor = theme.pageBackground.cgColor

                // Header controls (search field + its built-in buttons)
                searchField.textColor = theme.textColor
                searchField.backgroundColor = theme.pageBackground
                searchField.drawsBackground = true
                searchField.placeholderAttributedString = NSAttributedString(
                        string: "Search help headings…",
                        attributes: [
                                .foregroundColor: theme.popoutSecondaryColor,
                                .font: NSFont.systemFont(ofSize: 12)
                        ]
                )
                searchField.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

                updateTabBarSelectionUI()

        for (index, textView) in textViews.enumerated() {
            textView.backgroundColor = theme.pageAround
            textView.textColor = theme.textColor
            scrollViews[index].backgroundColor = theme.pageAround
        }
    }

        func windowDidResignKey(_ notification: Notification) {
                // Dismiss Help when the user clicks back into the main UI.
                window?.close()
        }

        @objc private func helpSearchSubmitted(_ sender: NSSearchField) {
                let rawQuery = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawQuery.isEmpty else { return }

                if headingIndex.isEmpty {
                        rebuildHeadingIndex()
                }

                let normalizedQuery = normalizeHeadingForSearch(rawQuery)
                guard !normalizedQuery.isEmpty else { return }

                func score(_ candidate: HelpHeadingLocation) -> Int {
                        let lowerRaw = rawQuery.lowercased()
                        let lowerTitle = candidate.title.lowercased()
                        if candidate.normalizedTitle == normalizedQuery { return 100 }
                        if candidate.normalizedTitle.hasPrefix(normalizedQuery) { return 80 }
                        if candidate.normalizedTitle.contains(normalizedQuery) { return 60 }
                        if lowerTitle.contains(lowerRaw) { return 50 }
                        // Partial word matching for phrases like "thematic resonance" matching "Thematic Resonance Map"
                        let queryWords = lowerRaw.split(separator: " ").map { String($0) }
                        let titleWords = lowerTitle.split(separator: " ").map { String($0) }
                        let matchCount = queryWords.filter { qw in titleWords.contains { $0.hasPrefix(qw) || $0.contains(qw) } }.count
                        if matchCount == queryWords.count && queryWords.count >= 2 { return 45 }
                        if matchCount > 0 { return 30 }
                        return 0
                }

                if let best = headingIndex.max(by: { score($0) < score($1) }), score(best) > 0 {
                        selectTab(identifier: best.tabIdentifier)

                        DispatchQueue.main.async { [weak self] in
                                guard let self else { return }
                                guard let tabIndex = self.tabIdentifiers.firstIndex(of: best.tabIdentifier),
                                          tabIndex < self.textViews.count else { return }
                                let textView = self.textViews[tabIndex]
                                textView.window?.makeFirstResponder(textView)
                                textView.setSelectedRange(best.range)
                                textView.scrollRangeToVisible(best.range)
                                textView.showFindIndicator(for: best.range)
                        }
                        return
                }

                // Fallback: search full help text (not just headings). This guarantees searches for
                // terms like "Thematic Resonance map" or "Failure Pattern Charts" still land somewhere helpful.
                let lowerQuery = rawQuery.lowercased()
                var bestFallback: (tabIdentifier: String, range: NSRange)?

                for (index, tabIdentifier) in tabIdentifiers.enumerated() {
                        guard index < textViews.count else { continue }
                        let textView = textViews[index]
                        let fullText = (textView.string as NSString)
                        let lowerText = fullText.lowercased
                        let swiftLowerText = String(lowerText)
                        if let r = swiftLowerText.range(of: lowerQuery) {
                                let location = swiftLowerText.distance(from: swiftLowerText.startIndex, to: r.lowerBound)
                                let length = lowerQuery.count
                                bestFallback = (tabIdentifier, NSRange(location: location, length: length))
                                break
                        }
                }

                guard let fallback = bestFallback else {
                        NSSound.beep()
                        return
                }

                selectTab(identifier: fallback.tabIdentifier)
                DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        guard let tabIndex = self.tabIdentifiers.firstIndex(of: fallback.tabIdentifier),
                                  tabIndex < self.textViews.count else { return }
                        let textView = self.textViews[tabIndex]
                        textView.window?.makeFirstResponder(textView)
                        textView.setSelectedRange(fallback.range)
                        textView.scrollRangeToVisible(fallback.range)
                        textView.showFindIndicator(for: fallback.range)
                }
        }

        private func rebuildHeadingIndex() {
                headingIndex.removeAll(keepingCapacity: true)

                for (index, tabIdentifier) in tabIdentifiers.enumerated() {
                        guard index < textViews.count else { continue }
                        let textView = textViews[index]
                        guard let storage = textView.textStorage, storage.length > 0 else { continue }
                        let fullRange = NSRange(location: 0, length: storage.length)
                        storage.enumerateAttribute(helpHeadingAttributeKey, in: fullRange, options: []) { value, range, _ in
                                guard let heading = value as? String else { return }
                                let normalized = normalizeHeadingForSearch(heading)
                                guard !normalized.isEmpty else { return }
                                headingIndex.append(HelpHeadingLocation(tabIdentifier: tabIdentifier, title: heading, normalizedTitle: normalized, range: range))
                        }
                }
        }

        private func normalizeHeadingForSearch(_ heading: String) -> String {
                let trimmed = heading.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return "" }

                // Drop leading emoji / punctuation so searches for "analysis" match "📊 Analysis Tools".
                let scalars = trimmed.unicodeScalars
                let startIndex = scalars.firstIndex(where: { CharacterSet.alphanumerics.contains($0) })
                let cleaned = startIndex.map { String(String.UnicodeScalarView(scalars[$0...])) } ?? trimmed
                return cleaned.lowercased()
        }

        func selectTab(identifier: String) {
                guard let tabView else { return }
                guard let item = tabView.tabViewItems.first(where: { ($0.identifier as? String) == identifier }) else { return }
                tabView.selectTabViewItem(item)
                updateTabBarSelectionUI()

                if let scrollView = item.view as? NSScrollView {
                        scrollView.contentView.scroll(to: .zero)
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                }
        }

    private func loadDocumentation() {
        loadWhyTab()
        loadAnalysisTab()
                loadCharacterLibraryTab()
        loadCharactersTab()
        loadPlotTab()
        loadNavigatorTab()
        loadScenesTab()
        loadToolbarTab()
        loadTypographyTab()
        loadReferencesNotesTab()
        loadShortcutsTab()

                // Build the search index after content is loaded.
                rebuildHeadingIndex()
    }

        private func normalizeAppNameInDocumentation(_ content: NSMutableAttributedString) {
                let fullRange = NSRange(location: 0, length: content.length)
                _ = content.mutableString.replaceOccurrences(of: "QuillPilot", with: "Quill Pilot", options: [], range: fullRange)
        }

        // MARK: - Tab: About

        private func loadWhyTab() {
        guard textViews.count > 0 else { return }
        let textView = textViews[0]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

                content.append(makeTitle("About Quill Pilot", color: titleColor))
                content.append(makeBody("""
        Designed for macOS with a fully adaptive interface—from 13-inch MacBooks to large desktop displays.

        Quill Pilot is a writing environment that prioritizes how words feel on the page, not just how they’re organized in a project.

        It’s primarily designed for experienced fiction writers who already understand story structure and want tools that enhance execution, not exploration. That said, it’s equally capable for non-fiction work, supporting lists, tables, columns, and other structures common in books and publications.

        At its core, Quill Pilot is about refining what you’ve already learned—making strong writing clearer, more consistent, and more intentional.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Writing as Final Output", color: headingColor))
                content.append(makeSubheading("Output-First Writing", color: headingColor))
                content.append(makeBody("""
        What you see is what you submit.
        No compile step. No export-format-revise cycle.

        The manuscript you write is the manuscript you send.

        For professional novelists, this changes how you:
        • Judge pacing
        • Feel paragraph density
        • Evaluate dialogue rhythm
        • Spot visual monotony early

        Quill Pilot removes the mental split between drafting and presentation.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Typography as a Cognitive Tool", color: headingColor))
                content.append(makeBody("""
        Good typography reduces cognitive load, improves rereading accuracy, and makes structural problems visible earlier.

        Quill Pilot treats typography as part of thinking on the page—not as output polish added later. Professional templates (Baskerville, Garamond, Hoefler Text) give your manuscript submission-quality presentation while you draft.

        Typography isn’t decoration here; it’s feedback.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Narrative Analysis & Story Intelligence", color: headingColor))
                content.append(makeBody("""
        One of Quill Pilot’s major strengths is its integrated analysis system, designed to surface patterns and weaknesses without pulling you out of the writing flow.

        Instead of spreadsheets or notebooks, narrative intelligence lives alongside the manuscript:
        • Belief-shift tracking across character arcs
        • Tension-curve visualization over time
        • Relationship evolution mapping
        • Scene-level decision and consequence chains
        • Emotional trajectory analysis

        These tools help you see relationships, diagnose weaknesses, and examine the deeper mechanics that comprise a story—all while staying inside the manuscript itself.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Story Data & Persistent Notes", color: headingColor))
                content.append(makeBody("""
        Quill Pilot separates certain story data from the manuscript text so it can persist independently.
        """, color: bodyColor))

                content.append(makeSubheading("Story Notes", color: headingColor))
                content.append(makeBody("""
        Theme, locations, outlines, and directions are saved as lightweight JSON files at:

        ~/Library/Application Support/Quill Pilot/StoryNotes/
        """, color: bodyColor))

                content.append(makeSubheading("Character Library", color: headingColor))
                content.append(makeBody("""
        Character entries are stored per document as a sidecar file next to your manuscript:

        MyStory.docx.characters.json

        If these files are deleted, Quill Pilot treats the associated data as empty for that document.

        This separation keeps your manuscript clean while preserving deep contextual knowledge.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Working Format", color: headingColor))
                content.append(makeSubheading("📦 RTFD (Recommended)", color: headingColor))
                content.append(makeBody("""
        RTFD is a macOS-native rich-text format stored as a package (a folder that appears as a single file). It reliably preserves text styling and embedded images and is generally the best format while drafting in Quill Pilot.

        For sharing, collaboration, or cross-platform editing, exporting is preferred. Quill Pilot supports export to:
        • Word (.docx)
        • OpenDocument (.odt)
        • PDF
        • HTML
        • Plain text
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Who Quill Pilot Is For", color: headingColor))
                content.append(makeSubheading("Choose Quill Pilot if you:", color: headingColor))
                content.append(makeBody("""
        • Write primarily novels or screenplays
        • Already understand story structure
        • Care how the page looks while you write
        • Want insight, not organization
        • Submit to agents or publishers regularly
        • Prefer writing in a finished-looking manuscript
        • Value execution refinement over project management
        """, color: bodyColor))

                content.append(makeSubheading("Quill Pilot is not trying to:", color: headingColor))
                content.append(makeBody("""
        • Manage research PDFs or web archives
        • Handle citations or footnotes
        • Compile into multiple output formats
        • Serve as a universal project manager
        • Replace Scrivener’s binder system

        Those are legitimate needs—but they’re not what Quill Pilot optimizes for.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("How Professionals Actually Use It", color: headingColor))
                content.append(makeBody("""
        Many professional fiction writers use:
        • Scrivener for planning, research, and complex projects
        • Quill Pilot for drafting and final manuscripts

        Quill Pilot replaces the moment when you export from a project tool and say:

        “Okay—now let me make this look and read right.”

        If that’s the moment you care about most, Quill Pilot wins.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Writer Seniority Matters", color: headingColor))
                content.append(makeBody("""
        Quill Pilot feels “simpler” because it assumes you already know how to write.
        """, color: bodyColor))

                normalizeAppNameInDocumentation(content)
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
• Use the character tool buttons listed under the analysis buttons (each tool has its own icon)

Quick access:
• 📊 Analysis — document-level metrics, writing-quality flags, dialogue metrics, and Poetry Analysis when using Poetry templates
• 📖 Plot Structure — plot/structure visualizations
• 👥 Character Analysis Tools — character-focused tools and maps

Tip: In this Help window, use the “📊 Analysis Tools”, “👥 Character Library”, “👥 Character Analysis Tools”, and “📖 Plot & Structure” tabs for in-depth documentation.
Tip: Auto-analyze behavior can be configured in Preferences.

If results aren’t available yet, QuillPilot runs analysis automatically the first time you open any analysis view.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("Built-in macOS Writing Tools (Apple)", color: headingColor))
        content.append(makeBody("""
Some Macs include system-provided Writing Tools (sometimes shown as Proofread, Rewrite, Summarize, etc.). If you see this panel while editing, it’s provided by macOS — not by QuillPilot.

How to use it:
• Select text in the editor
• Control-click (or right-click) the selection
• Choose Writing Tools, then pick an option (Proofread, Rewrite, Summarize, etc.)

Availability depends on your macOS version, device support, language/region, and whether the feature is enabled in System Settings.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("📊 Basic Metrics", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis

What you’ll see:
• Word Count — Total words in your document
• Sentence Count — Total sentences detected
• Paragraph Count — Total paragraphs
• Average Sentence Length — Words per sentence

How to use it:
• Treat these as “manuscript telemetry,” not goals. What matters is the delta: before vs after revisions.
• If sentence count looks off, check for unusual punctuation (em-dashes, ellipses, screenplay formatting) — detection is heuristic.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("📝 Writing Quality", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis

Passive Voice Detection
• Shows percentage of passive constructions
• Highlights "was," "were," "been" patterns
• Target: Keep below 10% for most genres

How to use it:
• Passive voice isn’t “bad,” it’s a tool. Use the report to find places where agency is unclear.
• If the prose is intentionally distant (noir, fairy tale, documentary voice), your target can be higher.

Adverb Usage
• Counts -ly adverbs
• Shows examples and locations
• Helps strengthen verb choices

How to use it:
• Hunt clusters. One adverb isn’t an issue; five in a paragraph often signals weak verb specificity.

Weak Verbs
• Detects: is, was, get, make, etc.
• Suggests stronger alternatives
• Context matters—not all are bad

How to use it:
• Replace only when it improves precision. “Was” is often correct in scene-setting and reflection.

Clichés & Overused Phrases
• Identifies common clichés
• "low-hanging fruit," "think outside the box"
• Helps keep writing fresh

How to use it:
• Prioritize clichés in character voice. If the character would say it, it may be intentional.

Filter Words
• Perception words that distance readers
• saw, felt, thought, realized, wondered
• Show, don't tell principle

How to use it:
• Replace when the POV can be rendered as direct experience. Keep when you need narrative distance.

Sensory Details
• Balance of sight, sound, touch, taste, smell
• Shows sensory distribution chart
• Helps immerse readers

How to use it:
• “Balance” is genre-dependent: thrillers skew visual/kinesthetic; literary can skew interiority.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("📖 Sentence Variety", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis

Visual graph showing distribution of:
• Short sentences (1-10 words)
• Medium sentences (11-20 words)
• Long sentences (21-30 words)
• Very long sentences (31+ words)

Good variety = engaging rhythm
Too uniform = monotonous reading

How to use it:
• In action sequences, you often want a higher short-sentence share.
• In contemplative passages, longer sentences can be a feature.
• Watch for “flatlines” where every paragraph has the same cadence.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("💬 Dialogue Analysis", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis

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

Notes on accuracy:
• These are pattern detectors, not literary judgments.
• Screenplay formatting and heavy dialect can reduce tagging accuracy.

How to use it (fast):
1) Find the worst-scoring chapter/segment.
2) Fix one issue (exposition, repetition, tag monotony).
3) Re-run analysis and look for movement, not perfection.
""", color: bodyColor))

        content.append(makeNewline())

        content.append(makeSubheading("🪶 Poetry Analysis", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis (Poetry templates)

What it’s for:
• A writer-facing lens on sound, rhythm, diction, and rhetorical motion.
• Pattern surfacing (“what’s happening in the language”) more than verdict (“what it means”).

Important note:
• Many results are heuristic — especially in stanzaic narrative poems and ballads.
• Use the output as revision prompts, not a grade.

Practical workflow:
1) Read the “Form / mode” notes first (lyric vs narrative/stanzaic).
2) Pick one lever (enjambment, compression, sonic texture, rhetorical turn).
3) Revise 20–40 lines, then re-run analysis to see if the pattern moved.
""", color: bodyColor))

                normalizeAppNameInDocumentation(content)
        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Tab 3: Character Library

    private func loadCharacterLibraryTab() {
        guard textViews.count > 2 else { return }
        let textView = textViews[2]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Character Library", color: titleColor))
        content.append(makeBody("""
Central repository for all character information (profiles, roles, motivations, relationships, arcs).

Location:
• Left sidebar (Navigator) → 👥 Characters

Notes:
• The Character Library is a data tool, not an analysis report. Analysis visualizations live in the right-side Analysis panel.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("What It Stores", color: headingColor))
        content.append(makeBody("""
• Character profiles (name, role)
• Descriptions and backstory
• Motivations and goals
• Relationships and notes

Tip: Consistent naming (and a complete Character Library) improves character detection in the analysis tools.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("How To Use", color: headingColor))
        content.append(makeBody("""
1) Open the Character Library from the Navigator
2) Add or edit characters (including common aliases/nicknames)
3) Keep names aligned with the manuscript’s actual usage

Character data is saved automatically.
""", color: bodyColor))

                normalizeAppNameInDocumentation(content)
        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Tab 4: Character Analysis Tools

    private func loadCharactersTab() {
                guard textViews.count > 3 else { return }
                let textView = textViews[3]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Character Analysis Tools", color: titleColor))
        content.append(makeBody("""
Character analysis lives in the right-side Analysis panel. Each character tool has its own button (no submenu).

If results aren’t available yet, QuillPilot runs analysis automatically when you open a character tool.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("📈 Emotional Trajectory", color: headingColor))
        content.append(makeBody("""
Visualize character emotional states throughout your story.

Access: Right panel → 📈 Emotional Trajectory

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

        content.append(makeSubheading("📊 Decision-Belief Loops", color: headingColor))
        content.append(makeBody("""
Tracks how character decisions reinforce or challenge their beliefs.

Access: Right panel → 📊 Decision-Belief Loops

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

        content.append(makeSubheading("📋 Belief Shift Matrix", color: headingColor))
        content.append(makeBody("""
Table format tracking character belief evolution through chapters.

Access: Right panel → 📋 Belief Shift Matrix

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

        content.append(makeSubheading("⛓️ Decision-Consequence Chains", color: headingColor))
        content.append(makeBody("""
Maps choices, not traits. Ensures growth comes from action, not narration.

Access: Right panel → ⛓️ Decision-Consequence Chains

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

        content.append(makeSubheading("🤝 Character Interactions", color: headingColor))
        content.append(makeBody("""
Analyzes relationships and scenes between characters.

Access: Right panel → 🤝 Character Interactions

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

How interactions are detected:
• The analyzer looks for character-name co-mentions within the same text segment.
• Segments are derived from your chapter/outline structure when available; otherwise it uses rolling word windows.
• Character Library aliases are used (nickname / first-name fallback) so dialogue like “Alex” can still count toward “Alex Ross.”

If the network looks incomplete:
• Make sure Character Library names match what the manuscript actually uses (including nicknames).
• Add/confirm chapter headings (or use the Outline styles) so segmentation aligns with your structure.
• This is a lightweight heuristic—implicit relationships without co-mentions won’t appear.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("📍 Character Presence", color: headingColor))
        content.append(makeBody("""
Heat map showing which characters appear in which chapters.

Access: Right panel → 📍 Character Presence

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

        content.append(makeSubheading("🔗 Relationship Evolution Maps", color: headingColor))
        content.append(makeBody("""
Network diagram visualizing character relationships and their evolution.

Access: Right panel → 🔗 Relationship Evolution Maps

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

How trust/conflict is estimated (important):
• Trust is a keyword-based signal, not a definitive model of the relationship.
• For each chapter/segment, the analyzer finds sentences that mention both characters (alias-aware) and scores cues like:
        • Trust-building: help/support/protect/thank/forgive/together/trust
        • Conflict: argue/fight/betray/accuse/blame/attack/distrust
• The graph shows an average trust/conflict level per relationship, and can vary by chapter.

Accuracy tips:
• Relationships that are implied but never co-mentioned will read as neutral.
• Clear on-page cues (“I trust you,” “He betrayed her,” etc.) are easier to detect than subtext.
• Consistent naming (and a complete Character Library) improves detection.

Great for:
• Mentor/rival dynamics - See power imbalances
• Romance arcs - Track trust building or breaking
• Ensemble casts - Balance relationship networks
• Finding isolated characters
• Identifying missing relationship development
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("🎭 Internal vs External Alignment", color: headingColor))
        content.append(makeBody("""
Track the gap between who characters are inside and how they act.

Access: Right panel → 🎭 Internal vs External Alignment

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

        content.append(makeSubheading("📝 Language Drift Analysis", color: headingColor))
        content.append(makeBody("""
Track how character's language changes — reveals unconscious growth.

Access: Right panel → 📝 Language Drift Analysis

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
        content.append(makeNewline())

        content.append(makeSubheading("🎯 Thematic Resonance Map", color: headingColor))
        content.append(makeBody("""
Visualize how each character aligns with (or resists) the story’s theme over time.

Access: Right panel → 🎯 Thematic Resonance Map

What it shows:
• Theme alignment (from opposed → embodied)
• Awareness of the theme (how conscious the character is of the theme)
• Influence (how much the character drives thematic exploration)
• Personal cost (what it costs the character to engage the theme)

How to read it:
• Alignment above 0 = thematically aligned; below 0 = in conflict with the theme
• Rising alignment suggests growth toward the theme
• High awareness + low alignment often indicates conscious resistance
• High cost highlights moments of thematic sacrifice

Use it to:
• Track character transformations in thematic terms
• Identify who embodies the theme vs who resists it
• Spot where the theme is under-explored in later chapters
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("📉 Failure Pattern Charts", color: headingColor))
        content.append(makeBody("""
Shows how character failures evolve across the story — not just success vs failure, but *how* they fail.

Access: Right panel → 📉 Failure Pattern Charts

Failure types tracked:
• Naive
• Reactive
• Misinformed
• Strategic
• Principled
• Costly but Chosen

What it indicates:
• Early failures trend toward naive/reactive patterns
• Later failures should show better judgment (strategic/principled)
• A flat pattern suggests limited growth in decision quality

Use it to:
• Diagnose whether characters are learning from mistakes
• Ensure failures evolve with the character arc
• Identify late-story regression or stagnation
""", color: bodyColor))

                normalizeAppNameInDocumentation(content)
        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Tab 4: Plot & Structure

    private func loadPlotTab() {
        guard textViews.count > 4 else { return }
        let textView = textViews[4]
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

                normalizeAppNameInDocumentation(content)
        textView.textStorage?.setAttributedString(content)
    }

        // MARK: - Tab: Navigator

        private func loadNavigatorTab() {
                guard textViews.count > 5 else { return }
                let textView = textViews[5]
                let theme = ThemeManager.shared.currentTheme
                let titleColor = theme.textColor
                let headingColor = theme.textColor
                let bodyColor = theme.textColor

                let content = NSMutableAttributedString()

                content.append(makeTitle("Navigator", color: titleColor))
                content.append(makeNewline())

                content.append(makeHeading("Document Outline (list.bullet.indent)", color: headingColor))
                content.append(makeBody("""
        Access: Click the Document Outline icon in the Navigator panel

        What it shows:
        • Live outline generated from your heading styles
        • Chapters, sections, and scene headers (when styled)
        • Click any entry to jump to that location

        Best for:
        • Fast navigation
        • Structural overview
        • Finding specific scenes
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Story Theme (theatermasks)", color: headingColor))
                content.append(makeBody("""
        Describe the central idea, question, or insight the story explores.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Scenes (film)", color: headingColor))
                content.append(makeBody("""
        See the Scenes tab in Help for the full breakdown of how Scenes work and how to use them effectively.
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("Story Outline (book)", color: headingColor))
                content.append(makeBody("""
        Access: Click the Story Outline icon in the Navigator panel

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

                content.append(makeHeading("Locations & Directions (map)", color: headingColor))
                content.append(makeBody("""
        Track settings and story progression.

        Locations (map icon in Navigator):
        • Create location profiles
        • Add descriptions and details
        • Track scenes set in each location
        • Maintain setting consistency

        Story Directions (compass icon in Navigator):
        • Define story direction and goals
        • Track thematic elements
        • Document narrative throughlines
        • Plan story progression
        """, color: bodyColor))
                content.append(makeNewline())

                content.append(makeHeading("General Notes (note.text)", color: headingColor))
                content.append(makeBody("""
        Capture free-form ideas, reminders, or planning notes tied to your document.
        """, color: bodyColor))

                                normalizeAppNameInDocumentation(content)
                textView.textStorage?.setAttributedString(content)
        }

        // MARK: - Tab 6: Scenes

    private func loadScenesTab() {
                guard textViews.count > 6 else { return }
                let textView = textViews[6]
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

                normalizeAppNameInDocumentation(content)
        textView.textStorage?.setAttributedString(content)
    }

        // MARK: - Tab: References & Notes

        private func loadReferencesNotesTab() {
                guard textViews.count > 9 else { return }
                let textView = textViews[9]
                let theme = ThemeManager.shared.currentTheme
                let titleColor = theme.textColor
                let headingColor = theme.textColor
                let bodyColor = theme.textColor

                let content = NSMutableAttributedString()

                content.append(makeTitle("References & Notes", color: titleColor))
                content.append(makeBody("""
Quill Pilot provides professional-grade footnotes, endnotes, bookmarks, and cross-references that follow industry-standard document semantics. These features are designed to work like their counterparts in Microsoft Word, ensuring compatibility and proper behavior when exporting to other formats.
""", color: bodyColor))
                content.append(makeNewline())

                // MARK: Footnotes & Endnotes
                content.append(makeHeading("📝 Footnotes & Endnotes", color: headingColor))
                content.append(makeBody("""
Footnotes and endnotes in Quill Pilot are structured objects—not just text with superscripts. Each note consists of:
• A unique internal ID
• A reference marker in the main text
• A corresponding note body stored separately
• Automatic numbering rules

This structure enables powerful features:
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Automatic Renumbering", color: headingColor))
                content.append(makeBody("""
Insert a footnote anywhere in your document, and all subsequent footnotes automatically renumber. Delete a footnote, and the numbering adjusts. No manual editing required.
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Conversion Between Types", color: headingColor))
                content.append(makeBody("""
Convert any footnote to an endnote (or vice versa) with a single click. The note's content is preserved; only its placement changes.

• Footnotes appear at the bottom of each page
• Endnotes collect at the end of the document
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Numbering Styles", color: headingColor))
                content.append(makeBody("""
Choose from multiple numbering styles:
• Arabic numerals (1, 2, 3...)
• Roman numerals, lowercase (i, ii, iii...)
• Roman numerals, uppercase (I, II, III...)
• Alphabetic, lowercase (a, b, c...)
• Alphabetic, uppercase (A, B, C...)
• Symbols (*, †, ‡, §, ‖, ¶...)

You can set different styles for footnotes and endnotes.
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Using Footnotes & Endnotes", color: headingColor))
                content.append(makeBody("""
Insert → Insert Footnote (or Insert Endnote)

The dialog allows you to:
• Enter note content
• View all existing notes
• Navigate to any note in the document
• Delete notes (both reference and content)
• Convert between footnote and endnote
• Change numbering style

Double-click any note in the list to jump to its location in the document.
""", color: bodyColor))
                content.append(makeNewline())

                // MARK: Bookmarks
                content.append(makeHeading("🔖 Bookmarks", color: headingColor))
                content.append(makeBody("""
Bookmarks are named anchors in your document that you can reference from elsewhere. Unlike simple text markers, Quill Pilot bookmarks have stable internal IDs that persist even when the document changes.
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Creating Bookmarks", color: headingColor))
                content.append(makeBody("""
Insert → Bookmark…

1. Position your cursor where you want the bookmark
2. Enter a descriptive name (e.g., "Chapter 3 Introduction")
3. Click Add

The bookmark is inserted as an invisible anchor at the cursor position.
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Managing Bookmarks", color: headingColor))
                content.append(makeBody("""
The Bookmark dialog shows all bookmarks in your document:
• Add: Create a new bookmark at the cursor
• Delete: Remove a bookmark and its anchor
• Go To: Jump to the bookmark's location

Bookmarks persist when you save and reload your document.
""", color: bodyColor))
                content.append(makeNewline())

                // MARK: Cross-References
                content.append(makeHeading("🔗 Cross-References", color: headingColor))
                content.append(makeBody("""
Cross-references are dynamic fields that point to bookmarks, headings, or other document elements. When the target moves or changes, you can update all cross-references to reflect the new state.
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Creating Cross-References", color: headingColor))
                content.append(makeBody("""
Insert → Cross-reference…

1. Choose the reference type (Bookmark, Heading, Caption, etc.)
2. Select the target from the list
3. Choose what to display:
   • Text: The referenced text itself
   • Page Number: The page where the target appears
   • Paragraph Number: For numbered items
   • Above/Below: Relative position ("see above" / "see below")
   • Full Context: Text with page number
4. Optionally make it a clickable hyperlink
5. Click Insert
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Updating Cross-References", color: headingColor))
                content.append(makeBody("""
Insert → Update Fields

Cross-references show their last computed value. When document content changes (page numbers shift, text moves), use Update Fields to refresh all references to their current values.

This manual update model prevents constant recalculation while editing and ensures you control when references are synchronized.
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Display Modes Explained", color: headingColor))
                content.append(makeBody("""
• Text: Shows the actual text at the bookmark/heading location
  Example: "Chapter 3: The Journey Begins"

• Page Number: Shows just the page number
  Example: "42"

• Above/Below: Shows relative position from the reference
  Example: "above" or "below"

• Full Context: Shows text plus page number
  Example: "Chapter 3: The Journey Begins on page 42"
""", color: bodyColor))
                content.append(makeNewline())

                // MARK: Best Practices
                content.append(makeHeading("💡 Best Practices", color: headingColor))

                content.append(makeSubheading("Footnotes vs. Endnotes", color: headingColor))
                content.append(makeBody("""
• Use footnotes for brief clarifications readers might want immediately
• Use endnotes for longer citations or supplementary material
• Academic writing typically uses footnotes for citations
• Fiction rarely uses either—consider whether you truly need them
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Naming Bookmarks", color: headingColor))
                content.append(makeBody("""
• Use descriptive names: "protagonist_introduction" not "bm1"
• Group related bookmarks with prefixes: "ch3_", "appendix_"
• Avoid special characters that might cause export issues
• Keep names concise but meaningful
""", color: bodyColor))
                content.append(makeNewline())

                content.append(makeSubheading("Cross-Reference Strategy", color: headingColor))
                content.append(makeBody("""
• Create bookmarks at stable structural points (chapter starts, key sections)
• Use "Above/Below" for nearby references that won't move far
• Use "Page Number" for distant references in print-oriented documents
• Update fields before final export or print
• Test cross-references after major structural edits
""", color: bodyColor))
                content.append(makeNewline())

                // MARK: FAQ
                content.append(makeHeading("❓ Frequently Asked Questions", color: headingColor))
                content.append(makeBody("""
Q: Why can't I just type footnote numbers manually?
A: Manual numbering breaks renumbering, navigation, export semantics, and accessibility. Quill Pilot's structured notes maintain all these features automatically.

Q: What happens if I delete a bookmark that has cross-references?
A: The cross-references will show "[Ref not found]" until you update them or delete them. The document remains intact.

Q: Do footnotes export to Word correctly?
A: Yes. Quill Pilot's structured footnotes export as proper Word footnotes, maintaining numbering and navigation.

Q: Can I have footnotes restart numbering each page/chapter?
A: The current version supports continuous numbering. Section-based restart is planned for a future update.

Q: Why don't cross-references update automatically?
A: Automatic updates during editing would cause constant recalculation and potential cursor jumping. Manual update gives you control and better performance.

Q: Can I convert all footnotes to endnotes at once?
A: Currently conversion is per-note. Bulk conversion is planned for a future update.

Q: Do bookmarks affect my document's appearance?
A: No. Bookmark anchors are invisible zero-width characters. They don't affect layout or printing.
""", color: bodyColor))

                normalizeAppNameInDocumentation(content)
                textView.textStorage?.setAttributedString(content)
        }

        // MARK: - Tab: Keyboard Shortcuts

        private func loadShortcutsTab() {
                                guard textViews.count > 10 else { return }
                                let textView = textViews[10]
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Keyboard Shortcuts", color: titleColor))
        content.append(makeNewline())

        content.append(makeSubheading("📄 File Operations", color: headingColor))
        content.append(makeBody("""
⌘N - New document
⌘O - Open document
⌘S - Save document
⌘⇧S - Save As (choose new location/format)
File > Export… - Export without changing the document’s identity
⌘P - Print
⌘W - Close window

Note: Auto-save runs periodically for saved documents (default 1 minute; configurable in Preferences: Off, 1 minute, or 5 minutes).
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("✂️ Editing", color: headingColor))
        content.append(makeBody("""
⌘Z - Undo
⌘⇧Z - Redo
⌘X - Cut
⌘C - Copy
⌘V - Paste
⌘A - Select All
⌘F - Find & Replace (opens the Find panel)
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeSubheading("📝 Formatting", color: headingColor))
        content.append(makeBody("""
⌘B - Bold
⌘I - Italic
⌘U - Underline
⌘T - Font panel
⌘[ - Align left
⌘] - Align right
⌘\\ - Align center
⌘E - Center text
⌘} - Increase indent

Format menu:
• Typography: Drop Cap, Old-Style Numerals, Optical Kerning
• Lists: Bulleted List, Numbered List, Restart Numbering
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
⌘, - Preferences
⌘? - Show this help (QuillPilot Help)
""", color: bodyColor))
        content.append(makeNewline())

                normalizeAppNameInDocumentation(content)
        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Helper Methods

    private func makeTitle(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacingBefore = 8
                paragraphStyle.paragraphSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: color,
                        .paragraphStyle: paragraphStyle,
                        helpHeadingAttributeKey: text
        ]
        return NSAttributedString(string: text + "\n", attributes: attributes)
    }

    private func makeHeading(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacingBefore = 8
                paragraphStyle.paragraphSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: color,
                        .paragraphStyle: paragraphStyle,
                        helpHeadingAttributeKey: text
        ]
        return NSAttributedString(string: text + "\n", attributes: attributes)
    }

    private func makeSubheading(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacingBefore = 6
                paragraphStyle.paragraphSpacing = 2
                                paragraphStyle.headIndent = 0
                                paragraphStyle.firstLineHeadIndent = 0

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: color,
                        .paragraphStyle: paragraphStyle,
                        helpHeadingAttributeKey: text
        ]
        return NSAttributedString(string: text + "\n", attributes: attributes)
    }

        private func makeBody(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 0
                paragraphStyle.paragraphSpacing = 1
                paragraphStyle.headIndent = 0
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
                let normalizedText = text.hasSuffix("\n") ? text : text + "\n"
                return NSAttributedString(string: normalizedText, attributes: attributes)
    }

    private func makeNewline() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0
        paragraphStyle.paragraphSpacing = 0
        return NSAttributedString(
                string: "\n",
                attributes: [
                        .font: NSFont.systemFont(ofSize: 13),
                        .paragraphStyle: paragraphStyle
                ]
        )
    }

                // MARK: - Toolbar Tab
    private func loadToolbarTab() {
                        guard textViews.count > 7, let textView = textViews[safe: 7] else { return }
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("🧰 Toolbar", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("Tables", color: headingColor))
        content.append(makeBody("""
Use the table button (⊞) in the toolbar to open Table Operations.

Insert a new table
• Choose Rows and Columns, then click Insert Table.

Edit an existing table
• Insert Row adds a row below your current row.
• Delete Row removes the row containing your cursor.
• Delete Table removes the entire table.

Note: Column delete is not supported in-place; recreate the table with the desired column count if you need fewer columns.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Images", color: headingColor))
        content.append(makeBody("""
Click an image to show its controls. Use Move to reposition the image:
• Click Move in the image controls.
• Click the destination in the document (including table cells).

The image is removed from the original location and inserted at the new position.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Format Painter", color: headingColor))
        content.append(makeBody("""
Use the paintbrush button to copy formatting from one selection and apply it to another.

How to use
• Select text with the formatting you want.
• Click Format Painter, then select the target text.
• The formatting is applied once and the tool turns off.

Tips
• Best for copying mixed formatting (font, size, paragraph style, inline bold/italic).
• Use it before or after applying a catalog style to fix small mismatches.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Sidebar Toggle", color: headingColor))
        content.append(makeBody("""
Use the sidebar button to show or hide both sidebars (left navigation + right panels).

Tips
• Hide the sidebar for a distraction-free writing space.
• Reopen it when you need navigation or analysis panels.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Style Editor", color: headingColor))
        content.append(makeBody("""
Use the style editor button to open the Style Editor and customize the current template.

What it does
• Edit font, size, spacing, and indents for each style.
• Save changes to your active template.

Tips
• Start with Body Text, then adjust headings and chapter styles to match.
• Use small, consistent changes to preserve layout across the manuscript.
• To remove overrides and return to defaults, use Tools → Reset Template Overrides.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Find & Replace", color: headingColor))
        content.append(makeBody("""
Use the Find & Replace button in the toolbar (or Edit → Find & Replace…, ⌘F) to open the search panel.

What you can do
• Find next/previous occurrences
• Replace single matches or Replace All
• Go to Page: jump to a specific page number and see current page info
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Indentation", color: headingColor))
        content.append(makeBody("""
Use the increase/decrease indent buttons to adjust paragraph indentation.

Tips
• ⌘} increases indent
• Indentation affects the current paragraph or selected paragraphs
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Bulleted Lists", color: headingColor))
        content.append(makeBody("""
Use the bulleted list button (or Format → Lists → Bulleted List) to toggle bullets.

Tips
• Press Return to continue bullets
• Press Return on an empty bullet to end the list
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Columns", color: headingColor))
        content.append(makeBody("""
Use the columns button (⫼) to create multi-column layouts.

Set columns
• Choose 2–4 columns from the sheet and apply.

Insert column breaks
• Use Insert Column Break (toolbar button or Insert → Insert Column Break) to force text into the next column. This only affects text when a multi-column layout is active.

Balance columns
• Use Balance Columns in the Column Operations sheet to reflow text evenly across columns.

Delete columns
• Delete Column removes the column at the cursor.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("List Numbering", color: headingColor))
        content.append(makeSubheading("Numbering Style: 1.1.1", color: headingColor))
        content.append(makeNewline())

        content.append(makeBody("""
QuillPilot uses a hierarchical numbering system for lists.

Numbering styles (Preferences → Numbering style):
• 1.1.1 (decimal dotted)
• A. B. C. (alphabetic uppercase)
• a. b. c. (alphabetic lowercase)
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("Creating Numbered Lists", color: headingColor))
        content.append(makeBody("""
• Go to Format → Lists → Numbered List
• Or use the numbering button in the toolbar
• Type your content and press Return to continue numbering
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("Indenting (Creating Sub-levels)", color: headingColor))
        content.append(makeBody("""
• Press Tab while the cursor is on a numbered line
• Tab does not change the current line — it queues the next Return to create a sub-level
• Press Return to create the indented sub-item on the next line
• You can nest multiple levels (1.1.1.1, etc.)
• Lettered lists alternate case by level (A → a → A …)
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("Restarting Numbering", color: headingColor))
        content.append(makeBody("""
• Go to Format → Lists → Restart Numbering…
• Choose a custom starting number
• Default restart is at 1
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("Auto-Numbering on Return", color: headingColor))
        content.append(makeBody("""
• Enabled by default in Preferences
• Can be turned off if you prefer manual control
• When enabled, pressing Return automatically continues the list
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("Ending a List", color: headingColor))
        content.append(makeBody("""
• If a numbered item is empty, pressing Return ends the list
• You can also manually remove numbering via Format → Lists → Numbered List (toggle off)
""", color: bodyColor))
        content.append(makeNewline())
        content.append(makeNewline())

        content.append(makeSubheading("Tips", color: headingColor))
        content.append(makeBody("""
• Configure auto-numbering behavior in Preferences
• Use Tab to quickly organize hierarchical lists
• Empty line + Return exits the list automatically
""", color: bodyColor))

                normalizeAppNameInDocumentation(content)
        textView.textStorage?.setAttributedString(content)
    }

    // MARK: - Typography & Styles Tab
    private func loadTypographyTab() {
        guard textViews.count > 8, let textView = textViews[safe: 8] else { return }
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("Typography & Styles", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("✨ Typography", color: headingColor))
        content.append(makeBody("""
QuillPilot includes professional typography features:

Automatic Features:
• Ligatures - Automatically enabled for serif fonts (fi, fl, ff, ffi, ffl)
• Smart Quotes - Converts straight quotes to curly quotes
• Smart Dashes - Converts double/triple hyphens to en/em dashes

Format > Typography Menu:
• Apply Drop Cap - Creates a decorative large initial letter (3 lines tall)
        How to use: Place the cursor anywhere in the paragraph you want to affect, then choose Apply Drop Cap.
        Undo: ⌘Z immediately removes it.

• Use Old-Style Numerals - Enables old-style (lowercase-style) numerals via OpenType features
        How to use: Select text containing numbers (recommended) then choose Use Old-Style Numerals.
        If nothing is selected, it applies to the current paragraph.
        Note: Some fonts don’t include old-style numerals, so the result can look identical.
        Undo: ⌘Z.

• Apply Optical Kerning - Uses font kerning features for better visual spacing
        How to use: Select a word/sentence (recommended) then choose Apply Optical Kerning.
        If nothing is selected, it applies to the current paragraph.
        Note: Optical kerning is subtle and font-dependent; it’s easiest to see at larger font sizes.
        Undo: ⌘Z.

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
• Poetry
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
• Import note: Import justification can depend on the active template when the imported text doesn’t include reliable paragraph styles. In those cases, QuillPilot fills the gaps using the current template’s defaults.
• When you open a document, QuillPilot applies the currently selected template even if the document was saved with a different template.
""", color: bodyColor))

                normalizeAppNameInDocumentation(content)
        textView.textStorage?.setAttributedString(content)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
