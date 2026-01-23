//
//  ThemeManager.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

extension NSPopUpButton {
    /// Apply Quill Pilot's dropdown border styling.
    /// Mirrors the Day-theme orange border used in the main toolbar.
    func qpApplyDropdownBorder(theme: AppTheme) {
        // Ensure consistent geometry so the layer border is actually visible.
        bezelStyle = .rounded
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = 6

        layer?.borderWidth = 1
        layer?.borderColor = theme.pageBorder.cgColor

        needsDisplay = true
    }
}

enum AppTheme: String {
    case day = "day"
    case cream = "cream"
    case night = "night"

    // Page colors
    var pageBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#FFFDF9") ?? .white
        case .cream:
            // Lightest cream (primary page surface)
            return NSColor(hex: "#FFFAF3") ?? .white
        case .night:
            return NSColor(hex: "#1F1F1F") ?? .black
        }
    }

    var pageAround: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#F7EEE0") ?? .lightGray
        case .cream:
            // Main card/background cream
            return NSColor(hex: "#FEF5E7") ?? .lightGray
        case .night:
            return NSColor(hex: "#121212") ?? .darkGray
        }
    }

    var pageBorder: NSColor {
        switch self {
        case .day:
            return .systemOrange
        case .cream:
            // Tome Orange (accent) for borders and separators in Cream mode.
            return NSColor(hex: "#C65A1E") ?? .gray
        case .night:
            return NSColor(hex: "#333333") ?? .gray
        }
    }

    // Text colors
    var textColor: NSColor {
        switch self {
        case .day:
            return NSColor(calibratedWhite: 0.1, alpha: 1.0)
        case .cream:
            return NSColor(hex: "#2C3E50") ?? NSColor(calibratedWhite: 0.1, alpha: 1.0)
        case .night:
            return NSColor(calibratedWhite: 0.9, alpha: 1.0)
        }
    }

    var insertionPointColor: NSColor {
        switch self {
        case .day:
            return NSColor(calibratedWhite: 0.1, alpha: 1.0)
        case .cream:
            return NSColor(hex: "#111827") ?? NSColor(calibratedWhite: 0.1, alpha: 1.0)
        case .night:
            return NSColor(hex: "#FFD479") ?? NSColor(calibratedWhite: 0.9, alpha: 1.0)
        }
    }

    // Header colors
    var headerBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#8B7355") ?? .darkGray  // Warm brown that contrasts with logo
        case .cream:
            // Light tan header so the app feels like a warm manuscript desk.
            return NSColor(hex: "#F7E6D0") ?? .lightGray
        case .night:
            return NSColor(hex: "#2D2D2D") ?? .darkGray
        }
    }

    var headerText: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#FFFDF9") ?? .white
        case .cream:
            return NSColor(hex: "#111827") ?? .black
        case .night:
            return NSColor(hex: "#E8E8E8") ?? .white
        }
    }

    // Toolbar colors
    var toolbarBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#F7EEE0") ?? .lightGray
        case .cream:
            return NSColor(hex: "#F5EAD9") ?? .lightGray
        case .night:
            return NSColor(hex: "#1A1A1A") ?? .black
        }
    }

    // Sidebar colors
    var outlineBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#F7EEE0") ?? .white
        case .cream:
            return NSColor(hex: "#FEF5E7") ?? .white
        case .night:
            return NSColor(hex: "#161616") ?? .black
        }
    }

    // Ruler colors
    var rulerBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#FFFDF9") ?? .white
        case .cream:
            return NSColor(hex: "#FFFAF3") ?? .white
        case .night:
            return NSColor(hex: "#1E1E1E") ?? .black
        }
    }

    var rulerBorder: NSColor {
        switch self {
        case .day:
            return .systemOrange
        case .cream:
            return NSColor(hex: "#C65A1E") ?? .gray
        case .night:
            return NSColor(hex: "#333333") ?? .gray
        }
    }

    var rulerMarkings: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#684F3C") ?? .gray
        case .cream:
            // Stone gray for legend/secondary marks
            return NSColor(hex: "#78716C") ?? .gray
        case .night:
            return NSColor(hex: "#888888") ?? .lightGray
        }
    }

    // Analysis popup colors
    var popoutTextColor: NSColor {
        switch self {
        case .day:
            return NSColor(calibratedWhite: 0.15, alpha: 1.0)
        case .cream:
            return NSColor(hex: "#111827") ?? NSColor(calibratedWhite: 0.15, alpha: 1.0)
        case .night:
            return NSColor(calibratedWhite: 0.9, alpha: 1.0)
        }
    }

    var popoutSecondaryColor: NSColor {
        switch self {
        case .day:
            return NSColor(calibratedWhite: 0.35, alpha: 1.0)
        case .cream:
            return NSColor(hex: "#6B7280") ?? NSColor(calibratedWhite: 0.35, alpha: 1.0)
        case .night:
            return NSColor(calibratedWhite: 0.7, alpha: 1.0)
        }
    }

    var popoutBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#FFFDF9") ?? .white
        case .cream:
            return NSColor(hex: "#FEF5E7") ?? .white
        case .night:
            return NSColor(hex: "#1F1F1F") ?? .black
        }
    }
}

class ThemeManager {
    static let shared = ThemeManager()

    private let themeKey = "appTheme"

    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
            NotificationCenter.default.post(name: .themeDidChange, object: currentTheme)
        }
    }

    /// Returns true if the current theme is a dark theme
    var isDarkMode: Bool {
        return currentTheme == .night
    }

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey) {
            if savedTheme == "dusk" {
                currentTheme = .night
            } else if let theme = AppTheme(rawValue: savedTheme) {
                currentTheme = theme
            } else {
                currentTheme = .cream
            }
        } else {
            // Default new installs to the warm Cream theme for experimentation.
            currentTheme = .cream
        }
    }

    func toggleTheme() {
        switch currentTheme {
        case .day:
            currentTheme = .cream
        case .cream:
            currentTheme = .night
        case .night:
            currentTheme = .day
        }
    }
}

extension Notification.Name {
    nonisolated static let themeDidChange = Notification.Name("themeDidChange")
}
