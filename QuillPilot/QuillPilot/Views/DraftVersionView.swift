//
//  DraftVersionView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

private struct RatioHSplitView<Left: View, Right: View>: NSViewControllerRepresentable {
    let ratio: CGFloat
    let resetToken: UUID
    let left: Left
    let right: Right

    func makeNSViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.set(left: AnyView(left), right: AnyView(right))
        controller.setRatio(ratio)
        controller.requestReset(to: resetToken)
        return controller
    }

    func updateNSViewController(_ nsViewController: Controller, context: Context) {
        nsViewController.set(left: AnyView(left), right: AnyView(right))
        nsViewController.setRatio(ratio)
        nsViewController.requestReset(to: resetToken)
    }

    final class Controller: NSSplitViewController {
        private let leftHost = NSHostingController(rootView: AnyView(EmptyView()))
        private let rightHost = NSHostingController(rootView: AnyView(EmptyView()))
        private var desiredRatio: CGFloat = 0.5
        private var lastResetToken: UUID?

        override func viewDidLoad() {
            super.viewDidLoad()

            let leftItem = NSSplitViewItem(viewController: leftHost)
            let rightItem = NSSplitViewItem(viewController: rightHost)

            addSplitViewItem(leftItem)
            addSplitViewItem(rightItem)

            splitView.isVertical = true
            splitView.dividerStyle = .thin
        }

        override func viewDidLayout() {
            super.viewDidLayout()
            applyRatioIfPossible()
        }

        func set(left: AnyView, right: AnyView) {
            leftHost.rootView = left
            rightHost.rootView = right
        }

        func setRatio(_ ratio: CGFloat) {
            desiredRatio = max(0.1, min(0.9, ratio))
        }

        func requestReset(to token: UUID) {
            guard token != lastResetToken else { return }
            lastResetToken = token
            applyRatioIfPossible()
        }

        private func applyRatioIfPossible() {
            guard splitView.arrangedSubviews.count >= 2 else { return }
            let totalWidth = splitView.bounds.width
            guard totalWidth > 10 else { return }
            splitView.setPosition(totalWidth * desiredRatio, ofDividerAt: 0)
        }
    }
}

/// View for managing draft versions of a document
struct DraftVersionView: View {
    let documentId: String
    @State private var drafts: [DraftVersion] = []
    @State private var selectedDraftId: DraftVersion.ID?
    @State private var compareMode = false
    @State private var compareDraft1: DraftVersion?
    @State private var compareDraft2: DraftVersion?
    @State private var comparisonResult: DraftComparison?
    @State private var splitResetToken = UUID()
    @State private var themeRefreshToken = UUID()
    @Environment(\.colorScheme) private var colorScheme
    private var themeAccent: Color { Color(ThemeManager.shared.currentTheme.pageBorder) }

    var onRestoreDraft: ((DraftVersion) -> Void)?
    var currentContentProvider: (() -> String)?
    var currentFormattedSnapshotProvider: (() -> String?)?

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
                RatioHSplitView(
                    ratio: 0.5,
                    resetToken: splitResetToken,
                    left: List {
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
                    .frame(minWidth: 240),
                    right: Group {
                        if let id = selectedDraftId,
                           let draft = drafts.first(where: { $0.id == id }) {
                            DraftDetailView(
                                draft: draft,
                                onRestore: { onRestoreDraft?(draft) },
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
                )
            }
        }
        .onAppear {
            refreshDrafts()
            splitResetToken = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
            // Force a rebuild so accent/background update immediately.
            themeRefreshToken = UUID()
        }
        .onChange(of: selectedDraftId) { _ in
            splitResetToken = UUID()
        }
        .id(themeRefreshToken)
        .tint(themeAccent)
        .accentColor(themeAccent)
    }

    private func refreshDrafts() {
        drafts = DraftVersionManager.shared.getDrafts(for: documentId)
    }

    private func saveDraft() {
        let content = currentContentProvider?() ?? ""
        let fileReference = currentFormattedSnapshotProvider?()
        _ = DraftVersionManager.shared.saveDraft(
            documentId: documentId,
            content: content,
            fileReference: fileReference
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
        let titleColor: Color = .primary
        let metaColor: Color = isSelected ? .primary.opacity(0.75) : .secondary

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(draft.title)
                    .font(.headline)
                    .foregroundColor(titleColor)
                Spacer()
                Text("v\(draft.versionNumber)")
                    .font(.caption)
                    .foregroundColor(metaColor)
            }

            HStack {
                Text(formatDate(draft.createdAt))
                    .font(.caption)
                    .foregroundColor(metaColor)
                Spacer()
                Text("\(draft.wordCount) words")
                    .font(.caption)
                    .foregroundColor(metaColor)
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
    var currentContentProvider: (() -> String)?
    var currentFormattedSnapshotProvider: (() -> String?)?
    var onRestoreDraft: ((DraftVersion) -> Void)?

    convenience init(
        documentId: String,
        currentContentProvider: @escaping () -> String,
        currentFormattedSnapshotProvider: @escaping () -> String?
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 650),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Draft Versions"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 860, height: 560)

        // Apply theme appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        self.init(window: window)
        self.documentId = documentId
        self.currentContentProvider = currentContentProvider
        self.currentFormattedSnapshotProvider = currentFormattedSnapshotProvider
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
            onRestoreDraft: { [weak self] draft in
                self?.onRestoreDraft?(draft)
            },
            currentContentProvider: currentContentProvider,
            currentFormattedSnapshotProvider: currentFormattedSnapshotProvider
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
