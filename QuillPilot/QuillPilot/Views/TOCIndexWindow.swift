//
//  TOCIndexWindow.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

private extension NSRange {
    func toOptional() -> NSRange? {
        return location == NSNotFound ? nil : self
    }
}

// MARK: - TOC Entry Model
struct TOCEntry: Identifiable {
    let id = UUID()
    var title: String
    var level: Int  // 1 = Chapter, 2 = Section, 3 = Subsection
    var pageNumber: Int
    var range: NSRange
    var styleName: String

    var indentation: CGFloat {
        return CGFloat(level - 1) * 20
    }
}

// MARK: - Index Entry Model
struct IndexEntry: Identifiable, Hashable {
    let id = UUID()
    var term: String
    var pageNumbers: [Int]
    var ranges: [NSRange]
    var category: String  // e.g., "People", "Places", "Concepts"

    func hash(into hasher: inout Hasher) {
        hasher.combine(term.lowercased())
    }

    static func == (lhs: IndexEntry, rhs: IndexEntry) -> Bool {
        lhs.term.lowercased() == rhs.term.lowercased()
    }
}

// MARK: - TOC & Index Manager
class TOCIndexManager {
    static let shared = TOCIndexManager()

    private(set) var tocEntries: [TOCEntry] = []
    private(set) var indexEntries: [IndexEntry] = []

    // Styles that indicate TOC-worthy headings
    let tocStyles = ["Title", "Chapter Title", "Part Title", "Heading 1", "Heading 2", "Heading 3",
                     "Section", "Subsection", "Chapter Heading"]

    // Generate TOC from document
    func generateTOC(from textStorage: NSTextStorage, pageWidth: CGFloat = 612, pageHeight: CGFloat = 792) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let styleAttributeKey = NSAttributedString.Key("QuillStyleName")

        // Exclude any existing TOC/Index sections so we don't re-ingest previously inserted lists
        let excludedRanges = findExcludedRanges(in: textStorage)

        textStorage.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            if rangeIntersectsExcluded(range, excludedRanges) { return }
            // Check for QuillStyleName attribute
            if let styleName = attrs[styleAttributeKey] as? String {
                let level = levelForStyle(styleName)
                if level > 0 {
                    let text = (textStorage.string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        let pageNumber = estimatePageNumber(for: range.location, in: textStorage, pageHeight: pageHeight)
                        entries.append(TOCEntry(
                            title: text,
                            level: level,
                            pageNumber: pageNumber,
                            range: range,
                            styleName: styleName
                        ))
                    }
                }
            }

            // Also check font size for headings (fallback for unstyled documents)
            if let font = attrs[.font] as? NSFont {
                if font.pointSize >= 18 {
                    let text = (textStorage.string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty && text.count < 100 {  // Likely a heading
                        let level = font.pointSize >= 24 ? 1 : (font.pointSize >= 20 ? 2 : 3)
                        let pageNumber = estimatePageNumber(for: range.location, in: textStorage, pageHeight: pageHeight)

                        // Check if we already have this entry
                        let isDuplicate = entries.contains { $0.range.location == range.location }
                        if !isDuplicate {
                            entries.append(TOCEntry(
                                title: text,
                                level: level,
                                pageNumber: pageNumber,
                                range: range,
                                styleName: "Heading"
                            ))
                        }
                    }
                }
            }
        }

        tocEntries = entries.sorted { $0.range.location < $1.range.location }
        return tocEntries
    }

    private func levelForStyle(_ styleName: String) -> Int {
        let lowercased = styleName.lowercased()
        if lowercased.contains("title") || lowercased.contains("chapter") || lowercased.contains("part") {
            return 1
        } else if lowercased.contains("heading 1") || lowercased.contains("section") {
            return 2
        } else if lowercased.contains("heading 2") || lowercased.contains("heading 3") || lowercased.contains("subsection") {
            return 3
        }
        return 0
    }

    private func estimatePageNumber(for location: Int, in textStorage: NSTextStorage, pageHeight: CGFloat) -> Int {
        // Rough estimate: ~3000 characters per page
        let charsPerPage = 3000
        return (location / charsPerPage) + 1
    }

    // Add index entry manually
    func addIndexEntry(term: String, range: NSRange, pageNumber: Int, category: String = "General") {
        if let existingIndex = indexEntries.firstIndex(where: { $0.term.lowercased() == term.lowercased() }) {
            indexEntries[existingIndex].pageNumbers.append(pageNumber)
            indexEntries[existingIndex].ranges.append(range)
            // Remove duplicates and sort
            indexEntries[existingIndex].pageNumbers = Array(Set(indexEntries[existingIndex].pageNumbers)).sorted()
        } else {
            indexEntries.append(IndexEntry(
                term: term,
                pageNumbers: [pageNumber],
                ranges: [range],
                category: category
            ))
        }
        indexEntries.sort { $0.term.lowercased() < $1.term.lowercased() }
    }

    // Auto-generate index from marked text
    func generateIndexFromMarkers(in textStorage: NSTextStorage) -> [IndexEntry] {
        let entries: [IndexEntry] = []
        let pattern = "\\{\\{index:([^}]+)\\}\\}"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return entries
        }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        let matches = regex.matches(in: textStorage.string, options: [], range: fullRange)

        for match in matches {
            if match.numberOfRanges >= 2 {
                let termRange = match.range(at: 1)
                let term = (textStorage.string as NSString).substring(with: termRange)
                let pageNumber = estimatePageNumber(for: match.range.location, in: textStorage, pageHeight: 792)
                addIndexEntry(term: term, range: match.range, pageNumber: pageNumber)
            }
        }

        return indexEntries
    }

    func clearTOC() {
        tocEntries.removeAll()
    }

    func clearIndex() {
        indexEntries.removeAll()
    }

    func removeIndexEntry(at index: Int) {
        guard index < indexEntries.count else { return }
        indexEntries.remove(at: index)
    }
}

// MARK: - Helpers for section exclusion/removal

// Finds the range of a section that begins with the given title and continues until the next occurrence of the same title (or document end).
private func findSectionRange(title: String, in storage: NSTextStorage) -> NSRange? {
    let fullString = storage.string as NSString
    let searchRange = NSRange(location: 0, length: fullString.length)
    guard let titleRange = fullString.range(of: title, options: [.caseInsensitive], range: searchRange).toOptional() else {
        return nil
    }

    let nextSearchStart = titleRange.location + titleRange.length
    if nextSearchStart < fullString.length,
       let nextTitleRange = fullString.range(of: title, options: [.caseInsensitive], range: NSRange(location: nextSearchStart, length: fullString.length - nextSearchStart)).toOptional() {
        let length = nextTitleRange.location - titleRange.location
        return NSRange(location: titleRange.location, length: length)
    }

    // No subsequent title found; remove to end of document
    return NSRange(location: titleRange.location, length: fullString.length - titleRange.location)
}

private func findExcludedRanges(in storage: NSTextStorage) -> [NSRange] {
    var ranges: [NSRange] = []
    if let toc = findSectionRange(title: "Table of Contents", in: storage) {
        ranges.append(toc)
    }
    if let idx = findSectionRange(title: "Index", in: storage) {
        ranges.append(idx)
    }
    return ranges
}

private func rangeIntersectsExcluded(_ range: NSRange, _ excluded: [NSRange]) -> Bool {
    for ex in excluded {
        if NSIntersectionRange(range, ex).length > 0 { return true }
    }
    return false
}

private func removeAllSections(title: String, in storage: NSTextStorage) {
    while let r = findSectionRange(title: title, in: storage) {
        storage.deleteCharacters(in: r)
    }
}

// MARK: - TOC & Index Window Controller
class TOCIndexWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private var tabView: NSTabView!
    private var tocOutlineView: NSOutlineView!
    private var indexTableView: NSTableView!
    private var addTermField: NSTextField!
    private var addCategoryPopup: NSPopUpButton!

    weak var editorTextView: NSTextView?

    private let categories = ["General", "People", "Places", "Concepts", "Events", "Terms"]

    private func resolveDocumentFont(from textView: NSTextView) -> NSFont {
        // Try to find the most common body text font by sampling the document
        if let storage = textView.textStorage, storage.length > 100 {
            var fontCounts: [String: (font: NSFont, count: Int)] = [:]
            let samplePoints = [
                storage.length / 4,      // 25%
                storage.length / 2,      // 50%
                storage.length * 3 / 4,  // 75%
                min(1000, storage.length - 1),  // Near start but past headers
                min(5000, storage.length - 1)   // Further in
            ]

            for point in samplePoints {
                let safePoint = min(point, storage.length - 1)
                if let font = storage.attribute(.font, at: safePoint, effectiveRange: nil) as? NSFont {
                    // Skip very large fonts (likely headings)
                    if font.pointSize <= 14 {
                        let key = font.familyName ?? font.fontName
                        if let existing = fontCounts[key] {
                            fontCounts[key] = (font, existing.count + 1)
                        } else {
                            fontCounts[key] = (font, 1)
                        }
                    }
                }
            }

            // Return most common body font
            if let mostCommon = fontCounts.max(by: { $0.value.count < $1.value.count }) {
                return mostCommon.value.font
            }
        }

        // Fallback to textView's font property
        if let viewFont = textView.font {
            return viewFont
        }

        return NSFont(name: "Helvetica", size: 12) ?? NSFont.systemFont(ofSize: 12)
    }

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Table of Contents & Index"
        panel.minSize = NSSize(width: 350, height: 400)
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false

        self.init(window: panel)
        setupUI()
        applyTheme()

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: .themeDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func themeDidChange() {
        applyTheme()
    }

    private func applyTheme() {
        guard let window = window else { return }
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode

        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        window.backgroundColor = theme.pageAround
        window.contentView?.layer?.backgroundColor = theme.pageAround.cgColor
    }

    private func setupUI() {
        guard let window = window else { return }
        let theme = ThemeManager.shared.currentTheme

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.pageAround.cgColor

        // Create tab view
        tabView = NSTabView(frame: contentView.bounds.insetBy(dx: 10, dy: 10))
        tabView.autoresizingMask = [.width, .height]

        // TOC Tab
        let tocTab = NSTabViewItem(identifier: "toc")
        tocTab.label = "Table of Contents"
        tocTab.view = createTOCView()
        tabView.addTabViewItem(tocTab)

        // Index Tab
        let indexTab = NSTabViewItem(identifier: "index")
        indexTab.label = "Index"
        indexTab.view = createIndexView()
        tabView.addTabViewItem(indexTab)

        contentView.addSubview(tabView)
        window.contentView = contentView
    }

    private func createTOCView() -> NSView {
        let theme = ThemeManager.shared.currentTheme
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 540))
        container.wantsLayer = true

        // Instructions
        let instructions = NSTextField(labelWithString: "Click \"Generate\" to scan your document for headings and chapters.")
        instructions.frame = NSRect(x: 10, y: 500, width: 410, height: 30)
        instructions.textColor = theme.textColor.withAlphaComponent(0.7)
        instructions.font = NSFont.systemFont(ofSize: 11)
        container.addSubview(instructions)

        // Scroll view for outline
        let scrollView = NSScrollView(frame: NSRect(x: 10, y: 50, width: 410, height: 440))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .bezelBorder

        // Outline view for TOC
        tocOutlineView = NSOutlineView()
        tocOutlineView.headerView = nil
        tocOutlineView.allowsMultipleSelection = false
        tocOutlineView.dataSource = self
        tocOutlineView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TOCColumn"))
        column.title = "Contents"
        column.width = 380
        tocOutlineView.addTableColumn(column)
        tocOutlineView.outlineTableColumn = column

        scrollView.documentView = tocOutlineView
        container.addSubview(scrollView)

        // Buttons
        let generateButton = NSButton(title: "Generate TOC", target: self, action: #selector(generateTOC))
        generateButton.frame = NSRect(x: 10, y: 10, width: 120, height: 30)
        generateButton.bezelStyle = .rounded
        container.addSubview(generateButton)

        let insertButton = NSButton(title: "Insert in Document", target: self, action: #selector(insertTOC))
        insertButton.frame = NSRect(x: 140, y: 10, width: 140, height: 30)
        insertButton.bezelStyle = .rounded
        container.addSubview(insertButton)

        let goToButton = NSButton(title: "Go to Selection", target: self, action: #selector(goToTOCEntry))
        goToButton.frame = NSRect(x: 290, y: 10, width: 130, height: 30)
        goToButton.bezelStyle = .rounded
        container.addSubview(goToButton)

        return container
    }

    private func createIndexView() -> NSView {
        let theme = ThemeManager.shared.currentTheme
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 540))
        container.wantsLayer = true

        // Add term section
        let addLabel = NSTextField(labelWithString: "Add Index Term:")
        addLabel.frame = NSRect(x: 10, y: 505, width: 100, height: 20)
        addLabel.textColor = theme.textColor
        container.addSubview(addLabel)

        addTermField = NSTextField(frame: NSRect(x: 10, y: 475, width: 200, height: 24))
        addTermField.placeholderString = "Enter term..."
        container.addSubview(addTermField)

        addCategoryPopup = NSPopUpButton(frame: NSRect(x: 220, y: 475, width: 120, height: 24))
        addCategoryPopup.addItems(withTitles: categories)
        container.addSubview(addCategoryPopup)

        let addButton = NSButton(title: "Add", target: self, action: #selector(addIndexTerm))
        addButton.frame = NSRect(x: 350, y: 475, width: 70, height: 24)
        addButton.bezelStyle = .rounded
        container.addSubview(addButton)

        // Scroll view for index table
        let scrollView = NSScrollView(frame: NSRect(x: 10, y: 50, width: 410, height: 415))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .bezelBorder

        // Table view for index
        indexTableView = NSTableView()
        indexTableView.allowsMultipleSelection = false
        indexTableView.dataSource = self
        indexTableView.delegate = self

        let termColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Term"))
        termColumn.title = "Term"
        termColumn.width = 180
        indexTableView.addTableColumn(termColumn)

        let categoryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Category"))
        categoryColumn.title = "Category"
        categoryColumn.width = 80
        indexTableView.addTableColumn(categoryColumn)

        let pagesColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Pages"))
        pagesColumn.title = "Pages"
        pagesColumn.width = 100
        indexTableView.addTableColumn(pagesColumn)

        scrollView.documentView = indexTableView
        container.addSubview(scrollView)

        // Buttons
        let scanButton = NSButton(title: "Scan Markers", target: self, action: #selector(scanIndexMarkers))
        scanButton.frame = NSRect(x: 10, y: 10, width: 100, height: 30)
        scanButton.bezelStyle = .rounded
        container.addSubview(scanButton)

        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeIndexEntry))
        removeButton.frame = NSRect(x: 120, y: 10, width: 80, height: 30)
        removeButton.bezelStyle = .rounded
        container.addSubview(removeButton)

        let insertButton = NSButton(title: "Insert Index", target: self, action: #selector(insertIndex))
        insertButton.frame = NSRect(x: 210, y: 10, width: 100, height: 30)
        insertButton.bezelStyle = .rounded
        container.addSubview(insertButton)

        let goToButton = NSButton(title: "Go to First", target: self, action: #selector(goToIndexEntry))
        goToButton.frame = NSRect(x: 320, y: 10, width: 100, height: 30)
        goToButton.bezelStyle = .rounded
        container.addSubview(goToButton)

        return container
    }

    // MARK: - Actions

    @objc private func generateTOC() {
        guard let textView = editorTextView, let textStorage = textView.textStorage else {
            showThemedAlert(title: "No Document", message: "Please open a document first.")
            return
        }

        let entries = TOCIndexManager.shared.generateTOC(from: textStorage)
        tocOutlineView.reloadData()

        if entries.isEmpty {
            showThemedAlert(title: "No Headings Found", message: "No chapter titles or headings were detected. Use styles like 'Chapter Title', 'Heading 1', etc., or use larger font sizes (18pt+) for headings.")
        } else {
            showThemedAlert(title: "TOC Generated", message: "Found \(entries.count) entries.")
        }
    }

    @objc private func insertTOC() {
        guard let textView = editorTextView else { return }
        let entries = TOCIndexManager.shared.tocEntries

        if entries.isEmpty {
            showThemedAlert(title: "No TOC", message: "Generate a Table of Contents first.")
            return
        }

        // Remove any previously inserted TOC to avoid duplicates
        if let storage = textView.textStorage {
            removeAllSections(title: "Table of Contents", in: storage)
        }

        let tocString = NSMutableAttributedString()

        // Detect document font (prefer typing attributes or selection)
        let documentFont = resolveDocumentFont(from: textView)
        print("DEBUG TOC: Resolved document font: \(documentFont.fontName) family: \(documentFont.familyName ?? "nil")")

        // Get font for this family at different sizes, derived from document font
        func fontFromDocument(_ baseFont: NSFont, size: CGFloat, bold: Bool) -> NSFont {
            if bold {
                let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.bold)
                return NSFont(descriptor: descriptor, size: size) ?? NSFont.boldSystemFont(ofSize: size)
            }
            let descriptor = baseFont.fontDescriptor.withSymbolicTraits([])
            return NSFont(descriptor: descriptor, size: size) ?? baseFont.withSize(size)
        }

        // Title
        let titleFont = fontFromDocument(documentFont, size: 18, bold: true)
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: ThemeManager.shared.currentTheme.textColor,
            .paragraphStyle: titleParagraph
        ]
        tocString.append(NSAttributedString(string: "Table of Contents\n\n", attributes: titleAttrs))

        // Calculate usable width inside the text container (respect padding)
        let textContainer = textView.textContainer!
        let containerWidth = textContainer.containerSize.width
        let lineFragmentPadding = textContainer.lineFragmentPadding
        // Use actual container width for both tab stops and dot calculation
        let actualLineWidth = containerWidth - (lineFragmentPadding * 2)

        // Entries with leader dots
        for entry in entries {
            let fontSize: CGFloat = entry.level == 1 ? 14 : (entry.level == 2 ? 12 : 11)
            let isBold = entry.level == 1
            let entryFont = fontFromDocument(documentFont, size: fontSize, bold: isBold)
            let leftIndent = CGFloat(entry.level - 1) * 20

            // Calculate widths to determine how many dots to insert
            let titleAttrsForMeasure: [NSAttributedString.Key: Any] = [.font: entryFont]
            let titleWidth = (entry.title as NSString).size(withAttributes: titleAttrsForMeasure).width
            let pageNumStr = String(entry.pageNumber)
            let pageNumWidth = (pageNumStr as NSString).size(withAttributes: titleAttrsForMeasure).width
            let dotWidth = (".").size(withAttributes: titleAttrsForMeasure).width
            let spaceWidth = (" ").size(withAttributes: titleAttrsForMeasure).width

            // Calculate dots to fill space between title and page number
            let contentWidth = actualLineWidth - leftIndent
            let paddingSpace = spaceWidth * 2  // Just minimal padding around dots
            let availableForDots = contentWidth - titleWidth - pageNumWidth - paddingSpace
            let dotCount = max(3, Int(availableForDots / dotWidth))
            let leaderDots = " " + String(repeating: ".", count: dotCount) + " "

            // Create paragraph style with right-aligned tab stop at actual line edge
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = leftIndent
            paragraphStyle.headIndent = leftIndent
            paragraphStyle.tabStops = []
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: actualLineWidth, options: [:])]

            let entryAttrs: [NSAttributedString.Key: Any] = [
                .font: entryFont,
                .foregroundColor: ThemeManager.shared.currentTheme.textColor,
                .paragraphStyle: paragraphStyle
            ]

            let line = "\(entry.title)\(leaderDots)\t\(pageNumStr)\n"
            tocString.append(NSAttributedString(string: line, attributes: entryAttrs))
        }

        tocString.append(NSAttributedString(string: "\n"))

        // Insert at cursor
        let insertLocation = textView.selectedRange().location
        textView.textStorage?.insert(tocString, at: insertLocation)

        showThemedAlert(title: "TOC Inserted", message: "Table of Contents has been inserted at the cursor position.")
    }

    @objc private func goToTOCEntry() {
        let selectedRow = tocOutlineView.selectedRow
        guard selectedRow >= 0,
              let item = tocOutlineView.item(atRow: selectedRow) as? TOCEntry,
              let textView = editorTextView else { return }

        textView.setSelectedRange(item.range)
        textView.scrollRangeToVisible(item.range)
        textView.window?.makeFirstResponder(textView)
    }

    @objc private func addIndexTerm() {
        let term = addTermField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }

        guard let textView = editorTextView,
                let _ = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        let pageNumber = (selectedRange.location / 3000) + 1
        let category = addCategoryPopup.titleOfSelectedItem ?? "General"

        TOCIndexManager.shared.addIndexEntry(term: term, range: selectedRange, pageNumber: pageNumber, category: category)
        indexTableView.reloadData()
        addTermField.stringValue = ""
    }

    @objc private func scanIndexMarkers() {
        guard let textView = editorTextView, let textStorage = textView.textStorage else { return }

        let entries = TOCIndexManager.shared.generateIndexFromMarkers(in: textStorage)
        indexTableView.reloadData()

        showThemedAlert(title: "Index Scan Complete", message: "Found \(entries.count) indexed terms. Use {{index:term}} markers in your text to add index entries.")
    }

    @objc private func removeIndexEntry() {
        let selectedRow = indexTableView.selectedRow
        guard selectedRow >= 0 else { return }

        TOCIndexManager.shared.removeIndexEntry(at: selectedRow)
        indexTableView.reloadData()
    }

    @objc private func insertIndex() {
        guard let textView = editorTextView else { return }
        let entries = TOCIndexManager.shared.indexEntries

        if entries.isEmpty {
            showThemedAlert(title: "No Index Entries", message: "Add some index terms first.")
            return
        }

        // Remove any previously inserted Index to avoid duplicates
        if let storage = textView.textStorage {
            removeAllSections(title: "Index", in: storage)
        }

        let indexString = NSMutableAttributedString()

        // Detect document font (prefer typing attributes or selection)
        let documentFont = resolveDocumentFont(from: textView)

        // Get font for this family at different sizes, derived from document font
        func fontFromDocument(_ baseFont: NSFont, size: CGFloat, bold: Bool) -> NSFont {
            if bold {
                let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.bold)
                return NSFont(descriptor: descriptor, size: size) ?? NSFont.boldSystemFont(ofSize: size)
            }
            let descriptor = baseFont.fontDescriptor.withSymbolicTraits([])
            return NSFont(descriptor: descriptor, size: size) ?? baseFont.withSize(size)
        }

        // Calculate usable width inside the text container (respect padding)
        let textContainer = textView.textContainer!
        let containerWidth = textContainer.containerSize.width
        let lineFragmentPadding = textContainer.lineFragmentPadding
        // Use actual container width for both tab stops and dot calculation
        let actualLineWidth = containerWidth - (lineFragmentPadding * 2)

        // Title
        let titleFont = fontFromDocument(documentFont, size: 18, bold: true)
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: ThemeManager.shared.currentTheme.textColor,
            .paragraphStyle: titleParagraph
        ]
        indexString.append(NSAttributedString(string: "Index\n\n", attributes: titleAttrs))

        // Group by first letter
        var currentLetter: Character = " "
        let letterFont = fontFromDocument(documentFont, size: 14, bold: true)
        let letterAttrs: [NSAttributedString.Key: Any] = [
            .font: letterFont,
            .foregroundColor: ThemeManager.shared.currentTheme.textColor
        ]

        let entryFont = fontFromDocument(documentFont, size: 12, bold: false)

        for entry in entries {
            let firstLetter = entry.term.first?.uppercased().first ?? "?"
            if firstLetter != currentLetter {
                currentLetter = firstLetter
                indexString.append(NSAttributedString(string: "\n\(currentLetter)\n", attributes: letterAttrs))
            }

            let pageList = entry.pageNumbers.map { String($0) }.joined(separator: ", ")

            // Calculate leader dots
            let termAttrsForMeasure: [NSAttributedString.Key: Any] = [.font: entryFont]
            let termWidth = (entry.term as NSString).size(withAttributes: termAttrsForMeasure).width
            let pageListWidth = (pageList as NSString).size(withAttributes: termAttrsForMeasure).width
            let dotWidth = (".").size(withAttributes: termAttrsForMeasure).width
            let spaceWidth = (" ").size(withAttributes: termAttrsForMeasure).width
            let leftIndent: CGFloat = 20

            // Calculate dots to fill space between term and page numbers
            let contentWidth = actualLineWidth - leftIndent
            let paddingSpace = spaceWidth * 2  // Minimal padding around dots
            let availableForDots = contentWidth - termWidth - pageListWidth - paddingSpace
            let dotCount = max(3, Int(availableForDots / dotWidth))
            let leaderDots = " " + String(repeating: ".", count: dotCount) + " "

            // Create paragraph style with right-aligned tab stop at actual line edge
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = leftIndent
            paragraphStyle.headIndent = leftIndent
            paragraphStyle.tabStops = []
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: actualLineWidth, options: [:])]

            let entryAttrs: [NSAttributedString.Key: Any] = [
                .font: entryFont,
                .foregroundColor: ThemeManager.shared.currentTheme.textColor,
                .paragraphStyle: paragraphStyle
            ]

            let line = "\(entry.term)\(leaderDots)\t\(pageList)\n"
            indexString.append(NSAttributedString(string: line, attributes: entryAttrs))
        }

        indexString.append(NSAttributedString(string: "\n"))

        // Insert at cursor
        let insertLocation = textView.selectedRange().location
        textView.textStorage?.insert(indexString, at: insertLocation)

        showThemedAlert(title: "Index Inserted", message: "Index has been inserted at the cursor position.")
    }

    @objc private func goToIndexEntry() {
        let selectedRow = indexTableView.selectedRow
        guard selectedRow >= 0, selectedRow < TOCIndexManager.shared.indexEntries.count,
              let textView = editorTextView else { return }

        let entry = TOCIndexManager.shared.indexEntries[selectedRow]
        if let firstRange = entry.ranges.first {
            textView.setSelectedRange(firstRange)
            textView.scrollRangeToVisible(firstRange)
            textView.window?.makeFirstResponder(textView)
        }
    }

    // MARK: - Utilities

// Finds the range of a section that begins with the given title and continues until the next occurrence of the same title (or document end).
private func findSectionRange(title: String, in storage: NSTextStorage) -> NSRange? {
    let fullString = storage.string as NSString
    let searchRange = NSRange(location: 0, length: fullString.length)
    guard let titleRange = fullString.range(of: title, options: [.caseInsensitive], range: searchRange).toOptional() else {
        return nil
    }

    let nextSearchStart = titleRange.location + titleRange.length
    if nextSearchStart < fullString.length,
       let nextTitleRange = fullString.range(of: title, options: [.caseInsensitive], range: NSRange(location: nextSearchStart, length: fullString.length - nextSearchStart)).toOptional() {
        let length = nextTitleRange.location - titleRange.location
        return NSRange(location: titleRange.location, length: length)
    }

    // No subsequent title found; remove to end of document
    return NSRange(location: titleRange.location, length: fullString.length - titleRange.location)
}

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return TOCIndexManager.shared.tocEntries.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return TOCIndexManager.shared.tocEntries[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let entry = item as? TOCEntry else { return nil }

        let cellIdentifier = NSUserInterfaceItemIdentifier("TOCCell")
        var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTextField

        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = cellIdentifier
        }

        let theme = ThemeManager.shared.currentTheme
        let fontSize: CGFloat = entry.level == 1 ? 13 : (entry.level == 2 ? 12 : 11)
        let weight: NSFont.Weight = entry.level == 1 ? .semibold : .regular

        let indent = String(repeating: "  ", count: entry.level - 1)
        cell?.stringValue = "\(indent)\(entry.title)  —  p.\(entry.pageNumber)"
        cell?.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        cell?.textColor = theme.textColor

        return cell
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return TOCIndexManager.shared.indexEntries.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < TOCIndexManager.shared.indexEntries.count else { return nil }
        let entry = TOCIndexManager.shared.indexEntries[row]

        let cellIdentifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("Cell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTextField

        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = cellIdentifier
        }

        let theme = ThemeManager.shared.currentTheme
        cell?.textColor = theme.textColor
        cell?.font = NSFont.systemFont(ofSize: 12)

        switch tableColumn?.identifier.rawValue {
        case "Term":
            cell?.stringValue = entry.term
        case "Category":
            cell?.stringValue = entry.category
        case "Pages":
            cell?.stringValue = entry.pageNumbers.map { String($0) }.joined(separator: ", ")
        default:
            break
        }

        return cell
    }
}
