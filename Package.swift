// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuillPilot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "QuillPilot",
            targets: ["QuillPilot"]
        )
    ],
    targets: [
        .executableTarget(
            name: "QuillPilot",
            dependencies: [],
            path: "QuillPilot/QuillPilot",
            sources: [
                "Sources/AppDelegate.swift",
                "Controllers/MainWindowController.swift",
                "Controllers/SplitViewController.swift",
                "Controllers/EditorViewController.swift",
                "Controllers/AnalysisViewController.swift",
                "Controllers/CharacterLibraryViewController.swift",
                "Models/AnalysisEngine.swift",
                "Models/CharacterLibrary.swift",
                "Models/PlotAnalysis.swift",
                "Models/CharacterArcAnalysis.swift",
                "Models/DecisionBeliefLoop.swift",
                "Models/Scene.swift",
                "Models/Chapter.swift",
                "Models/SceneManager.swift",
                "Utilities/ThemeManager.swift",
                "Utilities/DebugLog.swift",
                "Utilities/StyleCatalog.swift",
                "Utilities/QuillPilotSettings.swift",
                "Utilities/RecentDocuments.swift",
                "Utilities/ScreenplayImporter.swift",
                "Utilities/PoetryImporter.swift",
                "Utilities/FadeInImporter.swift",
                "Utilities/StoryNotesStore.swift",
                "Extensions/NSColor+Hex.swift",
                "Extensions/NSAlert+Themed.swift",
                "Views/DocumentInfoPanel.swift",
                "Views/RulerView.swift",
                "Views/HeaderFooterSettingsWindow.swift",
                "Views/StyleEditorWindow.swift",
                "Views/DocumentationWindow.swift",
                "Views/CharacterLibraryWindow.swift",
                "Views/ThemeWindow.swift",
                "Views/PreferencesWindowController.swift",
                "Views/StoryOutlineWindow.swift",
                "Views/LocationsWindow.swift",
                "Views/StoryDirectionsWindow.swift",
                "Views/AutoStoryWindow.swift",
                "Views/DialogueTipsWindow.swift",
                "Views/SceneListWindow.swift",
                "Views/SceneInspectorWindow.swift",
                "Views/PlotVisualizationView.swift",
                "Views/CharacterArcVisualizationView.swift",
                "Views/EmotionalTrajectoryView.swift",
                "Views/CharacterInteractionsView.swift",
                "Views/BeliefShiftMatrixView.swift",
                "Views/DecisionConsequenceChainView.swift",
                "Views/RelationshipEvolutionMapView.swift",
                "Views/InternalExternalAlignmentView.swift",
                "Views/LanguageDriftAnalysisView.swift",
                "Views/LogoView.swift",
                "Views/WelcomeWindow.swift",
                "Views/ThematicResonanceMapView.swift",
                "Views/FailurePatternChartView.swift",
                "Views/DecisionBeliefLoopView.swift",
                "Views/CharacterPresenceView.swift",
                "Views/TOCIndexWindow.swift"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
