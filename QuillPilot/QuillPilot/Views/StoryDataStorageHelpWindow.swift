import Cocoa

final class StoryDataStorageHelpWindowController: NSWindowController, NSWindowDelegate {
    private var logoView: LogoView?
    private var titleLabel: NSTextField?
    private var bodyLabel: NSTextField?
    private var revealButton: NSButton?
    private var helpButton: NSButton?

    private var clickOutsideMonitor: Any?

    private let onRevealStoryNotesFolder: (() -> Void)
    private let onOpenHelp: (() -> Void)

    private var themeObserver: NSObjectProtocol?

    init(onRevealStoryNotesFolder: @escaping (() -> Void), onOpenHelp: @escaping (() -> Void)) {
        self.onRevealStoryNotesFolder = onRevealStoryNotesFolder
        self.onOpenHelp = onOpenHelp

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 310),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Story Data Storage"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self

        setupUI()
        applyTheme()

        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
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

    func present(relativeTo hostWindow: NSWindow?) {
        guard let window else { return }
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        window.hidesOnDeactivate = true
        installClickOutsideMonitor()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let window else { return }

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true

        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 12

        let logo = LogoView(size: 52)
        logo.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Story Data Storage")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let body = NSTextField(wrappingLabelWithString: "")
        body.font = NSFont.systemFont(ofSize: 12)
        body.translatesAutoresizingMaskIntoConstraints = false
        body.maximumNumberOfLines = 0

        // Give the text a comfortable read width and consistent wrapping.
        body.preferredMaxLayoutWidth = 520

        let reveal = NSButton(title: "Reveal Story Notes Folder", target: self, action: #selector(revealTapped))
        reveal.bezelStyle = .rounded

        let help = NSButton(title: "Open Help", target: self, action: #selector(helpTapped))
        help.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [help, reveal])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = NSStackView(views: [logo, title])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 12
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let vStack = NSStackView(views: [headerStack, body, buttonStack])
        vStack.orientation = .vertical
        vStack.spacing = 16
        vStack.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        vStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(vStack)
        contentView.addSubview(card)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            vStack.topAnchor.constraint(equalTo: card.topAnchor),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            logo.widthAnchor.constraint(equalToConstant: 52),
            logo.heightAnchor.constraint(equalToConstant: 52),

            buttonStack.trailingAnchor.constraint(equalTo: vStack.trailingAnchor)
        ])

        window.contentView = contentView

        self.logoView = logo
        self.titleLabel = title
        self.bodyLabel = body
        self.revealButton = reveal
        self.helpButton = help
    }

    private func applyTheme() {
        guard let window, let contentView = window.contentView else { return }
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode

        // Keep native control rendering aligned with dark/light modes.
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        window.backgroundColor = theme.pageAround

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = theme.pageAround.cgColor

        // Card styling
        if let card = contentView.subviews.first {
            card.wantsLayer = true
            card.layer?.backgroundColor = theme.pageBackground.cgColor
            if theme == .day {
                card.layer?.borderWidth = 1
                card.layer?.borderColor = theme.pageBorder.cgColor
            } else {
                card.layer?.borderWidth = 0
            }
        }

        titleLabel?.textColor = theme.textColor

        let bodyText = """
Quill Pilot stores certain per-document data as JSON so it can preserve non-manuscript notes between sessions without modifying your .docx/.rtf text.

• Story Notes (Theme, Locations, Outline, Directions) are stored in Application Support.
• Character Library entries are stored in Application Support (StoryNotes/Characters).

If you delete these files, Quill Pilot will treat that data as empty for the affected document.
"""

        if let bodyLabel {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            paragraph.paragraphSpacing = 6
            paragraph.alignment = .left

            bodyLabel.attributedStringValue = NSAttributedString(
                string: bodyText,
                attributes: [
                    .foregroundColor: theme.textColor.withAlphaComponent(0.9),
                    .font: bodyLabel.font ?? NSFont.systemFont(ofSize: 12),
                    .paragraphStyle: paragraph
                ]
            )
        }

        func styleButton(_ button: NSButton?, isPrimary: Bool) {
            guard let button else { return }

            // Avoid the system accent (blue) by drawing our own background + border.
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.cornerRadius = 8
            button.layer?.borderWidth = 1
            button.layer?.borderColor = theme.pageBorder.cgColor
            button.layer?.backgroundColor = (isPrimary ? theme.pageBorder : theme.pageBackground).cgColor

            let font = button.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let titleColor: NSColor = isPrimary ? .white : theme.textColor
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: titleColor,
                    .font: font
                ]
            )
        }

        styleButton(helpButton, isPrimary: false)
        styleButton(revealButton, isPrimary: false)
    }

    @objc private func revealTapped() {
        onRevealStoryNotesFolder()
    }

    @objc private func helpTapped() {
        onOpenHelp()
    }

    private func closeWindow() {
        guard let window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }

    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let window = self.window, window.isVisible else { return event }
            if event.window !== window {
                self.closeWindow()
            }
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        removeClickOutsideMonitor()
    }
}
