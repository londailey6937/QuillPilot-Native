//
//  SubmissionTrackerView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

/// Main view for tracking poetry submissions
struct SubmissionTrackerView: View {
    @State private var submissions: [Submission] = []
    @State private var selectedSubmissionId: Submission.ID?
    @State private var showingNewSubmission = false
    @State private var searchText = ""
    @State private var showingStatistics = false
    @Environment(\.colorScheme) private var colorScheme
    private var themeAccent: Color { Color(ThemeManager.shared.currentTheme.pageBorder) }

    var body: some View {
        NavigationView {
            // Sidebar with filters
            VStack(spacing: 0) {
                // Search
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                // Status filters
                List {
                    Section("Status") {
                        StatusRow(title: "All", count: submissions.count)

                        ForEach(Submission.SubmissionStatus.allCases, id: \.self) { status in
                            let count = submissions.filter { $0.status == status }.count
                            StatusRow(title: "\(status.emoji) \(status.rawValue)", count: count)
                        }
                    }

                    Section {
                        Button(action: { showingStatistics = true }) {
                            Label("View Statistics", systemImage: "chart.pie")
                        }
                        .buttonStyle(ThemedActionButtonStyle())
                    }
                }
            }
            .frame(minWidth: 180)

            // Main content
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("Submissions")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingNewSubmission = true }) {
                        Label("New Submission", systemImage: "plus")
                    }
                    .buttonStyle(ThemedActionButtonStyle())
                }
                .padding()

                Divider()

                // Submission list
                if filteredSubmissions.isEmpty {
                    EmptySubmissionsView()
                } else {
                    List {
                        ForEach(filteredSubmissions) { submission in
                            SubmissionRow(submission: submission)
                                .listRowBackground(
                                    selectedSubmissionId == submission.id
                                        ? themeAccent.opacity(0.2)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSubmissionId = submission.id
                                }
                        }
                    }
                }
            }

            // Detail view
            if let id = selectedSubmissionId,
               let selected = submissions.first(where: { $0.id == id }) {
                SubmissionDetailView(
                    submission: selected,
                    onSave: { updated, refresh in
                        SubmissionManager.shared.updateSubmission(updated)
                        if refresh {
                            refreshSubmissions()
                        } else {
                            // Keep UI in sync without disrupting editing focus.
                            if let index = submissions.firstIndex(where: { $0.id == updated.id }) {
                                submissions[index] = updated
                            }
                        }
                    },
                    onDelete: {
                        SubmissionManager.shared.deleteSubmission(id: selected.id)
                        selectedSubmissionId = nil
                        refreshSubmissions()
                    }
                )
            } else {
                Text("Select a submission")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingNewSubmission) {
            NewSubmissionSheet { poem, publication, type in
                _ = SubmissionManager.shared.createSubmission(
                    poemTitle: poem,
                    publicationName: publication,
                    publicationType: type
                )
                refreshSubmissions()
            }
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsSheet(statistics: SubmissionManager.shared.getStatistics())
        }
        .onAppear {
            refreshSubmissions()
        }
        .tint(themeAccent)
        .accentColor(themeAccent)
    }

    private var filteredSubmissions: [Submission] {
        var result = submissions

        if !searchText.isEmpty {
            result = result.filter {
                $0.poemTitle.localizedCaseInsensitiveContains(searchText) ||
                $0.publicationName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private func refreshSubmissions() {
        submissions = SubmissionManager.shared.getSubmissions()
        // Preserve selection across refreshes.
        if let id = selectedSubmissionId, !submissions.contains(where: { $0.id == id }) {
            selectedSubmissionId = nil
        }
    }
}

struct StatusRow: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct SubmissionRow: View {
    let submission: Submission

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(submission.poemTitle)
                    .font(.headline)
                Spacer()
                StatusBadge(status: submission.status)
            }

            HStack {
                Text(submission.publicationName)
                    .foregroundColor(.secondary)
                Spacer()
                if let days = submission.daysSinceSubmission {
                    Text("\(days) days")
                        .font(.caption)
                        .foregroundColor(days > 90 ? .orange : .secondary)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: Submission.SubmissionStatus
    private var themeAccent: Color { Color(ThemeManager.shared.currentTheme.pageBorder) }

    var color: Color {
        switch status {
        case .draft: return .gray
        case .submitted: return themeAccent
        case .underReview: return .orange
        case .accepted: return .green
        case .rejected: return .red
        case .withdrawn: return .purple
        case .published: return .teal
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct SubmissionDetailView: View {
    let submission: Submission
    var onSave: (_ updated: Submission, _ refreshList: Bool) -> Void
    var onDelete: () -> Void

    @State private var edited: Submission
    @State private var hasUnsavedChanges = false

    init(submission: Submission, onSave: @escaping (_ updated: Submission, _ refreshList: Bool) -> Void, onDelete: @escaping () -> Void) {
        self.submission = submission
        self.onSave = onSave
        self.onDelete = onDelete
        _edited = State(initialValue: submission)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(edited.poemTitle)
                        .font(.title)
                    Text("Submitted to \(edited.publicationName)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                // Status picker
                HStack {
                    Text("Status")
                        .fontWeight(.medium)
                    Picker("", selection: $edited.status) {
                        ForEach(Submission.SubmissionStatus.allCases, id: \.self) { status in
                            Text("\(status.emoji) \(status.rawValue)").tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .onChange(of: edited.status) { _ in
                    // Auto-save status changes immediately (no extra click required).
                    hasUnsavedChanges = true
                    onSave(edited, false)
                    hasUnsavedChanges = false
                }

                Divider()

                // Details grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    DetailField(label: "Type", value: edited.publicationType.rawValue)
                    DetailField(label: "Submitted", value: formatDate(edited.submittedAt))

                    if let responded = edited.respondedAt {
                        DetailField(label: "Responded", value: formatDate(responded))
                    }

                    if let deadline = edited.responseDeadline {
                        DetailField(label: "Expected Response", value: formatDate(deadline))
                    }

                    if let fee = edited.fee, fee > 0 {
                        DetailField(label: "Fee Paid", value: String(format: "$%.2f", fee))
                    }

                    if let payment = edited.payment, payment > 0 {
                        DetailField(label: "Payment", value: String(format: "$%.2f", payment))
                    }
                }

                Divider()

                // Notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .fontWeight(.medium)
                    TextEditor(text: $edited.notes)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(4)
                }
                .onChange(of: edited.notes) { _ in
                    hasUnsavedChanges = true
                }

                // Confirmation number
                if !edited.confirmationNumber.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confirmation #")
                            .fontWeight(.medium)
                        Text(edited.confirmationNumber)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Spacer()

                // Actions
                HStack {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }

                    Spacer()

                    Button("Revert") {
                        edited = submission
                        hasUnsavedChanges = false
                    }
                    .disabled(!hasUnsavedChanges)

                    Button(action: {
                        onSave(edited, true)
                        hasUnsavedChanges = false
                    }) {
                        Label("Save Changes", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(ThemedActionButtonStyle())
                    .disabled(!hasUnsavedChanges)
                }
            }
            .padding()
        }
        .onAppear {
            syncFromSelected(force: true)
        }
        .onChange(of: submission.id) { _ in
            syncFromSelected(force: true)
        }
        .onChange(of: submission.status) { _ in
            syncFromSelected()
        }
        .onChange(of: submission.notes) { _ in
            syncFromSelected()
        }
    }

    // Keep edit buffer in sync when the selection changes or when the model refreshes.
    // Avoid clobbering in-progress edits (e.g. while typing notes).
    private func syncFromSelected(force: Bool = false) {
        if force || !hasUnsavedChanges {
            edited = submission
            hasUnsavedChanges = false
        } else if edited.id != submission.id {
            edited = submission
            hasUnsavedChanges = false
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct DetailField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

struct EmptySubmissionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "paperplane")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Submissions Yet")
                .font(.title2)
            Text("Track where you've sent your poems and their status.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NewSubmissionSheet: View {
    @State private var poemTitle = ""
    @State private var publicationName = ""
    @State private var publicationType: Submission.PublicationType = .literaryMagazine
    @Environment(\.dismiss) private var dismiss

    var onCreate: (String, String, Submission.PublicationType) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("New Submission")
                .font(.headline)

            TextField("Poem Title", text: $poemTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Publication Name", text: $publicationName)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $publicationType) {
                ForEach(Submission.PublicationType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    onCreate(poemTitle, publicationName, publicationType)
                    dismiss()
                }
                .disabled(poemTitle.isEmpty || publicationName.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .tint(Color(ThemeManager.shared.currentTheme.pageBorder))
    }
}

struct StatisticsSheet: View {
    let statistics: SubmissionStatistics
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Submission Statistics")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "Total", value: "\(statistics.totalSubmissions)", color: .blue)
                StatCard(title: "Pending", value: "\(statistics.pending)", color: .orange)
                StatCard(title: "Accepted", value: "\(statistics.accepted)", color: .green)
                StatCard(title: "Rejected", value: "\(statistics.rejected)", color: .red)
                StatCard(title: "Published", value: "\(statistics.published)", color: .teal)
                StatCard(title: "Acceptance Rate", value: String(format: "%.1f%%", statistics.acceptanceRate), color: .purple)
            }

            if let avgDays = statistics.averageResponseDays {
                Text("Average response time: \(Int(avgDays)) days")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Total fees: $\(String(format: "%.2f", statistics.totalFeesPaid))")
                Spacer()
                Text("Total payments: $\(String(format: "%.2f", statistics.totalPaymentsReceived))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400)
        .tint(Color(ThemeManager.shared.currentTheme.pageBorder))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Equatable

extension Submission: Equatable, Hashable {
    static func == (lhs: Submission, rhs: Submission) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Window Controller

final class SubmissionTrackerWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Submission Tracker"
        window.center()
        window.isReleasedWhenClosed = false

        // Apply theme appearance
        let isDarkMode = ThemeManager.shared.isDarkMode
        window.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)

        self.init(window: window)
        window.delegate = self

        let hostingView = FirstMouseHostingView(rootView: SubmissionTrackerView())
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
}

// MARK: - Preview

#if DEBUG
struct SubmissionTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        SubmissionTrackerView()
            .frame(width: 900, height: 600)
    }
}
#endif
