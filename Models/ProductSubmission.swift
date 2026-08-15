import Foundation

/// A user-submitted "we couldn't find this product" report — the manual path offered from
/// the not-found scan state. Same on-device-only pattern as `IssueReport`: there's no
/// backend to send this to yet, so it's stored locally and the screen says exactly that.
/// Doubles as a low-cost way to grow Grounded's own sense of coverage gaps over time.
nonisolated struct ProductSubmission: Codable, Hashable, Identifiable {
    let id: UUID
    let barcode: String
    let productName: String
    let note: String
    let createdAt: Date

    init(barcode: String, productName: String, note: String, createdAt: Date = .now) {
        self.id = UUID()
        self.barcode = barcode
        self.productName = productName
        self.note = note
        self.createdAt = createdAt
    }
}
