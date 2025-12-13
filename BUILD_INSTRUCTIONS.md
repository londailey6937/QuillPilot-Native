# QuillPilot Native - Build Instructions

## To Build and Run with Xcode (Recommended)

Since this is a GUI macOS app using AppKit, you need to build it with Xcode:

### Step 1: Create Xcode Project

```bash
cd /Users/londailey/QuillPilot/QuillPilotNative
open -a Xcode
```

Then in Xcode:

1. File → New → Project
2. Choose "macOS" → "App"
3. Product Name: "QuillPilot"
4. Interface: "Storyboard" (we'll replace with programmatic UI)
5. Language: "Swift"
6. Save to: `/Users/londailey/QuillPilot/QuillPilotNative`

### Step 2: Replace Generated Files

1. Delete the generated `AppDelegate.swift`, `ViewController.swift`, and `Main.storyboard`
2. Add existing files to the project:
   - Right-click project → Add Files
   - Select all files from `Sources/`, `Controllers/`, `Models/`
   - Make sure "Copy items if needed" is **unchecked** (they're already in place)
   - Add `Resources/Info.plist` as the app's Info.plist

### Step 3: Configure Build Settings

1. Select project in navigator
2. General tab:
   - Deployment Target: macOS 13.0
   - Bundle Identifier: com.quillpilot.app
3. Build Settings tab:
   - Search for "Info.plist File"
   - Set to: `QuillPilotNative/Resources/Info.plist`

### Step 4: Update Info.plist

Edit `Resources/Info.plist` and remove the storyboard reference:

- Delete the key `NSMainStoryboardFile`
- This allows the app to launch programmatically

### Step 5: Build and Run

Press Cmd+R or click the Play button in Xcode

---

## What You'll See

The app will launch with:

- **Main window** with toolbar (Bold, Italic, Analyze, Analysis Panel buttons)
- **Text editor** with cream background and placeholder text
- **Analysis sidebar** (initially visible, toggle with toolbar button)
- Click "Analyze" to see writing analysis results

---

## Quick Test

1. Delete the placeholder text
2. Paste or type some sample writing
3. Click **Analyze** button
4. See results in the right sidebar:
   - Word/sentence count
   - Paragraph length warnings
   - Passive voice detection
   - Sensory detail suggestions

---

## Troubleshooting

**"No such module 'Cocoa'"**

- Make sure you selected "macOS App" not iOS
- Check deployment target is macOS 13.0+

**"Main.storyboard not found"**

- Remove `NSMainStoryboardFile` from Info.plist
- The app uses programmatic UI via AppDelegate

**Build succeeds but app doesn't launch**

- Check that AppDelegate is marked with `@main`
- Verify Info.plist path in Build Settings

---

## File Structure Created

```
QuillPilotNative/
├── Sources/
│   └── AppDelegate.swift          ← App entry point (@main)
├── Controllers/
│   ├── MainWindowController.swift ← Window + toolbar setup
│   ├── SplitViewController.swift  ← Coordinates editor + sidebar
│   ├── EditorViewController.swift ← NSTextView editor (cream bg)
│   └── AnalysisViewController.swift ← Shows analysis results
├── Models/
│   └── AnalysisEngine.swift       ← Text analysis algorithms
├── Resources/
│   └── Info.plist                 ← App metadata
└── README.md                       ← This file
```

All Swift files are ready to go - just need to create the Xcode project wrapper!
