//
//  AnalysisViewController.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa
import SwiftUI

// Flipped view so (0,0) is top-left; keeps content pinned at the top of the scroll area
private final class AnalysisFlippedView: NSView {
    override var isFlipped: Bool { true }
}

// Window delegate that closes the window when it loses key status (user clicks elsewhere)
private class AutoCloseWindowDelegate: NSObject, NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.close()
        }
    }
}

// Sidebar buttons should respond on first click even when the window is inactive.
private final class SidebarButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

class AnalysisViewController: NSViewController, NSWindowDelegate {

    var onNotesTapped: (() -> Void)?

    private var menuSidebar: NSView!
    private var menuSeparator: NSView!
    private var menuSidebarWidthConstraint: NSLayoutConstraint?
    private var menuSeparatorWidthConstraint: NSLayoutConstraint?
    private var menuButtons: [NSButton] = []
    private var scrollContainer: NSView!
    private var scrollView: NSScrollView!
    private var documentView: NSView!
    private var contentStack: NSStackView!
    private var headerLabel: NSTextField!
    private var updateButton: NSButton!
    private var infoLabel: NSTextField!
    private var resultsStack: NSStackView!
    private var currentTheme: AppTheme = ThemeManager.shared.currentTheme
    private var currentCategory: AnalysisCategory = .basic
    private var isOutlineVisible = false
    private var lastSidebarHeight: CGFloat = 0

    var isMenuSidebarHidden: Bool {
        menuSidebar?.isHidden ?? true
    }

    // Analysis popout windows
    private var outlinePopoutWindow: NSWindow?
    private var analysisPopoutWindow: NSWindow?
    private var plotPopoutWindow: NSWindow?
    private var decisionBeliefPopoutWindow: NSWindow?
    private weak var plotPopoutScrollView: NSScrollView?
    private weak var plotPopoutContentView: NSView?
    private weak var plotPopoutStack: NSStackView?
    private weak var analysisPopoutStack: NSStackView?
    private weak var analysisPopoutContainer: NSView?

    // Monotonic counter incremented whenever new analysis results are stored.
    // Used to ensure popouts wait for *fresh* analysis results rather than opening
    // immediately with stale data.
    private var analysisResultsVersion: Int = 0

    // Analysis loading state
    private(set) var isAnalyzing: Bool = false {
        didSet {
            updateAnalysisLoadingUI()
        }
    }
    private var analysisLoadingIndicator: NSProgressIndicator?
    private var analysisStatusLabel: NSTextField?

    // Passive voice disclosure tracking
    private var passiveDisclosureViews: [NSButton: NSScrollView] = [:]

    // Coalesce popout resize work to avoid layout recursion warnings.
    private var pendingPopoutResizeWorkItem: DispatchWorkItem?

    // NSWindowDelegate: keep plot popout scroll sizing in sync
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == plotPopoutWindow,
              let scrollView = plotPopoutScrollView,
              let contentView = plotPopoutContentView,
              let stack = plotPopoutStack else { return }
        schedulePopoutResize(scrollView: scrollView, contentView: contentView, stack: stack)
    }

    /// Force the popout scroll view to have a content height larger than the viewport so the mouse wheel scrolls.
    private func resizePopoutContent(scrollView: NSScrollView, contentView: NSView, stack: NSStackView) {
        // Avoid forcing layout here; this can be called during an active layout pass.
        let viewportHeight = scrollView.contentSize.height
        let viewportWidth = scrollView.contentSize.width

        let stackHeight = max(stack.fittingSize.height, stack.bounds.height)
        let targetHeight = max(stackHeight + 24, viewportHeight + 1)
        let targetWidth = max(1, viewportWidth)

        if contentView.frame.size.width != targetWidth || contentView.frame.size.height != targetHeight {
            contentView.setFrameSize(NSSize(width: targetWidth, height: targetHeight))
        }
    }

    private func schedulePopoutResize(scrollView: NSScrollView, contentView: NSView, stack: NSStackView) {
        pendingPopoutResizeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self, weak scrollView, weak contentView, weak stack] in
            guard let self,
                  let scrollView,
                  let contentView,
                  let stack else { return }
            self.resizePopoutContent(scrollView: scrollView, contentView: contentView, stack: stack)
        }
        pendingPopoutResizeWorkItem = item
        DispatchQueue.main.async(execute: item)
    }

    @objc private func scrollPlotPopoutToChart() {
        guard let scrollView = plotPopoutScrollView,
              let contentView = plotPopoutContentView else { return }
        let maxY = contentView.bounds.height - scrollView.contentSize.height
        let targetPoint = NSPoint(x: 0, y: max(0, maxY))
        scrollView.contentView.scroll(to: targetPoint)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // Character analysis popouts
    private var emotionalJourneyPopoutWindow: NSWindow?
    private var interactionsPopoutWindow: NSWindow?
    private var presencePopoutWindow: NSWindow?
    private var emotionalTrajectoryPopoutWindow: NSWindow?
    private var beliefShiftMatrixPopoutWindow: NSWindow?
    private var decisionConsequenceChainPopoutWindow: NSWindow?
    private var relationshipMapPopoutWindow: NSWindow?
    private var alignmentChartPopoutWindow: NSWindow?
    private var languageDriftPopoutWindow: NSWindow?
    private var thematicResonanceMapPopoutWindow: NSWindow?
    private var failurePatternChartPopoutWindow: NSWindow?

    // Window delegate for auto-closing popouts
    private let autoCloseDelegate = AutoCloseWindowDelegate()

    // Emotional Trajectory: preserve metric selection across refreshes
    private var selectedEmotionalTrajectoryMetricIndex: Int = 0
    private var selectedEmotionalTrajectoryXAxisModeIndex: Int = 0 // 0 = Scenes, 1 = Acts
    private var lastEmotionalTrajectoryResults: AnalysisResults?

    // High-contrast qualitative palette reused across popouts
    private let qualitativePalette: [NSColor] = [
        NSColor(calibratedRed: 0.12, green: 0.47, blue: 0.71, alpha: 1.0),
        NSColor(calibratedRed: 0.84, green: 0.15, blue: 0.16, alpha: 1.0),
        NSColor(calibratedRed: 0.17, green: 0.63, blue: 0.17, alpha: 1.0),
        NSColor(calibratedRed: 1.00, green: 0.50, blue: 0.05, alpha: 1.0),
        NSColor(calibratedRed: 0.55, green: 0.34, blue: 0.76, alpha: 1.0),
        NSColor(calibratedRed: 0.60, green: 0.31, blue: 0.21, alpha: 1.0),
        NSColor(calibratedRed: 0.90, green: 0.47, blue: 0.76, alpha: 1.0),
        NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.50, alpha: 1.0),
        NSColor(calibratedRed: 0.74, green: 0.74, blue: 0.13, alpha: 1.0),
        NSColor(calibratedRed: 0.09, green: 0.75, blue: 0.81, alpha: 1.0),
        NSColor(calibratedRed: 0.11, green: 0.62, blue: 0.52, alpha: 1.0),
        NSColor(calibratedRed: 0.90, green: 0.67, blue: 0.00, alpha: 1.0),
        NSColor(calibratedRed: 0.30, green: 0.43, blue: 0.96, alpha: 1.0),
        NSColor(calibratedRed: 0.84, green: 0.12, blue: 0.55, alpha: 1.0),
        NSColor(calibratedRed: 0.40, green: 0.76, blue: 0.65, alpha: 1.0)
    ]

    // Character Library Window (Navigator panel only)
    private var characterLibraryWindow: CharacterLibraryWindowController?
    private var themeWindow: ThemeWindowController?
    private var sceneListWindow: SceneListWindowController?
    private var storyOutlineWindow: StoryOutlineWindowController?
    private var locationsWindow: LocationsWindowController?
    private var storyDirectionsWindow: StoryDirectionsWindowController?

    // Track current document for scene persistence
    private var currentDocumentURL: URL?

    // Visualization views (macOS 13+)
    @available(macOS 13.0, *)
    private lazy var plotVisualizationView: PlotVisualizationView = {
        let view = PlotVisualizationView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()

    @available(macOS 13.0, *)
    private lazy var characterArcVisualizationView: CharacterArcVisualizationView = {
        let view = CharacterArcVisualizationView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()

    var outlineViewController: OutlineViewController?
    var isOutlinePanel: Bool = false
    var analyzeCallback: (() -> Void)?
    var getOutlineEntriesCallback: (() -> [EditorViewController.OutlineEntry])?

    /// Optional hook so the analysis UI can label the current document/poem.
    /// Returns (title, author) if available.
    var getManuscriptInfoCallback: (() -> (title: String, author: String)?)? = nil

    /// Called when a new document is loaded or created
    func documentDidChange(url: URL?) {
        // Store current document URL for when scene window is created
        currentDocumentURL = url
        // Load scenes for this document if window exists
        sceneListWindow?.loadScenes(for: url)

        // Load story notes (theme/locations/outline/directions) for this document.
        StoryNotesStore.shared.load(for: url)

        // If navigator windows are already open, refresh them to the new document.
        themeWindow?.setDocumentURL(url)
        storyOutlineWindow?.setDocumentURL(url)
        locationsWindow?.setDocumentURL(url)
        storyDirectionsWindow?.setDocumentURL(url)

        // Clear analysis results and all UI to prevent stale data across documents
        latestAnalysisResults = nil
        clearAllAnalysisUI()

        // Clear plot visualization view to remove stale data
        if #available(macOS 13.0, *) {
            plotVisualizationView.configure(with: nil)
            plotVisualizationView.removeFromSuperview()
            characterArcVisualizationView.removeFromSuperview()
        }
    }

    /// Called when the document URL becomes known/changes (e.g. first Save / Save As).
    /// Unlike `documentDidChange`, this must NOT clear analysis UI.
    func documentURLDidUpdate(url: URL?) {
        currentDocumentURL = url
        sceneListWindow?.loadScenes(for: url)

        StoryNotesStore.shared.setDocumentURL(url)

        themeWindow?.updateDocumentURL(url)
        storyOutlineWindow?.updateDocumentURL(url)
        locationsWindow?.updateDocumentURL(url)
        storyDirectionsWindow?.updateDocumentURL(url)
    }

    private func scrollToTop() {
        guard let scrollView = scrollView else { return }
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // Navigator panel categories (left side - has Theme, Story Outline, and Characters)
    enum NavigatorCategory: String, CaseIterable {
        case basic = "Outline"
        case theme = "Theme"
        case storyOutline = "Story Outline"
        case locations = "Locations"
        case storyDirections = "Story Directions"
        case characters = "Characters"
        case scenes = "Scenes"

        var icon: String {
            switch self {
            case .basic: return "📝"
            case .theme: return "🎭"
            case .scenes: return "🎬"
            case .storyOutline: return "📚"
            case .locations: return "📍"
            case .storyDirections: return "🔀"
            case .characters: return "👥"
            }
        }

        var symbolName: String {
            switch self {
            case .basic: return "list.bullet.rectangle"
            case .theme: return "paintpalette"
            case .scenes: return "film"
            case .storyOutline: return "book.closed"
            case .locations: return "mappin.and.ellipse"
            case .storyDirections: return "shuffle"
            case .characters: return "person.2"
            }
        }
    }

    // Analysis panel categories (right side)
    enum AnalysisCategory: String, CaseIterable {
        case basic = "Analysis"
        case plot = "Plot Structure"
        case characters = "Characters"

        var icon: String {
            switch self {
            case .basic: return "📊"
            case .plot: return "📖"
            case .characters: return "👥"
            }
        }

        var symbolName: String {
            switch self {
            case .basic: return "chart.bar.xaxis"
            case .plot: return "chart.xyaxis.line"
            case .characters: return "person.2"
            }
        }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSidebarMenu()
        setupScrollView()
        setupContent()
        applyTheme(currentTheme)

        // Apply template-specific UI (Poetry vs Screenplay/Fiction)
        applyTemplateAdaptiveUI()

        // Respond to template switches (e.g., Poetry) to adapt the UI
        NotificationCenter.default.addObserver(forName: .styleTemplateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyTemplateAdaptiveUI()
        }

        // Hide inline analysis for the analysis panel; use popout only
        if !isOutlinePanel {
            scrollContainer.isHidden = true
        }

        // Don't auto-switch to category on load - let it stay empty until user clicks
        // Only show content when user explicitly clicks a button

        // Observe main window becoming key to close popups
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowBecameKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        // Listen for theme changes
        NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] notification in
            if let theme = notification.object as? AppTheme {
                self?.applyTheme(theme)
            }
        }

        // Clear analysis if Character Library is empty on startup
        if CharacterLibrary.shared.characters.isEmpty {
            latestAnalysisResults = nil
            clearAllAnalysisUI()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let currentHeight = menuSidebar?.bounds.height ?? 0
        guard currentHeight > 0 else { return }

        if abs(currentHeight - lastSidebarHeight) > 1 {
            lastSidebarHeight = currentHeight
            rebuildSidebarButtons()
        }
    }

    private func setupSidebarMenu() {
        menuSidebar = NSView()
        menuSidebar.translatesAutoresizingMaskIntoConstraints = false
        menuSidebar.wantsLayer = true
        view.addSubview(menuSidebar)

        menuSeparator = NSView()
        menuSeparator.translatesAutoresizingMaskIntoConstraints = false
        menuSeparator.wantsLayer = true
        view.addSubview(menuSeparator)

        if isOutlinePanel {
            menuSidebarWidthConstraint = menuSidebar.widthAnchor.constraint(equalToConstant: 56)
            menuSeparatorWidthConstraint = menuSeparator.widthAnchor.constraint(equalToConstant: 1)
            NSLayoutConstraint.activate([
                menuSidebar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                menuSidebar.topAnchor.constraint(equalTo: view.topAnchor),
                menuSidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                menuSidebarWidthConstraint!,

                menuSeparator.trailingAnchor.constraint(equalTo: menuSidebar.leadingAnchor),
                menuSeparator.topAnchor.constraint(equalTo: view.topAnchor),
                menuSeparator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                menuSeparatorWidthConstraint!
            ])
        } else {
            menuSidebarWidthConstraint = menuSidebar.widthAnchor.constraint(equalToConstant: 56)
            menuSeparatorWidthConstraint = menuSeparator.widthAnchor.constraint(equalToConstant: 1)
            NSLayoutConstraint.activate([
                menuSidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                menuSidebar.topAnchor.constraint(equalTo: view.topAnchor),
                menuSidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                menuSidebarWidthConstraint!,

                menuSeparator.leadingAnchor.constraint(equalTo: menuSidebar.trailingAnchor),
                menuSeparator.topAnchor.constraint(equalTo: view.topAnchor),
                menuSeparator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                menuSeparatorWidthConstraint!
            ])
        }

        rebuildSidebarButtons()
    }

    private func rebuildSidebarButtons() {
        // Remove existing buttons
        for button in menuButtons {
            button.removeFromSuperview()
        }
        menuButtons.removeAll()

        let isPoetry = StyleCatalog.shared.isPoetryTemplate
        let topPadding: CGFloat = 12
        let bottomPadding: CGFloat = 12
        let maxButtonSize: CGFloat = 44
        let minButtonSize: CGFloat = 32
        let maxSpacing: CGFloat = 8
        let minSpacing: CGFloat = 4

        let availableHeight = max(menuSidebar.bounds.height, view.bounds.height)

        var buttonCount = 0
        if isOutlinePanel {
            let categories: [NavigatorCategory] = isPoetry ? [] : NavigatorCategory.allCases
            buttonCount += categories.count
            if !isPoetry { buttonCount += 2 } // Notes + Submission Tracker
        } else {
            let categories: [AnalysisCategory] = isPoetry ? [.basic] : [.basic, .plot]
            buttonCount += categories.count
            if isPoetry {
                // Poetry tools buttons
                buttonCount += PoetryTool.allCases.count
            } else {
                let tools = CharacterTool.allCases.filter { $0.isAvailable(forScreenplay: StyleCatalog.shared.isScreenplayTemplate) }
                buttonCount += tools.count
            }
            buttonCount += 1 // Help button
        }

        let defaultTotal = CGFloat(buttonCount) * maxButtonSize + CGFloat(max(0, buttonCount - 1)) * maxSpacing
        let availableForButtons = max(0, availableHeight - topPadding - bottomPadding)
        let scale = defaultTotal > 0 ? min(1, availableForButtons / defaultTotal) : 1
        let buttonSize = max(minButtonSize, floor(maxButtonSize * scale))
        let spacing = max(minSpacing, floor(maxSpacing * scale))
        let iconPointSize = max(13, min(18, buttonSize * 0.36))
        let glyphPointSize = max(14, min(20, buttonSize * 0.42))
        let labelPointSize = max(11, min(18, buttonSize * 0.4))

        var yPosition: CGFloat = topPadding

        if isOutlinePanel {
            // Poetry: hide the navigator chrome entirely (more writing/outline space)
            let categories: [NavigatorCategory] = isPoetry ? [] : NavigatorCategory.allCases
            for category in categories {
                let button = SidebarButton(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))

                // Prose templates: use the square-box outline toggle icon for the first (Outline) button.
                // This replaces the previous 📝 icon so there is only one outline toggle.
                if category == .basic {
                    if #available(macOS 11.0, *) {
                        let base = NSImage(systemSymbolName: "square", accessibilityDescription: "Toggle Outline") ?? NSImage()
                        let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
                        button.image = base.withSymbolConfiguration(config) ?? base
                        button.imagePosition = .imageOnly
                        button.title = ""
                    } else {
                        button.title = "□"
                        button.font = .systemFont(ofSize: glyphPointSize)
                    }
                    let name = StyleCatalog.shared.isPoetryTemplate ? "Stanza Outline" : (StyleCatalog.shared.isScreenplayTemplate ? "Scene Outline" : "Document Outline")
                    button.toolTip = isOutlineVisible ? "Hide \(name)" : "Show \(name)"
                } else {
                    if #available(macOS 11.0, *) {
                        let base = NSImage(systemSymbolName: category.symbolName, accessibilityDescription: category.rawValue)
                        let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
                        if let base, let image = base.withSymbolConfiguration(config) {
                            button.image = image
                            button.imagePosition = .imageOnly
                            button.title = ""
                            button.image?.isTemplate = true
                        } else {
                            button.title = category.icon
                            button.font = .systemFont(ofSize: glyphPointSize)
                        }
                    } else {
                        button.title = category.icon
                        button.font = .systemFont(ofSize: glyphPointSize)
                    }
                    button.toolTip = category.rawValue
                }

                button.isBordered = false
                button.bezelStyle = .rounded
                button.target = self
                button.action = #selector(navigatorButtonTapped(_:))
                button.tag = NavigatorCategory.allCases.firstIndex(of: category) ?? 0
                button.translatesAutoresizingMaskIntoConstraints = false
                button.sendAction(on: [.leftMouseDown])

                menuSidebar.addSubview(button)
                menuButtons.append(button)

                NSLayoutConstraint.activate([
                    button.topAnchor.constraint(equalTo: menuSidebar.topAnchor, constant: yPosition),
                    button.centerXAnchor.constraint(equalTo: menuSidebar.centerXAnchor),
                    button.widthAnchor.constraint(equalToConstant: buttonSize),
                    button.heightAnchor.constraint(equalToConstant: buttonSize)
                ])

                yPosition += buttonSize + spacing
            }

            // Notes button: sits under the Characters icon in the left sidebar.
            if !isPoetry {
                let notesButton = SidebarButton(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
                if #available(macOS 11.0, *) {
                    let base = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notes")
                    let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
                    if let base, let image = base.withSymbolConfiguration(config) {
                        notesButton.image = image
                        notesButton.imagePosition = .imageOnly
                        notesButton.title = ""
                        notesButton.image?.isTemplate = true
                    } else {
                        notesButton.title = "Notes"
                        notesButton.font = .systemFont(ofSize: labelPointSize)
                    }
                } else {
                    notesButton.title = "Notes"
                    notesButton.font = .systemFont(ofSize: labelPointSize)
                }
                notesButton.isBordered = false
                notesButton.bezelStyle = .rounded
                notesButton.target = self
                notesButton.action = #selector(notesSidebarButtonTapped(_:))
                notesButton.translatesAutoresizingMaskIntoConstraints = false
                notesButton.toolTip = "Notes"
                notesButton.sendAction(on: [.leftMouseDown])

                menuSidebar.addSubview(notesButton)
                menuButtons.append(notesButton)

                NSLayoutConstraint.activate([
                    notesButton.topAnchor.constraint(equalTo: menuSidebar.topAnchor, constant: yPosition),
                    notesButton.centerXAnchor.constraint(equalTo: menuSidebar.centerXAnchor),
                    notesButton.widthAnchor.constraint(equalToConstant: buttonSize),
                    notesButton.heightAnchor.constraint(equalToConstant: buttonSize)
                ])

                yPosition += buttonSize + spacing

                // Submission Tracker button: sits directly under Notes.
                let submissionButton = SidebarButton(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
                if #available(macOS 11.0, *) {
                    let base = NSImage(systemSymbolName: "envelope", accessibilityDescription: "Submission Tracker")
                    let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
                    if let base, let image = base.withSymbolConfiguration(config) {
                        submissionButton.image = image
                        submissionButton.imagePosition = .imageOnly
                        submissionButton.title = ""
                        submissionButton.image?.isTemplate = true
                    } else {
                        submissionButton.title = "Sub"
                        submissionButton.font = .systemFont(ofSize: labelPointSize)
                    }
                } else {
                    submissionButton.title = "Sub"
                    submissionButton.font = .systemFont(ofSize: labelPointSize)
                }
                submissionButton.isBordered = false
                submissionButton.bezelStyle = .rounded
                submissionButton.target = self
                submissionButton.action = #selector(submissionTrackerSidebarButtonTapped(_:))
                submissionButton.translatesAutoresizingMaskIntoConstraints = false
                submissionButton.toolTip = "Submission Tracker"
                submissionButton.sendAction(on: [.leftMouseDown])

                menuSidebar.addSubview(submissionButton)
                menuButtons.append(submissionButton)

                NSLayoutConstraint.activate([
                    submissionButton.topAnchor.constraint(equalTo: menuSidebar.topAnchor, constant: yPosition),
                    submissionButton.centerXAnchor.constraint(equalTo: menuSidebar.centerXAnchor),
                    submissionButton.widthAnchor.constraint(equalToConstant: buttonSize),
                    submissionButton.heightAnchor.constraint(equalToConstant: buttonSize)
                ])

                yPosition += buttonSize + spacing
            }
        } else {
            // Poetry: only show the Poetry-focused Analysis popout (hide Plot/Characters)
            let categories: [AnalysisCategory] = isPoetry ? [.basic] : [.basic, .plot]
            for category in categories {
                let button = SidebarButton(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
                if #available(macOS 11.0, *) {
                    let base = NSImage(systemSymbolName: category.symbolName, accessibilityDescription: category.rawValue)
                    let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
                    if let base, let image = base.withSymbolConfiguration(config) {
                        button.image = image
                        button.imagePosition = .imageOnly
                        button.title = ""
                        button.image?.isTemplate = true
                    } else {
                        button.title = category.icon
                        button.font = .systemFont(ofSize: glyphPointSize)
                    }
                } else {
                    button.title = category.icon
                    button.font = .systemFont(ofSize: glyphPointSize)
                }
                button.isBordered = false
                button.bezelStyle = .rounded
                button.target = self
                button.action = #selector(categoryButtonTapped(_:))
                button.tag = AnalysisCategory.allCases.firstIndex(of: category) ?? 0
                button.translatesAutoresizingMaskIntoConstraints = false
                button.toolTip = (isPoetry && category == .basic) ? "Poetry Analysis" : category.rawValue
                button.sendAction(on: [.leftMouseDown])

                menuSidebar.addSubview(button)
                menuButtons.append(button)

                NSLayoutConstraint.activate([
                    button.topAnchor.constraint(equalTo: menuSidebar.topAnchor, constant: yPosition),
                    button.centerXAnchor.constraint(equalTo: menuSidebar.centerXAnchor),
                    button.widthAnchor.constraint(equalToConstant: buttonSize),
                    button.heightAnchor.constraint(equalToConstant: buttonSize)
                ])

                yPosition += buttonSize + spacing
            }

            // Poetry tools: add buttons for poetry-specific tools when poetry template is active
            if isPoetry {
                for tool in PoetryTool.allCases {
                    let button = SidebarButton(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
                    if #available(macOS 11.0, *) {
                        let base = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: tool.title)
                        let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
                        if let base, let image = base.withSymbolConfiguration(config) {
                            button.image = image
                            button.imagePosition = .imageOnly
                            button.title = ""
                            button.image?.isTemplate = true
                        } else {
                            button.title = tool.fallbackGlyph
                            button.font = .systemFont(ofSize: glyphPointSize)
                        }
                    } else {
                        button.title = tool.fallbackGlyph
                        button.font = .systemFont(ofSize: glyphPointSize)
                    }

                    button.isBordered = false
                    button.bezelStyle = .rounded
                    button.target = self
                    button.action = #selector(poetryToolButtonTapped(_:))
                    button.tag = tool.rawValue
                    button.translatesAutoresizingMaskIntoConstraints = false
                    button.toolTip = tool.title
                    button.sendAction(on: [.leftMouseDown])

                    menuSidebar.addSubview(button)
                    menuButtons.append(button)

                    NSLayoutConstraint.activate([
                        button.topAnchor.constraint(equalTo: menuSidebar.topAnchor, constant: yPosition),
                        button.centerXAnchor.constraint(equalTo: menuSidebar.centerXAnchor),
                        button.widthAnchor.constraint(equalToConstant: buttonSize),
                        button.heightAnchor.constraint(equalToConstant: buttonSize)
                    ])

                    yPosition += buttonSize + spacing
                }
            }

            // Character analysis tools: break out the old Characters menu into individual buttons.
            if !isPoetry {
                for tool in CharacterTool.allCases {
                    if !tool.isAvailable(forScreenplay: StyleCatalog.shared.isScreenplayTemplate) {
                        continue
                    }

                    let button = SidebarButton(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
                    if #available(macOS 11.0, *) {
                        let base = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: tool.title)
                        let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
                        if let base, let image = base.withSymbolConfiguration(config) {
                            button.image = image
                            button.imagePosition = .imageOnly
                            button.title = ""
                            button.image?.isTemplate = true
                        } else {
                            button.title = tool.fallbackGlyph
                            button.font = .systemFont(ofSize: glyphPointSize)
                        }
                    } else {
                        button.title = tool.fallbackGlyph
                        button.font = .systemFont(ofSize: glyphPointSize)
                    }

                    button.isBordered = false
                    button.bezelStyle = .rounded
                    button.target = self
                    button.action = #selector(characterToolButtonTapped(_:))
                    button.tag = tool.rawValue
                    button.translatesAutoresizingMaskIntoConstraints = false
                    button.toolTip = tool.title
                    button.sendAction(on: [.leftMouseDown])

                    menuSidebar.addSubview(button)
                    menuButtons.append(button)

                    NSLayoutConstraint.activate([
                        button.topAnchor.constraint(equalTo: menuSidebar.topAnchor, constant: yPosition),
                        button.centerXAnchor.constraint(equalTo: menuSidebar.centerXAnchor),
                        button.widthAnchor.constraint(equalToConstant: buttonSize),
                        button.heightAnchor.constraint(equalToConstant: buttonSize)
                    ])

                    yPosition += buttonSize + spacing
                }
            }

            // Help button: sits directly after the analysis buttons.
            let helpButton = SidebarButton(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
            if #available(macOS 11.0, *) {
                let base = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Help")
                let config = NSImage.SymbolConfiguration(pointSize: iconPointSize, weight: .regular)
                if let base, let image = base.withSymbolConfiguration(config) {
                    helpButton.image = image
                    helpButton.imagePosition = .imageOnly
                    helpButton.title = ""
                    helpButton.image?.isTemplate = true
                } else {
                    helpButton.title = "?"
                    helpButton.font = .systemFont(ofSize: glyphPointSize)
                }
            } else {
                helpButton.title = "?"
                helpButton.font = .systemFont(ofSize: glyphPointSize)
            }
            helpButton.isBordered = false
            helpButton.bezelStyle = .rounded
            helpButton.target = self
            helpButton.action = #selector(helpButtonTapped(_:))
            helpButton.translatesAutoresizingMaskIntoConstraints = false
            helpButton.toolTip = "Help (opens Quill Pilot Help)"
            helpButton.sendAction(on: [.leftMouseDown])

            menuSidebar.addSubview(helpButton)
            menuButtons.append(helpButton)

            NSLayoutConstraint.activate([
                helpButton.topAnchor.constraint(equalTo: menuSidebar.topAnchor, constant: yPosition),
                helpButton.centerXAnchor.constraint(equalTo: menuSidebar.centerXAnchor),
                helpButton.widthAnchor.constraint(equalToConstant: buttonSize),
                helpButton.heightAnchor.constraint(equalToConstant: buttonSize)
            ])

        }


        updateSelectedButton()

        // Apply current theme immediately so Day-mode borders are correct on first launch.
        applyThemeToMenuButtons(ThemeManager.shared.currentTheme)
    }

    private func applyThemeToMenuButtons(_ theme: AppTheme) {
        for button in menuButtons {
            button.wantsLayer = true
            button.layer?.masksToBounds = true
            button.layer?.backgroundColor = NSColor.clear.cgColor
            button.image?.isTemplate = true

            if #available(macOS 10.14, *) {
                button.contentTintColor = theme.textColor.withAlphaComponent(0.9)
            }

            // Day theme: orange border for all sidebar icon buttons (vertical stack).
            if theme == .day {
                button.layer?.borderWidth = 1
                button.layer?.borderColor = theme.pageBorder.cgColor
                button.layer?.cornerRadius = 10
            } else {
                button.layer?.borderWidth = 0
            }
        }
    }

    @objc private func submissionTrackerSidebarButtonTapped(_ sender: Any?) {
        (NSApp.delegate as? AppDelegate)?.showSubmissionTracker(sender)
    }

    private func applyTemplateAdaptiveUI() {
        let isPoetry = StyleCatalog.shared.isPoetryTemplate

        // Outline panel: remove navigator chrome in Poetry for a cleaner workspace.
        if isOutlinePanel {
            if isPoetry {
                menuSidebar.isHidden = true
                menuSeparator.isHidden = true
                menuSidebarWidthConstraint?.constant = 0
                menuSeparatorWidthConstraint?.constant = 0
                showOutlineInlineIfNeeded()
            } else {
                menuSidebar.isHidden = false
                menuSeparator.isHidden = false
                menuSidebarWidthConstraint?.constant = 56
                menuSeparatorWidthConstraint?.constant = 1
            }
        }

        // Rebuild buttons if template switch changes which ones are shown
        rebuildSidebarButtons()

        // Keep popout title aligned with template
        if let window = analysisPopoutWindow {
            window.title = isPoetry ? "🪶 Poetry Analysis" : "📊 Analysis"
        }

        // If analysis popout is open, re-render its content for the new template
        if analysisPopoutWindow != nil {
            refreshAnalysisPopoutContent()
        }
    }

    private func showOutlineInlineIfNeeded() {
        guard isOutlinePanel else { return }
        guard !isOutlineVisible else { return }
        scrollContainer.isHidden = true
        if let outlineVC = outlineViewController {
            if outlineVC.view.superview == nil {
                view.addSubview(outlineVC.view)
                outlineVC.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    outlineVC.view.topAnchor.constraint(equalTo: view.topAnchor),
                    outlineVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    outlineVC.view.trailingAnchor.constraint(equalTo: menuSeparator.leadingAnchor),
                    outlineVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])
            }
            outlineVC.view.isHidden = false
        }
        isOutlineVisible = true
        currentCategory = .basic
        updateSelectedButton()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
        }
    }

    @objc private func categoryButtonTapped(_ sender: NSButton) {
        let category = AnalysisCategory.allCases[sender.tag]

        // Track the last-opened category so context-aware Help can open the right documentation tab.
        currentCategory = category

        // Poetry template: hide non-poetry analysis categories
        if StyleCatalog.shared.isPoetryTemplate && category != .basic {
            return
        }

        // For basic analysis, open popout window
        if category == .basic {
            // Kick off analysis if we have no data yet
            if latestAnalysisResults == nil {
                analyzeCallback?()
            }

            if analysisPopoutWindow == nil {
                analysisPopoutWindow = createAnalysisPopoutWindow()
            }

            if StyleCatalog.shared.isPoetryTemplate, let info = getManuscriptInfoCallback?() {
                let t = info.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !t.isEmpty {
                    analysisPopoutWindow?.title = "🪶 Poetry Analysis — \(t)"
                } else {
                    analysisPopoutWindow?.title = "🪶 Poetry Analysis"
                }
            }
            refreshAnalysisPopoutContent()
            analysisPopoutWindow?.makeKeyAndOrderFront(nil)
            return
        }

        // For plot and characters, open popout windows
        if category == .plot {
            // Open immediately; if analysis is still running, show placeholder and refresh when results arrive.
            if plotPopoutWindow == nil {
                plotPopoutWindow = createPlotPopoutWindow()
            }
            refreshPlotPopoutContent()
            plotPopoutWindow?.makeKeyAndOrderFront(nil)

            // Trigger analysis if no data exists.
            if latestAnalysisResults == nil {
                analyzeCallback?()
            }
            return
        }

        if category == .characters {
            // Show menu to choose which character analysis to view
            showCharacterAnalysisMenu(sender)
            return
        }
    }

    @objc private func helpButtonTapped(_ sender: NSButton) {
        // Map the current analysis category to the matching Help window tab.
        // Poetry template gets poetry-specific help.
        let tabIdentifier: String
        if StyleCatalog.shared.isPoetryTemplate {
            tabIdentifier = "poetry"
        } else {
            switch currentCategory {
            case .basic:
                tabIdentifier = "analysis"
            case .plot:
                tabIdentifier = "plot"
            case .characters:
                tabIdentifier = "characters"
            }
        }

        (NSApp.delegate as? AppDelegate)?.openDocumentation(tabIdentifier: tabIdentifier)
    }

    private enum CharacterTool: Int, CaseIterable {
        case emotionalTrajectory
        case decisionBeliefLoops
        case beliefShiftMatrix
        case decisionConsequenceChains
        case relationshipEvolutionMaps
        case internalExternalAlignment
        case languageDrift
        case thematicResonance
        case failurePatterns
        case interactions
        case presence

        var title: String {
            switch self {
            case .emotionalTrajectory: return "Emotional Trajectory"
            case .decisionBeliefLoops: return "Decision-Belief Loops"
            case .beliefShiftMatrix: return "Belief Shift Matrix"
            case .decisionConsequenceChains: return "Decision-Consequence Chains"
            case .relationshipEvolutionMaps: return "Relationship Evolution Maps"
            case .internalExternalAlignment: return "Internal vs External Alignment"
            case .languageDrift: return "Language Drift Analysis"
            case .thematicResonance: return "Thematic Resonance Map"
            case .failurePatterns: return "Failure Pattern Charts"
            case .interactions: return "Character Interactions"
            case .presence: return "Character Presence"
            }
        }

        var symbolName: String {
            switch self {
            case .emotionalTrajectory: return "chart.line.uptrend.xyaxis"
            case .decisionBeliefLoops: return "arrow.triangle.branch"
            case .beliefShiftMatrix: return "tablecells"
            case .decisionConsequenceChains: return "link"
            case .relationshipEvolutionMaps: return "heart.circle"
            case .internalExternalAlignment: return "circle.lefthalf.filled"
            case .languageDrift: return "text.line.first.and.arrowtriangle.forward"
            case .thematicResonance: return "target"
            case .failurePatterns: return "chart.line.downtrend.xyaxis"
            case .interactions: return "person.2.fill"
            case .presence: return "person.crop.circle.badge.clock"
            }
        }

        var fallbackGlyph: String {
            switch self {
            case .emotionalTrajectory: return "📈"
            case .decisionBeliefLoops: return "📊"
            case .beliefShiftMatrix: return "📋"
            case .decisionConsequenceChains: return "⛓️"
            case .relationshipEvolutionMaps: return "🫂"
            case .internalExternalAlignment: return "🎭"
            case .languageDrift: return "📝"
            case .thematicResonance: return "🎯"
            case .failurePatterns: return "📉"
            case .interactions: return "🤝"
            case .presence: return "📍"
            }
        }

        func isAvailable(forScreenplay: Bool) -> Bool {
            // Mirror the existing menu logic: some tools are hidden for Screenplay templates.
            if forScreenplay {
                switch self {
                case .decisionConsequenceChains, .internalExternalAlignment, .languageDrift, .thematicResonance, .failurePatterns:
                    return false
                default:
                    return true
                }
            }
            return true
        }
    }

    // MARK: - Poetry Tool Enum

    private enum PoetryTool: Int, CaseIterable {
        case poetryTools       // Combined panel
        case formTemplates     // Form templates
        case collections       // Poetry collections
        case drafts            // Draft versions
        case submissions       // Submission tracker

        var title: String {
            switch self {
            case .poetryTools: return "Poetry Tools"
            case .formTemplates: return "Form Templates"
            case .collections: return "Collections"
            case .drafts: return "Draft Versions"
            case .submissions: return "Submissions"
            }
        }

        var symbolName: String {
            switch self {
            case .poetryTools: return "waveform.path.ecg"
            case .formTemplates: return "text.book.closed"
            case .collections: return "books.vertical"
            case .drafts: return "doc.on.doc"
            case .submissions: return "envelope"
            }
        }

        var fallbackGlyph: String {
            switch self {
            case .poetryTools: return "🔬"
            case .formTemplates: return "📖"
            case .collections: return "📚"
            case .drafts: return "📄"
            case .submissions: return "✉️"
            }
        }
    }

    @objc private func characterToolButtonTapped(_ sender: NSButton) {
        guard let tool = CharacterTool(rawValue: sender.tag) else { return }
        currentCategory = .characters

        switch tool {
        case .emotionalTrajectory:
            showEmotionalTrajectory()
        case .decisionBeliefLoops:
            showDecisionBeliefLoops()
        case .beliefShiftMatrix:
            showBeliefShiftMatrix()
        case .decisionConsequenceChains:
            showDecisionConsequenceChains()
        case .relationshipEvolutionMaps:
            showRelationshipEvolutionMaps()
        case .internalExternalAlignment:
            showInternalExternalAlignment()
        case .languageDrift:
            showLanguageDriftAnalysis()
        case .thematicResonance:
            showThematicResonanceMap()
        case .failurePatterns:
            showFailurePatternCharts()
        case .interactions:
            showInteractions()
        case .presence:
            showPresence()
        }
    }

    @objc private func poetryToolButtonTapped(_ sender: NSButton) {
        guard let tool = PoetryTool(rawValue: sender.tag) else { return }

        // Dispatch to AppDelegate for opening poetry tool windows
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }

        switch tool {
        case .poetryTools:
            appDelegate.showPoetryToolsPanel(sender)
        case .formTemplates:
            appDelegate.showPoetryFormTemplates(sender)
        case .collections:
            appDelegate.showPoetryCollections(sender)
        case .drafts:
            appDelegate.showDraftVersions(sender)
        case .submissions:
            appDelegate.showSubmissionTracker(sender)
        }
    }

    @objc private func notesSidebarButtonTapped(_ sender: NSButton) {
        onNotesTapped?()
    }

    @objc private func mainWindowBecameKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.windowController is MainWindowController else {
            return
        }

        // Close all analysis popup windows when main window becomes key
        plotPopoutWindow?.close()
        plotPopoutWindow = nil

        outlinePopoutWindow?.close()
        outlinePopoutWindow = nil

        analysisPopoutWindow?.close()
        analysisPopoutWindow = nil

        emotionalJourneyPopoutWindow?.close()
        emotionalJourneyPopoutWindow = nil

        interactionsPopoutWindow?.close()
        interactionsPopoutWindow = nil

        presencePopoutWindow?.close()
        presencePopoutWindow = nil

        relationshipMapPopoutWindow?.close()
        relationshipMapPopoutWindow = nil

        // Also close Navigator popup windows
        storyOutlineWindow?.close()
        storyOutlineWindow = nil

        characterLibraryWindow?.close()
        characterLibraryWindow = nil

        locationsWindow?.close()
        locationsWindow = nil

        storyDirectionsWindow?.close()
        storyDirectionsWindow = nil

        themeWindow?.close()
        themeWindow = nil
    }

    @objc private func navigatorButtonTapped(_ sender: NSButton) {
        let category = NavigatorCategory.allCases[sender.tag]

        if category == .theme {
            // Open Theme window
            if themeWindow == nil {
                themeWindow = ThemeWindowController(documentURL: currentDocumentURL)
            } else {
                themeWindow?.setDocumentURL(currentDocumentURL)
            }
            themeWindow?.showWindow(nil)
            themeWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if category == .scenes {
            // Open Scenes window
            if sceneListWindow == nil {
                sceneListWindow = SceneListWindowController()
                // Load scenes for current document when window is first created
                sceneListWindow?.loadScenes(for: currentDocumentURL)
            }
            sceneListWindow?.showWindow(nil)
            sceneListWindow?.window?.makeKeyAndOrderFront(nil)
            if let parent = view.window, let child = sceneListWindow?.window, child.parent != parent {
                parent.addChildWindow(child, ordered: .above)
            }
            return
        }

        if category == .storyOutline {
            // Open Story Outline window
            if storyOutlineWindow == nil {
                storyOutlineWindow = StoryOutlineWindowController(documentURL: currentDocumentURL)
            } else {
                storyOutlineWindow?.setDocumentURL(currentDocumentURL)
            }
            storyOutlineWindow?.showWindow(nil)
            storyOutlineWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if category == .locations {
            // Open Locations window
            if locationsWindow == nil {
                locationsWindow = LocationsWindowController(documentURL: currentDocumentURL)
            } else {
                locationsWindow?.setDocumentURL(currentDocumentURL)
            }
            locationsWindow?.showWindow(nil)
            locationsWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if category == .storyDirections {
            // Open Story Directions window
            if storyDirectionsWindow == nil {
                storyDirectionsWindow = StoryDirectionsWindowController(documentURL: currentDocumentURL)
            } else {
                storyDirectionsWindow?.setDocumentURL(currentDocumentURL)
            }
            storyDirectionsWindow?.showWindow(nil)
            storyDirectionsWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if category == .characters {
            // Open Character Library window
            if characterLibraryWindow == nil {
                characterLibraryWindow = CharacterLibraryWindowController()
            }
            characterLibraryWindow?.showWindow(nil)
            characterLibraryWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        // For outline, toggle it
        if isOutlineVisible {
            // Already showing - hide it immediately
            outlineViewController?.view.isHidden = true
            scrollContainer.isHidden = false
            isOutlineVisible = false
            if category == .basic {
                let name = StyleCatalog.shared.isPoetryTemplate ? "Stanza Outline" : (StyleCatalog.shared.isScreenplayTemplate ? "Scene Outline" : "Document Outline")
                sender.toolTip = "Show \(name)"
            }
            updateSelectedButton()
        } else {
            // Show it immediately without expensive operations
            scrollContainer.isHidden = true
            if let outlineVC = outlineViewController {
                if outlineVC.view.superview == nil {
                    view.addSubview(outlineVC.view)
                    outlineVC.view.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        outlineVC.view.topAnchor.constraint(equalTo: view.topAnchor),
                        outlineVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        outlineVC.view.trailingAnchor.constraint(equalTo: menuSeparator.leadingAnchor),
                        outlineVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                    ])
                }
                outlineVC.view.isHidden = false
            }
            isOutlineVisible = true
            currentCategory = .basic
            if category == .basic {
                let name = StyleCatalog.shared.isPoetryTemplate ? "Stanza Outline" : (StyleCatalog.shared.isScreenplayTemplate ? "Scene Outline" : "Document Outline")
                sender.toolTip = "Hide \(name)"
            }
            updateSelectedButton()
            // Trigger refresh asynchronously to avoid blocking UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
            }
        }
    }

    @objc private func updateButtonTapped() {
        if let callback = analyzeCallback {
            callback()
        }
    }

    @objc private func togglePassiveVoiceDisclosure(_ sender: NSButton) {
        guard let scrollView = passiveDisclosureViews[sender] else { return }

        let isHidden = !scrollView.isHidden
        scrollView.isHidden = isHidden

        if isHidden {
            sender.title = "▶ Show All (\(passiveDisclosureViews.count > 0 ? "\(latestAnalysisResults?.passiveVoicePhrases.count ?? 0)" : "0"))"
        } else {
            sender.title = "▼ Hide"
        }
    }

    private func updateSelectedButton() {
        for (_, button) in menuButtons.enumerated() {
            // No highlighting for any buttons - they all open popouts or toggle inline content
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func switchToCategory(_ category: AnalysisCategory) {
        currentCategory = category

        let showOutline = isOutlinePanel && category == .basic

        if showOutline {
            // Show outline, hide analysis content (navigator panel only)
            scrollContainer.isHidden = true
            if let outlineVC = outlineViewController {
                if outlineVC.view.superview == nil {
                    view.addSubview(outlineVC.view)
                    outlineVC.view.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        outlineVC.view.topAnchor.constraint(equalTo: view.topAnchor),
                        outlineVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        outlineVC.view.trailingAnchor.constraint(equalTo: menuSeparator.leadingAnchor),
                        outlineVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                    ])
                }
                outlineVC.view.isHidden = false
            }
            // Trigger a refresh of the outline data when opened via the top button
            NotificationCenter.default.post(name: Notification.Name("QuillPilotOutlineRefresh"), object: nil)
            updateSelectedButton()
            return
        }

        // For analysis panel showing basic analysis inline
        if !isOutlinePanel && category == .basic {
            scrollContainer.isHidden = false
            outlineViewController?.view.isHidden = true

            // Clear and show basic analysis
            resultsStack.arrangedSubviews.forEach { view in
                resultsStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }

            headerLabel.stringValue = "Document Analysis"
            updateButton.isHidden = false
            infoLabel.stringValue = ""

            // Add placeholder
            let placeholder = makeLabel("Click Update to analyze your document", size: 13, bold: false)
            placeholder.textColor = .secondaryLabelColor
            resultsStack.addArrangedSubview(placeholder)

            // Make sure scroll content is visible
            scrollContainer.isHidden = false

            updateSelectedButton()
            return
        }

        // Analysis panel buttons (plot, characters) are popouts only - do nothing for inline content
        outlineViewController?.view.isHidden = true
        updateSelectedButton()
    }

    private func setupScrollView() {
        // Simple scroll view setup matching OutlineViewController structure
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Document view - simple flipped view, no constraints
        documentView = AnalysisFlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        if let clipView = scrollView.contentView as NSClipView? {
            NSLayoutConstraint.activate([
                documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
                documentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
                documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
                documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor)
            ])
        }

        view.addSubview(scrollView)

        // Position based on panel type
        if isOutlinePanel {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                scrollView.trailingAnchor.constraint(equalTo: menuSeparator.leadingAnchor, constant: -8),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
            ])
        } else {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
                scrollView.leadingAnchor.constraint(equalTo: menuSeparator.trailingAnchor, constant: 8),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
            ])
        }

        // Keep reference to scrollContainer for show/hide toggling
        scrollContainer = scrollView
    }

    private func setupContent() {
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        // Simple background, no layer manipulation
        contentStack.wantsLayer = true
        if let layer = contentStack.layer {
            layer.backgroundColor = currentTheme.toolbarBackground.cgColor
            layer.cornerRadius = 12
            layer.masksToBounds = true
        }

        // Header with update button
        let headerContainer = NSStackView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.orientation = .horizontal
        headerContainer.spacing = 12
        headerContainer.alignment = .centerY

        let headerTitle = isOutlinePanel ? "" : "Document Analysis"
        headerLabel = makeLabel(headerTitle, size: 18, bold: true)
        headerContainer.addArrangedSubview(headerLabel)

        updateButton = NSButton(title: "Update", target: self, action: #selector(updateButtonTapped))
        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .small
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        updateButton.isEnabled = true
        // Hide update button entirely for analysis popout flow
        updateButton.isHidden = true
        headerContainer.addArrangedSubview(updateButton)

        contentStack.addArrangedSubview(headerContainer)

        // Info label
        infoLabel = makeLabel("", size: 13, bold: false)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.lineBreakMode = .byWordWrapping
        infoLabel.maximumNumberOfLines = 0
        infoLabel.isHidden = !isOutlinePanel
        contentStack.addArrangedSubview(infoLabel)

        // Results container
        resultsStack = NSStackView()
        resultsStack.translatesAutoresizingMaskIntoConstraints = false
        resultsStack.orientation = .vertical
        resultsStack.alignment = .leading
        resultsStack.spacing = 10
        contentStack.addArrangedSubview(resultsStack)

        NSLayoutConstraint.activate([
            resultsStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            resultsStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
        ])

        // Initial placeholder removed - analysis will populate directly

        // Start scrolled to top for empty/initial states
        scrollToTop()

        documentView.addSubview(contentStack)

        // Simple constraints - just pin to edges with padding
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -32),
            // Ensure documentView expands with content for scrolling
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: contentStack.heightAnchor, constant: 44)
        ])
    }

    // MARK: - Toggle Menu Sidebar
    func setMenuSidebarHidden(_ hidden: Bool, animated: Bool = true) {
        guard menuSidebar != nil, menuSeparator != nil else { return }

        // If the template forces this chrome off (e.g. Poetry navigator), keep it hidden.
        if isOutlinePanel, StyleCatalog.shared.isPoetryTemplate {
            menuSidebar.isHidden = true
            menuSeparator.isHidden = true
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                menuSidebar.animator().isHidden = hidden
                menuSeparator.animator().isHidden = hidden
            }
        } else {
            menuSidebar.isHidden = hidden
            menuSeparator.isHidden = hidden
        }
    }

    func toggleMenuSidebar() {
        setMenuSidebarHidden(!isMenuSidebarHidden)
    }

    func displayResults(_ results: AnalysisResults) {
        // If Character Library is empty, don't display character-based analysis
        if CharacterLibrary.shared.characters.isEmpty && results.wordCount == 0 {
            latestAnalysisResults = nil
            clearAllAnalysisUI()
            return
        }

        // Store results for visualization
        storeAnalysisResults(results)

        // Refresh Decision-Belief Loop popout if it's open
        if decisionBeliefPopoutWindow?.isVisible == true, !results.decisionBeliefLoops.isEmpty {
            openDecisionBeliefPopout(loops: results.decisionBeliefLoops)
        }

        // For analysis panel we show results only in the popout
        if !isOutlinePanel {
            refreshAnalysisPopoutContent()
            // Keep the Plot popout in sync if it is currently open.
            refreshPlotPopoutContent()
            return
        }

        // Only display if we're on the basic category
        guard currentCategory == .basic else { return }

        // Clear previous results
        resultsStack.arrangedSubviews.forEach { view in
            resultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard results.wordCount > 0 else {
            let msg = makeLabel("No content to analyze.", size: 13, bold: false)
            msg.textColor = .secondaryLabelColor
            resultsStack.addArrangedSubview(msg)
            return
        }

        // Basic stats
        addStat("Words", "\(results.wordCount)")
        addStat("Sentences", "\(results.sentenceCount)")
        addDivider()

        // Paragraph analysis
        addHeader("📊 Paragraphs")
        addStat("Count", "\(results.paragraphCount)")
        addStat("Pages", "~\(results.pageCount)")
        addStat("Avg Length", "\(results.averageParagraphLength) words")
        addStat("Dialogue", "\(results.dialoguePercentage)%")
        if !results.longParagraphs.isEmpty {
            addWarning("⚠️ \(results.longParagraphs.count) long paragraph(s)")
        }
        addDivider()

        // Passive voice
        addHeader("🔍 Passive Voice")
        if results.passiveVoiceCount > 0 {
            addWarning("Found \(results.passiveVoiceCount) instance(s)")
            for phrase in results.passiveVoicePhrases.prefix(3) {
                addDetail("• \"\(phrase)\"")
            }
        } else {
            addSuccess("✓ None detected")
        }
        addDivider()

        // Adverbs
        addHeader("🐢 Adverbs")
        if results.adverbCount > 0 {
            addWarning("Found \(results.adverbCount)")
            for phrase in results.adverbPhrases.prefix(3) {
                addDetail("• \"\(phrase)\"")
            }
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Sensory details
        addHeader("🌟 Sensory Details")
        addStat("Count", "\(results.sensoryDetailCount)")
        if results.wordCount == 0 {
            // Don't show any message for empty documents
        } else if results.missingSensoryDetail {
            addWarning("Consider adding more")
        } else {
            addSuccess("✓ Good usage")
        }
        addDivider()

        // Weak verbs
        addHeader("💪 Weak Verbs")
        if results.weakVerbCount > 0 {
            addWarning("Found \(results.weakVerbCount) instance(s)")
            for phrase in results.weakVerbPhrases.prefix(5) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Use stronger, more specific verbs")
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Clichés
        addHeader("🚫 Clichés")
        if results.clicheCount > 0 {
            addWarning("Found \(results.clicheCount) cliché(s)")
            for phrase in results.clichePhrases.prefix(3) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Replace with original descriptions")
        } else {
            addSuccess("✓ None detected")
        }
        addDivider()

        // Filter words
        addHeader("🔍 Filter Words")
        if results.filterWordCount > 0 {
            addWarning("Found \(results.filterWordCount) instance(s)")
            for phrase in results.filterWordPhrases.prefix(5) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Show directly instead of filtering through perception")
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Sentence variety with graph
        addHeader("📊 Sentence Variety")
        addStat("Score", "\(results.sentenceVarietyScore)%")
        if !results.sentenceLengths.isEmpty {
            let graphView = createSentenceGraph(results.sentenceLengths)

            // Wrap in container to ensure proper spacing and visibility
            let graphContainer = NSView()
            graphContainer.translatesAutoresizingMaskIntoConstraints = false
            graphContainer.addSubview(graphView)

            NSLayoutConstraint.activate([
                graphView.topAnchor.constraint(equalTo: graphContainer.topAnchor, constant: 8),
                graphView.leadingAnchor.constraint(equalTo: graphContainer.leadingAnchor),
                graphView.bottomAnchor.constraint(equalTo: graphContainer.bottomAnchor, constant: -8)
            ])

            resultsStack.addArrangedSubview(graphContainer)
        }
        if results.sentenceVarietyScore < 40 {
            addWarning("Low variety - mix short and long sentences")
        } else if results.sentenceVarietyScore < 70 {
            addDetail("Good variety - consider adding more variation")
        } else {
            addSuccess("✓ Excellent variety")
        }
        addDivider()

        // Dialogue Quality Analysis (10 Tips from The Silent Operator_Dialogue)
        if results.dialogueSegmentCount > 0 {
            addHeader("💬 Dialogue Quality")
            addStat("Overall Score", "\(results.dialogueQualityScore)%")
            addStat("Dialogue Segments", "\(results.dialogueSegmentCount)")

            // Tip #3: Filler Words
            if results.dialogueFillerCount > 0 {
                let fillerPercent = (results.dialogueFillerCount * 100) / results.dialogueSegmentCount
                addWarning("⚠️ Filler words in \(fillerPercent)% of dialogue")
                addDetail("Tip: Remove \"uh\", \"um\", \"well\" unless characterizing speech")
            } else {
                addSuccess("✓ Minimal filler words")
            }

            // Tip #2: Repetition
            if results.dialogueRepetitionScore > 30 {
                addWarning("⚠️ Repetitive dialogue detected (\(results.dialogueRepetitionScore)%)")
                addDetail("Tip: Vary dialogue - characters shouldn't repeat phrases")
            }

            // Tip #5: Predictability
            if !results.dialoguePredictablePhrases.isEmpty {
                addWarning("⚠️ Found \(results.dialoguePredictablePhrases.count) predictable dialogue phrase(s)")
                for phrase in results.dialoguePredictablePhrases.prefix(3) {
                    addDetail("• \"\(phrase)\"")
                }
                addDetail("Tip: Replace predictable dialogue with fresh, character-specific lines")
            }

            // Tip #7: Over-Exposition
            if results.dialogueExpositionCount > 0 {
                let expositionPercent = (results.dialogueExpositionCount * 100) / results.dialogueSegmentCount
                if expositionPercent > 20 {
                    addWarning("⚠️ \(expositionPercent)% of dialogue is info-dumping")
                    addDetail("Tip: Show through action, not lengthy explanations")
                }
            }

            // Tip #8: Conflict/Tension
            if !results.hasDialogueConflict {
                addWarning("⚠️ Dialogue lacks conflict or tension")
                addDetail("Tip: Add disagreement, subtext, or opposing goals")
            } else {
                addSuccess("✓ Good tension in dialogue")
            }

            // Tip #10: Pacing
            addStat("Pacing Variety", "\(results.dialoguePacingScore)%")
            if results.dialoguePacingScore < 40 {
                addWarning("Low pacing variety")
                addDetail("Tip: Mix short, punchy lines with longer speeches")
            } else if results.dialoguePacingScore >= 60 {
                addSuccess("✓ Good pacing variety")
            }

            // Overall quality assessment
            if results.dialogueQualityScore >= 80 {
                addSuccess("✓ Excellent dialogue quality!")
            } else if results.dialogueQualityScore >= 60 {
                addDetail("Good dialogue - minor improvements possible")
            } else {
                addWarning("Consider revising dialogue for more impact")
            }
        }

        // Refresh popout if open
        refreshAnalysisPopoutContent()
    }

    private func refreshPlotPopoutContent() {
        guard let window = plotPopoutWindow,
              let scrollView = plotPopoutScrollView,
              let contentView = plotPopoutContentView,
              let stack = plotPopoutStack else { return }

        let theme = ThemeManager.shared.currentTheme

        // Clear previous content
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let jumpButton = NSButton(title: "Scroll to chart", target: self, action: #selector(scrollPlotPopoutToChart))
        jumpButton.bezelStyle = .rounded
        jumpButton.controlSize = .small
        let jumpColor = theme.popoutTextColor
        let jumpFont = jumpButton.font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        jumpButton.attributedTitle = NSAttributedString(
            string: "Scroll to chart",
            attributes: [
                .foregroundColor: jumpColor,
                .font: jumpFont
            ]
        )
        if #available(macOS 10.14, *) {
            jumpButton.contentTintColor = jumpColor
        }
        stack.addArrangedSubview(jumpButton)

        let header = NSTextField(labelWithString: "Plot Structure Analysis")
        header.font = NSFont.boldSystemFont(ofSize: 18)
        header.textColor = theme.popoutTextColor
        stack.addArrangedSubview(header)

        if let results = latestAnalysisResults, let plotAnalysis = results.plotAnalysis {
            let plotView = PlotVisualizationView()
            plotView.translatesAutoresizingMaskIntoConstraints = false
            plotView.configure(with: plotAnalysis, wrapInScrollView: false)
            stack.addArrangedSubview(plotView)

            NSLayoutConstraint.activate([
                plotView.widthAnchor.constraint(equalTo: stack.widthAnchor),
                plotView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1400)
            ])
        } else {
            let info = NSTextField(labelWithString: "Plot structure visualization will appear here\n\nRun an analysis to see plot tension and pacing")
            info.textColor = theme.popoutSecondaryColor
            info.maximumNumberOfLines = 0
            stack.addArrangedSubview(info)
        }

        applyThemeToPopout(window: window, container: window.contentView, stack: stack)

        DispatchQueue.main.async { [weak self, weak scrollView, weak contentView, weak stack] in
            guard let self,
                  let scrollView,
                  let contentView,
                  let stack else { return }
            self.schedulePopoutResize(scrollView: scrollView, contentView: contentView, stack: stack)
        }
    }

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.isSelectable = false
        label.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        label.textColor = .labelColor
        return label
    }

    private func addHeader(_ text: String) {
        let label = makeLabel(text, size: 14, bold: true)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        resultsStack.addArrangedSubview(label)

        // Ensure label takes full width for centering to work
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: resultsStack.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: resultsStack.trailingAnchor)
        ])
    }

    private func addStat(_ name: String, _ value: String) {
        let label = makeLabel("\(name): \(value)", size: 12, bold: false)
        label.textColor = .secondaryLabelColor
        resultsStack.addArrangedSubview(label)
    }

    private func addWarning(_ text: String) {
        let label = makeLabel(text, size: 12, bold: false)
        label.textColor = .systemOrange
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(label)
    }

    private func addSuccess(_ text: String) {
        let label = makeLabel(text, size: 12, bold: false)
        label.textColor = .systemGreen
        resultsStack.addArrangedSubview(label)
    }

    private func addDetail(_ text: String) {
        let label = makeLabel(text, size: 11, bold: false)
        label.textColor = .tertiaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(label)
    }

    private func addDivider() {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        resultsStack.addArrangedSubview(box)

        // Make divider span the full width of resultsStack
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: resultsStack.leadingAnchor),
            box.trailingAnchor.constraint(equalTo: resultsStack.trailingAnchor)
        ])
    }

    private func createSentenceGraph(_ lengths: [Int]) -> NSView {
        // Make graph responsive to panel width
        let availableWidth = view.frame.width > 0 ? view.frame.width - 32 : 280
        let graphWidth = min(max(availableWidth, 240), 400)  // Between 240-400px
        let graphHeight: CGFloat = 180

        let container = NSView(frame: NSRect(x: 0, y: 0, width: graphWidth, height: graphHeight))
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer?.backgroundColor = currentTheme.textColor.withAlphaComponent(0.08).cgColor
        container.layer?.cornerRadius = 8

        // Create bar chart
        guard !lengths.isEmpty else {
            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: graphHeight),
                container.widthAnchor.constraint(equalToConstant: graphWidth)
            ])

            // Add "No data" label
            let noDataLabel = makeLabel("Not enough sentences", size: 11, bold: false)
            noDataLabel.textColor = .tertiaryLabelColor
            noDataLabel.frame = NSRect(x: 10, y: graphHeight/2 - 10, width: graphWidth - 20, height: 20)
            container.addSubview(noDataLabel)

            return container
        }

        let maxLength = lengths.max() ?? 1
        let barWidth: CGFloat = max(4.0, min(graphWidth / CGFloat(lengths.count), 12.0))
        let spacing: CGFloat = 2
        let chartWidth = graphWidth - 20
        let maxBars = Int(chartWidth / (barWidth + spacing))
        let chartHeight = graphHeight - 35  // Space for legend at bottom

        // Draw bars directly on container
        for (index, length) in lengths.prefix(maxBars).enumerated() {
            let barHeight = max(4, (CGFloat(length) / CGFloat(maxLength)) * (chartHeight - 10))
            let x = 10 + CGFloat(index) * (barWidth + spacing)
            let y: CGFloat = 25  // Start from bottom, bars grow upward

            let bar = NSView(frame: NSRect(x: x, y: y, width: barWidth, height: barHeight))
            bar.wantsLayer = true

            // Color by length: green (short), yellow (medium), red (long)
            if length < 12 {
                bar.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.85).cgColor
            } else if length < 20 {
                bar.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.85).cgColor
            } else {
                bar.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
            }

            bar.layer?.cornerRadius = 2
            container.addSubview(bar)
        }

        // Add legend labels at bottom
        let legendY: CGFloat = 8
        let legendX: CGFloat = 10

        func addLegendItem(_ color: NSColor, _ label: String, xOffset: CGFloat) {
            let dot = NSView(frame: NSRect(x: legendX + xOffset, y: legendY, width: 7, height: 7))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = color.cgColor
            dot.layer?.cornerRadius = 3.5
            container.addSubview(dot)

            let text = NSTextField(labelWithString: label)
            text.isEditable = false
            text.isBezeled = false
            text.drawsBackground = false
            text.font = .systemFont(ofSize: 9)
            text.textColor = .secondaryLabelColor
            text.lineBreakMode = .byTruncatingTail
            text.frame = NSRect(x: legendX + xOffset + 10, y: legendY - 2, width: 70, height: 14)
            container.addSubview(text)
        }

        addLegendItem(NSColor.systemGreen.withAlphaComponent(0.85), "Short (<12)", xOffset: 0)
        addLegendItem(NSColor.systemYellow.withAlphaComponent(0.85), "Medium (12-20)", xOffset: 95)
        addLegendItem(NSColor.systemRed.withAlphaComponent(0.85), "Long (20+)", xOffset: 205)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: graphHeight),
            container.widthAnchor.constraint(equalToConstant: graphWidth)
        ])

        return container
    }

    private func createSentenceGraphForPopout(_ lengths: [Int]) -> NSView {
        // Fixed width for popout
        let graphWidth: CGFloat = 560
        let graphHeight: CGFloat = 180

        let container = NSView(frame: NSRect(x: 0, y: 0, width: graphWidth, height: graphHeight))
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        // Use slightly darker shade of pageAround for graph to match theme
        let graphBackground = currentTheme.pageAround.blended(withFraction: 0.05, of: .black) ?? currentTheme.pageAround
        container.layer?.backgroundColor = graphBackground.cgColor
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 1.0
        let borderColor = currentTheme == .night ? NSColor(white: 0.3, alpha: 1.0) : currentTheme.pageBorder
        container.layer?.borderColor = borderColor.cgColor

        // Create bar chart
        guard !lengths.isEmpty else {
            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: graphHeight),
                container.widthAnchor.constraint(equalToConstant: graphWidth)
            ])

            // Add "No data" label
            let noDataLabel = NSTextField(labelWithString: "Not enough sentences")
            noDataLabel.isEditable = false
            noDataLabel.isBezeled = false
            noDataLabel.drawsBackground = false
            noDataLabel.font = .systemFont(ofSize: 11)
            noDataLabel.textColor = .tertiaryLabelColor
            noDataLabel.frame = NSRect(x: 10, y: graphHeight/2 - 10, width: graphWidth - 20, height: 20)
            container.addSubview(noDataLabel)

            return container
        }

        let maxLength = lengths.max() ?? 1
        let barWidth: CGFloat = max(4.0, min(graphWidth / CGFloat(lengths.count), 12.0))
        let spacing: CGFloat = 2
        let chartWidth = graphWidth - 20
        let maxBars = Int(chartWidth / (barWidth + spacing))
        let chartHeight = graphHeight - 35  // Space for legend at bottom

        // Draw bars directly on container
        for (index, length) in lengths.prefix(maxBars).enumerated() {
            let barHeight = max(4, (CGFloat(length) / CGFloat(maxLength)) * (chartHeight - 10))
            let x = 10 + CGFloat(index) * (barWidth + spacing)
            let y: CGFloat = 25  // Start from bottom, bars grow upward

            let bar = NSView(frame: NSRect(x: x, y: y, width: barWidth, height: barHeight))
            bar.wantsLayer = true

            // Color by length: green (short), yellow (medium), red (long)
            if length < 12 {
                bar.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.85).cgColor
            } else if length < 20 {
                bar.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.85).cgColor
            } else {
                bar.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
            }

            bar.layer?.cornerRadius = 2
            container.addSubview(bar)
        }

        // Add legend labels at bottom
        let legendY: CGFloat = 8
        let legendX: CGFloat = 10

        func addLegendItem(_ color: NSColor, _ label: String, xOffset: CGFloat) {
            let dot = NSView(frame: NSRect(x: legendX + xOffset, y: legendY, width: 7, height: 7))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = color.cgColor
            dot.layer?.cornerRadius = 3.5
            container.addSubview(dot)

            let text = NSTextField(labelWithString: label)
            text.isEditable = false
            text.isBezeled = false
            text.drawsBackground = false
            text.font = .systemFont(ofSize: 9)
            text.textColor = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            text.lineBreakMode = .byTruncatingTail
            text.frame = NSRect(x: legendX + xOffset + 10, y: legendY - 2, width: 80, height: 14)
            container.addSubview(text)
        }

        addLegendItem(NSColor.systemGreen.withAlphaComponent(0.85), "Short (<12)", xOffset: 0)
        addLegendItem(NSColor.systemYellow.withAlphaComponent(0.85), "Medium (12-20)", xOffset: 120)
        addLegendItem(NSColor.systemRed.withAlphaComponent(0.85), "Long (20+)", xOffset: 265)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: graphHeight),
            container.widthAnchor.constraint(equalToConstant: graphWidth)
        ])

        return container
    }

    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        let panelBackground = isOutlinePanel ? theme.outlineBackground : theme.toolbarBackground

        // Ensure all views are layer-backed and apply backgrounds
        view.wantsLayer = true
        view.layer?.backgroundColor = panelBackground.cgColor

        menuSidebar?.wantsLayer = true
        menuSidebar?.layer?.backgroundColor = theme.toolbarBackground.cgColor

        menuSeparator?.wantsLayer = true
        menuSeparator?.layer?.backgroundColor = theme.toolbarBackground.withAlphaComponent(0.3).cgColor

        scrollContainer?.wantsLayer = true
        scrollContainer?.layer?.backgroundColor = panelBackground.cgColor

        scrollView?.wantsLayer = true
        scrollView?.drawsBackground = false
        scrollView?.backgroundColor = .clear
        scrollView?.layer?.backgroundColor = NSColor.clear.cgColor

        documentView?.wantsLayer = true
        documentView?.layer?.backgroundColor = NSColor.clear.cgColor

        contentStack?.wantsLayer = true
        contentStack?.layer?.backgroundColor = panelBackground.cgColor

        applyThemeToAnalysisPopout()
        applyThemeToAllPopouts()

        // Force redisplay
        view.needsDisplay = true
        view.displayIfNeeded()

        outlineViewController?.applyTheme(theme)
        applyThemeToMenuButtons(theme)
        updateSelectedButton()
    }

    /// Apply theme to all popout windows
    private func applyThemeToAllPopouts() {
        let windows: [NSWindow?] = [
            emotionalTrajectoryPopoutWindow,
            beliefShiftMatrixPopoutWindow,
            decisionConsequenceChainPopoutWindow,
            emotionalJourneyPopoutWindow,
            interactionsPopoutWindow,
            presencePopoutWindow,
            plotPopoutWindow
        ]

        for window in windows {
            guard let window = window else { continue }
            applyThemeToPopout(window: window, container: window.contentView, stack: nil)

            // Update text colors in the window
            updateTextColorsInView(window.contentView)
        }
    }

    /// Recursively update text colors in a view hierarchy
    private func updateTextColorsInView(_ view: NSView?) {
        guard let view = view else { return }

        if let textField = view as? NSTextField {
            // Don't change text fields that are editable (input fields)
            if !textField.isEditable {
                textField.textColor = currentTheme.textColor
            }
        }

        for subview in view.subviews {
            updateTextColorsInView(subview)
        }
    }

    // MARK: - Visualization Methods

    var latestAnalysisResults: AnalysisResults?

    private func significantCharacterNameSet(presence: [CharacterPresence]?, interactions: [CharacterInteraction]?) -> Set<String> {
        let maxKeep = 15
        let minKeep = 5

        if let presence, !presence.isEmpty {
            let totals: [(name: String, total: Int)] = presence.map { entry in
                let totalMentions = entry.chapterPresence.values.reduce(0, +)
                return (entry.characterName, totalMentions)
            }
            let sorted = totals.sorted { $0.total > $1.total }

            // Prefer dropping one-off/minor characters, but keep at least a few.
            var kept = sorted.filter { $0.total >= 3 }.map { $0.name }
            if kept.count < minKeep {
                kept = Array(sorted.prefix(minKeep)).map { $0.name }
            }
            if kept.count > maxKeep {
                kept = Array(kept.prefix(maxKeep))
            }
            return Set(kept)
        }

        if let interactions, !interactions.isEmpty {
            var scores: [String: Int] = [:]
            for i in interactions {
                scores[i.character1, default: 0] += i.coAppearances
                scores[i.character2, default: 0] += i.coAppearances
            }
            let sorted = scores.map { (name: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
            var kept = sorted.filter { $0.total >= 2 }.map { $0.name }
            if kept.count < minKeep {
                kept = Array(sorted.prefix(minKeep)).map { $0.name }
            }
            if kept.count > maxKeep {
                kept = Array(kept.prefix(maxKeep))
            }
            return Set(kept)
        }

        return []
    }

    private func currentSignificantCharacterNameSet(fallbackPresence: [CharacterPresence]? = nil, fallbackInteractions: [CharacterInteraction]? = nil) -> Set<String> {
        if let results = latestAnalysisResults {
            let set = significantCharacterNameSet(presence: results.characterPresence, interactions: results.characterInteractions)
            if !set.isEmpty { return set }
        }
        return significantCharacterNameSet(presence: fallbackPresence, interactions: fallbackInteractions)
    }

    func storeAnalysisResults(_ results: AnalysisResults) {
        latestAnalysisResults = results
        analysisResultsVersion += 1
        isAnalyzing = false
    }

    /// Call this when analysis starts
    func setAnalysisStarted() {
        isAnalyzing = true
    }

    /// Updates the loading indicator UI based on isAnalyzing state
    private func updateAnalysisLoadingUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isAnalyzing {
                // Show loading indicator
                if self.analysisLoadingIndicator == nil {
                    let indicator = NSProgressIndicator()
                    indicator.style = .spinning
                    indicator.controlSize = .small
                    indicator.translatesAutoresizingMaskIntoConstraints = false
                    self.analysisLoadingIndicator = indicator
                    // Add to the main view at the bottom of the sidebar
                    self.view.addSubview(indicator)
                    NSLayoutConstraint.activate([
                        indicator.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -8),
                        indicator.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 12)
                    ])
                }
                self.analysisLoadingIndicator?.startAnimation(nil)
                self.analysisLoadingIndicator?.isHidden = false

                if self.analysisStatusLabel == nil {
                    let label = NSTextField(labelWithString: "Analyzing...")
                    label.font = NSFont.systemFont(ofSize: 11)
                    label.textColor = .secondaryLabelColor
                    label.translatesAutoresizingMaskIntoConstraints = false
                    self.analysisStatusLabel = label
                    // Add next to indicator
                    self.view.addSubview(label)
                    if let indicator = self.analysisLoadingIndicator {
                        NSLayoutConstraint.activate([
                            label.centerYAnchor.constraint(equalTo: indicator.centerYAnchor),
                            label.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 6)
                        ])
                    }
                }
                self.analysisStatusLabel?.stringValue = "Analyzing..."
                self.analysisStatusLabel?.isHidden = false
            } else {
                // Hide loading indicator
                self.analysisLoadingIndicator?.stopAnimation(nil)
                self.analysisStatusLabel?.stringValue = "Analysis Ready"
                // Hide after a moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    if self?.isAnalyzing == false {
                        self?.analysisStatusLabel?.isHidden = true
                        self?.analysisLoadingIndicator?.isHidden = true
                    }
                }
            }
        }
    }

    func clearAllAnalysisUI() {
        // Clear main results display
        resultsStack.arrangedSubviews.forEach { view in
            resultsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // Close all popout windows
        presencePopoutWindow?.close()
        presencePopoutWindow = nil
        interactionsPopoutWindow?.close()
        interactionsPopoutWindow = nil
        emotionalTrajectoryPopoutWindow?.close()
        emotionalTrajectoryPopoutWindow = nil
        decisionConsequenceChainPopoutWindow?.close()
        decisionConsequenceChainPopoutWindow = nil
        beliefShiftMatrixPopoutWindow?.close()
        beliefShiftMatrixPopoutWindow = nil
        failurePatternChartPopoutWindow?.close()
        failurePatternChartPopoutWindow = nil
        thematicResonanceMapPopoutWindow?.close()
        thematicResonanceMapPopoutWindow = nil
        relationshipMapPopoutWindow?.close()
        relationshipMapPopoutWindow = nil
        alignmentChartPopoutWindow?.close()
        alignmentChartPopoutWindow = nil
        languageDriftPopoutWindow?.close()
        languageDriftPopoutWindow = nil
        emotionalJourneyPopoutWindow?.close()
        emotionalJourneyPopoutWindow = nil
        analysisPopoutWindow?.close()
        analysisPopoutWindow = nil
        outlinePopoutWindow?.close()
        outlinePopoutWindow = nil
        plotPopoutWindow?.close()
        plotPopoutWindow = nil
    }

    @available(macOS 13.0, *)
    private func displayVisualizations() {
        guard let results = latestAnalysisResults else {
            let placeholder = makeLabel("📊 No visualization data available\n\nRun an analysis first to see plot and character graphs", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        // Show plot visualization
        if let plotAnalysis = results.plotAnalysis {

            // Remove from previous parent if needed
            plotVisualizationView.removeFromSuperview()
            resultsStack.addArrangedSubview(plotVisualizationView)

            NSLayoutConstraint.activate([
                plotVisualizationView.widthAnchor.constraint(equalTo: resultsStack.widthAnchor),
                plotVisualizationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1400)
            ])

            plotVisualizationView.configure(with: plotAnalysis)

            // Force layout update to enable scrolling
            contentStack.layoutSubtreeIfNeeded()
            documentView.layoutSubtreeIfNeeded()
        }

        // Add character visualizations below plot
        if !results.decisionBeliefLoops.isEmpty {
            // Add spacing between sections
            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            resultsStack.addArrangedSubview(spacer)
            NSLayoutConstraint.activate([
                spacer.heightAnchor.constraint(equalToConstant: 30)
            ])

            // Remove from previous parent if needed
            characterArcVisualizationView.removeFromSuperview()
            resultsStack.addArrangedSubview(characterArcVisualizationView)

            NSLayoutConstraint.activate([
                characterArcVisualizationView.widthAnchor.constraint(equalTo: resultsStack.widthAnchor),
                characterArcVisualizationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 600)
            ])

            characterArcVisualizationView.configure(
                loops: results.decisionBeliefLoops,
                interactions: results.characterInteractions,
                presence: results.characterPresence
            )
        }

        // Ensure we stay scrolled to the top after injecting content
        scrollToTop()
    }

    @available(macOS 13.0, *)
    private func displayPlotAnalysis() {

        guard let results = latestAnalysisResults else {
            let placeholder = makeLabel("📖 Run analysis first to view plot insights", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        guard let plotAnalysis = results.plotAnalysis else {
            let placeholder = makeLabel("📖 No plot points detected yet", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        // Remove from previous parent if needed
        plotVisualizationView.removeFromSuperview()
        resultsStack.addArrangedSubview(plotVisualizationView)

        NSLayoutConstraint.activate([
            plotVisualizationView.widthAnchor.constraint(equalTo: resultsStack.widthAnchor),
            plotVisualizationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1400)
        ])

        plotVisualizationView.configure(with: plotAnalysis)

        // Force layout update to enable scrolling
        contentStack.layoutSubtreeIfNeeded()
        documentView.layoutSubtreeIfNeeded()
        scrollToTop()
    }

    @available(macOS 13.0, *)
    private func displayCharacterAnalysis() {

        guard let results = latestAnalysisResults else {
            let placeholder = makeLabel("👥 Run analysis first to view character insights", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        guard !results.decisionBeliefLoops.isEmpty else {
            let placeholder = makeLabel("👥 No characters detected yet", size: 14, bold: true)
            placeholder.alignment = .center
            placeholder.textColor = .secondaryLabelColor
            placeholder.maximumNumberOfLines = 0
            resultsStack.addArrangedSubview(placeholder)
            return
        }

        // Remove from previous parent if needed
        characterArcVisualizationView.removeFromSuperview()
        resultsStack.addArrangedSubview(characterArcVisualizationView)

        NSLayoutConstraint.activate([
            characterArcVisualizationView.widthAnchor.constraint(equalTo: resultsStack.widthAnchor),
            characterArcVisualizationView.heightAnchor.constraint(greaterThanOrEqualToConstant: 800)
        ])

        characterArcVisualizationView.configure(
            loops: results.decisionBeliefLoops,
            interactions: results.characterInteractions,
            presence: results.characterPresence
        )
        scrollToTop()
    }

    private func displayReadabilityAnalysis() {

        let placeholder = makeLabel("👁️ Readability Analysis\n\nAnalyze sentence complexity, vocabulary diversity, and reading level.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }

    private func displayPacingAnalysis() {

        let placeholder = makeLabel("⚡ Pacing Analysis\n\nTrack scene lengths, chapter distribution, and narrative rhythm.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }

    private func displayDialogueAnalysis() {

        let placeholder = makeLabel("💬 Dialogue Analysis\n\nAnalyze speech patterns, conversation balance, and dialogue tags.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }

    private func displayThemeAnalysis() {

        let placeholder = makeLabel("🎭 Theme Analysis\n\nDetect recurring motifs, symbols, and thematic elements.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }

    private func displayWorldbuildingAnalysis() {

        let placeholder = makeLabel("🌍 Worldbuilding Analysis\n\nTrack locations, time references, and world consistency.\n\nComing soon...", size: 14, bold: false)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.maximumNumberOfLines = 0
        resultsStack.addArrangedSubview(placeholder)
    }
}

// MARK: - Visualization Delegates

@available(macOS 13.0, *)
extension AnalysisViewController: PlotVisualizationDelegate {
    func didTapPlotPoint(at wordPosition: Int) {
        // Notify the editor to jump to this position
        NotificationCenter.default.post(
            name: Notification.Name("QuillPilotJumpToPosition"),
            object: nil,
            userInfo: ["wordPosition": wordPosition]
        )
    }

    func openPlotPopout(_ analysis: PlotAnalysis) {
        // Close existing popout if any
        plotPopoutWindow?.close()
        plotPopoutWindow = nil

        let contentRect = NSRect(x: 0, y: 0, width: 1100, height: 760)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Story Progress"
        window.level = .normal
        window.isMovableByWindowBackground = true
        window.isExcludedFromWindowsMenu = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        let hostingView = NSHostingView(
            rootView: PlotTensionChart(
                plotAnalysis: analysis,
                onPointTap: { [weak self] position in
                    self?.didTapPlotPoint(at: position)
                },
                onPopout: { [weak window] in
                    window?.makeKeyAndOrderFront(nil)
                }
            )
            .preferredColorScheme(isDarkMode ? .dark : .light)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        plotPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.plotPopoutWindow = nil
        }
    }
}

@available(macOS 13.0, *)
extension AnalysisViewController: CharacterArcVisualizationDelegate {
    func didTapSection(at wordPosition: Int) {
        // Notify the editor to jump to this position
        NotificationCenter.default.post(
            name: Notification.Name("QuillPilotJumpToPosition"),
            object: nil,
            userInfo: ["wordPosition": wordPosition]
        )
    }
}

// MARK: - Character Analysis Popout Functions

extension AnalysisViewController {
    private func canonicalCharacterKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func openDecisionBeliefPopout(loops: [DecisionBeliefLoop]) {
        let window: NSWindow
        if let existing = decisionBeliefPopoutWindow {
            window = existing
        } else {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            created.title = "Decision-Belief Loop Framework"
            created.level = .normal
            created.isMovableByWindowBackground = true
            created.isExcludedFromWindowsMenu = false
            created.isReleasedWhenClosed = false
            created.hidesOnDeactivate = true
            // Auto-close when user clicks elsewhere
            created.delegate = autoCloseDelegate
            created.center()
            decisionBeliefPopoutWindow = created
            window = created
        }

        // Apply theme colors and appearance
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.backgroundColor = theme.pageBackground
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        let keep = StyleCatalog.shared.isScreenplayTemplate ? currentSignificantCharacterNameSet() : []
        let keepCanon = Set(keep.map { canonicalCharacterKey($0) })

        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        var canonicalOrderIndex: [String: Int] = [:]
        for (idx, name) in libraryOrder.enumerated() {
            let key = canonicalCharacterKey(name)
            if canonicalOrderIndex[key] == nil {
                canonicalOrderIndex[key] = idx
            }
        }

        let keptLoops = keepCanon.isEmpty ? loops : loops.filter { keepCanon.contains(canonicalCharacterKey($0.characterName)) }
        let filteredLoops = (!keepCanon.isEmpty && keptLoops.isEmpty) ? loops : keptLoops

        let displayLoops: [DecisionBeliefLoop]
        if !libraryOrder.isEmpty {
            let orderFiltered = filteredLoops.filter { canonicalOrderIndex[canonicalCharacterKey($0.characterName)] != nil }
            let base = orderFiltered.isEmpty ? filteredLoops : orderFiltered
            displayLoops = base.sorted {
                (canonicalOrderIndex[canonicalCharacterKey($0.characterName)] ?? Int.max) < (canonicalOrderIndex[canonicalCharacterKey($1.characterName)] ?? Int.max)
            }
        } else {
            displayLoops = filteredLoops
        }

        // Use AppKit view for proper theme support
        let decisionBeliefView = DecisionBeliefLoopView(frame: window.contentView!.bounds)
        decisionBeliefView.autoresizingMask = [.width, .height]
        decisionBeliefView.setLoops(displayLoops)

        window.contentView = decisionBeliefView
        window.makeKeyAndOrderFront(nil)

        // Scroll to top
        decisionBeliefView.scrollToTop()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.decisionBeliefPopoutWindow = nil
        }
    }

    func openInteractionsPopout(interactions: [CharacterInteraction]) {
        // Close existing window if open
        interactionsPopoutWindow?.close()
        interactionsPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Character Interactions Network"
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        // Create custom view
        let interactionsView = CharacterInteractionsView(frame: window.contentView!.bounds)
        interactionsView.autoresizingMask = [.width, .height]

        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        let librarySet = Set(libraryOrder)
        let filtered = interactions.filter { librarySet.contains($0.character1) && librarySet.contains($0.character2) }

        // Convert CharacterInteraction to InteractionData
        let interactionData = filtered.map { interaction in
            CharacterInteractionsView.InteractionData(
                character1: interaction.character1,
                character2: interaction.character2,
                coAppearances: interaction.coAppearances,
                relationshipStrength: interaction.relationshipStrength,
                sections: interaction.sections
            )
        }

        interactionsView.setInteractions(interactionData, allCharacterNames: libraryOrder)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(interactionsView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        interactionsPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.interactionsPopoutWindow = nil
        }
    }

    func openRelationshipEvolutionMapPopout(evolutionData: RelationshipEvolutionData) {
        // Close existing window if open
        relationshipMapPopoutWindow?.close()
        relationshipMapPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Relationship Evolution Maps"
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create custom view
        let mapView = RelationshipEvolutionMapView(frame: window.contentView!.bounds)
        mapView.autoresizingMask = [.width, .height]

        // Relationship maps are most useful when they include the full cast.
        // Only apply the “significant characters” filter for screenplays to avoid unreadable maps.
        let keep = StyleCatalog.shared.isScreenplayTemplate ? currentSignificantCharacterNameSet() : []

        // Convert data to view format
        let filteredNodesData = keep.isEmpty ? evolutionData.nodes : evolutionData.nodes.filter { keep.contains($0.character) }
        let nodes = filteredNodesData.map { nodeData in
            RelationshipEvolutionMapView.RelationshipNode(
                character: nodeData.character,
                emotionalInvestment: nodeData.emotionalInvestment,
                position: NSPoint(x: nodeData.positionX, y: nodeData.positionY)
            )
        }

        let filteredEdgesData = keep.isEmpty ? evolutionData.edges : evolutionData.edges.filter { keep.contains($0.from) && keep.contains($0.to) }
        let edges = filteredEdgesData.map { edgeData in
            let powerDirection: RelationshipEvolutionMapView.PowerDirection
            switch edgeData.powerDirection {
            case "fromToTo":
                powerDirection = .fromToTo
            case "toToFrom":
                powerDirection = .toToFrom
            default:
                powerDirection = .balanced
            }

            let evolutionPoints = edgeData.evolution.map { point in
                RelationshipEvolutionMapView.EvolutionPoint(
                    chapter: point.chapter,
                    trustLevel: point.trustLevel,
                    description: point.description
                )
            }

            return RelationshipEvolutionMapView.RelationshipEdge(
                from: edgeData.from,
                to: edgeData.to,
                trustLevel: edgeData.trustLevel,
                powerDirection: powerDirection,
                evolution: evolutionPoints
            )
        }

        mapView.setRelationships(nodes: nodes, edges: edges)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(mapView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        relationshipMapPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.relationshipMapPopoutWindow = nil
        }
    }

    func openInternalExternalAlignmentPopout(alignmentData: InternalExternalAlignmentData) {
        // Close existing window if open
        alignmentChartPopoutWindow?.close()
        alignmentChartPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Internal vs External Alignment Charts"
        window.minSize = NSSize(width: 800, height: 700)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create custom view
        let alignmentView = InternalExternalAlignmentView(frame: window.contentView!.bounds)
        alignmentView.autoresizingMask = [.width, .height]

        // Convert data to view format
        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        let librarySet = Set(libraryOrder)

        // Filter to analysis-eligible characters and keep Character Library order.
        let orderedSource = alignmentData.characterAlignments
            .filter { librarySet.contains($0.characterName) }
            .sorted { a, b in
                (libraryOrder.firstIndex(of: a.characterName) ?? Int.max) < (libraryOrder.firstIndex(of: b.characterName) ?? Int.max)
            }

        let characterAlignments = orderedSource.map { charData in
            let dataPoints = charData.dataPoints.map { point in
                InternalExternalAlignmentView.AlignmentDataPoint(
                    chapter: point.chapter,
                    innerTruth: point.innerTruth,
                    outerBehavior: point.outerBehavior,
                    innerLabel: point.innerLabel,
                    outerLabel: point.outerLabel
                )
            }

            let gapTrend: InternalExternalAlignmentView.GapTrend
            switch charData.gapTrend {
            case "widening":
                gapTrend = .widening
            case "stabilizing":
                gapTrend = .stabilizing
            case "closing":
                gapTrend = .closing
            case "collapsing":
                gapTrend = .collapsing
            default:
                gapTrend = .fluctuating
            }

            return InternalExternalAlignmentView.CharacterAlignment(
                characterName: charData.characterName,
                dataPoints: dataPoints,
                gapTrend: gapTrend
            )
        }

        alignmentView.setAlignments(characterAlignments)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(alignmentView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        alignmentChartPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.alignmentChartPopoutWindow = nil
        }
    }

    func openLanguageDriftPopout(driftData: LanguageDriftData) {
        // Close existing window if open
        languageDriftPopoutWindow?.close()
        languageDriftPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Language Drift Analysis"
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create custom view
        let driftView = LanguageDriftAnalysisView(frame: window.contentView!.bounds)
        driftView.autoresizingMask = [.width, .height]

        // Convert data to view format
        var characterDrifts = driftData.characterDrifts.map { charData in
            let metrics = charData.metrics.map { m in
                LanguageDriftAnalysisView.LanguageMetrics(
                    chapter: m.chapter,
                    pronounI: m.pronounI,
                    pronounWe: m.pronounWe,
                    modalMust: m.modalMust,
                    modalChoice: m.modalChoice,
                    emotionalDensity: m.emotionalDensity,
                    avgSentenceLength: m.avgSentenceLength,
                    certaintyScore: m.certaintyScore
                )
            }

            let summary = LanguageDriftAnalysisView.DriftSummary(
                pronounShift: charData.driftSummary.pronounShift,
                modalShift: charData.driftSummary.modalShift,
                emotionalTrend: charData.driftSummary.emotionalTrend,
                sentenceTrend: charData.driftSummary.sentenceTrend,
                certaintyTrend: charData.driftSummary.certaintyTrend
            )

            return LanguageDriftAnalysisView.CharacterLanguageDrift(
                characterName: charData.characterName,
                metrics: metrics,
                driftSummary: summary
            )
        }

        // Ensure every analysis-eligible library character is represented even if the analysis data was missing
        let libraryNames = CharacterLibrary.shared.analysisCharacterKeys
        let existingNames = Set(characterDrifts.map { $0.characterName })
        let missingNames = libraryNames.filter { !existingNames.contains($0) }

        if !missingNames.isEmpty {
            // Derive chapter count from existing data or outline, fall back to 6
            let existingChapterCount = characterDrifts.first?.metrics.count
            let outlineEntries = getOutlineEntriesCallback?()
            let outlineChapters = outlineEntries?.filter { $0.level == 1 }.count
            let chapterCount = existingChapterCount ?? (outlineChapters ?? 6)

            for name in missingNames {
                var metrics: [LanguageDriftAnalysisView.LanguageMetrics] = []
                for chapter in 1...max(chapterCount, 1) {
                    metrics.append(
                        LanguageDriftAnalysisView.LanguageMetrics(
                            chapter: chapter,
                            pronounI: 0.3,
                            pronounWe: 0.3,
                            modalMust: 0.3,
                            modalChoice: 0.3,
                            emotionalDensity: 0.3,
                            avgSentenceLength: 0.3,
                            certaintyScore: 0.3
                        )
                    )
                }

                let summary = LanguageDriftAnalysisView.DriftSummary(
                    pronounShift: "Stable",
                    modalShift: "Stable",
                    emotionalTrend: "Stable",
                    sentenceTrend: "Stable",
                    certaintyTrend: "Stable"
                )

                characterDrifts.append(
                    LanguageDriftAnalysisView.CharacterLanguageDrift(
                        characterName: name,
                        metrics: metrics,
                        driftSummary: summary
                    )
                )
            }
        }

        // Keep Character Library order (and only analysis-eligible characters).
        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        let librarySet = Set(libraryOrder)
        if !libraryOrder.isEmpty {
            characterDrifts = characterDrifts
                .filter { librarySet.contains($0.characterName) }
                .sorted {
                    (libraryOrder.firstIndex(of: $0.characterName) ?? Int.max) < (libraryOrder.firstIndex(of: $1.characterName) ?? Int.max)
                }
        }

        driftView.setDriftData(characterDrifts)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(driftView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        languageDriftPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.languageDriftPopoutWindow = nil
        }
    }

    func openThematicResonanceMapPopout() {
        // Close existing window if open
        thematicResonanceMapPopoutWindow?.close()
        thematicResonanceMapPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Thematic Resonance Map"
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Get story theme from theme window
        let storyTheme = getStoryThemeText()

        // Create custom view
        let resonanceView = ThematicResonanceMapView(frame: window.contentView!.bounds)
        resonanceView.autoresizingMask = [.width, .height]

        // Generate sample thematic data based on characters
        let journeys = generateThematicJourneys()
        resonanceView.setThematicData(journeys, theme: storyTheme)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(resonanceView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        thematicResonanceMapPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.thematicResonanceMapPopoutWindow = nil
        }

        // Listen for theme changes to update the view
        NotificationCenter.default.addObserver(
            forName: .storyThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self, weak resonanceView] _ in
            guard let self = self, let resonanceView = resonanceView else { return }
            let updatedTheme = self.getStoryThemeText()
            let updatedJourneys = self.generateThematicJourneys()
            resonanceView.setThematicData(updatedJourneys, theme: updatedTheme)
        }
    }

    func openFailurePatternChartsPopout() {
        // Close existing window if open
        failurePatternChartPopoutWindow?.close()
        failurePatternChartPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Failure Pattern Charts"
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Create custom view
        let chartView = FailurePatternChartView(frame: window.contentView!.bounds)
        chartView.autoresizingMask = [.width, .height]

        // Generate failure pattern data based on characters
        let patterns = generateFailurePatterns()
        chartView.setFailureData(patterns)

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(chartView)

        window.contentView = container
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        failurePatternChartPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.failurePatternChartPopoutWindow = nil
        }
    }

    private func generateFailurePatterns() -> [FailurePatternChartView.CharacterFailurePattern] {
        var patterns: [FailurePatternChartView.CharacterFailurePattern] = []

        let library = CharacterLibrary.shared
        let characterNames: [String]
        if !library.characters.isEmpty {
            characterNames = library.analysisCharacterKeys
        } else if let presenceEntries = latestAnalysisResults?.characterPresence, !presenceEntries.isEmpty {
            characterNames = presenceEntries.map { $0.characterName }
        } else {
            characterNames = []
        }

        for (index, name) in characterNames.enumerated() {
            let failures = generateFailuresForCharacter(characterName: name, index: index)
            let progression = determineFailureProgression(failures: failures)

            let pattern = FailurePatternChartView.CharacterFailurePattern(
                characterName: name,
                color: qualitativePalette[index % qualitativePalette.count],
                failures: failures,
                progression: progression
            )
            patterns.append(pattern)
        }

        return patterns
    }

    private func generateFailuresForCharacter(characterName: String, index: Int) -> [FailurePatternChartView.Failure] {
        var failures: [FailurePatternChartView.Failure] = []

        // Get actual chapter numbers from outline
        let outlineEntries = getOutlineEntriesCallback?()
        let actualChapters: [Int]
        if let entries = outlineEntries, !entries.isEmpty {
            // Look for level 1 entries (chapters)
            let chapterEntries = entries.filter { $0.level == 1 }
            if !chapterEntries.isEmpty {
                actualChapters = Array(1...chapterEntries.count)
            } else {
                // If no level 1, try level 0 (parts) or level 2 (headings)
                let level0Entries = entries.filter { $0.level == 0 }
                let level2Entries = entries.filter { $0.level == 2 }
                if !level0Entries.isEmpty {
                    actualChapters = Array(1...level0Entries.count)
                } else if !level2Entries.isEmpty {
                    actualChapters = Array(1...min(level2Entries.count, 10))
                } else {
                    // Fallback: estimate from document length
                    actualChapters = Array(1...6)
                }
            }
        } else {
            // No outline available - use reasonable default
            actualChapters = Array(1...6)
        }

        // Use actual chapters from outline (no arbitrary limit)
        let chapters = actualChapters

        for (chapterIndex, chapter) in chapters.enumerated() {
            let progress = chapters.count > 1 ? Double(chapterIndex) / Double(chapters.count - 1) : 0.0

            // Different patterns for different characters
            let failureType: FailurePatternChartView.FailureType
            let growthScore: Double
            let description: String
            let consequence: String

            switch index {
            case 0: // Protagonist - evolves from naive to principled
                if chapterIndex == 0 {
                    failureType = .naive
                    growthScore = 0.2
                    description = "Trusts wrong person, reveals operation"
                    consequence = "Team compromised, trust broken"
                } else if chapterIndex == 1 {
                    failureType = .reactive
                    growthScore = 0.3
                    description = "Acts without thinking, blows cover"
                    consequence = "Mission delayed, partner injured"
                } else if chapterIndex == 2 {
                    failureType = .misinformed
                    growthScore = 0.45
                    description = "Acts on false intel"
                    consequence = "Wrong target confronted"
                } else if chapterIndex == 3 {
                    failureType = .strategic
                    growthScore = 0.7
                    description = "Calculated risk that doesn't pay off"
                    consequence = "Asset lost but learns from it"
                } else {
                    failureType = .principled
                    growthScore = 0.85
                    description = "Refuses unethical order"
                    consequence = "Career at risk but integrity intact"
                }

            case 1: // Ally - starts reactive, becomes strategic
                if chapterIndex < 2 {
                    failureType = .reactive
                    growthScore = 0.25 + (progress * 0.15)
                    description = "Impulsive decision"
                    consequence = "Minor setback"
                } else if chapterIndex == 2 {
                    failureType = .misinformed
                    growthScore = 0.5
                    description = "Misread situation"
                    consequence = "Relationship strain"
                } else {
                    failureType = .strategic
                    growthScore = 0.65 + (progress * 0.15)
                    description = "Tactical gamble"
                    consequence = "Short-term loss, long-term gain"
                }

            case 2: // Antagonist - strategic failures that escalate
                if chapterIndex < 2 {
                    failureType = .strategic
                    growthScore = 0.4
                    description = "Underestimates opposition"
                    consequence = "Plan partially foiled"
                } else {
                    failureType = .costlyChosen
                    growthScore = 0.5 + (progress * 0.2)
                    description = "Sacrifices ally for goal"
                    consequence = "More isolated but closer to objective"
                }

            case 3: // Mentor - costly failures throughout
                if chapterIndex == 0 {
                    failureType = .naive
                    growthScore = 0.3
                    description = "Old mistake haunts them"
                    consequence = "Past comes back"
                } else {
                    failureType = .costlyChosen
                    growthScore = 0.6 + (progress * 0.25)
                    description = "Protects protagonist at personal cost"
                    consequence = "Reputation/health damaged"
                }

            default:
                failureType = .reactive
                growthScore = 0.3 + (progress * 0.4)
                description = "Generic failure"
                consequence = "Generic consequence"
            }

            let failure = FailurePatternChartView.Failure(
                chapter: chapter,
                type: failureType,
                description: description,
                consequence: consequence,
                growthScore: growthScore
            )
            failures.append(failure)
        }

        return failures
    }

    private func determineFailureProgression(failures: [FailurePatternChartView.Failure]) -> FailurePatternChartView.FailureProgression {
        guard failures.count >= 2 else { return .stagnant }

        let firstGrowth = failures.first!.growthScore
        let lastGrowth = failures.last!.growthScore
        let improvement = lastGrowth - firstGrowth

        // Check if failures are getting "better" (higher growth score)
        if improvement < 0.1 {
            return .stagnant
        } else if improvement < 0.3 {
            return .emerging
        } else if improvement < 0.5 {
            return .transforming
        } else {
            return .evolved
        }
    }

    private func getStoryThemeText() -> String {
        return StoryNotesStore.shared.notes.theme
    }

    private func generateThematicJourneys() -> [ThematicResonanceMapView.CharacterThematicJourney] {
        let library = CharacterLibrary.shared
        let characterNames: [String]

        if !library.characters.isEmpty {
            characterNames = library.analysisCharacterKeys
        } else if let presenceEntries = latestAnalysisResults?.characterPresence, !presenceEntries.isEmpty {
            characterNames = presenceEntries.map { $0.characterName }
        } else {
            characterNames = []
        }

        var journeys: [ThematicResonanceMapView.CharacterThematicJourney] = []

        for (index, name) in characterNames.enumerated() {
            let stances = generateStancesForCharacter(characterName: name, index: index)
            let trajectory = determineTrajectory(stances: stances)

            let journey = ThematicResonanceMapView.CharacterThematicJourney(
                characterName: name,
                color: qualitativePalette[index % qualitativePalette.count],
                stances: stances,
                overallTrajectory: trajectory
            )
            journeys.append(journey)
        }

        return journeys
    }

    private func generateStancesForCharacter(characterName: String, index: Int) -> [ThematicResonanceMapView.ThematicStance] {
        var stances: [ThematicResonanceMapView.ThematicStance] = []

        // Get actual chapter numbers from outline
        let outlineEntries = getOutlineEntriesCallback?()
        let actualChapters: [Int]
        if let entries = outlineEntries, !entries.isEmpty {
            // Look for level 1 entries (chapters)
            let chapterEntries = entries.filter { $0.level == 1 }
            if !chapterEntries.isEmpty {
                actualChapters = Array(1...chapterEntries.count)
            } else {
                // If no level 1, try level 0 (parts) or level 2 (headings)
                let level0Entries = entries.filter { $0.level == 0 }
                let level2Entries = entries.filter { $0.level == 2 }
                if !level0Entries.isEmpty {
                    actualChapters = Array(1...level0Entries.count)
                } else if !level2Entries.isEmpty {
                    actualChapters = Array(1...min(level2Entries.count, 10))
                } else {
                    // Fallback: estimate from document length
                    actualChapters = Array(1...6)
                }
            }
        } else {
            // No outline available - use reasonable default
            actualChapters = Array(1...6)
        }

        // Select evenly spaced chapters for thematic stance (max 7 points)
        let chapters: [Int]
        if actualChapters.count <= 7 {
            chapters = actualChapters
        } else {
            let step = Double(actualChapters.count - 1) / 6.0
            chapters = (0..<7).map { i in
                actualChapters[min(Int(Double(i) * step), actualChapters.count - 1)]
            }
        }

        for (chapterIndex, chapter) in chapters.enumerated() {
            let progress = chapters.count > 1 ? Double(chapterIndex) / Double(chapters.count - 1) : 0.0

            // Different patterns for different characters
            let alignment: Double
            let awareness: Double
            let influence: Double
            let cost: Double

            switch index {
            case 0: // Protagonist - starts opposed, gradually embraces theme
                alignment = -0.8 + (progress * 1.5) // -0.8 to 0.7
                awareness = 0.2 + (progress * 0.7)  // Growing awareness
                influence = 0.4 + (progress * 0.5)  // Growing influence
                cost = 0.3 + (progress * 0.6)       // Increasing cost

            case 1: // Ally - embodies theme, helps protagonist see it
                alignment = 0.6 + (progress * 0.3)  // High, increasing
                awareness = 0.8 - (progress * 0.1)  // High, slight drop
                influence = 0.7 + (progress * 0.2)  // Strong influence
                cost = 0.5 + (progress * 0.3)       // Moderate cost

            case 2: // Antagonist - opposes theme throughout
                alignment = -0.9 + (progress * 0.2) // Stays negative
                awareness = 0.9                      // Fully aware
                influence = 0.8 - (progress * 0.3)  // Losing influence
                cost = 0.2                           // Low personal cost

            case 3: // Mentor - embodies theme but at high cost
                alignment = 0.8
                awareness = 0.95
                influence = 0.6 - (progress * 0.3)  // Diminishing influence
                cost = 0.8 + (progress * 0.15)      // Very high cost

            default: // Other characters
                alignment = sin(progress * .pi) * 0.6
                awareness = progress * 0.8
                influence = 0.5 + (sin(progress * .pi) * 0.3)
                cost = progress * 0.6
            }

            let stance = ThematicResonanceMapView.ThematicStance(
                chapter: chapter,
                alignment: alignment,
                awareness: awareness,
                influence: influence,
                cost: cost
            )
            stances.append(stance)
        }

        return stances
    }

    private func determineTrajectory(stances: [ThematicResonanceMapView.ThematicStance]) -> ThematicResonanceMapView.ThematicTrajectory {
        guard stances.count >= 2 else { return .conflicted }

        let firstAlignment = stances.first!.alignment
        let lastAlignment = stances.last!.alignment
        let change = lastAlignment - firstAlignment

        let lastAwareness = stances.last!.awareness

        if abs(change) < 0.2 {
            if lastAlignment > 0.7 {
                return .embodying
            } else if lastAlignment < -0.5 {
                return .resisting
            } else {
                return .conflicted
            }
        } else if change > 0.5 {
            if lastAwareness > 0.7 {
                return .transforming
            } else {
                return .awakening
            }
        } else if change > 0.2 {
            return .embracing
        } else {
            return .resisting
        }
    }

    @available(macOS 13.0, *)
    func openBeliefShiftMatrixPopout(matrices: [BeliefShiftMatrix]) {
        // Close existing window if open
        beliefShiftMatrixPopoutWindow?.close()
        beliefShiftMatrixPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Belief - Value Shift Matrices"
        window.minSize = NSSize(width: 1000, height: 600)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        let keep = StyleCatalog.shared.isScreenplayTemplate ? currentSignificantCharacterNameSet() : []
        let keepCanon = Set(keep.map { canonicalCharacterKey($0) })

        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        var canonicalOrderIndex: [String: Int] = [:]
        for (idx, name) in libraryOrder.enumerated() {
            let key = canonicalCharacterKey(name)
            if canonicalOrderIndex[key] == nil {
                canonicalOrderIndex[key] = idx
            }
        }

        let filteredMatrices: [BeliefShiftMatrix]
        if keepCanon.isEmpty {
            filteredMatrices = matrices
        } else {
            let kept = matrices.filter { keepCanon.contains(canonicalCharacterKey($0.characterName)) }
            filteredMatrices = kept.count >= 2 ? kept : matrices
        }

        let displayMatrices: [BeliefShiftMatrix]
        if !libraryOrder.isEmpty {
            let orderFiltered = filteredMatrices.filter { canonicalOrderIndex[canonicalCharacterKey($0.characterName)] != nil }
            let base = orderFiltered.isEmpty ? filteredMatrices : orderFiltered
            displayMatrices = base.sorted {
                (canonicalOrderIndex[canonicalCharacterKey($0.characterName)] ?? Int.max) < (canonicalOrderIndex[canonicalCharacterKey($1.characterName)] ?? Int.max)
            }
        } else {
            displayMatrices = filteredMatrices
        }

        // Create SwiftUI view
        let beliefMatrixView = BeliefShiftMatrixView(matrices: displayMatrices)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        let hostingView = NSHostingView(rootView: beliefMatrixView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = window.contentView!.bounds

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(hostingView)

        window.contentView = container

        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        beliefShiftMatrixPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.beliefShiftMatrixPopoutWindow = nil
        }
    }

    func openDecisionConsequenceChainsPopout(chains: [DecisionConsequenceChain]) {
        // Close existing window if open
        decisionConsequenceChainPopoutWindow?.close()
        decisionConsequenceChainPopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1300, height: 750),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Decision-Consequence Chains"
        window.minSize = NSSize(width: 1100, height: 650)
        window.isReleasedWhenClosed = false
        window.delegate = autoCloseDelegate

        // Set window appearance to match the current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        // Always show all chains in this popout; hiding characters is confusing.
        let keepCanon: Set<String> = []

        let libraryOrder = CharacterLibrary.shared.analysisCharacterKeys
        var canonicalOrderIndex: [String: Int] = [:]
        for (idx, name) in libraryOrder.enumerated() {
            let key = canonicalCharacterKey(name)
            if canonicalOrderIndex[key] == nil {
                canonicalOrderIndex[key] = idx
            }
        }

        let keptChains = keepCanon.isEmpty ? chains : chains.filter { keepCanon.contains(canonicalCharacterKey($0.characterName)) }
        let filteredChains = (!keepCanon.isEmpty && keptChains.isEmpty) ? chains : keptChains

        let displayChains: [DecisionConsequenceChain]
        if !libraryOrder.isEmpty {
            let orderFiltered = filteredChains.filter { canonicalOrderIndex[canonicalCharacterKey($0.characterName)] != nil }
            let base = orderFiltered.isEmpty ? filteredChains : orderFiltered
            displayChains = base.sorted {
                (canonicalOrderIndex[canonicalCharacterKey($0.characterName)] ?? Int.max) < (canonicalOrderIndex[canonicalCharacterKey($1.characterName)] ?? Int.max)
            }
        } else {
            displayChains = filteredChains
        }

        // Create SwiftUI view
        let chainView = DecisionConsequenceChainView(chains: displayChains)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        let hostingView = NSHostingView(rootView: chainView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = window.contentView!.bounds

        // Create container
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = currentTheme.pageAround.cgColor
        container.addSubview(hostingView)

        window.contentView = container

        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        decisionConsequenceChainPopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.decisionConsequenceChainPopoutWindow = nil
        }
    }

    func openPresencePopout(presence: [CharacterPresence]) {
        // Close existing window if open
        presencePopoutWindow?.close()
        presencePopoutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let isScreenplay = StyleCatalog.shared.isScreenplayTemplate
        switch isScreenplay {
        case true:
            window.title = "Character Presence by Scene"
        case false:
            window.title = "Character Presence by Chapter"
        }
        window.level = .normal
        window.isMovableByWindowBackground = true
        window.isExcludedFromWindowsMenu = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        // Apply theme colors and appearance
        let theme = ThemeManager.shared.currentTheme
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.backgroundColor = theme.pageBackground
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        let keep = currentSignificantCharacterNameSet(fallbackPresence: presence, fallbackInteractions: nil)
        let filteredPresence = keep.isEmpty ? presence : presence.filter { keep.contains($0.characterName) }

        // Use AppKit view for proper theme support
        let presenceView = CharacterPresenceView(frame: window.contentView!.bounds)
        presenceView.autoresizingMask = [.width, .height]
        presenceView.setDisplayMode(isScreenplay ? .scenes : .chapters)
        presenceView.setPresence(filteredPresence)

        window.contentView = presenceView
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Store window reference and set up cleanup
        presencePopoutWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.presencePopoutWindow = nil
        }
    }


    // MARK: - Analysis Popout Windows

    private func refreshAnalysisPopoutContent() {
        guard let stack = analysisPopoutStack else { return }
        let theme = ThemeManager.shared.currentTheme

        // Log sizes before rebuild
        if let container = analysisPopoutContainer,
           let scrollView = container.subviews.compactMap({ $0 as? NSScrollView }).first,
           let _ = scrollView.documentView {
        }

        // Clear current content and disclosure mappings
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        passiveDisclosureViews.removeAll()

        let headerTitle = StyleCatalog.shared.isPoetryTemplate ? "Poetry Analysis" : "Document Analysis"
        let header = NSTextField(labelWithString: headerTitle)
        header.font = NSFont.boldSystemFont(ofSize: 18)
        header.textColor = theme.popoutTextColor
        stack.addArrangedSubview(header)

        guard let results = latestAnalysisResults, results.wordCount > 0 else {
            let placeholder = NSTextField(labelWithString: "No content to analyze.\n\nWrite some text and click Update.")
            placeholder.textColor = theme.popoutSecondaryColor
            placeholder.maximumNumberOfLines = 0
            stack.addArrangedSubview(placeholder)
            return
        }

        // Helper functions for building UI elements in the popout
        func addHeader(_ text: String) {
            let label = makeLabel(text, size: 16, bold: true)
            label.textColor = theme.popoutTextColor
            label.alignment = .center
            stack.addArrangedSubview(label)
        }

        func addStat(_ name: String, _ value: String) {
            let label = makeLabel("\(name): \(value)", size: 14, bold: false)
            label.textColor = theme.popoutSecondaryColor
            stack.addArrangedSubview(label)
        }

        func addWarning(_ text: String) {
            let label = makeLabel(text, size: 14, bold: false)
            label.textColor = .systemOrange
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            stack.addArrangedSubview(label)
        }

        func addSuccess(_ text: String) {
            let label = makeLabel(text, size: 14, bold: false)
            label.textColor = .systemGreen
            stack.addArrangedSubview(label)
        }

        func addDetail(_ text: String) {
            let label = makeLabel(text, size: 13, bold: false)
            label.textColor = theme.popoutSecondaryColor
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            stack.addArrangedSubview(label)
        }

        func addBullet(_ text: String) {
            let label = NSTextField(wrappingLabelWithString: "")
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = theme.popoutSecondaryColor
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0

            let paragraph = NSMutableParagraphStyle()
            let bulletTab: CGFloat = 14
            paragraph.tabStops = [NSTextTab(textAlignment: .left, location: bulletTab, options: [:])]
            paragraph.defaultTabInterval = bulletTab
            paragraph.firstLineHeadIndent = 0
            paragraph.headIndent = bulletTab

            let attrs: [NSAttributedString.Key: Any] = [
                .font: label.font as Any,
                .foregroundColor: label.textColor as Any,
                .paragraphStyle: paragraph
            ]
            label.attributedStringValue = NSAttributedString(string: "•\t\(text)", attributes: attrs)
            stack.addArrangedSubview(label)
        }

        func addDivider() {
            let box = NSBox()
            box.boxType = .separator
            box.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(box)
        }

        // Poetry template: show poetry-focused insights (and hide fiction/screenplay-oriented sections)
        if StyleCatalog.shared.isPoetryTemplate {
            if let poetry = results.poetryInsights {
                // Label the poem using current manuscript metadata if available.
                if let info = getManuscriptInfoCallback?() {
                    let t = info.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    let a = info.author.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !t.isEmpty {
                        addStat("Poem", t)
                    }
                    if !a.isEmpty {
                        addStat("Author", a)
                    }
                }

                addHeader("🪶 Writer’s Poetry Analysis")
                addStat("Words", "\(results.wordCount)")
                addStat("Lines", "\(poetry.formal.lineCount)")
                addStat("Stanzas", "\(poetry.formal.stanzaCount)")
                addDetail("Percentages are heuristic signals, not measurements.")
                addDetail("Poem Type: \(poetry.writers.mode.rawValue) — \(poetry.writers.modeRationale)")

                func addBullets(_ items: [String]) {
                    for item in items {
                        addBullet(item)
                    }
                }

                addDivider()
                addHeader("1. Pressure Points (Form as Leverage)")
                addBullets(poetry.writers.pressurePoints)

                addDivider()
                addHeader("2. Line Energy (The Physics of the Line)")
                addBullets(poetry.writers.lineEnergy)

                addDivider()
                addHeader("3. Image Logic (How Images Think)")
                addBullets(poetry.writers.imageLogic)

                addDivider()
                addHeader("4. Voice Management (Persona Control)")
                addBullets(poetry.writers.voiceManagement)

                addDivider()
                addHeader("5. Emotional Arc (Invisible Plot)")
                addBullets(poetry.writers.emotionalArc)
                let isLongPoem = poetry.formal.lineCount >= 80 || poetry.formal.stanzaCount >= 10
                let useStanzaCurve = isLongPoem && !poetry.emotion.stanzaScores.isEmpty
                let curveScores = useStanzaCurve ? poetry.emotion.stanzaScores : poetry.emotion.lineScores
                let curveShifts = useStanzaCurve ? poetry.emotion.notableShiftStanzas : poetry.emotion.notableShiftLines
                if !curveScores.isEmpty {
                    let caption = useStanzaCurve ? "Stanza-to-stanza affect (smoothed)" : "Line-by-line affect (smoothed)"
                    let graph = createPoetryEmotionGraphForPopout(curveScores, shiftIndices: curveShifts, caption: caption)
                    stack.addArrangedSubview(graph)
                    NSLayoutConstraint.activate([
                        graph.widthAnchor.constraint(equalTo: stack.widthAnchor)
                    ])
                }

                addDivider()
                addHeader("6. Compression Choices (What’s Omitted)")
                addBullets(poetry.writers.compressionChoices)

                addDivider()
                addHeader("7. Ending Strategy")
                addBullets(poetry.writers.endingStrategy)
            } else {
                let placeholder = NSTextField(labelWithString: "Poetry Insights not available yet.\n\nSet Template to Poetry and click Update.")
                placeholder.textColor = theme.popoutSecondaryColor
                placeholder.maximumNumberOfLines = 0
                stack.addArrangedSubview(placeholder)
            }
            return
        }

        // Basic stats (non-poetry templates)
        addStat("Words", "\(results.wordCount)")
        addStat("Sentences", "\(results.sentenceCount)")
        addDivider()

        // Paragraph analysis
        addHeader("📊 Paragraphs")
        addStat("Count", "\(results.paragraphCount)")
        addStat("Pages", "~\(results.pageCount)")
        addStat("Avg Length", "\(results.averageParagraphLength) words")
        addStat("Dialogue", "\(results.dialoguePercentage)%")
        if !results.longParagraphs.isEmpty {
            addWarning("⚠️ \(results.longParagraphs.count) long paragraph(s)")
        }
        addDivider()

        // Passive voice
        addHeader("🔍 Passive Voice")
        if results.passiveVoiceCount > 0 {
            addWarning("Found \(results.passiveVoiceCount) instance(s)")

            // Create disclosure button to show/hide all instances
            let disclosureButton = NSButton(title: "▶ Show All (\(results.passiveVoicePhrases.count))", target: nil, action: nil)
            disclosureButton.bezelStyle = .inline
            disclosureButton.isBordered = false
            disclosureButton.font = NSFont.systemFont(ofSize: 12)
            disclosureButton.contentTintColor = theme.popoutSecondaryColor

            // Create a stack of labels for each passive voice phrase (simpler and more reliable)
            let phrasesStack = NSStackView()
            phrasesStack.orientation = .vertical
            phrasesStack.alignment = .leading
            phrasesStack.spacing = 4
            phrasesStack.translatesAutoresizingMaskIntoConstraints = false

            for (index, phrase) in results.passiveVoicePhrases.enumerated() {
                let label = NSTextField(labelWithString: "\(index + 1). \"\(phrase)\"")
                label.font = NSFont.systemFont(ofSize: 11)
                label.textColor = NSColor.white
                label.backgroundColor = .clear
                label.isSelectable = true
                label.lineBreakMode = .byWordWrapping
                label.maximumNumberOfLines = 0
                label.preferredMaxLayoutWidth = 360
                phrasesStack.addArrangedSubview(label)
            }

            let passiveScrollView = NSScrollView()
            passiveScrollView.documentView = phrasesStack
            passiveScrollView.hasVerticalScroller = true
            passiveScrollView.autohidesScrollers = false
            passiveScrollView.borderType = .lineBorder
            passiveScrollView.drawsBackground = true
            passiveScrollView.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 1.0)
            passiveScrollView.translatesAutoresizingMaskIntoConstraints = false
            passiveScrollView.isHidden = true

            // Container for the expandable section
            let passiveContainer = NSStackView()
            passiveContainer.orientation = .vertical
            passiveContainer.alignment = .leading
            passiveContainer.spacing = 8

            passiveContainer.addArrangedSubview(disclosureButton)
            passiveContainer.addArrangedSubview(passiveScrollView)

            NSLayoutConstraint.activate([
                passiveScrollView.widthAnchor.constraint(equalToConstant: 380),
                passiveScrollView.heightAnchor.constraint(equalToConstant: min(CGFloat(results.passiveVoicePhrases.count * 20 + 16), 200)),
                phrasesStack.leadingAnchor.constraint(equalTo: passiveScrollView.contentView.leadingAnchor, constant: 8),
                phrasesStack.trailingAnchor.constraint(equalTo: passiveScrollView.contentView.trailingAnchor, constant: -8),
                phrasesStack.topAnchor.constraint(equalTo: passiveScrollView.contentView.topAnchor, constant: 8)
            ])

            // Toggle action for disclosure button
            disclosureButton.target = self
            passiveDisclosureViews[disclosureButton] = passiveScrollView
            disclosureButton.action = #selector(togglePassiveVoiceDisclosure(_:))

            stack.addArrangedSubview(passiveContainer)
        } else {
            addSuccess("✓ None detected")
        }
        addDivider()

        // Adverbs
        addHeader("🐢 Adverbs")
        if results.adverbCount > 0 {
            addWarning("Found \(results.adverbCount)")
            for phrase in results.adverbPhrases.prefix(3) {
                addDetail("• \"\(phrase)\"")
            }
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Sensory details
        addHeader("🌟 Sensory Details")
        addStat("Count", "\(results.sensoryDetailCount)")
        if results.missingSensoryDetail {
            addWarning("Consider adding more")
        } else {
            addSuccess("✓ Good usage")
        }
        addDivider()

        // Weak verbs
        addHeader("💪 Weak Verbs")
        if results.weakVerbCount > 0 {
            addWarning("Found \(results.weakVerbCount) instance(s)")
            for phrase in results.weakVerbPhrases.prefix(5) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Use stronger, more specific verbs")
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Clichés
        addHeader("🚫 Clichés")
        if results.clicheCount > 0 {
            addWarning("Found \(results.clicheCount) cliché(s)")
            for phrase in results.clichePhrases.prefix(3) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Replace with original descriptions")
        } else {
            addSuccess("✓ None detected")
        }
        addDivider()

        // Filter words
        addHeader("🔍 Filter Words")
        if results.filterWordCount > 0 {
            addWarning("Found \(results.filterWordCount) instance(s)")
            for phrase in results.filterWordPhrases.prefix(5) {
                addDetail("• \"\(phrase)\"")
            }
            addDetail("Tip: Show directly instead of filtering through perception")
        } else {
            addSuccess("✓ Minimal usage")
        }
        addDivider()

        // Sentence variety
        addHeader("📊 Sentence Variety")
        addStat("Score", "\(results.sentenceVarietyScore)%")
        if !results.sentenceLengths.isEmpty {
            let graphView = createSentenceGraphForPopout(results.sentenceLengths)
            stack.addArrangedSubview(graphView)
        }
        if results.sentenceVarietyScore < 40 {
            addWarning("Low variety - mix short and long sentences")
        } else if results.sentenceVarietyScore < 70 {
            addDetail("Good variety - consider adding more variation")
        } else {
            addSuccess("✓ Excellent variety")
        }
        addDivider()

        // Dialogue Quality Analysis
        if results.dialogueSegmentCount > 0 {
            addHeader("💬 Dialogue Quality")
            addStat("Overall Score", "\(results.dialogueQualityScore)%")
            addStat("Dialogue Segments", "\(results.dialogueSegmentCount)")

            // Tip #3: Filler Words
            if results.dialogueFillerCount > 0 {
                let fillerPercent = (results.dialogueFillerCount * 100) / results.dialogueSegmentCount
                addWarning("⚠️ Filler words in \(fillerPercent)% of dialogue")
                addDetail("Tip: Remove \"uh\", \"um\", \"well\" unless characterizing speech")
            } else {
                addSuccess("✓ Minimal filler words")
            }

            // Tip #2: Repetition
            if results.dialogueRepetitionScore > 30 {
                addWarning("⚠️ Repetitive dialogue detected (\(results.dialogueRepetitionScore)%)")
                addDetail("Tip: Vary dialogue - characters shouldn't repeat phrases")
            }

            // Tip #5: Predictability
            if !results.dialoguePredictablePhrases.isEmpty {
                addWarning("⚠️ Found \(results.dialoguePredictablePhrases.count) predictable dialogue phrase(s)")
                for phrase in results.dialoguePredictablePhrases.prefix(3) {
                    addDetail("• \"\(phrase)\"")
                }
                addDetail("Tip: Replace predictable dialogue with fresh, character-specific lines")
            }

            // Tip #7: Over-Exposition
            if results.dialogueExpositionCount > 0 {
                let expositionPercent = (results.dialogueExpositionCount * 100) / results.dialogueSegmentCount
                if expositionPercent > 20 {
                    addWarning("⚠️ \(expositionPercent)% of dialogue is info-dumping")
                    addDetail("Tip: Show through action, not lengthy explanations")
                }
            }

            // Tip #8: Conflict/Tension
            if !results.hasDialogueConflict {
                addWarning("⚠️ Dialogue lacks conflict or tension")
                addDetail("Tip: Add disagreement, subtext, or opposing goals")
            } else {
                addSuccess("✓ Good tension in dialogue")
            }

            // Tip #10: Pacing
            addStat("Pacing Variety", "\(results.dialoguePacingScore)%")
            if results.dialoguePacingScore < 40 {
                addWarning("Low pacing variety")
                addDetail("Tip: Mix short, punchy lines with longer speeches")
            } else if results.dialoguePacingScore >= 60 {
                addSuccess("✓ Good pacing variety")
            }

            // Overall quality assessment
            if results.dialogueQualityScore >= 80 {
                addSuccess("✓ Excellent dialogue quality!")
            } else if results.dialogueQualityScore >= 60 {
                addDetail("Good dialogue - minor improvements possible")
            } else {
                addWarning("Consider revising dialogue for more impact")
            }
        }

    }

    private func createPoetryEmotionGraphForPopout(_ scores: [Double], shiftIndices: [Int], caption: String) -> NSView {
        // Responsive: height is fixed; width is provided by the stack/window.
        let graphWidth: CGFloat = 560
        let graphHeight: CGFloat = 170

        final class PoetryEmotionChartView: NSView {
            let rawScores: [Double]
            let shiftIndices1Based: [Int]
            let strokePos: NSColor
            let strokeNeg: NSColor
            let axisColor: NSColor

            init(frame frameRect: NSRect, scores: [Double], shiftIndices1Based: [Int], strokePos: NSColor, strokeNeg: NSColor, axisColor: NSColor) {
                self.rawScores = scores
                self.shiftIndices1Based = shiftIndices1Based
                self.strokePos = strokePos
                self.strokeNeg = strokeNeg
                self.axisColor = axisColor
                super.init(frame: frameRect)
                wantsLayer = false
                translatesAutoresizingMaskIntoConstraints = false
            }

            required init?(coder: NSCoder) { nil }

            override func setFrameSize(_ newSize: NSSize) {
                super.setFrameSize(newSize)
                needsDisplay = true
            }

            private func smooth(_ data: [Double], window: Int) -> [Double] {
                guard data.count >= 3 else { return data }
                let w = max(3, window | 1) // force odd
                let half = w / 2
                var out: [Double] = []
                out.reserveCapacity(data.count)
                for i in 0..<data.count {
                    let a = max(0, i - half)
                    let b = min(data.count - 1, i + half)
                    var sum = 0.0
                    var n = 0
                    for j in a...b { sum += data[j]; n += 1 }
                    out.append(sum / Double(max(1, n)))
                }
                return out
            }

            override func draw(_ dirtyRect: NSRect) {
                super.draw(dirtyRect)
                guard rawScores.count >= 2 else { return }

                let inset: CGFloat = 12
                // Reserve bottom space for legend + caption.
                let chartRect = NSRect(x: inset, y: 40, width: bounds.width - inset * 2, height: bounds.height - 60)
                guard chartRect.width > 10 && chartRect.height > 10 else { return }
                let midY = chartRect.midY

                // Midline
                axisColor.withAlphaComponent(0.42).setStroke()
                let midPath = NSBezierPath()
                midPath.lineWidth = 1
                midPath.move(to: NSPoint(x: chartRect.minX, y: midY))
                midPath.line(to: NSPoint(x: chartRect.maxX, y: midY))
                midPath.stroke()

                // Smooth + sample if needed
                let targetPoints = min(max(30, Int(chartRect.width)), 220)
                let stride = max(1, rawScores.count / targetPoints)
                let sampledRaw: [Double] = stride == 1 ? rawScores : rawScores.enumerated().compactMap { ($0.offset % stride == 0) ? $0.element : nil }
                let window = max(3, min(9, sampledRaw.count / 10 * 2 + 1))
                let data = smooth(sampledRaw, window: window)

                func point(at index: Int, score: Double) -> NSPoint {
                    let tX = CGFloat(index) / CGFloat(max(1, data.count - 1))
                    let x = chartRect.minX + tX * chartRect.width
                    let y = chartRect.minY + (CGFloat((score + 1.0) / 2.0) * chartRect.height)
                    return NSPoint(x: x, y: y)
                }

                // Shift markers
                let markerColor = axisColor.withAlphaComponent(0.34)
                markerColor.setStroke()
                for idx1 in shiftIndices1Based {
                    let zeroBased = idx1 - 1
                    guard zeroBased >= 0 && zeroBased < rawScores.count else { continue }
                    let sampledIndex = stride == 1 ? zeroBased : Int(round(Double(zeroBased) / Double(stride)))
                    guard sampledIndex >= 0 && sampledIndex < data.count else { continue }
                    let p = point(at: sampledIndex, score: 0)
                    let v = NSBezierPath()
                    v.lineWidth = 1.25
                    v.move(to: NSPoint(x: p.x, y: chartRect.minY))
                    v.line(to: NSPoint(x: p.x, y: chartRect.maxY))
                    v.stroke()
                }

                // Draw curve segments, color-coded above/below 0
                func strokeSegment(from a: (i: Int, s: Double), to b: (i: Int, s: Double)) {
                    let p0 = point(at: a.i, score: a.s)
                    let p1 = point(at: b.i, score: b.s)

                    let s0 = a.s
                    let s1 = b.s
                    if (s0 >= 0 && s1 >= 0) {
                        strokePos.setStroke()
                        let path = NSBezierPath()
                        path.lineWidth = 2
                        path.lineCapStyle = .round
                        path.move(to: p0)
                        path.line(to: p1)
                        path.stroke()
                        return
                    }
                    if (s0 <= 0 && s1 <= 0) {
                        strokeNeg.setStroke()
                        let path = NSBezierPath()
                        path.lineWidth = 2
                        path.lineCapStyle = .round
                        path.move(to: p0)
                        path.line(to: p1)
                        path.stroke()
                        return
                    }

                    // Crossing: split at score==0
                    let denom = (s1 - s0)
                    let t = abs(denom) < 0.000001 ? 0.5 : (0.0 - s0) / denom
                    let tClamped = max(0.0, min(1.0, t))
                    let x = p0.x + (p1.x - p0.x) * CGFloat(tClamped)
                    let y = midY
                    let mid = NSPoint(x: x, y: y)

                    if s0 >= 0 {
                        strokePos.setStroke()
                    } else {
                        strokeNeg.setStroke()
                    }
                    let pathA = NSBezierPath()
                    pathA.lineWidth = 2
                    pathA.lineCapStyle = .round
                    pathA.move(to: p0)
                    pathA.line(to: mid)
                    pathA.stroke()

                    if s1 >= 0 {
                        strokePos.setStroke()
                    } else {
                        strokeNeg.setStroke()
                    }
                    let pathB = NSBezierPath()
                    pathB.lineWidth = 2
                    pathB.lineCapStyle = .round
                    pathB.move(to: mid)
                    pathB.line(to: p1)
                    pathB.stroke()
                }

                for i in 1..<data.count {
                    strokeSegment(from: (i: i - 1, s: data[i - 1]), to: (i: i, s: data[i]))
                }

                // Peak/trough markers
                if let peak = data.enumerated().max(by: { $0.element < $1.element }), let trough = data.enumerated().min(by: { $0.element < $1.element }) {
                    func drawMarker(at idx: Int, score: Double, color: NSColor) {
                        let p = point(at: idx, score: score)
                        color.withAlphaComponent(0.95).setFill()
                        let r = NSRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)
                        NSBezierPath(ovalIn: r).fill()
                    }
                    drawMarker(at: peak.offset, score: peak.element, color: strokePos)
                    drawMarker(at: trough.offset, score: trough.element, color: strokeNeg)
                }
            }
        }

        let container = NSView(frame: NSRect(x: 0, y: 0, width: graphWidth, height: graphHeight))
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let graphBackground = currentTheme.pageAround.blended(withFraction: 0.05, of: .black) ?? currentTheme.pageAround
        container.layer?.backgroundColor = graphBackground.cgColor
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 1.0
        let borderColor = currentTheme == .night ? NSColor(white: 0.3, alpha: 1.0) : currentTheme.pageBorder
        container.layer?.borderColor = borderColor.cgColor

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: graphHeight)
        ])

        guard scores.count >= 2 else {
            let label = NSTextField(labelWithString: "Not enough data for a curve")
            label.font = .systemFont(ofSize: 11)
            label.textColor = .tertiaryLabelColor
            label.frame = NSRect(x: 10, y: graphHeight/2 - 10, width: container.bounds.width - 20, height: 20)
            label.autoresizingMask = [.width]
            container.addSubview(label)
            return container
        }

        let inset: CGFloat = 12
        let chartView = PoetryEmotionChartView(
            frame: NSRect(x: 0, y: 0, width: graphWidth, height: graphHeight),
            scores: scores,
            shiftIndices1Based: shiftIndices,
            strokePos: NSColor.systemRed,
            strokeNeg: NSColor.systemBlue,
            axisColor: currentTheme.popoutSecondaryColor
        )
        container.addSubview(chartView)
        NSLayoutConstraint.activate([
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chartView.topAnchor.constraint(equalTo: container.topAnchor),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Labels
        let labelTop = NSTextField(labelWithString: "↑")
        labelTop.font = .systemFont(ofSize: 12, weight: .medium)
        labelTop.textColor = currentTheme.popoutSecondaryColor
        labelTop.frame = NSRect(x: 6, y: graphHeight - 44, width: 12, height: 12)
        container.addSubview(labelTop)

        let labelMid = NSTextField(labelWithString: "0")
        labelMid.font = .systemFont(ofSize: 12, weight: .medium)
        labelMid.textColor = currentTheme.popoutSecondaryColor
        labelMid.frame = NSRect(x: 6, y: graphHeight/2 - 6, width: 18, height: 12)
        container.addSubview(labelMid)

        let labelBottom = NSTextField(labelWithString: "↓")
        labelBottom.font = .systemFont(ofSize: 12, weight: .medium)
        labelBottom.textColor = currentTheme.popoutSecondaryColor
        labelBottom.frame = NSRect(x: 6, y: 20, width: 12, height: 12)
        container.addSubview(labelBottom)

        let legendLabel = NSTextField(labelWithString: "Legend: Red = above neutral (lift) • Blue = below neutral (darkening) • Faint vertical lines = major shifts")
        legendLabel.font = .systemFont(ofSize: 12)
        legendLabel.textColor = currentTheme.popoutSecondaryColor.withAlphaComponent(0.9)
        legendLabel.frame = NSRect(x: inset, y: 22, width: container.bounds.width - inset * 2, height: 14)
        legendLabel.autoresizingMask = [.width]
        container.addSubview(legendLabel)

        let captionLabel = NSTextField(labelWithString: caption)
        captionLabel.font = .systemFont(ofSize: 13)
        captionLabel.textColor = currentTheme.popoutSecondaryColor.withAlphaComponent(0.85)
        captionLabel.frame = NSRect(x: inset, y: 6, width: container.bounds.width - inset * 2, height: 16)
        captionLabel.autoresizingMask = [.width]
        container.addSubview(captionLabel)

        return container
    }

    /// Helper to apply theme colors to any popout window - ensures all analysis popouts match navigator style
    private func applyThemeToPopout(window: NSWindow, container: NSView?, stack: NSStackView?) {
        let backgroundColor = currentTheme.pageAround

        window.backgroundColor = backgroundColor

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = backgroundColor.cgColor
        }

        if let container = container {
            container.wantsLayer = true
            container.layer?.backgroundColor = backgroundColor.cgColor
        }

        if let stack = stack {
            stack.wantsLayer = true
            stack.layer?.backgroundColor = backgroundColor.cgColor
            stack.layer?.cornerRadius = 10
        }
    }

    private func applyThemeToAnalysisPopout() {
        guard let window = analysisPopoutWindow else { return }
        applyThemeToPopout(window: window, container: analysisPopoutContainer, stack: analysisPopoutStack)
    }

    private func createAnalysisPopoutWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = StyleCatalog.shared.isPoetryTemplate ? "🪶 Poetry Analysis" : "📊 Analysis"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = AnalysisFlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        scrollView.documentView = contentView

        if let clipView = scrollView.contentView as NSClipView? {
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: clipView.topAnchor),
                contentView.widthAnchor.constraint(equalTo: clipView.widthAnchor)
            ])
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        window.contentView = container
        window.center()

        // Set references before applying theme
        analysisPopoutStack = stack
        analysisPopoutContainer = container

        // Apply theme colors directly (can't use applyThemeToAnalysisPopout because analysisPopoutWindow isn't set yet)
        let backgroundColor = currentTheme.pageAround
        container.layer?.backgroundColor = backgroundColor.cgColor
        window.backgroundColor = backgroundColor
        stack.wantsLayer = true
        stack.layer?.backgroundColor = backgroundColor.cgColor
        stack.layer?.cornerRadius = 10

        refreshAnalysisPopoutContent()

        // After refresh, log sizes

        // Resize to ensure scrolling works after rebuild
        resizePopoutContent(scrollView: scrollView, contentView: contentView, stack: stack)

        // Log after initial population

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.analysisPopoutWindow = nil
            self?.analysisPopoutStack = nil
            self?.analysisPopoutContainer = nil
        }

        return window
    }

    private func createOutlinePopoutWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let outlineTitle = StyleCatalog.shared.isPoetryTemplate ? "📝 Stanza Outline" : (StyleCatalog.shared.isScreenplayTemplate ? "📝 Scene Outline" : "📝 Document Outline")
        window.title = outlineTitle
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = AnalysisFlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: StyleCatalog.shared.isPoetryTemplate ? "Stanza Outline" : (StyleCatalog.shared.isScreenplayTemplate ? "Scene Outline" : "Document Outline"))
        header.font = NSFont.boldSystemFont(ofSize: 18)
        stack.addArrangedSubview(header)

        // Get actual outline entries from editor
        if let entries = getOutlineEntriesCallback?(), !entries.isEmpty {
            for entry in entries {
                let indent = String(repeating: "  ", count: max(0, entry.level - 1))
                let entryLabel = NSTextField(labelWithString: "\(indent)\(entry.title)")
                entryLabel.font = NSFont.systemFont(ofSize: 13)
                entryLabel.textColor = entry.level == 1 ? .labelColor : .secondaryLabelColor
                entryLabel.lineBreakMode = .byTruncatingTail
                entryLabel.maximumNumberOfLines = 1
                stack.addArrangedSubview(entryLabel)
            }
        } else {
            let infoText = StyleCatalog.shared.isPoetryTemplate
                ? "No stanzas found\n\nAdd verse lines (and stanza breaks) to see the stanza outline"
                : "No outline entries found\n\nAdd headings to your document to see the outline"
            let info = NSTextField(labelWithString: infoText)
            info.textColor = .secondaryLabelColor
            info.maximumNumberOfLines = 0
            stack.addArrangedSubview(info)
        }

        contentView.addSubview(stack)
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -24)
        ])

        let container = NSView()
        container.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        window.contentView = container
        window.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.outlinePopoutWindow = nil
        }

        return window
    }

    private func createPlotPopoutWindow() -> NSWindow {
        let theme = ThemeManager.shared.currentTheme
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 900),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "📖 Plot Structure Analysis"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = true
        window.backgroundColor = theme.popoutBackground
        window.delegate = self

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false // keep visible while debugging
        scrollView.scrollerStyle = .legacy
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = AnalysisFlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let jumpButton = NSButton(title: "Scroll to chart", target: self, action: #selector(scrollPlotPopoutToChart))
        jumpButton.bezelStyle = .rounded
        jumpButton.controlSize = .small
        let jumpColor = theme.popoutTextColor
        let jumpFont = jumpButton.font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        jumpButton.attributedTitle = NSAttributedString(
            string: "Scroll to chart",
            attributes: [
                .foregroundColor: jumpColor,
                .font: jumpFont
            ]
        )
        if #available(macOS 10.14, *) {
            jumpButton.contentTintColor = jumpColor
        }
        stack.addArrangedSubview(jumpButton)

        let header = NSTextField(labelWithString: "Plot Structure Analysis")
        header.font = NSFont.boldSystemFont(ofSize: 18)
        header.textColor = theme.popoutTextColor
        stack.addArrangedSubview(header)

        // Add plot visualization if available
        if let results = latestAnalysisResults, let plotAnalysis = results.plotAnalysis {
            let plotView = PlotVisualizationView()
            plotView.translatesAutoresizingMaskIntoConstraints = false
            // Disable the inner SwiftUI scroll view so the AppKit scroll view handles wheel events
            plotView.configure(with: plotAnalysis, wrapInScrollView: false)
            stack.addArrangedSubview(plotView)

            NSLayoutConstraint.activate([
                plotView.widthAnchor.constraint(equalTo: stack.widthAnchor),
                plotView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1400)
            ])
        } else {
            let info = NSTextField(labelWithString: "Plot structure visualization will appear here\n\nRun an analysis to see plot tension and pacing")
            info.textColor = theme.popoutSecondaryColor
            info.maximumNumberOfLines = 0
            stack.addArrangedSubview(info)
        }

        contentView.addSubview(stack)
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: stack.heightAnchor, constant: 1),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -24)
        ])

        let container = NSView()
        container.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        window.contentView = container
        window.center()

        // Apply theme colors
        applyThemeToPopout(window: window, container: container, stack: stack)

        // Size content to enable scrolling
        resizePopoutContent(scrollView: scrollView, contentView: contentView, stack: stack)

        // Debug sizes at creation

        // Store references for later scroll/resize handling
        plotPopoutWindow = window
        plotPopoutScrollView = scrollView
        plotPopoutContentView = contentView
        plotPopoutStack = stack

        // Re-run sizing after first layout cycle so scrollFrame/contentSize are valid
        DispatchQueue.main.async { [weak self, weak scrollView, weak contentView, weak stack] in
            guard let self,
                  let scrollView,
                  let contentView,
                  let stack else { return }
            self.schedulePopoutResize(scrollView: scrollView, contentView: contentView, stack: stack)
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.plotPopoutWindow = nil
            self?.plotPopoutScrollView = nil
            self?.plotPopoutContentView = nil
            self?.plotPopoutStack = nil
        }

        return window
    }

    private func showCharacterAnalysisMenu(_ sender: NSButton) {
        // Trigger analysis if no data exists
        if latestAnalysisResults == nil {
            analyzeCallback?()
            // Give a moment for analysis to complete then show menu
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showCharacterAnalysisMenuAfterAnalysis(sender)
            }
        } else {
            showCharacterAnalysisMenuAfterAnalysis(sender)
        }
    }

    private func showCharacterAnalysisMenuAfterAnalysis(_ sender: NSButton) {
        let menu = NSMenu()

        // Set menu appearance to match current theme
        let isDarkMode = ThemeManager.shared.isDarkMode
        menu.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        let trajectoryItem = NSMenuItem(title: "📈 Emotional Trajectory", action: #selector(showEmotionalTrajectory), keyEquivalent: "")
        trajectoryItem.target = self
        menu.addItem(trajectoryItem)

        let loopItem = NSMenuItem(title: "📊 Decision-Belief Loops", action: #selector(showDecisionBeliefLoops), keyEquivalent: "")
        loopItem.target = self
        menu.addItem(loopItem)

        let beliefMatrixItem = NSMenuItem(title: "📋 Belief Shift Matrix", action: #selector(showBeliefShiftMatrix), keyEquivalent: "")
        beliefMatrixItem.target = self
        menu.addItem(beliefMatrixItem)

        if !StyleCatalog.shared.isScreenplayTemplate {
            let chainItem = NSMenuItem(title: "⛓️ Decision-Consequence Chains", action: #selector(showDecisionConsequenceChains), keyEquivalent: "")
            chainItem.target = self
            menu.addItem(chainItem)
        }

        let relationshipMapItem = NSMenuItem(title: "Relationship Evolution Maps", action: #selector(showRelationshipEvolutionMaps), keyEquivalent: "")
        relationshipMapItem.target = self
        if #available(macOS 11.0, *) {
            relationshipMapItem.image = NSImage(systemSymbolName: "heart.circle", accessibilityDescription: "Relationship Evolution Maps")
        }
        menu.addItem(relationshipMapItem)

        // Lower/optional diagnostics: hide by default for Screenplay templates.
        if !StyleCatalog.shared.isScreenplayTemplate {
            let alignmentItem = NSMenuItem(title: "🎭 Internal vs External Alignment", action: #selector(showInternalExternalAlignment), keyEquivalent: "")
            alignmentItem.target = self
            menu.addItem(alignmentItem)

            let languageDriftItem = NSMenuItem(title: "📝 Language Drift Analysis", action: #selector(showLanguageDriftAnalysis), keyEquivalent: "")
            languageDriftItem.target = self
            menu.addItem(languageDriftItem)

            let thematicResonanceItem = NSMenuItem(title: "🎯 Thematic Resonance Map", action: #selector(showThematicResonanceMap), keyEquivalent: "")
            thematicResonanceItem.target = self
            menu.addItem(thematicResonanceItem)

            let failurePatternItem = NSMenuItem(title: "📉 Failure Pattern Charts", action: #selector(showFailurePatternCharts), keyEquivalent: "")
            failurePatternItem.target = self
            menu.addItem(failurePatternItem)
        }

        let interactionsItem = NSMenuItem(title: "🤝 Character Interactions", action: #selector(showInteractions), keyEquivalent: "")
        interactionsItem.target = self
        menu.addItem(interactionsItem)

        let presenceItem = NSMenuItem(title: "📍 Character Presence", action: #selector(showPresence), keyEquivalent: "")
        presenceItem.target = self
        menu.addItem(presenceItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    private func showMissingCharactersAlert() {
        let alert = NSAlert.themedWarning(
            title: "No Characters Detected",
            message: "Run Character Analysis or add characters before opening these popouts."
        )
        if let window = view.window {
            alert.runThemedSheet(for: window)
        } else {
            _ = alert.runThemedModal()
        }
    }

    private func showUnsupportedOSAlert() {
        guard let window = view.window else { return }
        let alert = NSAlert.themedWarning(
            title: "Feature Unavailable",
            message: "This feature requires macOS 13 or later."
        )
        alert.runThemedSheet(for: window)
    }

    @objc private func showDecisionBeliefLoops() {
        // If there are no analysis-eligible characters *and* no cached results,
        // show a warning right away. Otherwise allow existing results to open.
        if CharacterLibrary.shared.analysisCharacterKeys.isEmpty,
           (latestAnalysisResults?.decisionBeliefLoops.isEmpty ?? true) {
            showMissingCharactersAlert()
            return
        }

        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            // Wait for analysis to complete, then open
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    let loops = latestAnalysisResults?.decisionBeliefLoops ?? []
                    openDecisionBeliefPopout(loops: loops)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        // Open immediately with cached data (like Plot Structure does)
        let loops = latestAnalysisResults?.decisionBeliefLoops ?? []
        openDecisionBeliefPopout(loops: loops)

        // Trigger fresh analysis in background to update if needed
        if latestAnalysisResults == nil {
            analyzeCallback?()
        }
    }

    @objc private func showBeliefShiftMatrix() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        guard #available(macOS 13.0, *) else {
            showUnsupportedOSAlert()
            return
        }

        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    let matrices = latestAnalysisResults?.beliefShiftMatrices ?? []
                    openBeliefShiftMatrixPopout(matrices: matrices)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        let matrices = latestAnalysisResults?.beliefShiftMatrices ?? []
        openBeliefShiftMatrixPopout(matrices: matrices)

        if latestAnalysisResults == nil {
            analyzeCallback?()
        }
    }

    @objc private func showDecisionConsequenceChains() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    let chains = latestAnalysisResults?.decisionConsequenceChains ?? []
                    openDecisionConsequenceChainsPopout(chains: chains)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        let chains = latestAnalysisResults?.decisionConsequenceChains ?? []
        openDecisionConsequenceChainsPopout(chains: chains)

        if latestAnalysisResults == nil {
            analyzeCallback?()
        }
    }

    @objc private func showInteractions() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    let interactions = latestAnalysisResults?.characterInteractions ?? []
                    openInteractionsPopout(interactions: interactions)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        let interactions = latestAnalysisResults?.characterInteractions ?? []
        openInteractionsPopout(interactions: interactions)

        if latestAnalysisResults == nil {
            analyzeCallback?()
        }
    }

    @objc private func showPresence() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    let presence = latestAnalysisResults?.characterPresence ?? []
                    openPresencePopout(presence: presence)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        let presence = latestAnalysisResults?.characterPresence ?? []
        openPresencePopout(presence: presence)

        if latestAnalysisResults == nil {
            analyzeCallback?()
        }
    }

    @objc private func showRelationshipEvolutionMaps() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    let evolutionData = latestAnalysisResults?.relationshipEvolutionData ?? RelationshipEvolutionData()
                    openRelationshipEvolutionMapPopout(evolutionData: evolutionData)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        let evolutionData = latestAnalysisResults?.relationshipEvolutionData ?? RelationshipEvolutionData()
        openRelationshipEvolutionMapPopout(evolutionData: evolutionData)

        if latestAnalysisResults == nil {
            analyzeCallback?()
        }
    }

    @objc private func showInternalExternalAlignment() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    let alignmentData = latestAnalysisResults?.internalExternalAlignment ?? InternalExternalAlignmentData()
                    openInternalExternalAlignmentPopout(alignmentData: alignmentData)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        let alignmentData = latestAnalysisResults?.internalExternalAlignment ?? InternalExternalAlignmentData()
        openInternalExternalAlignmentPopout(alignmentData: alignmentData)

        if latestAnalysisResults == nil {
            analyzeCallback?()
        }
    }

    @objc private func showLanguageDriftAnalysis() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    let driftData = latestAnalysisResults?.languageDriftData ?? LanguageDriftData()
                    openLanguageDriftPopout(driftData: driftData)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        let driftData = latestAnalysisResults?.languageDriftData ?? LanguageDriftData()
        openLanguageDriftPopout(driftData: driftData)

        if latestAnalysisResults == nil {
            analyzeCallback?()
        }
    }

    @objc private func showThematicResonanceMap() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        // Generate data asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            DispatchQueue.main.async {
                self?.openThematicResonanceMapPopout()
            }
        }
    }

    @objc private func showFailurePatternCharts() {
        // Don't show if Character Library is empty
        guard !CharacterLibrary.shared.characters.isEmpty else {
            showMissingCharactersAlert()
            return
        }

        openFailurePatternChartsPopout()
    }

    @objc private func showEmotionalTrajectory() {
        // If analysis is in progress, wait for it to complete before opening
        if isAnalyzing {
            var attempts = 0
            func waitAndOpen() {
                attempts += 1
                if !isAnalyzing || attempts > 30 {
                    if let results = latestAnalysisResults {
                        openEmotionalTrajectoryPopout(results: results)
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        waitAndOpen()
                    }
                }
            }
            waitAndOpen()
            return
        }

        // Open immediately with cached data (like Plot Structure does)
        if let results = latestAnalysisResults {
            openEmotionalTrajectoryPopout(results: results)
        } else {
            // No cached results - trigger analysis and open when ready
            analyzeCallback?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                if let results = self?.latestAnalysisResults {
                    self?.openEmotionalTrajectoryPopout(results: results)
                }
            }
        }
    }

    private func openEmotionalTrajectoryPopout(results: AnalysisResults) {
        lastEmotionalTrajectoryResults = results
        // If window exists and is visible, bring it to front but still refresh its content
        if let existingWindow = emotionalTrajectoryPopoutWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
        }
        if emotionalTrajectoryPopoutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Emotional Trajectory Curves"
            window.minSize = NSSize(width: 700, height: 500)
            window.isReleasedWhenClosed = false
            window.delegate = autoCloseDelegate

            window.center()

            emotionalTrajectoryPopoutWindow = window
        }

        guard let window = emotionalTrajectoryPopoutWindow else { return }

        // Create content view
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = currentTheme.pageAround.cgColor

        // Create toolbar for metric selection
        let toolbar = NSView(frame: NSRect(x: 0, y: window.contentView!.bounds.height - 50, width: window.contentView!.bounds.width, height: 50))
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = currentTheme.headerBackground.cgColor

        let titleLabel = NSTextField(labelWithString: "Emotional Trajectory Curves")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = currentTheme.textColor
        titleLabel.frame = NSRect(x: 20, y: 15, width: 300, height: 24)
        toolbar.addSubview(titleLabel)

        // Metric selector
        let metricLabel = NSTextField(labelWithString: "Metric:")
        metricLabel.font = NSFont.systemFont(ofSize: 12)
        metricLabel.textColor = currentTheme.textColor
        metricLabel.frame = NSRect(x: 350, y: 18, width: 50, height: 20)
        toolbar.addSubview(metricLabel)

        let metricPopup = NSPopUpButton(frame: NSRect(x: 410, y: 13, width: 200, height: 26))
        for metric in EmotionalTrajectoryView.EmotionalMetric.allCases {
            metricPopup.addItem(withTitle: metric.rawValue)
        }
        metricPopup.target = self
        metricPopup.action = #selector(metricChanged(_:))
        toolbar.addSubview(metricPopup)

        containerView.addSubview(toolbar)

        // Create trajectory view
        let trajectoryView = EmotionalTrajectoryView(frame: NSRect(x: 20, y: 20, width: window.contentView!.bounds.width - 40, height: window.contentView!.bounds.height - 90))
        trajectoryView.autoresizingMask = [.width, .height]

        // Generate sample trajectory data from analysis results
        let trajectories = generateEmotionalTrajectories(from: results)
        trajectoryView.setTrajectories(trajectories)

        containerView.addSubview(trajectoryView)

        window.contentView = containerView
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func metricChanged(_ sender: NSPopUpButton) {
        guard let window = emotionalTrajectoryPopoutWindow,
              let containerView = window.contentView,
              let trajectoryView = containerView.subviews.first(where: { $0 is EmotionalTrajectoryView }) as? EmotionalTrajectoryView else {
            return
        }

        let metrics = EmotionalTrajectoryView.EmotionalMetric.allCases
        guard sender.indexOfSelectedItem >= 0 && sender.indexOfSelectedItem < metrics.count else {
            return
        }

        let selectedMetric = metrics[sender.indexOfSelectedItem]
        trajectoryView.setMetric(selectedMetric)
    }

    private func generateEmotionalTrajectories(from results: AnalysisResults) -> [EmotionalTrajectoryView.CharacterTrajectory] {
        var trajectories: [EmotionalTrajectoryView.CharacterTrajectory] = []

        // CHARACTER LIBRARY IS THE ONLY SOURCE OF TRUTH.
        // Do NOT fall back to document styles or presence data for character names.
        let library = CharacterLibrary.shared

        func keyForName(_ name: String) -> String {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }
            let firstToken = trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? trimmed
            return firstToken.trimmingCharacters(in: .punctuationCharacters).lowercased()
        }

        var displayNameByKey: [String: String] = [:]
        for profile in library.analysisEligibleCharacters {
            if let key = profile.analysisKey?.lowercased(), !key.isEmpty {
                displayNameByKey[key] = profile.displayName
            }
        }

        // ONLY use Character Library keys - no fallback to presence/interactions data.
        let libraryKeys = library.analysisCharacterKeys.map { $0.lowercased() }
        guard !libraryKeys.isEmpty else {
            // No characters in library = no trajectories.
            return []
        }
        let characterKeys = libraryKeys

        // Build presence lookup from results but only for library characters.
        for presence in results.characterPresence {
            let key = keyForName(presence.characterName)
            if displayNameByKey[key] == nil && characterKeys.contains(key) {
                let trimmed = presence.characterName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { displayNameByKey[key] = trimmed }
            }
        }
        // Only use interaction data for library characters (don't add new characters from interactions).
        for interaction in results.characterInteractions {
            for raw in [interaction.character1, interaction.character2] {
                let key = keyForName(raw)
                // Only add display name if this character is in the library.
                if characterKeys.contains(key) && displayNameByKey[key] == nil {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { displayNameByKey[key] = trimmed }
                }
            }
        }

        let colors: [NSColor] = [.systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple, .systemTeal, .systemIndigo, .systemPink]

        // Find max chapter across presence data.
        // IMPORTANT: `CharacterInteraction.sections` are “co-appearance section indexes” and can be a different
        // scale than `CharacterPresence.chapterPresence` (which would distort the x-axis and cause trajectories
        // to drop to zero for much of the graph).
        let allChapters = results.characterPresence.flatMap { Array($0.chapterPresence.keys) }
        let maxChapterFromPresence = allChapters.max() ?? 10
        let chapterCount = max(1, maxChapterFromPresence)

        // If interaction sections are on a different index scale, remap them to chapters.
        let maxInteractionSection = results.characterInteractions.flatMap { $0.sections }.max() ?? 0
        func mapInteractionSectionToChapter(_ section: Int) -> Int {
            guard maxInteractionSection > 0 else { return 1 }
            if maxInteractionSection <= 1 || chapterCount <= 1 {
                return 1
            }
            // Map section index domain [1..maxInteractionSection] onto [1..chapterCount]
            let t = Double(max(1, section) - 1) / Double(maxInteractionSection - 1)
            let mapped = Int(round(t * Double(chapterCount - 1))) + 1
            return min(chapterCount, max(1, mapped))
        }

        // Pre-calculate interaction data per chapter for attachment metric
        var interactionsByChapter: [String: [Int: Int]] = [:] // key -> chapter -> interaction count
        for interaction in results.characterInteractions {
            for name in [interaction.character1, interaction.character2] {
                let key = keyForName(name)
                if key.isEmpty { continue }
                if interactionsByChapter[key] == nil {
                    interactionsByChapter[key] = [:]
                }
                for section in interaction.sections {
                    let chapter = mapInteractionSectionToChapter(section)
                    interactionsByChapter[key]![chapter, default: 0] += 1
                }
            }
        }

        // Pre-calculate presence lookup and global max for normalization
        var presenceByName: [String: [Int: Int]] = [:]
        for presence in results.characterPresence {
            let key = keyForName(presence.characterName)
            guard !key.isEmpty else { continue }
            presenceByName[key] = presence.chapterPresence
        }
        let maxPresenceGlobal = max(1, results.characterPresence.flatMap { $0.chapterPresence.values }.max() ?? 1)

        // For confidence, we want a per-chapter dominance metric to avoid compressing
        // values into a small band when a single chapter has an outlier max.
        var maxPresenceByChapter: [Int: Int] = [:]
        for chapterPresence in presenceByName.values {
            for (chapter, count) in chapterPresence {
                let existing = maxPresenceByChapter[chapter] ?? 0
                if count > existing {
                    maxPresenceByChapter[chapter] = count
                }
            }
        }

        // Keep both the raw max (to detect “no interaction data”) and a non-zero max for normalization.
        let maxInteractionsGlobalRaw = interactionsByChapter.values.flatMap { $0.values }.max() ?? 0
        let maxInteractionsGlobal = max(1, maxInteractionsGlobalRaw)

        for (index, characterKey) in characterKeys.enumerated() {
            var states: [EmotionalTrajectoryView.EmotionalState] = []

            // Get this character's presence data
            let presence = presenceByName[characterKey] ?? [:]
            let charInteractions = interactionsByChapter[characterKey] ?? [:]
            let hasAnyInteractionDataForCharacter = (charInteractions.values.reduce(0, +) > 0)

            // Track running values for trend calculation
            var previousPresence: Double = 0
            var runningTrend: Double = 0

            // Generate states for each chapter position
            let steps = min(chapterCount, 24) // Cap at 24 data points for readability

            for stepIndex in 0...steps {
                let position = Double(stepIndex) / Double(steps)
                let chapter = min(chapterCount, max(1, Int(round(position * Double(chapterCount - 1))) + 1))

                // CONFIDENCE: Based on presence dominance (high presence = character is driving action)
                // Confidence is a 0..1 metric (not bipolar).
                let presenceCount = Double(presence[chapter] ?? 0)
                let normalizedPresenceGlobal = presenceCount / Double(maxPresenceGlobal)
                let chapterMaxPresence = Double(max(1, maxPresenceByChapter[chapter] ?? 1))
                let confidence = max(0, min(1, presenceCount / chapterMaxPresence))

                // HOPE: Based on presence trajectory (rising = hope, falling = despair)
                let presenceDelta = normalizedPresenceGlobal - previousPresence
                runningTrend = runningTrend * 0.7 + presenceDelta * 0.3 // Smoothed trend
                let hope = max(-1, min(1, runningTrend * 5.0)) // Amplify for visibility
                previousPresence = normalizedPresenceGlobal

                // CONTROL: Based on presence consistency (stable presence = in control)
                // Look at variance in nearby chapters
                var nearbyPresences: [Double] = []
                for nearChapter in max(1, chapter - 2)...min(chapterCount, chapter + 2) {
                    let p = Double(presence[nearChapter] ?? 0)
                    nearbyPresences.append(p / Double(maxPresenceGlobal))
                }
                let avgNearby = nearbyPresences.isEmpty ? 0 : nearbyPresences.reduce(0, +) / Double(nearbyPresences.count)
                let variance = nearbyPresences.isEmpty ? 0 : nearbyPresences.map { pow($0 - avgNearby, 2) }.reduce(0, +) / Double(nearbyPresences.count)
                let control = (1.0 - min(1.0, variance * 10)) * 2.0 - 1.0 // Low variance = high control

                // ATTACHMENT: Prefer interactions with other characters; if no interaction data exists
                // (common when only one character is present), fall back to normalized presence.
                let interactionCount = Double(charInteractions[chapter] ?? 0)
                let normalizedInteractions = interactionCount / Double(maxInteractionsGlobal)
                let attachmentSource = (maxInteractionsGlobalRaw > 0 && hasAnyInteractionDataForCharacter)
                    ? normalizedInteractions
                    : normalizedPresenceGlobal
                let attachment = attachmentSource * 2.0 - 1.0 // Map 0-1 to -1 to 1

                let state = EmotionalTrajectoryView.EmotionalState(
                    position: position,
                    confidence: confidence,
                    hope: max(-1, min(1, hope)),
                    control: max(-1, min(1, control)),
                    attachment: max(-1, min(1, attachment))
                )
                states.append(state)
            }

            let trajectory = EmotionalTrajectoryView.CharacterTrajectory(
                characterName: displayNameByKey[characterKey] ?? characterKey,
                color: colors[index % colors.count],
                states: states,
                isDashed: false
            )
            trajectories.append(trajectory)
        }

        return trajectories
    }
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

