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
            path: ".",
            exclude: ["README.md"],
            sources: [
                "Sources/AppDelegate.swift",
                "Controllers/MainWindowController.swift",
                "Controllers/SplitViewController.swift",
                "Controllers/EditorViewController.swift",
                "Controllers/AnalysisViewController.swift",
                "Models/AnalysisEngine.swift",
                "Utilities/ThemeManager.swift",
                "Utilities/StyleCatalog.swift",
                "Views/DocumentInfoPanel.swift",
                "Views/RulerView.swift",
                "Views/HeaderFooterSettingsWindow.swift",
                "Views/StyleEditorWindow.swift",
                "Views/DocumentationWindow.swift"
            ],
            resources: [
                .process("Resources/Info.plist")
            ]
        )
    ]
)
