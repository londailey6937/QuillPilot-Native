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
    case night = "night"

    // Page colors
    var pageBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#FFFDF9") ?? .white
        case .night:
            return NSColor(hex: "#1F1F1F") ?? .black
        }
    }

    var pageAround: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#F7EEE0") ?? .lightGray
        case .night:
            return NSColor(hex: "#121212") ?? .darkGray
        }
    }

    var pageBorder: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#CEBCA7") ?? .gray
        case .night:
            return NSColor(hex: "#333333") ?? .gray
        }
    }

    // Text colors
    var textColor: NSColor {
        switch self {
        case .day:
            return NSColor(calibratedWhite: 0.1, alpha: 1.0)
        case .night:
            return NSColor(calibratedWhite: 0.9, alpha: 1.0)
        }
    }

    var insertionPointColor: NSColor {
        switch self {
        case .day:
            return NSColor(calibratedWhite: 0.1, alpha: 1.0)
        case .night:
            return NSColor(hex: "#FFD479") ?? NSColor(calibratedWhite: 0.9, alpha: 1.0)
        }
    }

    // Header colors
    var headerBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#684F3C") ?? .darkGray
        case .night:
            return NSColor(hex: "#2A2A2A") ?? .darkGray
        }
    }

    var headerText: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#FFFDF9") ?? .white
        case .night:
            return NSColor(hex: "#E8E8E8") ?? .white
        }
    }

    // Toolbar colors
    var toolbarBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#F7EEE0") ?? .lightGray
        case .night:
            return NSColor(hex: "#1A1A1A") ?? .black
        }
    }

    // Sidebar colors
    var outlineBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#F7EEE0") ?? .white
        case .night:
            return NSColor(hex: "#161616") ?? .black
        }
    }

    // Ruler colors
    var rulerBackground: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#FFFDF9") ?? .white
        case .night:
            return NSColor(hex: "#1E1E1E") ?? .black
        }
    }

    var rulerBorder: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#CEBCA7") ?? .gray
        case .night:
            return NSColor(hex: "#333333") ?? .gray
        }
    }

    var rulerMarkings: NSColor {
        switch self {
        case .day:
            return NSColor(hex: "#684F3C") ?? .gray
        case .night:
            return NSColor(hex: "#888888") ?? .lightGray
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

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        } else {
            currentTheme = .day
        }
    }

    func toggleTheme() {
        currentTheme = (currentTheme == .day) ? .night : .day
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
