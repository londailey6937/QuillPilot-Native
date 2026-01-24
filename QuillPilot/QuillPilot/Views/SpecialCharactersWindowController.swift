 import Cocoa

@MainActor
final class SpecialCharactersWindowController: NSWindowController {

    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    private let onInsertText: (String) -> Void
    private let onToggleParagraphMarks: () -> Void
    private let onFindInvisibleCharacters: () -> Void
    private let onRemoveExtraBlankLines: () -> Void
    private let onApplyDropCap: () -> Void
    private let onApplyOldStyleNumerals: () -> Void
    private let onApplyOpticalKerning: () -> Void

    private var scrollView: NSScrollView!
    private var insertionByButton: [ObjectIdentifier: String] = [:]
    private var rootContentView: NSView?
    private var documentContainerView: NSView?
    private var rootStackView: NSStackView?
    private var themeObserver: NSObjectProtocol?
    private var clickOutsideMonitor: Any?

    struct Entry {
        let title: String
        let insert: String
        let toolTip: String?
    }

    convenience init(
        onInsertText: @escaping (String) -> Void,
        onToggleParagraphMarks: @escaping () -> Void,
        onFindInvisibleCharacters: @escaping () -> Void,
        onRemoveExtraBlankLines: @escaping () -> Void,
        onApplyDropCap: @escaping () -> Void,
        onApplyOldStyleNumerals: @escaping () -> Void,
        onApplyOpticalKerning: @escaping () -> Void
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Special Characters"
        window.minSize = NSSize(width: 460, height: 520)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false

        self.init(
            window: window,
            onInsertText: onInsertText,
            onToggleParagraphMarks: onToggleParagraphMarks,
            onFindInvisibleCharacters: onFindInvisibleCharacters,
            onRemoveExtraBlankLines: onRemoveExtraBlankLines,
            onApplyDropCap: onApplyDropCap,
            onApplyOldStyleNumerals: onApplyOldStyleNumerals,
            onApplyOpticalKerning: onApplyOpticalKerning
        )

        setupUI()
    }

    init(
        window: NSWindow,
        onInsertText: @escaping (String) -> Void,
        onToggleParagraphMarks: @escaping () -> Void,
        onFindInvisibleCharacters: @escaping () -> Void,
        onRemoveExtraBlankLines: @escaping () -> Void,
        onApplyDropCap: @escaping () -> Void,
        onApplyOldStyleNumerals: @escaping () -> Void,
        onApplyOpticalKerning: @escaping () -> Void
    ) {
        self.onInsertText = onInsertText
        self.onToggleParagraphMarks = onToggleParagraphMarks
        self.onFindInvisibleCharacters = onFindInvisibleCharacters
        self.onRemoveExtraBlankLines = onRemoveExtraBlankLines
        self.onApplyDropCap = onApplyDropCap
        self.onApplyOldStyleNumerals = onApplyOldStyleNumerals
        self.onApplyOpticalKerning = onApplyOpticalKerning
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // Scroll to top after layout so the window opens at the beginning.
        DispatchQueue.main.async { [weak self] in
            self?.updateDocumentLayout()
            self?.scrollToTop()
        }
    }

    private func scrollToTop() {
        guard let scrollView else { return }
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func updateDocumentLayout() {
        guard let scrollView, let docView = scrollView.documentView, let stack = rootStackView else { return }

        // Force layout so fittingSize is accurate.
        stack.layoutSubtreeIfNeeded()
        docView.layoutSubtreeIfNeeded()

        // Update the documentView frame height so the scroll view has a stable content size.
        let targetWidth = scrollView.contentView.bounds.width
        if targetWidth > 0 {
            docView.frame.size.width = targetWidth
        }

        let fitting = stack.fittingSize
        let padding = stack.edgeInsets.top + stack.edgeInsets.bottom
        let targetHeight = max(200, fitting.height + padding)
        if abs(docView.frame.size.height - targetHeight) > 0.5 {
            docView.frame.size.height = targetHeight
        }
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
    }

    private func setupUI() {
        guard let window else { return }

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        rootContentView = contentView

        applyTheme(ThemeManager.shared.currentTheme)

        // Scroll container
        scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = ThemeManager.shared.currentTheme.pageAround

        let docView = FlippedView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width, height: 1000))
        docView.translatesAutoresizingMaskIntoConstraints = true
        docView.autoresizingMask = [.width]
        docView.wantsLayer = true
        documentContainerView = docView
        docView.layer?.backgroundColor = ThemeManager.shared.currentTheme.pageAround.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        rootStackView = stack

        let intro = NSTextField(labelWithString: "Curated punctuation, spacing, and editorial marks — no emoji picker.")
        intro.textColor = ThemeManager.shared.currentTheme.textColor.withAlphaComponent(0.75)
        intro.font = NSFont.systemFont(ofSize: 12)
        intro.lineBreakMode = .byWordWrapping
        intro.maximumNumberOfLines = 0
        stack.addArrangedSubview(intro)

        stack.addArrangedSubview(makeTypographySection(theme: ThemeManager.shared.currentTheme))
        stack.addArrangedSubview(makeVisibilitySection(theme: ThemeManager.shared.currentTheme))

        stack.addArrangedSubview(makeSection(
            title: "Smart punctuation",
            theme: ThemeManager.shared.currentTheme,
            entries: [
                Entry(title: "Em dash", insert: "—", toolTip: "U+2014"),
                Entry(title: "En dash", insert: "–", toolTip: "U+2013"),
                Entry(title: "Figure dash", insert: "‒", toolTip: "U+2012"),
                Entry(title: "Ellipsis", insert: "…", toolTip: "U+2026"),
                Entry(title: "Left double quote", insert: "“", toolTip: "U+201C"),
                Entry(title: "Right double quote", insert: "”", toolTip: "U+201D"),
                Entry(title: "Left single quote", insert: "‘", toolTip: "U+2018"),
                Entry(title: "Right single quote", insert: "’", toolTip: "U+2019"),
            ]
        ))

        stack.addArrangedSubview(makeSection(
            title: "Spacing characters",
            theme: ThemeManager.shared.currentTheme,
            entries: [
                Entry(title: "Non-breaking space", insert: "\u{00A0}", toolTip: "NBSP (U+00A0)"),
                Entry(title: "Thin space", insert: "\u{2009}", toolTip: "U+2009"),
                Entry(title: "Hair space", insert: "\u{200A}", toolTip: "U+200A"),
                Entry(title: "Narrow no-break space", insert: "\u{202F}", toolTip: "U+202F"),
            ]
        ))

        stack.addArrangedSubview(makeSection(
            title: "Line & paragraph controls",
            theme: ThemeManager.shared.currentTheme,
            entries: [
                Entry(title: "Soft line break", insert: "\u{2028}", toolTip: "Line Separator (U+2028)"),
                Entry(title: "Non-breaking hyphen", insert: "\u{2011}", toolTip: "U+2011"),
                Entry(title: "Discretionary (soft) hyphen", insert: "\u{00AD}", toolTip: "Soft Hyphen (U+00AD)"),
                Entry(title: "Pilcrow", insert: "¶", toolTip: "U+00B6"),
            ]
        ))

        stack.addArrangedSubview(makeSection(
            title: "Literary & editorial",
            theme: ThemeManager.shared.currentTheme,
            entries: [
                Entry(title: "Section mark", insert: "§", toolTip: "U+00A7"),
                Entry(title: "Dagger", insert: "†", toolTip: "U+2020"),
                Entry(title: "Double dagger", insert: "‡", toolTip: "U+2021"),
                Entry(title: "Reference mark", insert: "※", toolTip: "U+203B"),
                Entry(title: "Asterism", insert: "⁂", toolTip: "U+2042"),
                Entry(title: "Four flower", insert: "⁕", toolTip: "U+2055"),
            ]
        ))

        stack.addArrangedSubview(makeDiacriticsSection(theme: ThemeManager.shared.currentTheme))

        docView.addSubview(stack)
        scrollView.documentView = docView
        contentView.addSubview(scrollView)
        window.contentView = contentView

        // Keep appearance in sync with the app theme (critical for labels/buttons).
        applyTheme(ThemeManager.shared.currentTheme)
        themeObserver = NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] notification in
            guard let self, let theme = notification.object as? AppTheme else { return }
            Task { @MainActor in
                self.applyTheme(theme)
            }
        }

        // Close when the user clicks back into the main UI (or any other app window).
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self, let window = self.window, window.isVisible else { return event }
            if event.window != window {
                window.close()
            }
            return event
        }

        // Auto Layout: make docView track scroll width; stack fills docView.
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: docView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: docView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: docView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: docView.bottomAnchor)
        ])

        // Establish stable content size immediately.
        updateDocumentLayout()
        scrollToTop()
    }

    private func makeTypographySection(theme: AppTheme) -> NSView {
        let container = NSView()
        let title = makeSectionHeader("Typography", theme: theme)

        let dropCap = NSButton(title: "Apply Drop Cap", target: self, action: #selector(applyDropCapTapped(_:)))
        dropCap.bezelStyle = .rounded

        let oldStyle = NSButton(title: "Use Old-Style Numerals", target: self, action: #selector(oldStyleNumeralsTapped(_:)))
        oldStyle.bezelStyle = .rounded

        let optical = NSButton(title: "Apply Optical Kerning", target: self, action: #selector(opticalKerningTapped(_:)))
        optical.bezelStyle = .rounded

        let row = NSStackView(views: [dropCap, oldStyle, optical])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let note = NSTextField(labelWithString: "Ligatures and smart quotes are enabled by default.")
        note.textColor = theme.textColor.withAlphaComponent(0.75)
        note.font = NSFont.systemFont(ofSize: 12)

        let stack = NSStackView(views: [title, row, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func applyTheme(_ theme: AppTheme) {
        // Match app appearance for proper label rendering.
        let isDarkMode = ThemeManager.shared.isDarkMode
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        rootContentView?.layer?.backgroundColor = theme.pageAround.cgColor
        documentContainerView?.layer?.backgroundColor = theme.pageAround.cgColor
        scrollView?.backgroundColor = theme.pageAround

        if let root = rootContentView {
            applyThemeRecursively(in: root, theme: theme)
        }
    }

    private func applyThemeRecursively(in view: NSView, theme: AppTheme) {
        // Ensure views inherit our appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        view.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        if let textField = view as? NSTextField, textField.isEditable == false, textField.isSelectable == false {
            textField.textColor = theme.textColor
        }

        if let button = view as? NSButton {
            button.contentTintColor = theme.textColor
            // NSButton title color doesn't always follow contentTintColor; force it.
            let font = button.font ?? NSFont.systemFont(ofSize: 13)
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: theme.textColor,
                    .font: font
                ]
            )
        }

        if let scroll = view as? NSScrollView {
            scroll.drawsBackground = true
            scroll.backgroundColor = theme.pageAround
        }

        for sub in view.subviews {
            applyThemeRecursively(in: sub, theme: theme)
        }
    }

    private func makeVisibilitySection(theme: AppTheme) -> NSView {
        let container = NSView()

        let title = makeSectionHeader("Invisible but important", theme: theme)

        let showParagraphMarks = NSButton(checkboxWithTitle: "Show / hide paragraph marks (¶)", target: self, action: #selector(toggleParagraphMarksTapped(_:)))
        showParagraphMarks.contentTintColor = theme.textColor

        let findInvisible = NSButton(title: "Find Invisible Characters…", target: self, action: #selector(findInvisibleTapped(_:)))
        findInvisible.bezelStyle = .rounded

        let removeBlankLines = NSButton(title: "Remove Extra Blank Lines", target: self, action: #selector(removeBlankLinesTapped(_:)))
        removeBlankLines.bezelStyle = .rounded

        let row = NSStackView(views: [findInvisible, removeBlankLines])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let stack = NSStackView(views: [title, showParagraphMarks, row])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func makeSection(title: String, theme: AppTheme, entries: [Entry]) -> NSView {
        let container = NSView()

        let header = makeSectionHeader(title, theme: theme)

        // Use a compact grid of buttons.
        let grid = NSGridView()
        grid.yPlacement = .center
        grid.xPlacement = .leading
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false

        var rowViews: [[NSView]] = []
        var currentRow: [NSView] = []

        for entry in entries {
            currentRow.append(makeEntryButton(entry, theme: theme))
            if currentRow.count == 2 {
                rowViews.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty {
            rowViews.append(currentRow)
        }

        for row in rowViews {
            grid.addRow(with: row)
        }

        let stack = NSStackView(views: [header, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Make grid fill horizontally.
        grid.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return container
    }

    private func makeDiacriticsSection(theme: AppTheme) -> NSView {
        let container = NSView()
        let header = makeSectionHeader("Language & diacritics", theme: theme)

        func row(label: String, variants: [Entry]) -> NSView {
            let labelView = NSTextField(labelWithString: label)
            labelView.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            labelView.textColor = theme.textColor.withAlphaComponent(0.8)
            labelView.setContentHuggingPriority(.required, for: .horizontal)

            let buttons = NSStackView(views: variants.map { makeVariantButton($0, theme: theme) })
            buttons.orientation = .horizontal
            buttons.spacing = 8
            buttons.alignment = .centerY

            let stack = NSStackView(views: [labelView, buttons])
            stack.orientation = .horizontal
            stack.spacing = 12
            stack.alignment = .centerY
            return stack
        }

        let aRow = row(label: "a", variants: [
            Entry(title: "á", insert: "á", toolTip: "a-acute"),
            Entry(title: "à", insert: "à", toolTip: "a-grave"),
            Entry(title: "â", insert: "â", toolTip: "a-circumflex"),
            Entry(title: "ä", insert: "ä", toolTip: "a-umlaut"),
        ])

        let eRow = row(label: "e", variants: [
            Entry(title: "é", insert: "é", toolTip: "e-acute"),
            Entry(title: "è", insert: "è", toolTip: "e-grave"),
            Entry(title: "ê", insert: "ê", toolTip: "e-circumflex"),
            Entry(title: "ë", insert: "ë", toolTip: "e-umlaut"),
        ])

        let iRow = row(label: "i", variants: [
            Entry(title: "í", insert: "í", toolTip: "i-acute"),
            Entry(title: "ì", insert: "ì", toolTip: "i-grave"),
            Entry(title: "î", insert: "î", toolTip: "i-circumflex"),
            Entry(title: "ï", insert: "ï", toolTip: "i-umlaut"),
        ])

        let oRow = row(label: "o", variants: [
            Entry(title: "ó", insert: "ó", toolTip: "o-acute"),
            Entry(title: "ò", insert: "ò", toolTip: "o-grave"),
            Entry(title: "ô", insert: "ô", toolTip: "o-circumflex"),
            Entry(title: "ö", insert: "ö", toolTip: "o-umlaut"),
        ])

        let uRow = row(label: "u", variants: [
            Entry(title: "ú", insert: "ú", toolTip: "u-acute"),
            Entry(title: "ù", insert: "ù", toolTip: "u-grave"),
            Entry(title: "û", insert: "û", toolTip: "u-circumflex"),
            Entry(title: "ü", insert: "ü", toolTip: "u-umlaut"),
        ])

        let miscGrid = NSGridView()
        miscGrid.yPlacement = .center
        miscGrid.xPlacement = .leading
        miscGrid.rowSpacing = 8
        miscGrid.columnSpacing = 10
        miscGrid.translatesAutoresizingMaskIntoConstraints = false
        miscGrid.addRow(with: [
            makeEntryButton(Entry(title: "ñ", insert: "ñ", toolTip: "n-tilde"), theme: theme),
            makeEntryButton(Entry(title: "ç", insert: "ç", toolTip: "c-cedilla"), theme: theme)
        ])
        miscGrid.addRow(with: [
            makeEntryButton(Entry(title: "æ", insert: "æ", toolTip: "ligature"), theme: theme),
            makeEntryButton(Entry(title: "œ", insert: "œ", toolTip: "ligature"), theme: theme)
        ])
        miscGrid.addRow(with: [
            makeEntryButton(Entry(title: "¿", insert: "¿", toolTip: "inverted question"), theme: theme),
            makeEntryButton(Entry(title: "¡", insert: "¡", toolTip: "inverted exclamation"), theme: theme)
        ])

        let stack = NSStackView(views: [header, aRow, eRow, iRow, oRow, uRow, miscGrid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        miscGrid.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return container
    }

    private func makeVariantButton(_ entry: Entry, theme: AppTheme) -> NSButton {
        let button = NSButton(title: entry.title, target: self, action: #selector(insertTapped(_:)))
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 14)
        button.contentTintColor = theme.textColor
        button.toolTip = entry.toolTip
        insertionByButton[ObjectIdentifier(button)] = entry.insert
        return button
    }

    private func makeSectionHeader(_ title: String, theme: AppTheme) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = theme.textColor
        return label
    }

    private func makeEntryButton(_ entry: Entry, theme: AppTheme) -> NSButton {
        let displayTitle: String
        if entry.insert == "\u{00A0}" {
            displayTitle = "⍽  \(entry.title)"
        } else if entry.insert == "\u{2009}" {
            displayTitle = "⟨thin⟩  \(entry.title)"
        } else if entry.insert == "\u{200A}" {
            displayTitle = "⟨hair⟩  \(entry.title)"
        } else if entry.insert == "\u{202F}" {
            displayTitle = "⟨nnbsp⟩  \(entry.title)"
        } else if entry.insert == "\u{00AD}" {
            displayTitle = "⟨shy⟩  \(entry.title)"
        } else if entry.insert == "\u{2028}" {
            displayTitle = "↩︎  \(entry.title)"
        } else {
            displayTitle = "\(entry.insert)  \(entry.title)"
        }

        let button = NSButton(title: displayTitle, target: self, action: #selector(insertTapped(_:)))
        button.bezelStyle = .rounded
        button.alignment = .left
        button.contentTintColor = theme.textColor
        button.toolTip = entry.toolTip
        insertionByButton[ObjectIdentifier(button)] = entry.insert
        return button
    }

    @objc private func insertTapped(_ sender: NSButton) {
        guard let insert = insertionByButton[ObjectIdentifier(sender)] else { return }
        onInsertText(insert)
    }

    @objc private func toggleParagraphMarksTapped(_ sender: NSButton) {
        onToggleParagraphMarks()
    }

    @objc private func findInvisibleTapped(_ sender: Any?) {
        onFindInvisibleCharacters()
    }

    @objc private func removeBlankLinesTapped(_ sender: Any?) {
        onRemoveExtraBlankLines()
    }

    @objc private func applyDropCapTapped(_ sender: Any?) {
        onApplyDropCap()
    }

    @objc private func oldStyleNumeralsTapped(_ sender: Any?) {
        onApplyOldStyleNumerals()
    }

    @objc private func opticalKerningTapped(_ sender: Any?) {
        onApplyOpticalKerning()
    }
}
