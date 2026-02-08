import Cocoa

// MARK: - Scene List Window Controller
/// Displays a list of scenes for the project.
/// IMPORTANT: This window only manages metadata - it NEVER accesses the editor.
final class SceneListWindowController: NSWindowController {

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var toolbar: NSView!
    private var filterBar: NSView!
    private var addButton: NSButton!
    private var deleteButton: NSButton!
    private var stateFilterPopup: NSPopUpButton!
    private var intentFilterPopup: NSPopUpButton!

    private var sceneManager = SceneManager()
    private var inspectorWindow: SceneInspectorWindowController?

    // Filtering state
    private var filteredScenes: [Scene] = []
    private var stateFilter: RevisionState? = nil
    private var intentFilter: SceneIntent? = nil

    // Persistence - document specific
    private var currentDocumentURL: URL?

    // Store UI elements for theme updates
    private var countLabel: NSTextField?
    private var filterLabel: NSTextField?

    private func scenesStorageKey(for documentURL: URL?) -> String {
        guard let url = documentURL else {
            return "QuillPilot.Scenes.Untitled"
        }
        // Use document path as unique identifier
        return "QuillPilot.Scenes.\(url.path)"
    }

    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Scenes"
        window.minSize = NSSize(width: 280, height: 300)
        window.isReleasedWhenClosed = false
        // Treat as an in-app utility panel: stay above Quill Pilot windows, but hide when switching apps.
        window.isFloatingPanel = true
        window.hidesOnDeactivate = true
        window.collectionBehavior = [.moveToActiveSpace]

        // Set window appearance to match theme (light/dark mode)
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        super.init(window: window)

        setupUI()
        applyCurrentTheme()

        // Listen for theme changes
        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyCurrentTheme()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        // Toolbar at bottom
        toolbar = NSView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width, height: 44))
        toolbar.autoresizingMask = [.width]
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.addSubview(toolbar)

        // Add button (larger)
        addButton = NSButton(title: "+", target: self, action: #selector(addScene))
        addButton.bezelStyle = .texturedRounded
        addButton.frame = NSRect(x: 8, y: 6, width: 40, height: 32)
        addButton.font = NSFont.systemFont(ofSize: 20)
        addButton.toolTip = "Add new scene"
        toolbar.addSubview(addButton)

        // Delete button (larger)
        deleteButton = NSButton(title: "−", target: self, action: #selector(deleteSelectedScene))
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.frame = NSRect(x: 52, y: 6, width: 40, height: 32)
        deleteButton.font = NSFont.systemFont(ofSize: 20)
        deleteButton.toolTip = "Delete selected scene"
        deleteButton.isEnabled = false
        toolbar.addSubview(deleteButton)

        // Scene count label
        countLabel = NSTextField(labelWithString: "0 scenes")
        countLabel!.tag = 100
        countLabel!.frame = NSRect(x: toolbar.bounds.width - 100, y: 12, width: 90, height: 20)
        countLabel!.alignment = .right
        countLabel!.textColor = NSColor.secondaryLabelColor
        countLabel!.font = NSFont.systemFont(ofSize: 11)
        countLabel!.autoresizingMask = [.minXMargin]
        toolbar.addSubview(countLabel!)

        // Filter bar at top
        filterBar = NSView(frame: NSRect(x: 0, y: contentView.bounds.height - 32, width: contentView.bounds.width, height: 32))
        filterBar.autoresizingMask = [.width, .minYMargin]
        filterBar.wantsLayer = true
        filterBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.addSubview(filterBar)

        // Filter label
        filterLabel = NSTextField(labelWithString: "Filter:")
        filterLabel!.frame = NSRect(x: 8, y: 6, width: 40, height: 20)
        filterLabel!.font = NSFont.systemFont(ofSize: 11)
        filterLabel!.textColor = NSColor.secondaryLabelColor
        filterBar.addSubview(filterLabel!)

        // State filter popup
        stateFilterPopup = NSPopUpButton(frame: NSRect(x: 50, y: 3, width: 100, height: 26), pullsDown: false)
        stateFilterPopup.font = NSFont.systemFont(ofSize: 11)
        stateFilterPopup.addItem(withTitle: "All States")
        for state in RevisionState.allCases {
            stateFilterPopup.addItem(withTitle: "\(state.icon) \(state.rawValue)")
        }
        stateFilterPopup.target = self
        stateFilterPopup.action = #selector(filterChanged)
        filterBar.addSubview(stateFilterPopup)

        // Intent filter popup
        intentFilterPopup = NSPopUpButton(frame: NSRect(x: 155, y: 3, width: 110, height: 26), pullsDown: false)
        intentFilterPopup.font = NSFont.systemFont(ofSize: 11)
        intentFilterPopup.addItem(withTitle: "All Intents")
        for intent in SceneIntent.allCases {
            intentFilterPopup.addItem(withTitle: intent.rawValue)
        }
        intentFilterPopup.target = self
        intentFilterPopup.action = #selector(filterChanged)
        filterBar.addSubview(intentFilterPopup)

        // Scroll view for table
        scrollView = NSScrollView(frame: NSRect(
            x: 0,
            y: 44,
            width: contentView.bounds.width,
            height: contentView.bounds.height - 44 - 32
        ))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        contentView.addSubview(scrollView)

        // Table view
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 48
        tableView.allowsMultipleSelection = false
        tableView.doubleAction = #selector(doubleClickScene)
        tableView.target = self
        tableView.selectionHighlightStyle = .none

        // Enable drag and drop for reordering
        tableView.registerForDraggedTypes([.string])
        tableView.draggingDestinationFeedbackStyle = .gap

        // Single column for scene display
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("scene"))
        column.title = "Scene"
        column.width = 280
        column.minWidth = 150
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        tableView.headerView = nil
        scrollView.documentView = tableView

        updateCountLabel()
    }

    /// Load scenes for a specific document. If documentURL is nil, uses the shared Untitled key.
    func loadScenes(for documentURL: URL?) {
        currentDocumentURL = documentURL

        // Clear existing scenes first
        sceneManager.clear()

        // Load from UserDefaults (supports nil URL via the Untitled key)
        if let data = UserDefaults.standard.data(forKey: scenesStorageKey(for: documentURL)) {
            do {
                try sceneManager.decode(from: data)
            } catch {
            }
        }

        applyFilters()
        tableView.reloadData()
        updateCountLabel()

        NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
    }

    private func saveScenes() {
        do {
            let data = try sceneManager.encode()
            UserDefaults.standard.set(data, forKey: scenesStorageKey(for: currentDocumentURL))
        } catch {
        }

        NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
    }

    private func applyFilters() {
        filteredScenes = sceneManager.scenes.filter { scene in
            // State filter
            if let state = stateFilter, scene.revisionState != state {
                return false
            }
            // Intent filter
            if let intent = intentFilter, scene.intent != intent {
                return false
            }
            return true
        }
    }

    @objc private func filterChanged() {
        // Update state filter
        if stateFilterPopup.indexOfSelectedItem == 0 {
            stateFilter = nil
        } else {
            stateFilter = RevisionState.allCases[stateFilterPopup.indexOfSelectedItem - 1]
        }

        // Update intent filter
        if intentFilterPopup.indexOfSelectedItem == 0 {
            intentFilter = nil
        } else {
            intentFilter = SceneIntent.allCases[intentFilterPopup.indexOfSelectedItem - 1]
        }

        applyFilters()
        tableView.reloadData()
        updateCountLabel()

        // Clear selection when filters change
        tableView.deselectAll(nil)
        deleteButton.isEnabled = false
    }

    private func updateCountLabel() {
        if let label = toolbar.viewWithTag(100) as? NSTextField {
            let total = sceneManager.sceneCount
            let shown = filteredScenes.count
            if stateFilter == nil && intentFilter == nil {
                label.stringValue = "\(total) scene\(total == 1 ? "" : "s")"
            } else {
                label.stringValue = "\(shown)/\(total) scenes"
            }
        }
    }

    // MARK: - Actions

    @objc private func addScene() {
        let newScene = Scene(
            order: sceneManager.sceneCount,
            title: "New Scene",
            intent: .setup
        )
        sceneManager.addScene(newScene)
        saveScenes()
        applyFilters()
        tableView.reloadData()
        updateCountLabel()

        // Select and scroll to new scene if visible after filtering
        if let newIndex = filteredScenes.firstIndex(where: { $0.id == newScene.id }) {
            tableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(newIndex)
        }
    }

    @objc private func deleteSelectedScene() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < filteredScenes.count else { return }

        let scene = filteredScenes[selectedRow]
        sceneManager.deleteScene(id: scene.id)
        saveScenes()
        applyFilters()
        tableView.reloadData()
        updateCountLabel()

        // Update button states
        deleteButton.isEnabled = false
    }

    @objc private func showInspector() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < filteredScenes.count else { return }

        let scene = filteredScenes[selectedRow]

        if inspectorWindow == nil {
            inspectorWindow = SceneInspectorWindowController()
        }

        inspectorWindow?.loadScene(scene, documentURL: currentDocumentURL) { [weak self] updatedScene in
            self?.sceneManager.updateScene(updatedScene)
            self?.saveScenes()
            self?.applyFilters()
            self?.tableView.reloadData()
        }

        inspectorWindow?.showWindow(nil)
        if let parent = window, let child = inspectorWindow?.window {
            let alreadyChild = parent.childWindows?.contains(child) ?? false
            if !alreadyChild {
                parent.addChildWindow(child, ordered: .above)
            }
            child.makeKeyAndOrderFront(nil)
        } else {
            inspectorWindow?.window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func doubleClickScene() {
        showInspector()
    }
}

// MARK: - NSTableViewDataSource
extension SceneListWindowController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredScenes.count
    }

    // Drag support - disabled when filtering is active
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        // Disable drag when filters are active (reordering doesn't make sense with filtered view)
        guard stateFilter == nil && intentFilter == nil else { return nil }

        let item = NSPasteboardItem()
        item.setString(String(row), forType: .string)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        // Disable drop when filters are active
        guard stateFilter == nil && intentFilter == nil else { return [] }

        if dropOperation == .above {
            return .move
        }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        // Disable drop when filters are active
        guard stateFilter == nil && intentFilter == nil else { return false }

        guard let items = info.draggingPasteboard.pasteboardItems,
              let item = items.first,
              let rowString = item.string(forType: .string),
              let sourceRow = Int(rowString) else {
            return false
        }

        var destinationRow = row
        if sourceRow < row {
            destinationRow -= 1
        }

        sceneManager.moveScene(from: sourceRow, to: destinationRow)
        saveScenes()
        applyFilters()
        tableView.reloadData()

        return true
    }
}

// MARK: - NSTableViewDelegate
extension SceneListWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredScenes.count else { return nil }
        let scene = filteredScenes[row]

        let cellView = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 280, height: 48))
        cellView.wantsLayer = true
        let theme = ThemeManager.shared.currentTheme
        let isSelected = tableView.selectedRow == row
        cellView.layer?.backgroundColor = isSelected ? theme.pageBorder.withAlphaComponent(0.18).cgColor : NSColor.clear.cgColor

        // Container for layout
        let container = NSView(frame: cellView.bounds)
        container.autoresizingMask = [.width, .height]
        cellView.addSubview(container)

        // Status icon
        let statusLabel = NSTextField(labelWithString: scene.revisionState.icon)
        statusLabel.frame = NSRect(x: 8, y: 14, width: 20, height: 20)
        statusLabel.font = NSFont.systemFont(ofSize: 14)
        container.addSubview(statusLabel)

        // Title
        let titleLabel = NSTextField(labelWithString: scene.title)
        titleLabel.frame = NSRect(x: 32, y: 26, width: container.bounds.width - 80, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = theme.textColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.autoresizingMask = [.width]
        container.addSubview(titleLabel)

        // Subtitle (intent + summary)
        let subtitle = scene.summary.isEmpty ? scene.intent.rawValue : "\(scene.intent.rawValue) • \(scene.summary)"
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.frame = NSRect(x: 32, y: 6, width: container.bounds.width - 80, height: 16)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = theme.textColor.withAlphaComponent(0.7)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.autoresizingMask = [.width]
        container.addSubview(subtitleLabel)

        // Order number badge (shows original order, not filtered position)
        let orderLabel = NSTextField(labelWithString: "\(scene.order + 1)")
        orderLabel.frame = NSRect(x: container.bounds.width - 40, y: 14, width: 32, height: 20)
        orderLabel.alignment = .right
        orderLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        orderLabel.textColor = theme.textColor.withAlphaComponent(0.5)
        orderLabel.autoresizingMask = [.minXMargin]
        container.addSubview(orderLabel)

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        deleteButton.isEnabled = hasSelection
    }

    private func applyCurrentTheme() {
        let theme = ThemeManager.shared.currentTheme
        guard let contentView = window?.contentView else { return }

        // Window appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        window?.backgroundColor = theme.pageBackground

        // Window background
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.pageBackground.cgColor

        // Toolbar
        toolbar?.wantsLayer = true
        toolbar?.layer?.backgroundColor = theme.pageAround.cgColor

        // Filter bar
        filterBar?.wantsLayer = true
        filterBar?.layer?.backgroundColor = theme.pageAround.cgColor

        // Labels
        countLabel?.textColor = theme.textColor.withAlphaComponent(0.7)
        filterLabel?.textColor = theme.textColor.withAlphaComponent(0.7)

        // Table view
        tableView?.backgroundColor = theme.pageBackground
        tableView?.reloadData()

        stateFilterPopup?.qpApplyDropdownBorder(theme: theme)
        intentFilterPopup?.qpApplyDropdownBorder(theme: theme)
        stateFilterPopup?.contentTintColor = theme.textColor
        intentFilterPopup?.contentTintColor = theme.textColor

        // Update button content colors (text color for rounded buttons)
        if let add = addButton {
            add.contentTintColor = theme.textColor
        }
        if let delete = deleteButton {
            delete.contentTintColor = theme.textColor
        }
    }
}
