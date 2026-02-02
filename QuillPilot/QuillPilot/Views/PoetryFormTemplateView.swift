//
//  PoetryFormTemplateView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

/// A view for selecting and viewing poetry form templates
struct PoetryFormTemplateView: View {
    @State private var selectedForm: PoetryFormTemplate = PoetryFormTemplate.freeVerse
    @State private var showingExample: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    private var themeAccent: Color { Color(ThemeManager.shared.currentTheme.pageBorder) }

    var onInsertTemplate: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "text.book.closed")
                    .foregroundColor(.secondary)
                Text("Poetry Forms")
                    .font(.headline)
                Spacer()
            }

            // Form picker
            Picker("Form", selection: $selectedForm) {
                ForEach(PoetryFormTemplate.allForms, id: \.name) { form in
                    Text(form.name).tag(form)
                }
            }
            .pickerStyle(.menu)
            .tint(themeAccent)

            // Description
            Text(selectedForm.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)

            Divider()

            // Toggle between structure and example
            Picker("View", selection: $showingExample) {
                Text("Structure").tag(false)
                Text("Example").tag(true)
            }
            .pickerStyle(.segmented)
            .tint(themeAccent)

            // Content area
            ScrollView {
                Text(showingExample ? selectedForm.example : selectedForm.structure)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
            )

            // Rules
            VStack(alignment: .leading, spacing: 4) {
                Text("Rules:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ForEach(selectedForm.rules, id: \.self) { rule in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(rule)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 4)

            // Insert button
            if onInsertTemplate != nil {
                Button(action: {
                    onInsertTemplate?(selectedForm.structure)
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Insert Template")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ThemedActionButtonStyle())
                .padding(.top, 8)
            }
        }
        .padding()
        .tint(themeAccent)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.windowBackgroundColor) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Form Template Equatable

extension PoetryFormTemplate: Equatable, Hashable {
    static func == (lhs: PoetryFormTemplate, rhs: PoetryFormTemplate) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// MARK: - NSViewRepresentable for AppKit Integration

struct PoetryFormTemplateHostingView: NSViewRepresentable {
    var onInsertTemplate: ((String) -> Void)?

    func makeNSView(context: Context) -> NSHostingView<PoetryFormTemplateView> {
        let view = NSHostingView(rootView: PoetryFormTemplateView(onInsertTemplate: onInsertTemplate))
        return view
    }

    func updateNSView(_ nsView: NSHostingView<PoetryFormTemplateView>, context: Context) {
        nsView.rootView = PoetryFormTemplateView(onInsertTemplate: onInsertTemplate)
    }
}

// MARK: - Form Template Window Controller

final class PoetryFormTemplateWindowController: NSWindowController, NSWindowDelegate {

    var onInsertTemplate: ((String) -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Poetry Form Templates"
        window.center()
        window.isReleasedWhenClosed = false

        // Apply theme appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        self.init(window: window)
        window.delegate = self

        let hostingView = FirstMouseHostingView(rootView: PoetryFormTemplateView(onInsertTemplate: { [weak self] template in
            self?.onInsertTemplate?(template)
        }))
        window.contentView = hostingView
    }

    // Close window when it loses key status (user clicks elsewhere)
    // but NOT if a sheet is attached (modal dialog open)
    func windowDidResignKey(_ notification: Notification) {
        guard let window = window else { return }
        // Don't close if a sheet is currently presented
        if window.attachedSheet != nil {
            return
        }
        window.close()
    }

    func showWindow(relativeTo parentWindow: NSWindow?) {
        guard let window = window else { return }

        if let parent = parentWindow {
            let parentFrame = parent.frame
            let windowFrame = window.frame
            let newOrigin = NSPoint(
                x: parentFrame.maxX + 20,
                y: parentFrame.midY - windowFrame.height / 2
            )
            window.setFrameOrigin(newOrigin)
        }

        showWindow(self)
    }
}

// MARK: - Preview

#if DEBUG
struct PoetryFormTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        PoetryFormTemplateView()
            .frame(width: 400)
            .padding()
    }
}
#endif
