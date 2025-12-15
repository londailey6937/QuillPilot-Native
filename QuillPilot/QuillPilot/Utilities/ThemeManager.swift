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
        // Page surface
        return NSColor(hex: "#FFFDF9") ?? .white
    }

    var pageAround: NSColor {
        // Surrounding area
        return NSColor(hex: "#F7EEE0") ?? .lightGray
    }

    var pageBorder: NSColor {
        return NSColor(hex: "#CEBCA7") ?? .gray
    }

    // Text colors
    var textColor: NSColor {
        // Near-black for readability
        return NSColor(calibratedWhite: 0.1, alpha: 1.0)
    }

    var insertionPointColor: NSColor {
        return NSColor(calibratedWhite: 0.1, alpha: 1.0)
    }

    // Header colors
    var headerBackground: NSColor {
        return NSColor(hex: "#684F3C") ?? .darkGray
    }

    var headerText: NSColor {
        return NSColor(hex: "#FFFDF9") ?? .white
    }

    // Toolbar colors
    var toolbarBackground: NSColor {
        return NSColor(hex: "#F7EEE0") ?? .lightGray
    }

    // Sidebar colors
    var outlineBackground: NSColor {
        return NSColor(hex: "#F7EEE0") ?? .white
    }

    var analysisBackground: NSColor {
        return NSColor(hex: "#FFFDF9") ?? .white
    }

    // Ruler colors
    var rulerBackground: NSColor {
        return NSColor(hex: "#FFFDF9") ?? .white
    }

    var rulerBorder: NSColor {
        return NSColor(hex: "#CEBCA7") ?? .gray
    }

    var rulerMarkings: NSColor {
        return NSColor(hex: "#684F3C") ?? .gray
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
