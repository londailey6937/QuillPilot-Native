//
//  ThemedButtonStyle.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2026 QuillPilot. All rights reserved.
//

import SwiftUI

/// Themed button style matching QuillPilot's AppTheme colors.
struct ThemedActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let theme = ThemeManager.shared.currentTheme
        let background = Color(theme.pageBackground)
        let border = Color(theme.pageBorder)
        let text = Color(theme.textColor)

        return configuration.label
            .foregroundColor(text)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(background.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(border, lineWidth: 1)
            )
    }
}

/// Themed destructive button style (no system red/blue chrome).
struct ThemedDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let theme = ThemeManager.shared.currentTheme
        let background = Color(theme.pageBackground)
        let border = Color(NSColor.systemRed)

        return configuration.label
            .foregroundColor(border)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(background.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(border, lineWidth: 1)
            )
    }
}
