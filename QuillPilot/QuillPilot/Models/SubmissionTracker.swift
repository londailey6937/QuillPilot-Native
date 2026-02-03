//
//  SubmissionTracker.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import Foundation
import Combine

// MARK: - Submission Model

/// Represents a poem submission to a publication
struct Submission: Codable, Identifiable {
    let id: UUID
    var poemTitle: String
    var publicationName: String
    var publicationType: PublicationType
    var status: SubmissionStatus
    var submittedAt: Date
    var respondedAt: Date?
    var responseDeadline: Date?
    var fee: Double?
    var payment: Double?
    var notes: String
    var simultaneousSubmissionAllowed: Bool
    var coverLetter: String
    var confirmationNumber: String
    var contactEmail: String
    var websiteURL: String

    enum PublicationType: String, Codable, CaseIterable {
        case literaryMagazine = "Literary Magazine"
        case journal = "Journal"
        case anthology = "Anthology"
        case contest = "Contest"
        case chapbookPress = "Chapbook Press"
        case fullLengthPress = "Full-Length Press"
        case online = "Online Publication"
        case other = "Other"
    }

    enum SubmissionStatus: String, Codable, CaseIterable {
        case draft = "Draft"
        case submitted = "Submitted"
        case underReview = "Under Review"
        case accepted = "Accepted"
        case rejected = "Rejected"
        case withdrawn = "Withdrawn"
        case published = "Published"

        var color: String {
            switch self {
            case .draft: return "gray"
            case .submitted: return "blue"
            case .underReview: return "orange"
            case .accepted: return "green"
            case .rejected: return "red"
            case .withdrawn: return "purple"
            case .published: return "teal"
            }
        }

        var emoji: String {
            switch self {
            case .draft: return "📝"
            case .submitted: return "📤"
            case .underReview: return "⏳"
            case .accepted: return "✅"
            case .rejected: return "❌"
            case .withdrawn: return "↩️"
            case .published: return "📖"
            }
        }
    }

    init(
        id: UUID = UUID(),
        poemTitle: String,
        publicationName: String,
        publicationType: PublicationType = .literaryMagazine,
        status: SubmissionStatus = .draft,
        submittedAt: Date = Date(),
        respondedAt: Date? = nil,
        responseDeadline: Date? = nil,
        fee: Double? = nil,
        payment: Double? = nil,
        notes: String = "",
        simultaneousSubmissionAllowed: Bool = true,
        coverLetter: String = "",
        confirmationNumber: String = "",
        contactEmail: String = "",
        websiteURL: String = ""
    ) {
        self.id = id
        self.poemTitle = poemTitle
        self.publicationName = publicationName
        self.publicationType = publicationType
        self.status = status
        self.submittedAt = submittedAt
        self.respondedAt = respondedAt
        self.responseDeadline = responseDeadline
        self.fee = fee
        self.payment = payment
        self.notes = notes
        self.simultaneousSubmissionAllowed = simultaneousSubmissionAllowed
        self.coverLetter = coverLetter
        self.confirmationNumber = confirmationNumber
        self.contactEmail = contactEmail
        self.websiteURL = websiteURL
    }

    var daysSinceSubmission: Int? {
        guard status == .submitted || status == .underReview else { return nil }
        return Calendar.current.dateComponents([.day], from: submittedAt, to: Date()).day
    }

    var isOverdue: Bool {
        guard let deadline = responseDeadline else { return false }
        return Date() > deadline && (status == .submitted || status == .underReview)
    }
}

// MARK: - Publication (Saved Venue)

/// A saved publication/venue for quick reuse
struct Publication: Codable, Identifiable {
    let id: UUID
    var name: String
    var type: Submission.PublicationType
    var website: String
    var submissionURL: String
    var contactEmail: String
    var averageResponseDays: Int?
    var simultaneousSubmissionAllowed: Bool
    var typicalFee: Double?
    var typicalPayment: Double?
    var notes: String
    var genres: [String]
    var submissionPeriods: String  // e.g., "January-March, July-September"
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: Submission.PublicationType = .literaryMagazine,
        website: String = "",
        submissionURL: String = "",
        contactEmail: String = "",
        averageResponseDays: Int? = nil,
        simultaneousSubmissionAllowed: Bool = true,
        typicalFee: Double? = nil,
        typicalPayment: Double? = nil,
        notes: String = "",
        genres: [String] = [],
        submissionPeriods: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.website = website
        self.submissionURL = submissionURL
        self.contactEmail = contactEmail
        self.averageResponseDays = averageResponseDays
        self.simultaneousSubmissionAllowed = simultaneousSubmissionAllowed
        self.typicalFee = typicalFee
        self.typicalPayment = typicalPayment
        self.notes = notes
        self.genres = genres
        self.submissionPeriods = submissionPeriods
        self.isFavorite = isFavorite
    }
}

// MARK: - Submission Statistics

struct SubmissionStatistics {
    let totalSubmissions: Int
    let pending: Int
    let accepted: Int
    let rejected: Int
    let withdrawn: Int
    let published: Int
    let acceptanceRate: Double
    let averageResponseDays: Double?
    let totalFeesPaid: Double
    let totalPaymentsReceived: Double

    init(from submissions: [Submission]) {
        totalSubmissions = submissions.count
        pending = submissions.filter { $0.status == .submitted || $0.status == .underReview }.count
        accepted = submissions.filter { $0.status == .accepted }.count
        rejected = submissions.filter { $0.status == .rejected }.count
        withdrawn = submissions.filter { $0.status == .withdrawn }.count
        published = submissions.filter { $0.status == .published }.count

        let responded = accepted + rejected
        acceptanceRate = responded > 0 ? Double(accepted) / Double(responded) * 100 : 0

        // Calculate average response time
        let responseTimes = submissions.compactMap { sub -> Int? in
            guard let responded = sub.respondedAt else { return nil }
            return Calendar.current.dateComponents([.day], from: sub.submittedAt, to: responded).day
        }
        averageResponseDays = responseTimes.isEmpty ? nil : Double(responseTimes.reduce(0, +)) / Double(responseTimes.count)

        totalFeesPaid = submissions.compactMap { $0.fee }.reduce(0, +)
        totalPaymentsReceived = submissions.compactMap { $0.payment }.reduce(0, +)
    }
}

// MARK: - Submission Manager

/// Manages poem submissions
@MainActor
final class SubmissionManager: ObservableObject {

    static let shared = SubmissionManager()

    private let submissionsKey = "poetrySubmissions"
    private let publicationsKey = "savedPublications"

    @Published private(set) var submissions: [Submission] = []
    @Published private(set) var publications: [Publication] = []

    private init() {
        loadData()
    }

    // MARK: - Submission CRUD

    func createSubmission(
        poemTitle: String,
        publicationName: String,
        publicationType: Submission.PublicationType = .literaryMagazine
    ) -> Submission {
        let submission = Submission(
            poemTitle: poemTitle,
            publicationName: publicationName,
            publicationType: publicationType
        )
        submissions = submissions + [submission]
        saveData()
        return submission
    }

    func getSubmissions() -> [Submission] {
        submissions.sorted { $0.submittedAt > $1.submittedAt }
    }

    func getSubmissions(for poemTitle: String) -> [Submission] {
        submissions.filter { $0.poemTitle.lowercased() == poemTitle.lowercased() }
            .sorted { $0.submittedAt > $1.submittedAt }
    }

    func getPendingSubmissions() -> [Submission] {
        submissions.filter { $0.status == .submitted || $0.status == .underReview }
            .sorted { $0.submittedAt > $1.submittedAt }
    }

    func getSubmission(id: UUID) -> Submission? {
        submissions.first { $0.id == id }
    }

    func updateSubmission(_ submission: Submission) {
        if let index = submissions.firstIndex(where: { $0.id == submission.id }) {
            var updated = submissions
            updated[index] = submission
            submissions = updated
            saveData()
        }
    }

    func updateStatus(id: UUID, status: Submission.SubmissionStatus) {
        guard var submission = getSubmission(id: id) else { return }
        submission.status = status
        if status == .accepted || status == .rejected || status == .withdrawn {
            submission.respondedAt = Date()
        }
        updateSubmission(submission)
    }

    func deleteSubmission(id: UUID) {
        submissions = submissions.filter { $0.id != id }
        saveData()
    }

    // MARK: - Publication CRUD

    func savePublication(_ publication: Publication) {
        if let index = publications.firstIndex(where: { $0.id == publication.id }) {
            var updated = publications
            updated[index] = publication
            publications = updated
        } else {
            publications = publications + [publication]
        }
        saveData()
    }

    func getPublications() -> [Publication] {
        publications.sorted { ($0.isFavorite ? 0 : 1, $0.name) < ($1.isFavorite ? 0 : 1, $1.name) }
    }

    func getFavoritePublications() -> [Publication] {
        publications.filter { $0.isFavorite }.sorted { $0.name < $1.name }
    }

    func deletePublication(id: UUID) {
        publications = publications.filter { $0.id != id }
        saveData()
    }

    // MARK: - Statistics

    func getStatistics() -> SubmissionStatistics {
        SubmissionStatistics(from: submissions)
    }

    func getStatistics(for poemTitle: String) -> SubmissionStatistics {
        SubmissionStatistics(from: getSubmissions(for: poemTitle))
    }

    // MARK: - Queries

    func getOverdueSubmissions() -> [Submission] {
        submissions.filter { $0.isOverdue }
    }

    func getSubmissionsByPublication(_ name: String) -> [Submission] {
        submissions.filter { $0.publicationName.lowercased() == name.lowercased() }
    }

    func getUniquePublicationNames() -> [String] {
        Array(Set(submissions.map { $0.publicationName })).sorted()
    }

    func getUniquePoemTitles() -> [String] {
        Array(Set(submissions.map { $0.poemTitle })).sorted()
    }

    // MARK: - Export

    func exportToCSV() -> String {
        var csv = "Poem Title,Publication,Type,Status,Submitted,Responded,Fee,Payment,Notes\n"

        for sub in submissions {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short

            let submitted = dateFormatter.string(from: sub.submittedAt)
            let responded = sub.respondedAt.map { dateFormatter.string(from: $0) } ?? ""
            let fee = sub.fee.map { String(format: "%.2f", $0) } ?? ""
            let payment = sub.payment.map { String(format: "%.2f", $0) } ?? ""
            let notes = sub.notes.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")

            csv += "\"\(sub.poemTitle)\",\"\(sub.publicationName)\",\"\(sub.publicationType.rawValue)\",\"\(sub.status.rawValue)\",\"\(submitted)\",\"\(responded)\",\"\(fee)\",\"\(payment)\",\"\(notes)\"\n"
        }

        return csv
    }

    // MARK: - Persistence

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: submissionsKey) {
            do {
                submissions = try JSONDecoder().decode([Submission].self, from: data)
            } catch {
                print("Failed to load submissions: \(error)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: publicationsKey) {
            do {
                publications = try JSONDecoder().decode([Publication].self, from: data)
            } catch {
                print("Failed to load publications: \(error)")
            }
        }
    }

    private func saveData() {
        do {
            let submissionData = try JSONEncoder().encode(submissions)
            UserDefaults.standard.set(submissionData, forKey: submissionsKey)

            let publicationData = try JSONEncoder().encode(publications)
            UserDefaults.standard.set(publicationData, forKey: publicationsKey)
        } catch {
            print("Failed to save data: \(error)")
        }
    }
}
