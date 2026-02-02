//
//  DocumentationWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import WebKit

// MARK: - Help Topic Model

struct HelpTopic: Identifiable {
    let id: String
    let title: String
    let icon: String?
    var children: [HelpTopic]
    let contentLoader: (() -> NSAttributedString)?

    var isSection: Bool { children.isEmpty == false && contentLoader == nil }

    init(id: String, title: String, icon: String? = nil, children: [HelpTopic] = [], contentLoader: (() -> NSAttributedString)? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.children = children
        self.contentLoader = contentLoader
    }
}

// MARK: - Sidebar Item for Outline View

class HelpSidebarItem: NSObject {
    let topic: HelpTopic
    var isExpanded: Bool = true
    var children: [HelpSidebarItem]

    init(topic: HelpTopic) {
        self.topic = topic
        self.children = topic.children.map { HelpSidebarItem(topic: $0) }
        super.init()
    }
}

// MARK: - Sidebar Row View

final class HelpRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { false }
        set { }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let theme = ThemeManager.shared.currentTheme
        let selectionColor = theme.pageBorder.withAlphaComponent(0.35)
        selectionColor.setFill()
        let selectionRect = bounds.insetBy(dx: 6, dy: 3)
        let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
        path.fill()
    }
}

// MARK: - Search Result

struct HelpSearchResult {
    let topicId: String
    let topicTitle: String
    let matchedText: String
    let range: NSRange
    let score: Int
}

// MARK: - Documentation Window Controller

class DocumentationWindowController: NSWindowController, NSWindowDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NSSearchFieldDelegate, NSTextFieldDelegate, NSSplitViewDelegate {

    private let helpHeadingAttributeKey = NSAttributedString.Key("QuillHelpHeading")

    // UI Components
    private var splitView: NSSplitView!
    private var sidebarScrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var contentScrollView: NSScrollView!
    private var contentTextView: NSTextView!
    private var searchField: NSSearchField!
    private var searchResults: [HelpSearchResult] = []
    private var headerView: NSView!
    private var currentSearchQuery: String?
    private var searchMatchRanges: [NSRange] = []
    private var currentMatchIndex: Int = 0
    private var currentMatchTopicId: String?

    private var searchTextObserver: NSObjectProtocol?

    // Data
    private var sidebarItems: [HelpSidebarItem] = []
    private var topicContent: [String: NSAttributedString] = [:]
    private var flatTopics: [HelpTopic] = []

    // Observers
    private var themeObserver: NSObjectProtocol?
    private var keyDownMonitor: Any?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quill Pilot Help"
        window.minSize = NSSize(width: 700, height: 500)
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self

        buildHelpStructure()
        setupUI()
        loadAllContent()
        selectTopic(id: "quickstart")

        debugLog("Help window initialized; Bundle.main.bundlePath=\(Bundle.main.bundlePath)")

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
            // Cmd+F focuses search
            if event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers,
               chars.lowercased() == "f" {
                self.searchField.becomeFirstResponder()
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
        if let searchTextObserver {
            NotificationCenter.default.removeObserver(searchTextObserver)
        }
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
    }

    func windowWillClose(_ notification: Notification) {
        searchField?.stringValue = ""
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = window else { return }
        // Don't close if a sheet is currently presented
        if window.attachedSheet != nil {
            return
        }
        window.close()
    }

    // MARK: - Build Help Structure

    private func buildHelpStructure() {
        let topics: [HelpTopic] = [
            HelpTopic(id: "quickstart", title: "Quick Start", icon: "🚀", contentLoader: { self.makeQuickStartContent() }),

            HelpTopic(id: "getting-started", title: "Getting Started", icon: "▸", children: [
                HelpTopic(id: "about", title: "About", icon: "ℹ️", contentLoader: { self.makeAboutContent() }),
                HelpTopic(id: "toolbar", title: "Toolbar", icon: "🧰", contentLoader: { self.makeToolbarContent() }),
                HelpTopic(id: "navigator", title: "Navigator", icon: "🧭", contentLoader: { self.makeNavigatorContent() })
            ]),

            HelpTopic(id: "writing-structure", title: "Writing & Structure", icon: "▸", children: [
                HelpTopic(id: "scenes", title: "Scenes", icon: "🎬", contentLoader: { self.makeScenesContent() }),
                HelpTopic(id: "plot-structure", title: "Plot & Structure", icon: "📖", contentLoader: { self.makePlotContent() }),
                HelpTopic(id: "character-library", title: "Character Library", icon: "👥", contentLoader: { self.makeCharacterLibraryContent() })
            ]),

            HelpTopic(id: "analysis-tools", title: "Analysis & Story Tools", icon: "▸", children: [
                HelpTopic(id: "analysis-overview", title: "Overview", icon: "📊", contentLoader: { self.makeAnalysisOverviewContent() }),
                HelpTopic(id: "character-analysis", title: "Character Analysis", icon: "📈", contentLoader: { self.makeCharacterAnalysisContent() }),
                HelpTopic(id: "poetry-analysis", title: "Poetry Analysis", icon: "🪶", contentLoader: { self.makePoetryAnalysisContent() })
            ]),

            HelpTopic(id: "formatting-layout", title: "Formatting & Layout", icon: "▸", children: [
                HelpTopic(id: "typography-styles", title: "Typography & Styles", icon: "🎨", contentLoader: { self.makeTypographyContent() }),
                HelpTopic(id: "sections-pagenumbers", title: "Sections & Page Numbers", icon: "📄", contentLoader: { self.makeSectionsContent() })
            ]),

            HelpTopic(id: "references-notes", title: "References & Notes", icon: "▸", children: [
                HelpTopic(id: "references", title: "References", icon: "🔖", contentLoader: { self.makeReferencesContent() }),
                HelpTopic(id: "notes", title: "Notes", icon: "📝", contentLoader: { self.makeNotesContent() })
            ]),

            HelpTopic(id: "productivity", title: "Productivity", icon: "▸", children: [
                HelpTopic(id: "shortcuts", title: "Keyboard Shortcuts", icon: "⌨️", contentLoader: { self.makeShortcutsContent() })
            ])
        ]

        sidebarItems = topics.map { HelpSidebarItem(topic: $0) }

        // Build flat list for search
        func flatten(_ topic: HelpTopic) {
            if topic.contentLoader != nil {
                flatTopics.append(topic)
            }
            for child in topic.children {
                flatten(child)
            }
        }
        topics.forEach { flatten($0) }
    }

    // MARK: - Setup UI

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true

        // Search header
        headerView = NSView(frame: .zero)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        contentView.addSubview(headerView)

        // Search field with magnifying glass styling
        searchField = NSSearchField(frame: .zero)
        searchField.placeholderString = "Search Help"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        headerView.addSubview(searchField)

        // Ensure we get change events even if target/action isn't sent per keystroke.
        searchTextObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: searchField,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.searchFieldChanged(self.searchField)
        }

        // Split view for sidebar + content
        splitView = NSSplitView(frame: .zero)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        contentView.addSubview(splitView)

        // Sidebar
        sidebarScrollView = NSScrollView(frame: .zero)
        sidebarScrollView.hasVerticalScroller = true
        sidebarScrollView.hasHorizontalScroller = false
        sidebarScrollView.autohidesScrollers = true
        sidebarScrollView.borderType = .noBorder

        outlineView = NSOutlineView(frame: .zero)
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 16
        outlineView.rowHeight = 28
        outlineView.selectionHighlightStyle = .regular
        outlineView.allowsEmptySelection = false
        outlineView.allowsMultipleSelection = false
        outlineView.target = self
        outlineView.action = #selector(outlineViewClicked(_:))
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.autosaveExpandedItems = false
        outlineView.autosaveName = nil

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        sidebarScrollView.documentView = outlineView
        splitView.addArrangedSubview(sidebarScrollView)

        // Content area
        contentScrollView = NSScrollView(frame: .zero)
        contentScrollView.hasVerticalScroller = true
        contentScrollView.hasHorizontalScroller = false
        contentScrollView.autohidesScrollers = false
        contentScrollView.borderType = .noBorder

        contentTextView = NSTextView(frame: .zero)
        contentTextView.isEditable = false
        contentTextView.isSelectable = true
        contentTextView.drawsBackground = true
        contentTextView.textContainerInset = NSSize(width: 24, height: 24)
        contentTextView.isHorizontallyResizable = false
        contentTextView.isVerticallyResizable = true
        contentTextView.autoresizingMask = [.width]
        contentTextView.minSize = NSSize(width: 0, height: 0)
        contentTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        contentTextView.textContainer?.containerSize = NSSize(width: contentScrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        contentTextView.textContainer?.widthTracksTextView = true
        contentTextView.textContainer?.heightTracksTextView = false

        contentScrollView.documentView = contentTextView
        splitView.addArrangedSubview(contentScrollView)

        window.contentView = contentView

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 52),

            searchField.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            splitView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Defer layout-sensitive sizing to avoid layout recursion warnings.
        DispatchQueue.main.async { [weak self] in
            self?.finalizeInitialLayout()
        }

        // Expand all sections by default
        for item in sidebarItems {
            outlineView.expandItem(item)
        }

        applyTheme()
    }

    private func finalizeInitialLayout() {
        // Ensure the text view has a non-zero initial size; otherwise it can render blank.
        let contentSize = contentScrollView.contentSize
        let initialHeight = max(contentSize.height, 1)
        contentTextView.frame = NSRect(x: 0, y: 0, width: max(contentSize.width, 1), height: initialHeight)
        contentTextView.autoresizingMask = [.width, .height]
        contentTextView.textContainer?.containerSize = NSSize(width: max(contentSize.width, 1), height: CGFloat.greatestFiniteMagnitude)
        contentTextView.textContainer?.widthTracksTextView = true

        // Always force a sensible sidebar width to ensure content pane is visible.
        // Clear any persisted state that might collapse a pane.
        UserDefaults.standard.removeObject(forKey: "NSSplitView Subview Frames HelpSplitView")
        splitView.setPosition(240, ofDividerAt: 0)
        splitView.adjustSubviews()

        // Ensure both scroll views have minimum width constraints.
        sidebarScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        contentScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode

        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        window?.backgroundColor = theme.pageAround
        window?.contentView?.layer?.backgroundColor = theme.pageAround.cgColor

        // Header (search area)
        headerView.layer?.backgroundColor = theme.headerBackground.cgColor
        headerView.layer?.borderWidth = 0
        headerView.layer?.borderColor = theme.pageBorder.withAlphaComponent(0.2).cgColor

        // Search field
        searchField.textColor = theme.textColor
        searchField.backgroundColor = theme.pageBackground
        searchField.drawsBackground = true
        searchField.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Sidebar
        sidebarScrollView.backgroundColor = theme.pageBackground.blended(withFraction: 0.05, of: theme.pageAround) ?? theme.pageBackground
        outlineView.backgroundColor = sidebarScrollView.backgroundColor

        // Content
        contentScrollView.backgroundColor = theme.pageAround
        contentTextView.backgroundColor = theme.pageAround
        contentTextView.textColor = theme.textColor

        outlineView.reloadData()
    }

    // MARK: - Load Content

    private func loadAllContent() {
        for topic in flatTopics {
            if let loader = topic.contentLoader {
                topicContent[topic.id] = loader()
            }
        }
    }

    // MARK: - Topic Selection

    func selectTopic(id: String) {
        // Find and select in outline
        func findItem(_ items: [HelpSidebarItem], id: String) -> HelpSidebarItem? {
            for item in items {
                if item.topic.id == id { return item }
                if let found = findItem(item.children, id: id) {
                    outlineView.expandItem(item)
                    return found
                }
            }
            return nil
        }

        if let item = findItem(sidebarItems, id: id) {
            let row = outlineView.row(forItem: item)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }

            showTopicContent(id: id)
        }
    }

    private func showTopicContent(id: String) {
        guard let content = topicContent[id] else { return }
        debugLog("Help showTopicContent id=\(id) length=\(content.length)")
        if let title = flatTopics.first(where: { $0.id == id })?.title {
            window?.title = "Quill Pilot Help — \(title)"
        }
        let displayContent = NSMutableAttributedString(attributedString: content)
        if let query = currentSearchQuery, !query.isEmpty {
            applySearchHighlights(to: displayContent, query: query)
        }
        contentTextView.textStorage?.setAttributedString(displayContent)
        if let container = contentTextView.textContainer {
            contentTextView.layoutManager?.ensureLayout(for: container)
        }
            currentMatchTopicId = id
            updateSearchMatches(for: currentSearchQuery)
        contentTextView.setSelectedRange(NSRange(location: 0, length: 0))
        contentTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        contentScrollView.reflectScrolledClipView(contentScrollView.contentView)
        contentTextView.needsDisplay = true
    }

    func jumpToHeading(_ heading: String) {
        // Search for topic containing this heading
        let normalized = heading.lowercased()
        for topic in flatTopics {
            if let content = topicContent[topic.id] {
                let text = content.string.lowercased()
                if text.contains(normalized) {
                    selectTopic(id: topic.id)
                    // Find and highlight the heading
                    if let range = text.range(of: normalized) {
                        let location = text.distance(from: text.startIndex, to: range.lowerBound)
                        let nsRange = NSRange(location: location, length: normalized.count)
                        contentTextView.setSelectedRange(nsRange)
                        contentTextView.scrollRangeToVisible(nsRange)
                        contentTextView.showFindIndicator(for: nsRange)
                    }
                    return
                }
            }
        }
        // Fallback to Quick Start
        selectTopic(id: "quickstart")
    }

    /// Legacy compatibility: Maps old tab identifiers to new sidebar topics
    func selectTab(identifier: String) {
        // Map old tab identifiers to new topic IDs
        let mapping: [String: String] = [
            "about": "about",
            "why": "about",
            "toolbar": "toolbar",
            "navigator": "navigator",
            "scenes": "scenes",
            "plot": "plot-structure",
            "characters": "character-library",
            "character-library": "character-library",
            "analysis": "analysis-overview",
            "character-analysis": "character-analysis",
            "poetry": "poetry-analysis",
            "poetry-analysis": "poetry-analysis",
            "typography": "typography-styles",
            "sections": "sections-pagenumbers",
            "formatting": "sections-pagenumbers",
            "references": "references",
            "notes": "notes",
            "shortcuts": "shortcuts",
            "keyboard": "shortcuts"
        ]

        let topicId = mapping[identifier] ?? "quickstart"
        selectTopic(id: topicId)
    }

    // MARK: - Search

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        let query = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        debugLog("Help search changed query='\(query)'")

        currentSearchQuery = query.isEmpty ? nil : query

        if query.isEmpty {
            contentTextView.setSelectedRange(NSRange(location: 0, length: 0))
            searchMatchRanges = []
            currentMatchIndex = 0
            currentMatchTopicId = nil
            return
        }

        performSearch(query: query)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === searchField else { return }
        searchFieldChanged(field)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField else { return false }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                return true
            }
            if currentSearchQuery == query, !searchMatchRanges.isEmpty {
                goToNextSearchMatch()
            } else {
                performSearch(query: query)
            }
            return true
        }

        return false
    }

    private func performSearch(query: String) {
        searchResults.removeAll()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryWords = trimmedQuery.split(separator: " ").map { String($0) }

        for topic in flatTopics {
            guard let content = topicContent[topic.id] else { continue }
            let text = content.string
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)

            // Score based on matches
            var score = 0
            var matchRange: NSRange?

            // Title match (highest priority)
            if (topic.title as NSString).range(of: trimmedQuery, options: [.caseInsensitive]).location != NSNotFound {
                score += 100
            }

            // Exact phrase match (preferred)
            let phraseRange = nsText.range(of: trimmedQuery, options: [.caseInsensitive], range: fullRange)
            if phraseRange.location != NSNotFound {
                score += 120
                matchRange = phraseRange
            }

            // Word matches
            let matchCount = queryWords.filter { word in
                nsText.range(of: word, options: [.caseInsensitive], range: fullRange).location != NSNotFound
            }.count
            if matchCount == queryWords.count {
                score += 50
            } else if matchCount > 0 {
                score += 20 * matchCount
            }

            // If we have word matches but no phrase range yet, pick the earliest word occurrence.
            if matchRange == nil, matchCount > 0 {
                var best: NSRange?
                for word in queryWords where !word.isEmpty {
                    let r = nsText.range(of: word, options: [.caseInsensitive], range: fullRange)
                    if r.location == NSNotFound { continue }
                    if best == nil || r.location < best!.location {
                        best = r
                    }
                }
                matchRange = best
            }

            if score > 0 {
                // Extract context around match
                var matchedText = topic.title
                if let range = matchRange {
                    let start = max(0, range.location - 20)
                    let end = min(nsText.length, range.location + range.length + 40)
                    if end > start {
                        let snippetRange = NSRange(location: start, length: end - start)
                        matchedText = nsText.substring(with: snippetRange).trimmingCharacters(in: .whitespacesAndNewlines)
                        if start > 0 { matchedText = "…" + matchedText }
                        if end < nsText.length { matchedText += "…" }
                    }
                }

                searchResults.append(HelpSearchResult(
                    topicId: topic.id,
                    topicTitle: topic.title,
                    matchedText: matchedText,
                    range: matchRange ?? NSRange(location: 0, length: 0),
                    score: score
                ))
            }
        }

        // Sort by score
        searchResults.sort { $0.score > $1.score }
        searchResults = Array(searchResults.prefix(10))

        if let topResult = searchResults.first {
            applySearchResult(topResult)
        }
    }

    private func applySearchResult(_ result: HelpSearchResult) {
        debugLog("Help applySearchResult topicId=\(result.topicId) score=\(result.score) range=\(result.range)")
        // Make search navigation work even if the outline selection is finicky.
        selectTopic(id: result.topicId)

        currentMatchTopicId = result.topicId

        if result.range.length > 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateSearchMatches(for: self.currentSearchQuery)
                self.setSearchMatchIndex(for: result.range)
                self.contentTextView.setSelectedRange(result.range)
                self.contentTextView.scrollRangeToVisible(result.range)
                self.contentTextView.showFindIndicator(for: result.range)
            }
        }
    }

    private func updateSearchMatches(for query: String?) {
        guard let query, !query.isEmpty else {
            searchMatchRanges = []
            currentMatchIndex = 0
            return
        }

        let nsText = contentTextView.string as NSString
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.location < nsText.length {
            let found = nsText.range(of: query, options: [.caseInsensitive], range: searchRange)
            if found.location == NSNotFound { break }
            ranges.append(found)
            let nextLocation = found.location + max(1, found.length)
            searchRange = NSRange(location: nextLocation, length: max(0, nsText.length - nextLocation))
        }

        searchMatchRanges = ranges
        currentMatchIndex = ranges.isEmpty ? 0 : min(currentMatchIndex, ranges.count - 1)
    }

    private func setSearchMatchIndex(for range: NSRange) {
        if let idx = searchMatchRanges.firstIndex(where: { $0.location == range.location && $0.length == range.length }) {
            currentMatchIndex = idx
        }
    }

    private func goToNextSearchMatch() {
        guard !searchMatchRanges.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % searchMatchRanges.count
        let range = searchMatchRanges[currentMatchIndex]
        contentTextView.setSelectedRange(range)
        contentTextView.scrollRangeToVisible(range)
        contentTextView.showFindIndicator(for: range)
    }

    private func applySearchHighlights(to content: NSMutableAttributedString, query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        let nsText = content.string as NSString
        let textLength = nsText.length

        let highlightColor = ThemeManager.shared.currentTheme.pageBorder.withAlphaComponent(0.25)
        var searchRange = NSRange(location: 0, length: textLength)

        while searchRange.location < textLength {
            let found = nsText.range(of: trimmedQuery, options: [.caseInsensitive], range: searchRange)
            if found.location == NSNotFound { break }
            if found.length > 0 {
                content.addAttribute(.backgroundColor, value: highlightColor, range: found)
            }
            let nextLocation = found.location + max(1, found.length)
            searchRange = NSRange(location: nextLocation, length: max(0, textLength - nextLocation))
        }
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 200  // Sidebar minimum width
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return splitView.bounds.width - 300  // Content area minimum width
    }

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return false  // Prevent any subview from collapsing
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return sidebarItems.count
        }
        if let sidebarItem = item as? HelpSidebarItem {
            return sidebarItem.children.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return sidebarItems[index]
        }
        if let sidebarItem = item as? HelpSidebarItem {
            return sidebarItem.children[index]
        }
        return NSNull()
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let sidebarItem = item as? HelpSidebarItem {
            return !sidebarItem.children.isEmpty
        }
        return false
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let sidebarItem = item as? HelpSidebarItem else { return nil }

        let theme = ThemeManager.shared.currentTheme
        let cellIdentifier = NSUserInterfaceItemIdentifier("HelpCell")

        var cellView = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        if cellView == nil {
            cellView = NSTableCellView(frame: .zero)
            cellView?.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cellView?.addSubview(textField)
            cellView?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        let topic = sidebarItem.topic
        let isSection = topic.isSection

        var displayText = ""
        if let icon = topic.icon, icon != "▸" {
            displayText = "\(icon) \(topic.title)"
        } else {
            displayText = topic.title
        }

        cellView?.textField?.stringValue = displayText
        cellView?.textField?.font = isSection ? NSFont.systemFont(ofSize: 13, weight: .semibold) : NSFont.systemFont(ofSize: 13)
        cellView?.textField?.textColor = theme.textColor

        return cellView
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return HelpRowView()
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let sidebarItem = item as? HelpSidebarItem else { return true }
        let topic = sidebarItem.topic

        if topic.isSection {
            if outlineView.isItemExpanded(sidebarItem) {
                outlineView.collapseItem(sidebarItem)
            } else {
                outlineView.expandItem(sidebarItem)
                if let firstChild = sidebarItem.children.first {
                    let childRow = outlineView.row(forItem: firstChild)
                    if childRow >= 0 {
                        outlineView.selectRowIndexes(IndexSet(integer: childRow), byExtendingSelection: false)
                    }
                }
            }
            return false
        }

        showTopicContent(id: topic.id)
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0 else { return }
        guard let item = outlineView.item(atRow: row) as? HelpSidebarItem else { return }

        let topic = item.topic

        debugLog("Help selectionDidChange row=\(row) topicId=\(topic.id) title='\(topic.title)'")

        // If it's a section header, expand/collapse it
        if topic.isSection {
            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
                if let firstChild = item.children.first {
                    let childRow = outlineView.row(forItem: firstChild)
                    if childRow >= 0 {
                        outlineView.selectRowIndexes(IndexSet(integer: childRow), byExtendingSelection: false)
                    }
                }
            }
            return
        }

        // Load content
        showTopicContent(id: topic.id)
    }

    @objc private func outlineViewClicked(_ sender: Any?) {
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0 else { return }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineViewSelectionDidChange(Notification(name: NSOutlineView.selectionDidChangeNotification, object: outlineView))
    }

    // MARK: - Helper: Make Attributed Strings

    private func makeTitle(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 8
        paragraphStyle.paragraphSpacing = 8

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
        paragraphStyle.paragraphSpacingBefore = 16
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
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 2

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
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        let normalizedText = text.hasSuffix("\n") ? text : text + "\n"
        return NSAttributedString(string: normalizedText, attributes: attributes)
    }

    private func makeNewline() -> NSAttributedString {
        return NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 8)])
    }

    private func normalizeAppNameInDocumentation(_ content: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: content.length)
        _ = content.mutableString.replaceOccurrences(of: "QuillPilot", with: "Quill Pilot", options: [], range: fullRange)
    }

    // MARK: - Content Loaders

    private func makeQuickStartContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("🚀 Quick Start", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("Getting Started in 5 Minutes", color: headingColor))
        content.append(makeBody("""
1. Create or open a document (⌘N / ⌘O)
2. Choose a template from the toolbar dropdown (Baskerville, Garamond, etc.)
3. Start writing — what you see is what you'll submit
4. Use the Navigator (left sidebar) for outline, scenes, and characters
5. Use the Analysis panel (right sidebar) for writing insights
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Common Tasks", color: headingColor))

        content.append(makeSubheading("Writing", color: headingColor))
        content.append(makeBody("""
• Apply styles from the Style Catalog (dropdown in toolbar)
• Use ⌘B / ⌘I / ⌘U for bold, italic, underline
• Insert images, tables, and columns from the toolbar
""", color: bodyColor))

        content.append(makeSubheading("Organization", color: headingColor))
        content.append(makeBody("""
• Navigator → 📖 Story Outline for chapter navigation
• Navigator → 🎬 Scenes for scene metadata
• Navigator → 👥 Characters for character profiles
""", color: bodyColor))

        content.append(makeSubheading("Analysis", color: headingColor))
        content.append(makeBody("""
• Right panel → 📊 Analysis for writing metrics
• Right panel → 📈 Character tools for arc visualization
• Right panel → 📖 Plot Structure for story beats
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Troubleshooting", color: headingColor))
        content.append(makeBody("""
• Analysis not appearing? Click the 📊 button to run analysis
• Styles not applying? Check the template dropdown
• Lost your place? Use Navigator → Document Outline
• Need keyboard shortcuts? See Productivity → Keyboard Shortcuts
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Getting Help", color: headingColor))
        content.append(makeBody("""
• Use the search field above to find any topic
• Browse categories in the sidebar
• Press ⌘F to focus search from anywhere in Help
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeAboutContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("About Quill Pilot", color: titleColor))
        content.append(makeBody("""
Designed for macOS with a fully adaptive interface—from 13-inch MacBooks to large desktop displays.

Quill Pilot is a writing environment that prioritizes how words feel on the page, not just how they're organized in a project.

It's primarily designed for experienced fiction writers who already understand story structure and want tools that enhance execution, not exploration. That said, it's equally capable for non-fiction work, supporting lists, tables, columns, and other structures common in books and publications.

At its core, Quill Pilot is about refining what you've already learned—making strong writing clearer, more consistent, and more intentional.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Writing as Final Output", color: headingColor))
        content.append(makeBody("""
What you see is what you submit. No compile step. No export-format-revise cycle.

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

Typography isn't decoration here; it's feedback.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Narrative Analysis & Story Intelligence", color: headingColor))
        content.append(makeBody("""
One of Quill Pilot's major strengths is its integrated analysis system, designed to surface patterns and weaknesses without pulling you out of the writing flow.

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

Story Notes
Theme, locations, outlines, and directions are saved as lightweight JSON files at:
~/Library/Application Support/Quill Pilot/StoryNotes/

Character Library
Character entries are stored per document as a sidecar file next to your manuscript:
MyStory.docx.characters.json

If these files are deleted, Quill Pilot treats the associated data as empty for that document.

This separation keeps your manuscript clean while preserving deep contextual knowledge.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Working Format", color: headingColor))
        content.append(makeBody("""
📦 RTFD (Recommended)
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
        content.append(makeBody("""
Choose Quill Pilot if you:
• Write primarily novels or screenplays
• Already understand story structure
• Care how the page looks while you write
• Want insight, not organization
• Submit to agents or publishers regularly
• Prefer writing in a finished-looking manuscript
• Value execution refinement over project management

Quill Pilot is not trying to:
• Manage research PDFs or web archives
• Handle citations or footnotes
• Compile into multiple output formats
• Serve as a universal project manager
• Replace Scrivener's binder system

Those are legitimate needs—but they're not what Quill Pilot optimizes for.
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeToolbarContent() -> NSAttributedString {
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

        content.append(makeHeading("Columns", color: headingColor))
        content.append(makeBody("""
Use the columns button (⫼) to create multi-column layouts.

Set columns
• Choose 2–4 columns from the sheet and apply.

Insert column breaks
• Use Insert Column Break (toolbar button or Insert → Insert Column Break) to force text into the next column.

Balance columns
• Use Balance Columns in the Column Operations sheet to reflow text evenly across columns.
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeNavigatorContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("🧭 Navigator", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("Document Outline", color: headingColor))
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

        content.append(makeHeading("Story Theme", color: headingColor))
        content.append(makeBody("""
Describe the central idea, question, or insight the story explores.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Scenes", color: headingColor))
        content.append(makeBody("""
See the Scenes topic under Writing & Structure for the full breakdown of how Scenes work.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Story Outline", color: headingColor))
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

        content.append(makeHeading("Locations & Directions", color: headingColor))
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

        content.append(makeHeading("General Notes", color: headingColor))
        content.append(makeBody("""
Capture free-form ideas, reminders, or planning notes tied to your document.
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeScenesContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("🎬 Scene Management", color: titleColor))
        content.append(makeBody("""
Scenes provide a semantic spine for your story—organizational metadata that helps you track, analyze, and navigate your manuscript without touching the text itself.

Access: Click 🎬 Scenes in the Navigator panel (right sidebar)

IMPORTANT: Scenes are created manually, NOT extracted from your document. You create each scene by clicking the + button and filling in the details.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Quick Start: Creating Your First Scene", color: headingColor))
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

        content.append(makeHeading("What Are Scenes?", color: headingColor))
        content.append(makeBody("""
Scenes in Quill Pilot are metadata containers—they track information ABOUT your story without storing or modifying your actual text. Think of them as index cards for your manuscript.

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

        content.append(makeHeading("Scene Intent Types", color: headingColor))
        content.append(makeBody("""
Intent describes the narrative PURPOSE of a scene:

• Setup - Establishes characters, setting, or stakes
• Exposition - Delivers necessary background information
• Rising Action - Builds tension toward a peak
• Conflict - Direct confrontation or opposition
• Climax - Peak tension, point of no return
• Falling Action - Immediate aftermath of climax
• Resolution - Wrapping up story threads
• Transition - Moving between story elements
• Denouement - Final wrap-up after resolution

Tip: Most scenes have one PRIMARY intent, even if they serve multiple purposes. Pick the dominant one.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Revision States", color: headingColor))
        content.append(makeBody("""
Track where each scene is in your revision process:

✏️ Draft - First pass, getting ideas down
📝 Revised - Second or later pass, major changes made
✨ Polished - Line-editing complete, prose refined
✅ Final - Locked and complete
⚠️ Needs Work - Flagged for attention

Workflow Tip:
1. All scenes start as Draft
2. After story revisions → Revised
3. After line editing → Polished
4. After final review → Final
5. Use Needs Work as a flag, not a stage
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Filtering Scenes", color: headingColor))
        content.append(makeBody("""
Use the filter bar at the top of the Scene List to find specific scenes quickly.

Two Filter Dropdowns:

1. Status Filter - All States, Draft, Revised, Polished, Final, Needs Work
2. Intent Filter - All Intents, Setup, Conflict, Resolution, etc.

Filter Behavior:
• When filtering, the count shows "3/10 scenes" format
• Drag-drop reordering is disabled during filtering
• Clear filters by selecting "All States" and "All Intents"
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makePlotContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("📖 Plot Structure Analysis", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("Plot Points Visualization", color: headingColor))
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

Structure Score Guide:
90-100%: Excellent structure, all beats present
70-89%: Good structure, minor improvements possible
50-69%: Adequate structure, some beats may be weak
Below 50%: Consider restructuring
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Understanding Tension", color: headingColor))
        content.append(makeBody("""
What the % means
• Tension is normalized per story (0–100%) from sentence/beat-level signals: stakes, conflict verbs, reversals, momentum, and peril vocabulary.
• 25% = low relative tension for THIS manuscript; 75% = high pressure relative to your own quietest passages.

How the curve is built
• We score each segment, smooth spikes, and clamp to keep extreme outliers from flattening the rest.
• Novel view auto-tightens the Y-axis to your data so quiet fiction doesn't hug the bottom.

Reading the graph
• Look for rises: conflicts, reveals, and reversals should trend upward into the midpoint and act turns.
• Look for resets: valleys after climaxes show aftermath; long flat stretches can indicate low narrative momentum.
• Use the beat markers: hover or click a beat to jump to that section and confirm the tension change is earned in the prose.
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeCharacterLibraryContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("👥 Character Library", color: titleColor))
        content.append(makeBody("""
Central repository for all character information (profiles, roles, motivations, relationships, arcs).

Location:
• Left sidebar (Navigator) → 👥 Characters

Notes:
• The Character Library is a data tool, not an analysis report. Analysis visualizations live in the right-side Analysis panel.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("What It Stores", color: headingColor))
        content.append(makeBody("""
• Character profiles (name, role)
• Descriptions and backstory
• Motivations and goals
• Relationships and notes

Tip: Consistent naming (and a complete Character Library) improves character detection in the analysis tools.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("How To Use", color: headingColor))
        content.append(makeBody("""
1) Open the Character Library from the Navigator
2) Add or edit characters (including common aliases/nicknames)
3) Keep names aligned with the manuscript's actual usage

Character data is saved automatically.
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeAnalysisOverviewContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("📊 Analysis Overview", color: titleColor))
        content.append(makeBody("""
Quill Pilot's Analysis tools help you objectively evaluate your manuscript's strengths and weaknesses. Analysis runs automatically when you open any tool.

Open analysis from the right-side Analysis panel:
• Click 📊 (Analysis) to open the main analysis popout
• Click 📖 (Plot Structure) for plot/structure visualizations
• Use the character tool buttons listed under the analysis buttons

Quick access:
• 📊 Analysis — document-level metrics, writing-quality flags, dialogue metrics
• 📖 Plot Structure — plot/structure visualizations
• 👥 Character Analysis Tools — character-focused tools and maps

Tip: Auto-analyze behavior can be configured in Preferences.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("How Analysis Works", color: headingColor))
        content.append(makeBody("""
When you trigger analysis (by opening a tool), Quill Pilot:

1. Scans your entire document for patterns
2. Identifies chapters/scenes using your outline headings
3. Extracts character names from your Character Library
4. Detects decisions, beliefs, outcomes, and interactions
5. Generates visualizations and metrics

Analysis Loading Indicator:
When analysis is running, you'll see a spinning indicator and "Analyzing..." text at the bottom of the sidebar. When complete, it briefly shows "Analysis Ready" before hiding.

Waiting for Results:
If you click a character tool while analysis is still running, the tool will automatically wait for analysis to complete before opening (up to ~6 seconds). This ensures you always see current data.

Best Practices:
• Keep your Character Library updated with character names
• Use consistent chapter/scene headings for accurate segmentation
• Write clear action sentences for better decision detection
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Basic Metrics", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis

What you'll see:
• Word Count — Total words in your document
• Sentence Count — Total sentences detected
• Paragraph Count — Total paragraphs
• Average Sentence Length — Words per sentence

Example Interpretation:
A 60,000 word manuscript with 4,500 sentences has ~13 words/sentence average. If your genre typically runs 15-18 words/sentence, you might need longer, more complex sentences in places.

How to use it:
• Treat these as "manuscript telemetry," not goals
• What matters is the delta: before vs after revisions
• Compare against genre norms for context
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Writing Quality", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis

Passive Voice Detection
• Shows percentage of passive constructions
• Target: Keep below 10% for most genres
• Example: "The door was opened by Sarah" → "Sarah opened the door"

Adverb Usage
• Counts -ly adverbs
• Helps strengthen verb choices
• Example: "She walked slowly" → "She crept" or "She shuffled"

Weak Verbs
• Detects: is, was, were, get, make, have, etc.
• Suggests stronger alternatives
• Example: "He was angry" → "He fumed" or "His fists clenched"

Clichés & Overused Phrases
• Identifies common clichés
• Helps keep writing fresh
• Example: "It was a dark and stormy night" → Describe specific sensory details

Filter Words
• Perception words that distance readers: saw, felt, thought, realized, wondered, noticed
• Example: "She felt the cold wind" → "The cold wind bit her face"

Sensory Details
• Balance of sight, sound, touch, taste, smell
• Shows sensory distribution chart
• Aim for variety; don't rely only on visual descriptions
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Sentence Variety", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis

Visual graph showing distribution of:
• Short sentences (1-10 words) — Punchy, urgent
• Medium sentences (11-20 words) — Standard narrative
• Long sentences (21-30 words) — Complex, flowing
• Very long sentences (31+ words) — Elaborate, potentially difficult

Example Good Distribution:
• Short: 20%
• Medium: 50%
• Long: 25%
• Very Long: 5%

Good variety = engaging rhythm
Too uniform = monotonous reading

Tip: Action scenes benefit from shorter sentences. Introspection and description can use longer ones.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Dialogue Analysis", color: headingColor))
        content.append(makeBody("""
Access: Right panel → 📊 Analysis

10 comprehensive metrics for dialogue quality:

• Filler Word Percentage — "um," "uh," "like," "you know"
  Example: "Um, I think, you know, we should go" → "We should go"

• Repetition Detection — overused phrases in dialogue
  Example: If "I don't know" appears 15 times, characters need more varied responses

• Clichéd Phrases — avoid predictable dialogue
  Example: "It's not what it looks like" → Find a fresher way to express denial

• Exposition Levels — info-dumping in conversation
  Example: "As you know, Bob, our company was founded in 1952..." is exposition disguised as dialogue

• Conflict Presence — tension and disagreement
  Good dialogue has subtext and competing wants

• Pacing Variety — rhythm of exchanges
  Mix quick back-and-forth with longer speeches

• Tag Variety — "said" alternatives
  "Said" is often invisible, but occasional variety adds color: whispered, snapped, murmured

• Subtext Quality — what's unsaid
  Characters rarely say exactly what they mean

• Authenticity Score — sounds like real speech
  Read dialogue aloud to test naturalness

• Balance — distribution among characters
  Watch for one character dominating every conversation
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Built-in macOS Writing Tools (Apple)", color: headingColor))
        content.append(makeBody("""
Some Macs include system-provided Writing Tools (Proofread, Rewrite, Summarize, etc.). If you see this panel while editing, it's provided by macOS — not by Quill Pilot.

How to use it:
• Select text in the editor
• Control-click (or right-click) the selection
• Choose Writing Tools, then pick an option

Availability depends on your macOS version, device support, and region.
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeCharacterAnalysisContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("📈 Character Analysis Tools", color: titleColor))
        content.append(makeBody("""
Character analysis lives in the right-side Analysis panel. Each character tool has its own button.

If results aren't available yet, Quill Pilot runs analysis automatically when you open a character tool. You'll see "Analyzing..." at the bottom of the sidebar while it runs.

Prerequisites for Best Results:
• Add your main characters to the Character Library (use exact names as they appear in your manuscript)
• Use consistent chapter/scene headings for accurate segmentation
• Write clear action verbs when characters make decisions
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Emotional Trajectory", color: headingColor))
        content.append(makeBody("""
Visualize character emotional states throughout your story.

Access: Right panel → 📈 Emotional Trajectory

Features:
• Multi-character overlay with color coding
• Four emotional metrics: Confidence, Hope vs Despair, Control vs Chaos, Attachment vs Isolation
• Continuous line plots showing progression

How to interpret the curves:
• Look for changes (rises/drops), not exact numbers
• Sudden shifts often indicate turning points
• Crossovers between characters indicate conflict or reversal

Example Interpretation:
If your protagonist's "Confidence" line drops sharply in Chapter 5, then gradually rises through Chapters 6-8, that's a clear arc pattern. If it stays flat, the character may need more emotional variation.

Metric definitions:
• Confidence = presence dominance per chapter (more mentions = higher confidence displayed)
• Hope vs Despair = presence trend (rising presence = hope, falling = despair)
• Control vs Chaos = presence stability (steady appearance = control, erratic = chaos)
• Attachment vs Isolation = interaction frequency with other characters
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Decision-Belief Loops", color: headingColor))
        content.append(makeBody("""
Tracks how character decisions reinforce or challenge their beliefs. This is the core framework for understanding character growth.

Access: Right panel → 📊 Decision-Belief Loops

What the framework tracks (per chapter):
• Pressure — new forces acting on the character (external conflict, internal doubt, deadline)
• Belief in Play — the value/worldview being tested ("I can't trust anyone," "Love conquers all")
• Decision — the choice made because of (or against) that belief
• Outcome — the immediate result of that decision
• Belief Shift — how the belief changes (reinforced, refined, reversed)

Example Loop:
Chapter 3:
  Pressure: "Deadline to pay rent"
  Belief: "I have to handle everything alone"
  Decision: "Refuses roommate's offer to help"
  Outcome: "Fails to pay rent, faces eviction"
  Belief Shift: "Beginning to question self-reliance"

How the tool detects these:
• Decisions: Action verbs like "decided," "chose," "refused," "took," "grabbed," "nodded," "agreed"
• Outcomes: Result indicators like "then," "suddenly," "discovered," "found," "resulted," "meant"
• Beliefs: Cognitive words like "believed," "thought," "knew," "felt," "assumed," "expected"

If fields are empty ("No explicit keyword found"):
1. Check if the scene contains clear decision language
2. Add action verbs that signal choices: "Sarah decided to..." or "He chose the..."
3. Make outcomes explicit: "As a result..." or "This led to..."

How to use it:
1) Start with your protagonist
2) Scan for rows with 2+ empty cells
3) Open that chapter and ask: "What is the pressure? What is the choice? What does it cost?"
4) Revise to make the decision-consequence chain clearer
5) Re-run analysis to verify
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Belief Shift Matrix", color: headingColor))
        content.append(makeBody("""
Table format tracking character belief evolution through chapters.

Access: Right panel → 📋 Belief Shift Matrix

Columns:
• Chapter — Where the belief appears
• Core Belief — Character's worldview at that point
• Evidence — Actions/decisions reflecting the belief
• Counterpressure — Forces challenging the belief

Example Progression:
Ch 1: Belief: "People always let you down" | Evidence: "Refuses team assignment"
Ch 5: Belief: "People always let you down" | Counterpressure: "Partner saves his life"
Ch 9: Belief: "Some people can be trusted" | Evidence: "Asks for help voluntarily"

Evolution Quality Badge:
• Logical Evolution — Clear pressures causing belief shifts (ideal)
• Developing — Some belief shifts occurring (needs more work)
• Unchanging — Beliefs remain static (character may feel flat)
• Insufficient Data — Not enough entries to assess

If you see "Unchanging": Your character may need more moments where their worldview is challenged and they must respond.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Decision-Consequence Chains", color: headingColor))
        content.append(makeBody("""
Maps choices, not traits. Ensures growth comes from action, not narration.

Access: Right panel → ⛓️ Decision-Consequence Chains

Structure (per row):
• Scene — Chapter number where the decision occurs
• Decision — The choice the character makes
• Immediate Outcome — What happens right after
• Long-term Effect — How it changes the story going forward

Example Chain:
Scene: Ch 2
Decision: "Lies to cover friend's theft"
Immediate Outcome: "Friend escapes punishment"
Long-term Effect: "Creates guilt that drives confession in Ch 8"

Agency Assessment Badge:
• Active Protagonist — Character drives the story (ideal)
• Developing — Good balance of action and consequence
• Reactive — Some agency, needs strengthening
• Passive — Character reacts to events rather than causing them (warning)

"Insufficient Data" Means:
The tool couldn't find enough explicit decision keywords. Try adding clearer choice language:
  Instead of: "The door opened and she went through"
  Try: "She chose the left door, knowing it might be locked"

Common Patterns to Watch For:
• All decisions in early chapters, none later = character becomes passive
• No immediate outcomes = missing cause-and-effect
• No long-term effects = decisions feel inconsequential
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Character Interactions", color: headingColor))
        content.append(makeBody("""
Analyzes relationships and scenes between characters.

Access: Right panel → 🤝 Character Interactions

Features:
• Network graph of character relationships
• Frequency of interactions (how often characters appear together)
• Strength of relationships (0-100%)
• Identifies isolated characters

Example Reading:
If Character A and Character B show 85% interaction strength but Character C shows only 12%, Character C may be underdeveloped in the relationship web.

If the network looks incomplete:
• Make sure Character Library names match what the manuscript uses (including nicknames)
• Add/confirm chapter headings so segmentation aligns with your structure
• Characters need to appear in the same paragraphs/scenes to register as interacting
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Character Presence", color: headingColor))
        content.append(makeBody("""
Heat map showing which characters appear in which chapters.

Access: Right panel → 📍 Character Presence

Displays:
• Grid: Rows = Characters, Columns = Chapters
• Color intensity = mention frequency
• Numbers show exact count per chapter

Example Use Cases:
• Spot characters who disappear mid-story (gaps in their row)
• Balance POV distribution (ensure protagonist appears consistently)
• Track subplot threads (secondary characters should have presence patterns that make sense)

Warning Signs:
• A main character with zero presence in 3+ consecutive chapters
• A subplot character who appears once and never returns
• One character dominating every chapter (may overshadow others)
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Relationship Evolution Maps", color: headingColor))
        content.append(makeBody("""
Network diagram visualizing character relationships and their evolution.

Access: Right panel → 🫂 Relationship Evolution Maps

Visual Elements:
• Nodes = Characters (size = emotional investment %)
• Lines = Relationships (thickness = trust/conflict strength)
• Green lines = Trust relationships
• Red/Orange lines = Conflict relationships
• Arrows = Power direction between characters

Example Interpretation:
A thick green line between Hero and Mentor with arrow pointing from Mentor to Hero = strong trust, Mentor has influence. A thin red line between Hero and Rival = low-stakes conflict (may need intensifying).

Interactive Features:
• Drag nodes to rearrange the layout
• Edges follow as you move nodes
• Use this to visualize relationship clusters
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Internal vs External Alignment", color: headingColor))
        content.append(makeBody("""
Track the gap between who characters are inside and how they act.

Access: Right panel → 🎭 Internal vs External Alignment

Two Parallel Tracks:
• Purple line = Inner Truth (what they feel/believe)
• Teal line = Outer Behavior (what they show/do)

Gap Interpretation:
• Wide gap = Denial, repression, or masking (character hiding true self)
• Narrow gap = Authenticity or integration (character being genuine)
• Gap closing = Character becoming more authentic OR inner walls collapsing

Example Arc:
Chapter 1: Wide gap (character pretends confidence, feels insecure)
Chapter 5: Gap narrows (crack in façade after failure)
Chapter 10: Gap closes (accepts vulnerability, asks for help)

Use this to ensure characters aren't emotionally static.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Language Drift Analysis", color: headingColor))
        content.append(makeBody("""
Track how character's language changes — reveals unconscious growth.

Access: Right panel → 📝 Language Drift Analysis

Five Metrics Tracked:
1. Pronouns (I vs We)
   I → We shift = Growing sense of community/belonging
   Example: "I'll handle it" (Ch1) → "We can figure this out" (Ch10)

2. Modal Verbs (Must vs Choose)
   Must → Choose = Growing agency and autonomy
   Example: "I must obey" → "I choose to help"

3. Emotional Vocabulary
   Increasing range = Character opening up emotionally
   Limited range = Character may be emotionally stunted

4. Sentence Length
   Increasing = More complex, confident thought
   Decreasing = Possible distress or urgency

5. Certainty Level
   Rising = Growing confidence in worldview
   Falling = Doubt or transformation in progress

How to Use This:
If your character's language doesn't drift, they may feel static even if plot events happen TO them. Growth should show in HOW they speak, not just what they do.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Thematic Resonance Map", color: headingColor))
        content.append(makeBody("""
Visualize how each character aligns with (or resists) the story's theme over time.

Access: Right panel → 🎯 Thematic Resonance Map

What it shows:
• Theme alignment (from opposed → embodied)
• Awareness of the theme (unconscious → fully aware)
• Influence (how much the character drives thematic exploration)
• Personal cost (what it costs the character to engage the theme)

Example (Theme: "Forgiveness"):
Protagonist: Starts opposed (revenge-focused), ends embodied (forgives antagonist)
Antagonist: Starts unaware, ends aware but rejecting
Mentor: Embodies theme from start, high influence, low personal cost
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Failure Pattern Charts", color: headingColor))
        content.append(makeBody("""
Shows how character failures evolve across the story.

Access: Right panel → 📉 Failure Pattern Charts

Failure types tracked:
• Naive — Fails from inexperience ("I didn't know that would happen")
• Reactive — Fails from hasty response ("I panicked and ran")
• Misinformed — Fails from bad information ("They told me it was safe")
• Strategic — Fails despite good planning ("The plan was sound but...")
• Principled — Fails because of values ("I couldn't betray them")
• Costly but Chosen — Accepts failure for greater good ("I knew I'd lose, but...")

What it indicates:
• Early failures should trend toward naive/reactive patterns (character learning)
• Middle failures should show misinformed/strategic patterns (character trying)
• Late failures should show principled/costly-but-chosen patterns (character evolved)
• A flat pattern suggests limited growth in decision quality

Example Arc:
Ch 2: Naive failure (didn't know enemy's strength)
Ch 5: Strategic failure (good plan, unexpected variable)
Ch 9: Principled failure (could have won by cheating, chose not to)
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makePoetryAnalysisContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("🪶 Poetry Analysis", color: titleColor))
        content.append(makeBody("""
When the Poetry template is active, Quill Pilot provides specialized analysis tools designed for verse. The Analysis popout (📊 button) opens a poetry-focused window with six analytical lenses.

Access: Right panel → 📊 Analysis (with Poetry template active)
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Formal / Technical Analysis", color: headingColor))
        content.append(makeBody("""
Examines the structural mechanics of your poem.

What it tracks:
• Line Count — Total lines in the poem body (excludes title/author)
• Stanza Count — Number of stanza groupings (separated by blank lines)
• Average Line Length — Mean syllables or words per line
• Enjambment Rate — Percentage of lines that run over without punctuation
• End-Stop Rate — Percentage of lines ending with punctuation
• Rhyme Scheme Detection — Identifies patterns (ABAB, AABB, free verse, etc.)
• Meter Hints — Detects dominant rhythmic patterns if present

How to use it:
• Compare enjambment vs end-stop rates to understand your poem's pacing
• High enjambment (60%+) creates urgency and forward momentum
• High end-stop (70%+) creates a more measured, deliberate feel
• Use rhyme scheme detection to verify intentional patterns
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Imagery / Sensory Analysis", color: headingColor))
        content.append(makeBody("""
Maps the sensory landscape of your poem.

What it tracks:
• Visual imagery — sight-based descriptions (colors, light, shapes)
• Auditory imagery — sound references (music, noise, silence)
• Tactile imagery — touch sensations (texture, temperature, pressure)
• Olfactory imagery — smell references
• Gustatory imagery — taste references
• Kinesthetic imagery — movement and bodily sensation

Distribution chart shows which senses dominate your poem.

How to use it:
• Poems relying solely on visual imagery may feel flat
• Adding unexpected senses (taste in a grief poem, sound in a visual scene) creates depth
• The balance should serve your poem's intent, not follow a formula
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Voice / Rhetoric Analysis", color: headingColor))
        content.append(makeBody("""
Analyzes the speaker's presence and persuasive techniques.

What it tracks:
• Point of View — First person (I/we), second person (you), third person
• Tone Indicators — Words suggesting emotional register (intimate, distant, urgent)
• Rhetorical Devices — Questions, repetition, imperatives, apostrophe
• Direct Address — How often the poem speaks TO someone/something

How to use it:
• A shift from "I" to "we" can signal a move from isolation to connection
• Questions without answers create different tension than answered questions
• Imperatives ("Listen," "Remember") demand reader engagement
• Apostrophe (addressing absent/abstract entities) elevates emotional stakes
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Emotional Trajectory", color: headingColor))
        content.append(makeBody("""
Charts the emotional arc of your poem from beginning to end.

What it tracks:
• Opening Emotional State — Where the poem begins emotionally
• Volta/Turn Detection — Identifies shifts in tone, subject, or perspective
• Closing Emotional State — Where the poem resolves (or doesn't)
• Emotional Range — The distance between highest and lowest points

How to use it:
• Poems that start and end in the same emotional place may feel circular (intentionally or not)
• A clear volta often marks the poem's emotional center of gravity
• Wide emotional range creates drama; narrow range creates meditation
• The trajectory should match your poem's intent
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Motif & Symbol Tracking", color: headingColor))
        content.append(makeBody("""
Identifies recurring images, words, and symbolic patterns.

What it tracks:
• Repeated Words — Words appearing 2+ times (excluding articles/prepositions)
• Image Clusters — Related images that form patterns (water imagery, light/dark, etc.)
• Symbolic Candidates — Concrete nouns that may carry abstract meaning
• Motif Frequency — How often key images recur throughout the poem

How to use it:
• Repetition creates emphasis—make sure repeated words earn their recurrence
• Image clusters reveal unconscious themes you may want to strengthen
• If a symbol appears only once, consider whether it needs development or removal
• Three occurrences often establishes a pattern; two may feel accidental
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Macro Structure", color: headingColor))
        content.append(makeBody("""
Examines the poem's overall architecture.

What it tracks:
• Opening Strategy — How the poem begins (in medias res, setting, question, statement)
• Stanza Function — What each stanza accomplishes in the whole
• Closure Type — How the poem ends (resolution, open-ended, circular, escalation)
• White Space Usage — How blank lines create pause and section

How to use it:
• Strong openings hook readers; analyze whether your first line/stanza does work
• Each stanza should advance the poem—look for stanzas that repeat without adding
• Endings that surprise while feeling inevitable are strongest
• White space is punctuation at the stanza level; use it deliberately
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Pressure Points (Writer's Feedback)", color: headingColor))
        content.append(makeBody("""
Quill Pilot identifies specific areas that may benefit from revision attention.

Pressure points include:
• Lines with weak verbs that could be strengthened
• Abstract language that could become concrete
• Passive constructions that distance the reader
• Clichés or familiar phrases that could be made fresh
• Moments where form and content may be misaligned

These are suggestions, not rules:
• Sometimes a cliché is the right choice (for irony, character voice, etc.)
• Passive voice can create specific effects (mystery, victim perspective)
• Abstract language has its place in philosophical or meditative poems

The goal is awareness, not compliance. You decide what serves your poem.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Poetry Tools Panel", color: headingColor))
        content.append(makeBody("""
When the Poetry template is active, additional poetry-specific tools appear in the right sidebar.

Sidebar buttons (from top to bottom):
• 📊 Poetry Analysis — Opens the main analysis popout with writer-focused insights
• 🔬 Poetry Tools — Combined panel with all analysis tools in one window
• 📖 Form Templates — Selector for classic poetry forms (Sonnet, Villanelle, Haiku, etc.)
• 📚 Collections — Organize poems into chapbooks and full-length manuscripts
• 📄 Draft Versions — Track revision history and compare drafts
• ✉️ Submissions — Track submissions to journals, magazines, and contests

Access: These buttons appear automatically when you select the Poetry template.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Poetry Tools Panel Details", color: headingColor))
        content.append(makeBody("""
The Poetry Tools window (accessible via the 🔬 button or Tools → Poetry Tools → Poetry Analysis Tools) provides:

Syllables Tab:
• Counts syllables per line
• Shows total, average, and line count statistics
• Detects meter patterns (Haiku, Iambic Pentameter, etc.)

Scansion Tab:
• Marks stressed (/) and unstressed (u) syllables
• Shows secondary stress marks (\\)
• Navigate line by line to examine stress patterns

Sound Devices Tab:
• Detects alliteration, assonance, consonance
• Identifies sibilance and internal rhyme
• Finds onomatopoeia

Word Cloud Tab:
• Visual display of word frequency
• Excludes common stop words
• Larger words appear more frequently

Line Length Tab:
• Bar graph showing syllable/word/character counts per line
• Statistics: average, min, max, and standard deviation
• Helps identify rhythm patterns and variations

Form Templates Tab:
• 10 classic poetry forms with structures and examples
• Sonnet, Villanelle, Haiku, Tanka, Ghazal, Pantoum, Sestina, Limerick, Free Verse, Blank Verse
• Insert template structures directly into your document
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Poetry Collections", color: headingColor))
        content.append(makeBody("""
Organize your poems into collections (chapbooks or full manuscripts).

Features:
• Create named collections with author and description
• Add poems from your current document
• Organize poems into sections
• Generate table of contents
• Export collection data

Using Collections:
1. Click the ＋ button in the sidebar to create a new collection
2. Select a collection from the sidebar to view its contents
3. Click "Add Current Poem" to add the poem you're editing to the collection
4. Use the folder+ button to create sections within a collection
5. Click the list button to view/copy the table of contents

Access: Tools → Poetry Tools → Poetry Collections, or the 📚 sidebar button.
Tip: Modal dialogs appear inside the window (the window dims while the dialog is open). Complete the dialog or press Cancel/Esc to return.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Draft Versioning", color: headingColor))
        content.append(makeBody("""
Track your revision history and compare versions.

Features:
• Save snapshots of your poem at any point
• Add notes to each version
• Compare two versions side-by-side with diff highlighting
• Restore previous versions

Access: Tools → Poetry Tools → Draft Versions, or the 📄 sidebar button.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Submission Tracker", color: headingColor))
        content.append(makeBody("""
Track submissions to journals, magazines, contests, and publishers.

Features:
• Log submissions with date, status, and notes
• Filter by status (Pending, Accepted, Rejected, Withdrawn)
• Track submission statistics
• Save publication venues for reuse

Access: Tools → Poetry Tools → Submission Tracker, or the ✉️ sidebar button.
Tip: Click New Submission to open the entry sheet. The window dims while the sheet is open—save or cancel to return.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Best Practices for Poetry Analysis", color: headingColor))
        content.append(makeBody("""
To get the most from poetry analysis:

1. Use the Poetry template — Analysis adapts to the template type
2. Separate stanzas with blank lines — This enables stanza-level analysis
3. Place title and author at the top — The analyzer detects and excludes header lines
4. Run analysis after significant revisions — Compare before/after metrics
5. Use analysis as a mirror, not a judge — It shows what's there, not what should be

Remember: Analysis can identify patterns but cannot evaluate meaning. A "low" score in any category may be exactly right for your poem's intent.
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeTypographyContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("🎨 Typography & Styles", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("Typography Features", color: headingColor))
        content.append(makeBody("""
Quill Pilot includes professional typography features:

Automatic Features:
• Ligatures - Automatically enabled for serif fonts (fi, fl, ff, ffi, ffl)
• Smart Quotes - Converts straight quotes to curly quotes
• Smart Dashes - Converts double/triple hyphens to en/em dashes

Format > Typography Menu:
• Apply Drop Cap - Creates a decorative large initial letter (3 lines tall)
• Use Old-Style Numerals - Enables old-style (lowercase-style) numerals
• Apply Optical Kerning - Uses font kerning features for better visual spacing

These features work best with professional fonts like Times New Roman, Georgia, Baskerville, Garamond, Palatino, and Hoefler Text.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Style Templates", color: headingColor))
        content.append(makeBody("""
Templates in Quill Pilot are complete style sets (Body Text, headings, chapter formats, TOC/Index styles, etc.) tuned around a specific typeface.

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
3. Style names and previews update instantly

Notes:
• Switching templates changes which style definitions are available; it doesn't automatically rewrite existing paragraphs unless you apply styles.
• When you open a document, Quill Pilot applies the currently selected template.
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeSectionsContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("📄 Sections & Page Numbers", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("What Are Sections?", color: headingColor))
        content.append(makeBody("""
Sections let you create independent page-numbering sequences within a single document. This is essential for:

• Front matter (title page, copyright, table of contents) using Roman numerals (i, ii, iii)
• Body text using Arabic numerals starting at 1
• Back matter (index, appendix) with separate numbering

Each section can have its own starting page number and number format.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Creating Section Breaks", color: headingColor))
        content.append(makeBody("""
1. Place your cursor at the very beginning of the section
2. Go to Insert → Section Break…
3. In the dialog:
   • Name your section (e.g., "Front Matter", "Chapter 1")
   • Set the starting page number
   • Choose number format: Arabic (1, 2, 3), Roman Upper (I, II, III), or Roman Lower (i, ii, iii)
4. Click Insert

The section break is inserted at the cursor position. Page numbers will restart and use the specified format from that point forward.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Editing Section Breaks", color: headingColor))
        content.append(makeBody("""
To edit or remove an existing section break:

1. Place your cursor anywhere in the section
2. Go to Insert → Section Break…
3. The dialog shows the current section's settings
4. Make changes and click Save, or click Remove to delete the section break
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Viewing Section Breaks", color: headingColor))
        content.append(makeBody("""
Section breaks are invisible by default. To see them:

• Go to View → Show Section Breaks
• Section breaks appear as § markers in the document
• Toggle off to hide them again

This is useful for verifying section placement without affecting print output.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Page Numbering Behavior", color: headingColor))
        content.append(makeBody("""
• Each section numbers pages independently
• Page numbers in headers/footers automatically use the section's format
• "Hide Page Number on First Page" applies to the first page of EACH section

Example Setup:
Section 1 (Front Matter): Starts at i, Roman Lower → i, ii, iii, iv
Section 2 (Body): Starts at 1, Arabic → 1, 2, 3, 4…
Section 3 (Index): Starts at 1, Arabic → 1, 2, 3…
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Facing Pages", color: headingColor))
        content.append(makeBody("""
For print documents, you can position page numbers on outer margins:

1. Go to Format → Headers & Footers…
2. Check "Facing Pages (outer margins)"
3. Click Apply

Page numbers will appear:
• Left margin on even (left-hand) pages
• Right margin on odd (right-hand) pages
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Tips", color: headingColor))
        content.append(makeBody("""
• Insert section breaks at the TOP of each section (before any text)
• Use View → Show Section Breaks to verify placement
• Remember: a section break affects everything AFTER it until the next section break
• Test page numbering by scrolling through the document in page view
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeReferencesContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("🔖 References", color: titleColor))
        content.append(makeBody("""
Quill Pilot provides professional-grade bookmarks and cross-references that follow industry-standard document semantics.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Bookmarks", color: headingColor))
        content.append(makeBody("""
Bookmarks are named anchors in your document that you can reference from elsewhere.

Creating Bookmarks:
Insert → Bookmark…
1. Position your cursor where you want the bookmark
2. Enter a descriptive name (e.g., "Chapter 3 Introduction")
3. Click Add

Managing Bookmarks:
The Bookmark dialog shows all bookmarks in your document:
• Add: Create a new bookmark at the cursor
• Delete: Remove a bookmark and its anchor
• Go To: Jump to the bookmark's location

Bookmarks persist when you save and reload your document.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Cross-References", color: headingColor))
        content.append(makeBody("""
Cross-references are dynamic fields that point to bookmarks, headings, or other document elements.

Creating Cross-References:
Insert → Cross-reference…
1. Choose the reference type (Bookmark, Heading, Caption, etc.)
2. Select the target from the list
3. Choose what to display:
   • Text: The referenced text itself
   • Page Number: The page where the target appears
   • Above/Below: Relative position
   • Full Context: Text with page number
4. Optionally make it a clickable hyperlink
5. Click Insert

Updating Cross-References:
Insert → Update Fields
Cross-references show their last computed value. Use Update Fields to refresh all references when document content changes.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Best Practices", color: headingColor))
        content.append(makeBody("""
Naming Bookmarks:
• Use descriptive names: "protagonist_introduction" not "bm1"
• Group related bookmarks with prefixes: "ch3_", "appendix_"
• Avoid special characters that might cause export issues

Cross-Reference Strategy:
• Create bookmarks at stable structural points
• Use "Above/Below" for nearby references
• Use "Page Number" for distant references in print documents
• Update fields before final export or print
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeNotesContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("📝 Footnotes & Endnotes", color: titleColor))
        content.append(makeBody("""
Footnotes and endnotes in Quill Pilot are structured objects—not just text with superscripts.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("How They Work", color: headingColor))
        content.append(makeBody("""
Each note consists of:
• A unique internal ID
• A reference marker in the main text
• A corresponding note body stored separately
• Automatic numbering rules

This structure enables:
• Automatic Renumbering: Insert or delete notes anywhere, and all numbers adjust
• Conversion: Convert footnotes to endnotes (or vice versa) with a single click
• Multiple Styles: Choose from Arabic, Roman, Alphabetic, or Symbol numbering
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Creating Notes", color: headingColor))
        content.append(makeBody("""
Insert → Insert Footnote (or Insert Endnote)

The dialog allows you to:
• Enter note content
• View all existing notes
• Navigate to any note in the document
• Delete notes (both reference and content)
• Convert between footnote and endnote
• Change numbering style

Double-click any note in the list to jump to its location.
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Numbering Styles", color: headingColor))
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

        content.append(makeHeading("Footnotes vs. Endnotes", color: headingColor))
        content.append(makeBody("""
• Use footnotes for brief clarifications readers might want immediately
• Use endnotes for longer citations or supplementary material
• Academic writing typically uses footnotes for citations
• Fiction rarely uses either—consider whether you truly need them

• Footnotes appear at the bottom of each page
• Endnotes collect at the end of the document
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }

    private func makeShortcutsContent() -> NSAttributedString {
        let theme = ThemeManager.shared.currentTheme
        let titleColor = theme.textColor
        let headingColor = theme.textColor
        let bodyColor = theme.textColor

        let content = NSMutableAttributedString()

        content.append(makeTitle("⌨️ Keyboard Shortcuts", color: titleColor))
        content.append(makeNewline())

        content.append(makeHeading("File Operations", color: headingColor))
        content.append(makeBody("""
⌘N - New document
⌘O - Open document
⌘S - Save document
⌘⇧S - Save As (choose new location/format)
⌘P - Print
⌘W - Close window

Note: Auto-save runs periodically for saved documents (default 1 minute; configurable in Preferences).
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Editing", color: headingColor))
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

        content.append(makeHeading("Formatting", color: headingColor))
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
""", color: bodyColor))
        content.append(makeNewline())

        content.append(makeHeading("Navigation", color: headingColor))
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

        content.append(makeHeading("Window Management", color: headingColor))
        content.append(makeBody("""
⌘M - Minimize window
⌘` - Cycle through windows
⌘, - Preferences
⌘? - Show Help
""", color: bodyColor))

        normalizeAppNameInDocumentation(content)
        return content
    }
}
