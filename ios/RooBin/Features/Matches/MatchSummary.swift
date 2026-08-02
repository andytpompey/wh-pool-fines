import Foundation

struct MatchSummary: Identifiable, Hashable, Sendable {
    enum Venue: String, Codable, Hashable, Sendable {
        case home
        case away

        var displayName: String {
            rawValue.capitalized
        }
    }

    let id: UUID
    let date: Date
    let opponent: String
    let venue: Venue
    let seasonName: String?
    let seasonID: UUID?
    let submitted: Bool
    let editVersion: Int64
    let playerCount: Int
    let fineCount: Int
    let total: Decimal
}
