import Foundation

/// The three streams a user can opt into. Each one owns its own default, because two of the
/// three are deliberately off until someone asks for them.
nonisolated enum UpdateChannel: String, CaseIterable, Codable, Hashable, Identifiable {
    case savedRemedies
    case newInSavedCategories
    case appNews

    var id: String { rawValue }

    var title: String {
        switch self {
        case .savedRemedies: "Saved remedy updates"
        case .newInSavedCategories: "New remedies added to your saved categories"
        case .appNews: "App updates / what's new"
        }
    }

    var detail: String {
        switch self {
        case .savedRemedies:
            "When an entry on your shelf changes tier, gains a source, or picks up a new safety note."
        case .newInSavedCategories:
            "When a remedy is added to a shelf you already save from."
        case .appNews:
            "Occasional notes on what changed in the app itself."
        }
    }

    /// Short form used as the eyebrow on an inbox entry.
    var inboxLabel: String {
        switch self {
        case .savedRemedies: "Remedy update"
        case .newInSavedCategories: "New entry"
        case .appNews: "What's new"
        }
    }

    /// Only the first channel is on out of the box. Read per-channel rather than as one
    /// blanket default, so changing a default later can't silently switch on a stream the
    /// user already turned off.
    var isOnByDefault: Bool {
        self == .savedRemedies
    }
}

/// A single entry in the Updates inbox.
nonisolated struct AppUpdate: Identifiable, Hashable {
    let id: String
    let channel: UpdateChannel
    let title: String
    let body: String
    let date: Date
    /// Set when the entry is about one specific remedy, which makes the row navigable.
    let remedyID: String?
    /// Set on `newInSavedCategories` entries so the row can say which shelf it landed on.
    let categoryName: String?

    init(
        id: String,
        channel: UpdateChannel,
        title: String,
        body: String,
        daysAgo: Int,
        remedyID: String? = nil,
        categoryName: String? = nil
    ) {
        self.id = id
        self.channel = channel
        self.title = title
        self.body = body
        // Relative to launch rather than hardcoded, so the sample set doesn't age into
        // obviously stale dates while this is still static content.
        self.date = Date.now.addingTimeInterval(-Double(daysAgo) * 86_400)
        self.remedyID = remedyID
        self.categoryName = categoryName
    }
}

/// A report filed against a remedy entry. Held on-device only — see `AppModel`.
nonisolated struct IssueReport: Codable, Hashable, Identifiable {
    enum Reason: String, Codable, CaseIterable, Identifiable {
        case inaccurate = "Something here is inaccurate"
        case missingSafety = "A safety warning is missing"
        case source = "A source is wrong, weak or unavailable"
        case preparation = "The preparation or dosage looks wrong"
        case other = "Something else"

        var id: String { rawValue }
    }

    let id: UUID
    let remedyID: String
    let remedyName: String
    let reason: Reason
    let note: String
    let createdAt: Date

    init(remedyID: String, remedyName: String, reason: Reason, note: String, createdAt: Date = .now) {
        self.id = UUID()
        self.remedyID = remedyID
        self.remedyName = remedyName
        self.reason = reason
        self.note = note
        self.createdAt = createdAt
    }
}
