# QuillPilot Native macOS App

Native macOS writing application with bulletproof text editing powered by NSTextView.

## Features

- **Native Text Editing**: Uses macOS NSTextView for rock-solid stability
- **Real-time Analysis**: Analyzes writing for:
  - Paragraph length and pacing
  - Passive voice detection
  - Sensory detail suggestions
- **Rich Text Formatting**: Bold, italic, and full font control
- **Split View Interface**: Editor + analysis sidebar
- **QuillPilot Branding**: Consistent colors and design

## Building the App

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9+

### Build Instructions

1. Open Terminal and navigate to the QuillPilotNative directory:

   ```bash
   cd /Users/londailey/QuillPilot/QuillPilotNative
   ```

2. Create an Xcode project file. Run this command to generate the project:
   ```bash
   cat > create_project.sh << 'EOF'
   #!/bin/bash
   ```

# This script creates the Xcode project manually

mkdir -p QuillPilot.xcodeproj
cat > QuillPilot.xcodeproj/project.pbxproj << 'PBXPROJ'
// Xcode project configuration will be created via Xcode
PBXPROJ

echo "Please open Xcode and create a new macOS App project named 'QuillPilot'"
echo "Then add the existing Swift files from the Controllers, Models, Sources, and Views folders"
EOF
chmod +x create_project.sh

````

3. **Alternative**: Use Swift Package Manager to build:
```bash
# Create Package.swift in the QuillPilotNative directory
# Then run: swift build
````

### Quick Start (Xcode)

1. Open Xcode
2. Create New Project → macOS → App
3. Name it "QuillPilot"
4. Set deployment target to macOS 13.0
5. Replace the generated files with the files from this directory:
   - Sources/AppDelegate.swift
   - Controllers/\*.swift
   - Models/\*.swift
   - Resources/Info.plist
6. Build and run (Cmd+R)

## Project Structure

```
QuillPilotNative/
├── Sources/
│   └── AppDelegate.swift          # Application entry point
├── Controllers/
│   ├── MainWindowController.swift # Main window + toolbar
│   ├── SplitViewController.swift  # Manages editor + sidebar
│   ├── EditorViewController.swift # NSTextView wrapper
│   └── AnalysisViewController.swift # Analysis results display
├── Models/
│   └── AnalysisEngine.swift       # Text analysis logic
├── Views/
│   └── (future custom views)
└── Resources/
    └── Info.plist                 # App metadata
```

## Architecture

- **MVC Pattern**: Clean separation of concerns
- **Native AppKit**: No web technologies
- **NSTextView**: Bulletproof text editing
- **Delegate Pattern**: Communication between components

## Development Notes

This is a **proof of concept** demonstrating:

- Native text editing stability
- Analysis engine architecture
- UI layout matching web version
- Brand consistency

Future enhancements:

- Document persistence
- Export to DOCX/PDF
- More analysis features
- Preferences/settings
- Auto-save functionality

## Color Scheme

Matches QuillPilot web app:

- Primary Orange: #ef8432
- Navy: #2c3e50
- Cream Background: #fef5e7
- Light Cream: #fffaf3

## License

Copyright © 2025 QuillPilot. All rights reserved.
