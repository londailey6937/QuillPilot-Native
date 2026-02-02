//
//  DraftVersionView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

/// View for managing draft versions of a document
struct DraftVersionView: View {
    let documentId: String
    @State private var drafts: [DraftVersion] = []
    @State private var selectedDraftId: DraftVersion.ID?
    @State private var compareMode = false
    @State private var compareDraft1: DraftVersion?
    @State private var compareDraft2: DraftVersion?
    @State private var comparisonResult: DraftComparison?
    @Environment(\.colorScheme) private var colorScheme
    private var themeAccent: Color { Color(ThemeManager.shared.currentTheme.pageBorder) }

    var onRestoreDraft: ((String) -> Void)?
    var currentContent: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.secondary)
                Text("Draft Versions")
                    .font(.headline)
                Spacer()

                Toggle("Compare", isOn: $compareMode)
                    .toggleStyle(.switch)

                Button("Save Draft") {
                    saveDraft()
                }
                .buttonStyle(ThemedActionButtonStyle())
            }
            .padding()

            Divider()

            if drafts.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Saved Drafts")
                        .font(.title3)
                    Text("Save drafts to track your revision history")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if compareMode {
                // Comparison mode
                ComparisonView(
                    drafts: drafts,
                    draft1: $compareDraft1,
                    draft2: $compareDraft2,
                    comparison: $comparisonResult
                )
            } else {
                // Normal list mode
                HSplitView {
                    // Draft list
                    List {
                        ForEach(drafts) { draft in
                            DraftRow(draft: draft, isSelected: selectedDraftId == draft.id)
                                .listRowBackground(
                                    selectedDraftId == draft.id
                                        ? themeAccent.opacity(0.2)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedDraftId = draft.id
                                }
                        }
                    }
                    .frame(minWidth: 200)

                    // Draft detail
                    if let id = selectedDraftId,
                       let draft = drafts.first(where: { $0.id == id }) {
                        DraftDetailView(
                            draft: draft,
                            onRestore: { onRestoreDraft?(draft.content) },
                            onDelete: { deleteDraft(draft) },
                            onUpdateNotes: { notes in
                                DraftVersionManager.shared.updateDraftNotes(
                                    id: draft.id,
                                    documentId: documentId,
                                    notes: notes
                                )
                                refreshDrafts()
                            }
                        )
                    } else {
                        Text("Select a draft to view")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onAppear {
            refreshDrafts()
        }
        .tint(themeAccent)
        .accentColor(themeAccent)
    }

    private func refreshDrafts() {
        drafts = DraftVersionManager.shared.getDrafts(for: documentId)
    }

    private func saveDraft() {
        _ = DraftVersionManager.shared.saveDraft(
            documentId: documentId,
            content: currentContent
        )
        refreshDrafts()
    }

    private func deleteDraft(_ draft: DraftVersion) {
        DraftVersionManager.shared.deleteDraft(id: draft.id, documentId: documentId)
        selectedDraftId = nil
        refreshDrafts()
    }
}

struct DraftRow: View {
    let draft: DraftVersion
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(draft.title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
                Text("v\(draft.versionNumber)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }

            HStack {
                Text(formatDate(draft.createdAt))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                Spacer()
                Text("\(draft.wordCount) words")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DraftDetailView: View {
    let draft: DraftVersion
    var onRestore: () -> Void
    var onDelete: () -> Void
    var onUpdateNotes: (String) -> Void

    @State private var notes: String = ""
    @State private var showingContent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(draft.title)
                        .font(.title2)
                    Text("Version \(draft.versionNumber) • \(formatDate(draft.createdAt))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Stats
            HStack(spacing: 20) {
                StatBox(label: "Words", value: "\(draft.wordCount)")
                StatBox(label: "Characters", value: "\(draft.characterCount)")
            }

            Divider()

            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $notes)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(4)
                    .onChange(of: notes) { newValue in
                        onUpdateNotes(newValue)
                    }
            }

            // Content preview toggle
            DisclosureGroup("Content Preview", isExpanded: $showingContent) {
                ScrollView {
                    Text(draft.content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }

            Spacer()

            // Actions
            HStack {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }

                Spacer()

                Button(action: onRestore) {
                    Label("Restore This Draft", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(ThemedActionButtonStyle())
            }
        }
        .padding()
        .onAppear {
            notes = draft.notes
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ComparisonView: View {
    let drafts: [DraftVersion]
    @Binding var draft1: DraftVersion?
    @Binding var draft2: DraftVersion?
    @Binding var comparison: DraftComparison?

    var body: some View {
        VStack(spacing: 12) {
            // Draft selectors
            HStack {
                Picker("Older", selection: $draft1) {
                    Text("Select...").tag(nil as DraftVersion?)
                    ForEach(drafts) { draft in
                        Text("v\(draft.versionNumber) - \(draft.title)").tag(draft as DraftVersion?)
                    }
                }

                Image(systemName: "arrow.right")

                Picker("Newer", selection: $draft2) {
                    Text("Select...").tag(nil as DraftVersion?)
                    ForEach(drafts) { draft in
                        Text("v\(draft.versionNumber) - \(draft.title)").tag(draft as DraftVersion?)
                    }
                }

                Button("Compare") {
                    if let d1 = draft1, let d2 = draft2 {
                        comparison = DraftVersionManager.shared.compare(
                            draftId1: d1.id,
                            draftId2: d2.id,
                            documentId: d1.documentId
                        )
                    }
                }
                .disabled(draft1 == nil || draft2 == nil)
            }
            .padding()

            Divider()

            // Comparison results
            if let comp = comparison {
                ScrollView {
                    Text(comp.generateDiff())
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                Text("Select two drafts to compare")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Equatable Conformance

extension DraftVersion: Equatable, Hashable {
    static func == (lhs: DraftVersion, rhs: DraftVersion) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Window Controller

final class DraftVersionWindowController: NSWindowController, NSWindowDelegate {

    var documentId: String = ""
    var currentContent: String = ""
    var onRestoreDraft: ((String) -> Void)?

    convenience init(documentId: String, currentContent: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Draft Versions"
        window.center()
        window.isReleasedWhenClosed = false

        // Apply theme appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        self.init(window: window)
        self.documentId = documentId
        self.currentContent = currentContent
        window.delegate = self
        updateContent()
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

    func updateContent() {
        let view = DraftVersionView(
            documentId: documentId,
            onRestoreDraft: { [weak self] content in
                self?.onRestoreDraft?(content)
            },
            currentContent: currentContent
        )
        window?.contentView = FirstMouseHostingView(rootView: view)
    }
}

// MARK: - Preview

#if DEBUG
struct DraftVersionView_Previews: PreviewProvider {
    static var previews: some View {
        DraftVersionView(documentId: "preview-doc")
            .frame(width: 600, height: 500)
    }
}
#endif
