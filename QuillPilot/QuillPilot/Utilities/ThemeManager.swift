//
//  ThemeManager.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Cocoa

enum AppTheme: String {
    case day = "day"
    case cream = "cream"
    case night = "night"
    case dusk = "dusk"

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
        case .dusk:
            return NSColor(hex: "#1A1726") ?? .black
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
        case .dusk:
            return NSColor(hex: "#0F0D17") ?? .black
        }
    }

    var pageBorder: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#CEBCA7") ?? .gray
        case .cream:
            // Tome Orange (accent) for borders and separators in Cream mode.
            return NSColor(hex: "#C65A1E") ?? .gray
        case .night:
            return NSColor(hex: "#333333") ?? .gray
        case .dusk:
            return NSColor(hex: "#3A3355") ?? .gray
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
        case .dusk:
            return NSColor(hex: "#E8E5FF") ?? NSColor(calibratedWhite: 0.9, alpha: 1.0)
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
        case .dusk:
            return NSColor(hex: "#FFB86C") ?? NSColor(calibratedWhite: 0.9, alpha: 1.0)
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
        case .dusk:
            return NSColor(hex: "#241E37") ?? .darkGray
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
        case .dusk:
            return NSColor(hex: "#F2F0FF") ?? .white
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
        case .dusk:
            return NSColor(hex: "#151225") ?? .black
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
        case .dusk:
            return NSColor(hex: "#121020") ?? .black
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
        case .dusk:
            return NSColor(hex: "#19162A") ?? .black
        }
    }

    var rulerBorder: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#CEBCA7") ?? .gray
        case .cream:
            return NSColor(hex: "#C65A1E") ?? .gray
        case .night:
            return NSColor(hex: "#333333") ?? .gray
        case .dusk:
            return NSColor(hex: "#3A3355") ?? .gray
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
        case .dusk:
            return NSColor(hex: "#A9A2C6") ?? .lightGray
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
        case .dusk:
            return NSColor(hex: "#EDEAFF") ?? NSColor(calibratedWhite: 0.9, alpha: 1.0)
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
        case .dusk:
            return NSColor(hex: "#B8B2D6") ?? NSColor(calibratedWhite: 0.7, alpha: 1.0)
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
        case .dusk:
            return NSColor(hex: "#1A1726") ?? .black
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
        return currentTheme == .night || currentTheme == .dusk
    }

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            // Light mode (Day) has been removed; migrate any saved Day selection to Cream.
            currentTheme = (theme == .day) ? .cream : theme
        } else {
            // Default new installs to the warm Cream theme for experimentation.
            currentTheme = .cream
        }
    }

    func toggleTheme() {
        // Light mode (Day) is no longer supported.
        // Cycle through the three supported themes for the header toggle.
        switch currentTheme {
        case .night:
            currentTheme = .dusk
        case .dusk:
            currentTheme = .cream
        case .cream, .day:
            currentTheme = .night
        }
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
