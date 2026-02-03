import Cocoa

@MainActor
final class SectionBreaksWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var nameColumn: NSTableColumn!
    private var startColumn: NSTableColumn!
    private var formatColumn: NSTableColumn!

    private var goToButton: NSButton!
    private var editButton: NSButton!
    private var removeButton: NSButton!
    private var closeButton: NSButton!

    private var themeObserver: NSObjectProtocol?

    private final class ThemedTableRowView: NSTableRowView {
        override func drawSelection(in dirtyRect: NSRect) {
            guard isSelected else { return }
            let theme = ThemeManager.shared.currentTheme
            let fill: NSColor = {
                switch theme {
                case .night:
                    return theme.pageBorder.withAlphaComponent(0.35)
                case .day, .cream:
                    return theme.pageBorder.withAlphaComponent(0.22)
                }
            }()
            fill.setFill()
            NSBezierPath(rect: bounds).fill()
        }
    }

    private var sectionBreaks: [SectionBreakInfo] = []

    private let provider: () -> [SectionBreakInfo]
    private let onGoTo: (String) -> Void
    private let onEdit: (String) -> Void
    private let onRemove: (String) -> Void

    init(
        provider: @escaping () -> [SectionBreakInfo],
        onGoTo: @escaping (String) -> Void,
        onEdit: @escaping (String) -> Void,
        onRemove: @escaping (String) -> Void
    ) {
        self.provider = provider
        self.onGoTo = onGoTo
        self.onEdit = onEdit
        self.onRemove = onRemove

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Section Breaks"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        setupUI()
        reload()
        applyTheme()

        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyTheme()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    func reload() {
        sectionBreaks = provider()
        tableView?.reloadData()
        tableView?.sizeLastColumnToFit()
        updateButtonEnabledStates()
    }

    private func setupUI() {
        guard let window else { return }

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.wantsLayer = true
        window.contentView = contentView

        let headerLabel = NSTextField(labelWithString: "Section breaks in this document:")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.tag = 900
        contentView.addSubview(headerLabel)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
        contentView.addSubview(scrollView)

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.selectionHighlightStyle = .none
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.intercellSpacing = NSSize(width: 10, height: 6)
        tableView.delegate = self
        tableView.dataSource = self

        nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 240
        nameColumn.minWidth = 160
        nameColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(nameColumn)

        startColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("start"))
        startColumn.title = "Start"
        startColumn.width = 70
        startColumn.minWidth = 60
        startColumn.maxWidth = 90
        startColumn.resizingMask = .userResizingMask
        tableView.addTableColumn(startColumn)

        formatColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("format"))
        formatColumn.title = "Format"
        formatColumn.width = 160
        formatColumn.minWidth = 140
        formatColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(formatColumn)

        scrollView.documentView = tableView

        goToButton = NSButton(title: "Go To", target: self, action: #selector(goToTapped))
        editButton = NSButton(title: "Edit…", target: self, action: #selector(editTapped))
        removeButton = NSButton(title: "Remove", target: self, action: #selector(removeTapped))
        closeButton = NSButton(title: "Close", target: self, action: #selector(closeTapped))

        [goToButton, editButton, removeButton, closeButton].forEach { button in
            button?.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(button!)
        }

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            scrollView.bottomAnchor.constraint(equalTo: goToButton.topAnchor, constant: -14),

            goToButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            goToButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            goToButton.widthAnchor.constraint(equalToConstant: 80),

            editButton.leadingAnchor.constraint(equalTo: goToButton.trailingAnchor, constant: 8),
            editButton.centerYAnchor.constraint(equalTo: goToButton.centerYAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 80),

            removeButton.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 8),
            removeButton.centerYAnchor.constraint(equalTo: goToButton.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 90),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            closeButton.centerYAnchor.constraint(equalTo: goToButton.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 80)
        ])

        updateButtonEnabledStates()
    }

    private func updateButtonEnabledStates() {
        let hasSelection = tableView?.selectedRow ?? -1 >= 0
        goToButton?.isEnabled = hasSelection
        editButton?.isEnabled = hasSelection
        removeButton?.isEnabled = hasSelection
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme
        let isDark = ThemeManager.shared.isDarkMode

        window?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        window?.backgroundColor = theme.pageBackground

        if let contentView = window?.contentView {
            contentView.layer?.backgroundColor = theme.pageBackground.cgColor
            for view in contentView.subviews {
                if let label = view as? NSTextField, !label.isEditable {
                    label.textColor = theme.textColor
                }
            }
        }

        tableView.backgroundColor = theme.pageBackground
        styleTextAreaScrollView(scrollView, theme: theme)

        [goToButton, editButton, removeButton, closeButton].forEach { button in
            guard let button else { return }
            themeButton(button, theme: theme)
        }
    }

    private func styleTextAreaScrollView(_ scrollView: NSScrollView, theme: AppTheme) {
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.pageBackground
        scrollView.borderType = .noBorder

        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = theme.pageBackground.cgColor
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.masksToBounds = false

        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.backgroundColor = theme.pageBackground.cgColor
        scrollView.contentView.layer?.borderWidth = 1
        scrollView.contentView.layer?.cornerRadius = 6
        scrollView.contentView.layer?.borderColor = theme.pageBorder.cgColor
        scrollView.contentView.layer?.masksToBounds = true
    }

    private func themeButton(_ button: NSButton, theme: AppTheme) {
        button.contentTintColor = theme.textColor
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = theme.pageBackground.cgColor
        button.layer?.borderColor = theme.pageBorder.cgColor
        button.layer?.borderWidth = 1
        button.layer?.cornerRadius = 6
        let font = button.font ?? NSFont.systemFont(ofSize: 13)
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .foregroundColor: theme.textColor,
                .font: font
            ]
        )
    }

    // MARK: - NSTableView

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        ThemedTableRowView()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        sectionBreaks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < sectionBreaks.count else { return nil }
        let theme = ThemeManager.shared.currentTheme
        let item = sectionBreaks[row]

        let text: String
        switch tableColumn?.identifier.rawValue {
        case "start":
            text = String(item.startPageNumber)
        case "format":
            text = item.numberFormatDisplay
        default:
            text = item.name
        }

        let cell = NSTextField(labelWithString: text)
        cell.lineBreakMode = .byTruncatingTail
        cell.textColor = theme.textColor
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonEnabledStates()
    }

    // MARK: - Actions

    @objc private func goToTapped() {
        guard let item = selectedSectionBreak() else {
            NSSound.beep()
            return
        }
        onGoTo(item.id)
    }

    @objc private func editTapped() {
        guard let item = selectedSectionBreak() else {
            NSSound.beep()
            return
        }
        onEdit(item.id)
        // Edits can change names/starts/formats.
        DispatchQueue.main.async { [weak self] in
            self?.reload()
        }
    }

    @objc private func removeTapped() {
        guard let item = selectedSectionBreak() else {
            NSSound.beep()
            return
        }
        onRemove(item.id)
        reload()
    }

    @objc private func closeTapped() {
        window?.close()
    }

    private func selectedSectionBreak() -> SectionBreakInfo? {
        let row = tableView.selectedRow
        guard row >= 0, row < sectionBreaks.count else { return nil }
        return sectionBreaks[row]
    }
}
