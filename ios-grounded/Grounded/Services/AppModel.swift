import Foundation
import Observation

nonisolated struct StoredHealthItem: Codable, Hashable, Identifiable {
    let id: UUID
    let label: String
    let detail: String
    let createdAt: Date

    init(label: String, detail: String, createdAt: Date = .now) {
        self.id = UUID()
        self.label = label
        self.detail = detail
        self.createdAt = createdAt
    }
}

/// Shared app state for the v1 shell: onboarding consent, profile, bookmarks and
/// the locally stored health-data record shown in Account → Privacy & data.
@Observable
final class AppModel {
    private enum Key {
        static let onboarded = "grounded.onboarded"
        static let consented = "grounded.consent.health"
        static let ageAffirmed = "grounded.consent.age"
        static let bookmarks = "grounded.bookmarks"
        static let name = "grounded.profile.name"
        static let email = "grounded.profile.email"
        static let avatarWash = "grounded.profile.avatarWash"
        static let health = "grounded.health.items"
        static let consentDate = "grounded.consent.recordedAt"
        static let channels = "grounded.updates.channels"
        static let updatesOpenedAt = "grounded.updates.lastOpenedAt"
        static let reports = "grounded.reports.issues"
        static let productSubmissions = "grounded.reports.productSubmissions"
        static let startHereDismissed = "grounded.apothecary.startHereDismissed"
    }

    private let defaults = UserDefaults.standard

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarded) }
    }

    var didConsentToHealthData: Bool {
        didSet { defaults.set(didConsentToHealthData, forKey: Key.consented) }
    }

    var didAffirmAge: Bool {
        didSet { defaults.set(didAffirmAge, forKey: Key.ageAffirmed) }
    }

    /// When the onboarding consents were recorded. Nil for anyone who onboarded before this
    /// was tracked — About states that plainly rather than inventing a date.
    var consentRecordedAt: Date? {
        didSet { defaults.set(consentRecordedAt, forKey: Key.consentDate) }
    }

    /// Whether the Apothecary's "Start here" strip has been dismissed. Stored the same way as
    /// onboarding completion — a local flag, no backend call — so it sticks across launches
    /// on this device.
    var hasDismissedStartHere: Bool {
        didSet { defaults.set(hasDismissedStartHere, forKey: Key.startHereDismissed) }
    }

    /// Inert preview for the reserved emergency-banner slot. Lives here rather than on
    /// `ChatModel` because the control that flips it now sits in Help & Support, two tabs
    /// away from the banner it previews. Deliberately not persisted — a preview that
    /// survived a relaunch would look like a real alert.
    var isSafetyBannerPreviewActive = false

    var profileName: String {
        didSet { defaults.set(profileName, forKey: Key.name) }
    }

    /// Read-only in the UI for now: changing it needs an email re-verification flow.
    var profileEmail: String {
        didSet { defaults.set(profileEmail, forKey: Key.email) }
    }

    /// Hex of the category wash the leaf avatar sits on. Stored as the hex rather than a
    /// category name so the avatar survives the shelves being renamed or reordered.
    var profileAvatarWash: String {
        didSet { defaults.set(profileAvatarWash, forKey: Key.avatarWash) }
    }

    private(set) var bookmarkedRemedyIDs: [String] {
        didSet { defaults.set(bookmarkedRemedyIDs, forKey: Key.bookmarks) }
    }

    private(set) var storedHealthItems: [StoredHealthItem] {
        didSet { persistHealthItems() }
    }

    /// Explicit per-channel choices. Absent keys fall back to the channel's own default, so
    /// an untouched channel isn't stored and a later default change doesn't overwrite a
    /// deliberate opt-out.
    private var channelChoices: [String: Bool] {
        didSet { defaults.set(channelChoices, forKey: Key.channels) }
    }

    private(set) var updatesLastOpenedAt: Date? {
        didSet { defaults.set(updatesLastOpenedAt, forKey: Key.updatesOpenedAt) }
    }

    /// Issue reports filed from Help & Support or a remedy screen. There is no reporting
    /// endpoint yet, so these are held on-device and both screens say so.
    private(set) var issueReports: [IssueReport] {
        didSet { persist(issueReports, forKey: Key.reports) }
    }

    /// "We couldn't find this product" submissions from the barcode scanner's not-found
    /// state. Same on-device-only storage as `issueReports` — no backend to send to yet.
    private(set) var productSubmissions: [ProductSubmission] {
        didSet { persist(productSubmissions, forKey: Key.productSubmissions) }
    }

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded)
        didConsentToHealthData = defaults.bool(forKey: Key.consented)
        didAffirmAge = defaults.bool(forKey: Key.ageAffirmed)
        profileName = defaults.string(forKey: Key.name) ?? "Wren Halloway"
        profileEmail = defaults.string(forKey: Key.email) ?? "wren@example.com"
        profileAvatarWash = defaults.string(forKey: Key.avatarWash) ?? "#28345A"
        bookmarkedRemedyIDs = defaults.stringArray(forKey: Key.bookmarks) ?? []
        consentRecordedAt = defaults.object(forKey: Key.consentDate) as? Date
        channelChoices = defaults.dictionary(forKey: Key.channels) as? [String: Bool] ?? [:]
        updatesLastOpenedAt = defaults.object(forKey: Key.updatesOpenedAt) as? Date
        hasDismissedStartHere = defaults.bool(forKey: Key.startHereDismissed)
        if let data = defaults.data(forKey: Key.reports),
           let decoded = try? JSONDecoder().decode([IssueReport].self, from: data) {
            issueReports = decoded
        } else {
            issueReports = []
        }
        if let data = defaults.data(forKey: Key.productSubmissions),
           let decoded = try? JSONDecoder().decode([ProductSubmission].self, from: data) {
            productSubmissions = decoded
        } else {
            productSubmissions = []
        }
        if let data = defaults.data(forKey: Key.health),
           let items = try? JSONDecoder().decode([StoredHealthItem].self, from: data) {
            storedHealthItems = items
        } else {
            storedHealthItems = [
                StoredHealthItem(label: "Symptom topics you asked about", detail: "3 chat topics kept on this device"),
                StoredHealthItem(label: "Saved remedies", detail: "Stored locally so your shelf persists"),
                StoredHealthItem(label: "Scanned products", detail: "Barcode history kept on this device"),
            ]
        }
    }

    // MARK: Profile

    /// Trims and rejects an all-whitespace name, so the profile card can never render blank.
    /// Returns false when the edit was discarded.
    @discardableResult
    func updateProfileName(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        profileName = String(trimmed.prefix(48))
        return true
    }

    // MARK: Bookmarks

    func isBookmarked(_ remedy: Remedy) -> Bool {
        bookmarkedRemedyIDs.contains(remedy.id)
    }

    func toggleBookmark(_ remedy: Remedy) {
        if let index = bookmarkedRemedyIDs.firstIndex(of: remedy.id) {
            bookmarkedRemedyIDs.remove(at: index)
        } else {
            bookmarkedRemedyIDs.append(remedy.id)
        }
    }

    // MARK: Update channels

    func isChannelEnabled(_ channel: UpdateChannel) -> Bool {
        channelChoices[channel.rawValue] ?? channel.isOnByDefault
    }

    func setChannel(_ channel: UpdateChannel, enabled: Bool) {
        channelChoices[channel.rawValue] = enabled
    }

    func markUpdatesRead() {
        updatesLastOpenedAt = .now
    }

    // MARK: Issue reports

    func submitIssueReport(remedyID: String, remedyName: String, reason: IssueReport.Reason, note: String) {
        issueReports.append(
            IssueReport(
                remedyID: remedyID,
                remedyName: remedyName,
                reason: reason,
                note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000))
            )
        )
    }

    // MARK: Product submissions

    func submitProductSubmission(barcode: String, productName: String, note: String) {
        productSubmissions.append(
            ProductSubmission(
                barcode: barcode,
                productName: String(productName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)),
                note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000))
            )
        )
    }

    // MARK: Health data controls

    func deleteHealthItem(_ item: StoredHealthItem) {
        storedHealthItems.removeAll { $0.id == item.id }
    }

    func deleteAllHealthData() {
        storedHealthItems.removeAll()
    }

    /// Signs out of the local shell and returns the user to onboarding, where the
    /// disclaimer, consent and age-affirmation steps must be completed again.
    func signOut() {
        hasCompletedOnboarding = false
        didConsentToHealthData = false
        didAffirmAge = false
        consentRecordedAt = nil
        // Signing out drops the user back through onboarding, so the new-user entry point
        // comes back with it — leaving it dismissed would hand a freshly onboarded user the
        // bare shelves with no starting point.
        hasDismissedStartHere = false
    }

    private func persistHealthItems() {
        persist(storedHealthItems, forKey: Key.health)
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            print("[AppModel] could not persist value for \(key)")
        }
    }
}
