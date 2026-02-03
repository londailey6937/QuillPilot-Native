//
//  PoetryCollectionView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

/// Main view for managing poetry collections
struct PoetryCollectionView: View {
    @State private var collections: [PoetryCollection] = []
    @State private var selectedCollectionId: PoetryCollection.ID?
    @State private var showingNewCollection = false
    @State private var newCollectionTitle = ""
    @State private var newCollectionAuthor = ""
    @State private var dropTargetCollectionId: PoetryCollection.ID?
    @Environment(\.colorScheme) private var colorScheme
    private var themeAccent: Color { Color(ThemeManager.shared.currentTheme.pageBorder) }

    var onSelectPoem: ((PoemEntry) -> Void)?
    var onAddCurrentPoem: ((PoetryCollection) -> Void)?

    var body: some View {
        NavigationView {
            // Sidebar - Collection List
            VStack(spacing: 0) {
                HStack {
                    Text("Collections")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingNewCollection = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()

                Divider()

                List {
                    ForEach(collections) { collection in
                        CollectionRow(collection: collection)
                            .listRowBackground(
                                selectedCollectionId == collection.id
                                    ? themeAccent.opacity(0.2)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCollectionId = collection.id
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    PoetryCollectionManager.shared.deleteCollection(id: collection.id)
                                    collections = PoetryCollectionManager.shared.getCollections()
                                    if selectedCollectionId == collection.id {
                                        selectedCollectionId = nil
                                    }
                                } label: {
                                    Label("Delete Collection", systemImage: "trash")
                                }
                            }
                            .onDrop(
                                of: ["public.utf8-plain-text", "public.file-url"],
                                isTargeted: Binding(
                                    get: { dropTargetCollectionId == collection.id },
                                    set: { isTargeted in
                                        dropTargetCollectionId = isTargeted ? collection.id : nil
                                    }
                                ),
                                perform: { providers in
                                    handleDrop(providers, into: collection.id)
                                }
                            )
                    }
                    .onDelete(perform: deleteCollection)
                }
            }
            .frame(minWidth: 200)

            // Detail View
                if let id = selectedCollectionId,
                    let index = collections.firstIndex(where: { $0.id == id }) {
                CollectionDetailView(
                    collection: Binding(
                        get: { collections[index] },
                        set: { updated in
                            collections[index] = updated
                            PoetryCollectionManager.shared.updateCollection(updated)
                        }
                    ),
                    allCollections: collections,
                    onSelectPoem: onSelectPoem,
                    onAddCurrentPoem: {
                        onAddCurrentPoem?(collections[index])
                        // Refresh the selected collection after adding.
                        if let updated = PoetryCollectionManager.shared.getCollection(id: collections[index].id) {
                            collections[index] = updated
                        }
                    }
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select or Create a Collection")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Collections help you organize poems into chapbooks or full-length manuscripts.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingNewCollection) {
            NewCollectionSheet(
                title: $newCollectionTitle,
                author: $newCollectionAuthor,
                onCreate: createCollection
            )
        }
        .onAppear {
            collections = PoetryCollectionManager.shared.getCollections()
        }
        .tint(themeAccent)
        .accentColor(themeAccent)
    }

    private func createCollection() {
        let collection = PoetryCollectionManager.shared.createCollection(
            title: newCollectionTitle,
            author: newCollectionAuthor
        )
        collections = PoetryCollectionManager.shared.getCollections()
        selectedCollectionId = collection.id
        newCollectionTitle = ""
        newCollectionAuthor = ""
        showingNewCollection = false
    }

    private func deleteCollection(at offsets: IndexSet) {
        for index in offsets {
            PoetryCollectionManager.shared.deleteCollection(id: collections[index].id)
        }
        collections = PoetryCollectionManager.shared.getCollections()
        if let id = selectedCollectionId, !collections.contains(where: { $0.id == id }) {
            selectedCollectionId = nil
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], into collectionId: UUID) -> Bool {
        if let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let text = object as? String else { return }

                // Internal drag-drop: move an existing poem between collections.
                if let payload = PoetryCollectionDragPayload.parse(from: text) {
                    DispatchQueue.main.async {
                        PoetryCollectionManager.shared.movePoem(
                            payload.poemId,
                            from: payload.sourceCollectionId,
                            to: collectionId,
                            sectionId: nil
                        )
                        collections = PoetryCollectionManager.shared.getCollections()
                        return
                    }
                }

                let title = text.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines)
                let safeTitle = (title?.isEmpty == false) ? title! : "Untitled"
                DispatchQueue.main.async {
                    PoetryCollectionManager.shared.addPoem(to: collectionId, title: safeTitle, content: text)
                    collections = PoetryCollectionManager.shared.getCollections()
                }
            }
            return true
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.file-url") }) {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    let title = url.deletingPathExtension().lastPathComponent
                    let content = try? String(contentsOf: url)
                    DispatchQueue.main.async {
                        PoetryCollectionManager.shared.addPoem(to: collectionId, title: title, content: content, fileReference: url.path)
                        collections = PoetryCollectionManager.shared.getCollections()
                    }
                }
            }
            return true
        }

        return false
    }
}

struct CollectionRow: View {
    let collection: PoetryCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(collection.title)
                .font(.headline)
            HStack {
                Text("\(collection.poemCount) poems")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !collection.author.isEmpty {
                    Text("• \(collection.author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CollectionDetailView: View {
    @Binding var collection: PoetryCollection
    let allCollections: [PoetryCollection]
    var onSelectPoem: ((PoemEntry) -> Void)?
    var onAddCurrentPoem: (() -> Void)?

    @State private var showingAddPoem = false
    @State private var showingAddSection = false
    @State private var newPoemTitle = ""
    @State private var newSectionTitle = ""
    @State private var showingTOC = false
    @State private var showingAddedConfirmation = false
    @State private var pendingDeleteSection: CollectionSection?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(collection.title)
                        .font(.title)
                    if !collection.author.isEmpty {
                        Text("by \(collection.author)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    if showingAddedConfirmation {
                        Text("✓ Added")
                            .foregroundColor(.green)
                            .font(.caption)
                            .transition(.opacity)
                    }

                    Button("Add Current Poem") {
                        onAddCurrentPoem?()
                        // Refresh collection to show new poem
                        if let updated = PoetryCollectionManager.shared.getCollection(id: collection.id) {
                            collection = updated
                        }
                        // Show confirmation
                        withAnimation {
                            showingAddedConfirmation = true
                        }
                        // Hide after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingAddedConfirmation = false
                            }
                        }
                    }
                    .buttonStyle(ThemedActionButtonStyle())

                    Button(action: { showingAddSection = true }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("Add Section")

                    Button(action: { showingTOC = true }) {
                        Image(systemName: "list.bullet")
                    }
                    .help("View Table of Contents")
                }
            }
            .padding()

            Divider()

            // Poem list with sections
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    let orderedSections = collection.sections.sorted(by: { $0.order < $1.order })
                    let sectionIds = Set(orderedSections.map { $0.id })
                    let unsectioned = collection.poems
                        .filter { poem in
                            guard let sid = poem.sectionId else { return true }
                            return !sectionIds.contains(sid)
                        }
                        .sorted(by: { $0.order < $1.order })

                    if orderedSections.isEmpty {
                        // No sections - just show poems
                        ForEach(collection.poems.sorted(by: { $0.order < $1.order })) { poem in
                            PoemRow(
                                poem: poem,
                                sourceCollectionId: collection.id,
                                onOpen: { onSelectPoem?(poem) },
                                onRemove: { removePoem(poem) },
                                onMoveToSection: { movePoem(poem, to: $0) },
                                onMoveToCollection: { movePoem(poem, to: $0) },
                                availableSections: collection.sections
                                ,availableCollections: allCollections.filter { $0.id != collection.id }
                            )
                        }
                    } else {
                        // Show by section
                        ForEach(orderedSections) { section in
                            let poemsInSection = collection.poems
                                .filter { $0.sectionId == section.id }
                                .sorted(by: { $0.order < $1.order })

                            Section(header: SectionHeader(
                                title: section.title,
                                onDelete: {
                                pendingDeleteSection = section
                                },
                                onDropPoem: { payload in
                                    handlePoemDrop(payload, to: section.id)
                                }
                            )) {
                                if poemsInSection.isEmpty {
                                    Text("No poems in this section")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 2)
                                } else {
                                    ForEach(poemsInSection) { poem in
                                        PoemRow(
                                            poem: poem,
                                            sourceCollectionId: collection.id,
                                            onOpen: { onSelectPoem?(poem) },
                                            onRemove: { removePoem(poem) },
                                            onMoveToSection: { movePoem(poem, to: $0) },
                                            onMoveToCollection: { movePoem(poem, to: $0) },
                                            availableSections: collection.sections
                                            ,availableCollections: allCollections.filter { $0.id != collection.id }
                                        )
                                    }
                                }
                            }
                        }

                        // Uncategorized
                        if !unsectioned.isEmpty {
                            Section(header: SectionHeader(
                                title: "Uncategorized",
                                onDropPoem: { payload in
                                    handlePoemDrop(payload, to: nil)
                                }
                            )) {
                                ForEach(unsectioned) { poem in
                                    PoemRow(
                                        poem: poem,
                                        sourceCollectionId: collection.id,
                                        onOpen: { onSelectPoem?(poem) },
                                        onRemove: { removePoem(poem) },
                                        onMoveToSection: { movePoem(poem, to: $0) },
                                        onMoveToCollection: { movePoem(poem, to: $0) },
                                        availableSections: collection.sections
                                        ,availableCollections: allCollections.filter { $0.id != collection.id }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            // Statistics footer
            HStack {
                Text("\(collection.poemCount) \(collection.poemCount == 1 ? "poem" : "poems")")
                Spacer()
                if !collection.sections.isEmpty {
                        let count = collection.sections.count
                        Text("\(count) \(count == 1 ? "section" : "sections")")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.windowBackgroundColor))
        }
        .tint(Color(ThemeManager.shared.currentTheme.pageBorder))
        .sheet(isPresented: $showingAddSection) {
            AddSectionSheet(title: $newSectionTitle, onAdd: addSection)
        }
        .sheet(isPresented: $showingTOC) {
            TOCSheet(collection: collection)
        }
        .alert(
            "Delete Section?",
            isPresented: Binding(
                get: { pendingDeleteSection != nil },
                set: { if !$0 { pendingDeleteSection = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let section = pendingDeleteSection else { return }
                PoetryCollectionManager.shared.removeSection(from: collection.id, sectionId: section.id)
                if let updated = PoetryCollectionManager.shared.getCollection(id: collection.id) {
                    withAnimation { collection = updated }
                }
                pendingDeleteSection = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteSection = nil
            }
        } message: {
            if let section = pendingDeleteSection {
                Text("This removes \"\(section.title)\" and moves its poems to Uncategorized.")
            } else {
                Text("This removes the section and moves its poems to Uncategorized.")
            }
        }
    }

    private func addSection() {
        PoetryCollectionManager.shared.addSection(to: collection.id, title: newSectionTitle)
        if let updated = PoetryCollectionManager.shared.getCollection(id: collection.id) {
            collection = updated
        }
        newSectionTitle = ""
        showingAddSection = false
    }

    private func removePoem(_ poem: PoemEntry) {
        PoetryCollectionManager.shared.removePoem(from: collection.id, poemId: poem.id)
        if let updated = PoetryCollectionManager.shared.getCollection(id: collection.id) {
            withAnimation {
                collection = updated
            }
        }
    }

    private func movePoem(_ poem: PoemEntry, to section: CollectionSection?) {
        PoetryCollectionManager.shared.movePoem(poem.id, to: section?.id, in: collection.id)
        if let updated = PoetryCollectionManager.shared.getCollection(id: collection.id) {
            withAnimation {
                collection = updated
            }
        }
    }

    private func movePoem(_ poem: PoemEntry, to destination: PoetryCollection) {
        PoetryCollectionManager.shared.movePoem(poem.id, from: collection.id, to: destination.id, sectionId: nil)
        if let updated = PoetryCollectionManager.shared.getCollection(id: collection.id) {
            withAnimation {
                collection = updated
            }
        }
    }

    private func handlePoemDrop(_ payload: PoetryCollectionDragPayload, to sectionId: UUID?) {
        if payload.sourceCollectionId == collection.id {
            PoetryCollectionManager.shared.movePoem(payload.poemId, to: sectionId, in: collection.id)
        } else {
            PoetryCollectionManager.shared.movePoem(payload.poemId, from: payload.sourceCollectionId, to: collection.id, sectionId: sectionId)
        }
        if let updated = PoetryCollectionManager.shared.getCollection(id: collection.id) {
            withAnimation {
                collection = updated
            }
        }
    }
}

struct PoemRow: View {
    let poem: PoemEntry
    let sourceCollectionId: UUID
    var onOpen: (() -> Void)?
    var onRemove: (() -> Void)?
    var onMoveToSection: ((CollectionSection?) -> Void)?
    var onMoveToCollection: ((PoetryCollection) -> Void)?
    var availableSections: [CollectionSection]
    var availableCollections: [PoetryCollection] = []

    @State private var showingActions = false

    private var themeAccent: Color { Color(ThemeManager.shared.currentTheme.pageBorder) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(poem.title)
                    .font(.body)
                HStack {
                    Text("\(poem.lineCount) lines")
                    Text("•")
                    Text("\(poem.wordCount) words")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if !poem.tags.isEmpty {
                ForEach(poem.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(themeAccent.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
        .onTapGesture { showingActions = true }
        .onDrag {
            NSItemProvider(object: NSString(string: PoetryCollectionDragPayload(sourceCollectionId: sourceCollectionId, poemId: poem.id).serialized))
        }
        .popover(isPresented: $showingActions, arrowEdge: .trailing) {
            PoemActionsPopover(
                poemTitle: poem.title,
                hasSections: !availableSections.isEmpty,
                sections: availableSections.sorted(by: { $0.order < $1.order }),
                collections: availableCollections.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }),
                onOpen: {
                    showingActions = false
                    onOpen?()
                },
                onMoveToSection: { section in
                    showingActions = false
                    onMoveToSection?(section)
                },
                onMoveToCollection: { collection in
                    showingActions = false
                    onMoveToCollection?(collection)
                },
                onRemove: {
                    showingActions = false
                    onRemove?()
                },
                onCancel: {
                    showingActions = false
                }
            )
            .tint(themeAccent)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var onDelete: (() -> Void)? = nil
    var onDropPoem: ((PoetryCollectionDragPayload) -> Void)? = nil

    @State private var isDropTargeted = false

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Delete Section")
            }
        }
        .padding(.vertical, 8)
        .background(isDropTargeted ? Color(ThemeManager.shared.currentTheme.pageBorder).opacity(0.12) : Color.clear)
        .onDrop(
            of: ["public.utf8-plain-text"],
            isTargeted: $isDropTargeted,
            perform: { providers in
                guard let onDropPoem,
                      let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
                    return false
                }
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let text = object as? String,
                          let payload = PoetryCollectionDragPayload.parse(from: text) else { return }
                    DispatchQueue.main.async {
                        onDropPoem(payload)
                    }
                }
                return true
            }
        )
    }
}

struct PoetryCollectionDragPayload {
    let sourceCollectionId: UUID
    let poemId: UUID

    var serialized: String {
        "quillpilot-poem:\(sourceCollectionId.uuidString):\(poemId.uuidString)"
    }

    static func parse(from text: String) -> PoetryCollectionDragPayload? {
        let prefix = "quillpilot-poem:"
        guard text.hasPrefix(prefix) else { return nil }
        let remainder = String(text.dropFirst(prefix.count))
        let parts = remainder.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let sourceId = UUID(uuidString: String(parts[0])),
              let poemId = UUID(uuidString: String(parts[1])) else {
            return nil
        }
        return PoetryCollectionDragPayload(sourceCollectionId: sourceId, poemId: poemId)
    }
}

struct PoemActionsPopover: View {
    let poemTitle: String
    let hasSections: Bool
    let sections: [CollectionSection]
    let collections: [PoetryCollection]
    var onOpen: () -> Void
    var onMoveToSection: (CollectionSection?) -> Void
    var onMoveToCollection: (PoetryCollection) -> Void
    var onRemove: () -> Void
    var onCancel: () -> Void

    @State private var confirmingRemove = false

    private var theme: AppTheme { ThemeManager.shared.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(poemTitle)
                .font(.headline)
                .foregroundColor(Color(theme.textColor))
                .lineLimit(2)

            Divider()

            if confirmingRemove {
                Text("Remove this poem from the collection?")
                    .font(.subheadline)
                    .foregroundColor(Color(theme.textColor))

                HStack {
                    Button("Cancel") {
                        confirmingRemove = false
                    }
                    .buttonStyle(ThemedActionButtonStyle())

                    Spacer()

                    Button("Remove") {
                        onRemove()
                    }
                    .buttonStyle(ThemedDestructiveButtonStyle())
                }
            } else {
                Button("Open Poem") { onOpen() }
                    .buttonStyle(ThemedActionButtonStyle())

                if hasSections {
                    Menu("Move to Section") {
                        Button("Uncategorized") { onMoveToSection(nil) }
                        ForEach(sections) { section in
                            Button(section.title) { onMoveToSection(section) }
                        }
                    }
                }

                if !collections.isEmpty {
                    Menu("Move to Collection") {
                        ForEach(collections) { collection in
                            Button(collection.title) { onMoveToCollection(collection) }
                        }
                    }
                }

                Button("Remove from Collection") {
                    confirmingRemove = true
                }
                .buttonStyle(ThemedDestructiveButtonStyle())

                Button("Cancel") { onCancel() }
                    .buttonStyle(ThemedActionButtonStyle())
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(Color(theme.popoutBackground))
    }
}

struct NewCollectionSheet: View {
    @Binding var title: String
    @Binding var author: String
    var onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("New Collection")
                .font(.headline)

            TextField("Collection Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Author Name", text: $author)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") { onCreate() }
                    .disabled(title.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .tint(Color(ThemeManager.shared.currentTheme.pageBorder))
    }
}

struct AddSectionSheet: View {
    @Binding var title: String
    var onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("New Section")
                .font(.headline)

            Text("Sections group poems within a collection (chapters). You can move poems into a section from the poem’s context menu.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("Section Title", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") { onAdd() }
                    .disabled(title.isEmpty)
            }
        }
        .padding()
        .frame(width: 250)
        .tint(Color(ThemeManager.shared.currentTheme.pageBorder))
    }
}

struct TOCSheet: View {
    let collection: PoetryCollection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Table of Contents")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }

            ScrollView {
                Text(PoetryCollectionManager.shared.generateTableOfContents(for: collection))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Copy to Clipboard") {
                let toc = PoetryCollectionManager.shared.generateTableOfContents(for: collection)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(toc, forType: .string)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

// MARK: - Window Controller

final class PoetryCollectionWindowController: NSWindowController, NSWindowDelegate {

    var onSelectPoem: ((PoemEntry) -> Void)?
    var onAddCurrentPoem: ((PoetryCollection) -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Poetry Collections"
        window.center()
        window.isReleasedWhenClosed = false

        // Apply theme appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        self.init(window: window)
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

    private func updateContent() {
        let hostingView = FirstMouseHostingView(rootView: PoetryCollectionView(
            onSelectPoem: { [weak self] poem in
                self?.onSelectPoem?(poem)
            },
            onAddCurrentPoem: { [weak self] collection in
                self?.onAddCurrentPoem?(collection)
            }
        ))
        window?.contentView = hostingView
    }
}

// MARK: - Preview

#if DEBUG
struct PoetryCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        PoetryCollectionView()
            .frame(width: 700, height: 500)
    }
}
#endif
