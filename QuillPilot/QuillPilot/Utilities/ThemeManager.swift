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
        case .day: return NSColor(hex: "#fef5e7") ?? .white
        case .night: return NSColor(hex: "#1e1e1e") ?? .black
        }
    }
    
    var pageAround: NSColor {
        switch self {
        case .day: return NSColor(hex: "#f5f0e8") ?? .lightGray
        case .night: return NSColor(hex: "#121212") ?? .black
        }
    }
    
    var pageBorder: NSColor {
        switch self {
        case .day: return NSColor(hex: "#d4c5b0") ?? .gray
        case .night: return NSColor(hex: "#3a3a3a") ?? .darkGray
        }
    }
    
    // Text colors
    var textColor: NSColor {
        switch self {
        case .day: return NSColor(hex: "#2c3e50") ?? .black
        case .night: return NSColor(hex: "#e0e0e0") ?? .white
        }
    }
    
    var insertionPointColor: NSColor {
        switch self {
        case .day: return NSColor(hex: "#2c3e50") ?? .black
        case .night: return NSColor(hex: "#ffffff") ?? .white
        }
    }
    
    // Header colors
    var headerBackground: NSColor {
        switch self {
        case .day: return NSColor(hex: "#2c3e50") ?? .darkGray
        case .night: return NSColor(hex: "#0d1117") ?? .black
        }
    }
    
    var headerText: NSColor {
        switch self {
        case .day: return NSColor(hex: "#fef5e7") ?? .white
        case .night: return NSColor(hex: "#c9d1d9") ?? .lightGray
        }
    }
    
    // Toolbar colors
    var toolbarBackground: NSColor {
        switch self {
        case .day: return NSColor(hex: "#f5f0e8") ?? .lightGray
        case .night: return NSColor(hex: "#21262d") ?? .darkGray
        }
    }
    
    // Sidebar colors
    var outlineBackground: NSColor {
        switch self {
        case .day: return NSColor(hex: "#f9f4ed") ?? .white
        case .night: return NSColor(hex: "#1c1f26") ?? .black
        }
    }
    
    var analysisBackground: NSColor {
        switch self {
        case .day: return NSColor(hex: "#fffaf3") ?? .white
        case .night: return NSColor(hex: "#161b22") ?? .black
        }
    }
    
    // Ruler colors
    var rulerBackground: NSColor {
        switch self {
        case .day: return NSColor(hex: "#ffffff") ?? .white
        case .night: return NSColor(hex: "#2d333b") ?? .darkGray
        }
    }
    
    var rulerBorder: NSColor {
        switch self {
        case .day: return NSColor(hex: "#d0d0d0") ?? .gray
        case .night: return NSColor(hex: "#444c56") ?? .gray
        }
    }
    
    var rulerMarkings: NSColor {
        switch self {
        case .day: return NSColor(hex: "#666666") ?? .gray
        case .night: return NSColor(hex: "#8b949e") ?? .lightGray
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
