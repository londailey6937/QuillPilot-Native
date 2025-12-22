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
            exclude: [
                "Assets.xcassets"
            ],
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
                "Utilities/ThemeManager.swift",
                "Utilities/StyleCatalog.swift",
                "Extensions/NSColor+Hex.swift",
                "Views/DocumentInfoPanel.swift",
                "Views/RulerView.swift",
                "Views/HeaderFooterSettingsWindow.swift",
                "Views/StyleEditorWindow.swift",
                "Views/DocumentationWindow.swift",
                "Views/CharacterLibraryWindow.swift",
                "Views/ThemeWindow.swift",
                "Views/StoryOutlineWindow.swift",
                "Views/LocationsWindow.swift",
                "Views/StoryDirectionsWindow.swift",
                "Views/DialogueTipsWindow.swift",
                "Views/PlotVisualizationView.swift",
                "Views/CharacterArcVisualizationView.swift",
                "Views/EmotionalTrajectoryView.swift",
                "Views/CharacterInteractionsView.swift",
                "Views/BeliefShiftMatrixView.swift",
                "Views/DecisionConsequenceChainView.swift",
                "Views/RelationshipEvolutionMapView.swift"
            ]
        )
    ]
)
