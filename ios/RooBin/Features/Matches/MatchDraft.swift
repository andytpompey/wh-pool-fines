import Foundation

struct MatchPlayerOption: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
}

struct MatchDraft: Equatable, Sendable {
    let id: UUID
    let date: Date
    let opponent: String
    let venue: MatchSummary.Venue
    let seasonID: UUID?
    let playerIDs: Set<UUID>
    let driverIDs: Set<UUID>
}

struct MatchFixtureDraft: Equatable, Sendable {
    let matchID: UUID
    let expectedVersion: Int64
    let date: Date
    let opponent: String
    let venue: MatchSummary.Venue
    let seasonID: UUID?
}

struct MatchWorkspace: Equatable, Sendable {
    let seasons: [SeasonOption]
    let players: [MatchPlayerOption]
    let matches: [MatchSummary]
    let fineTypes: [FineTypeOption]
    let activity: [UUID: MatchActivity]
    let ledgerEntries: [LedgerEntry]

    static let empty = MatchWorkspace(
        seasons: [], players: [], matches: [], fineTypes: [], activity: [:], ledgerEntries: []
    )
}

struct FineTypeOption: Identifiable, Equatable, Sendable, Decodable {
    let id: UUID
    let name: String
    let cost: Decimal
}

struct MatchFineEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let playerID: UUID?
    let playerName: String
    let fineName: String
    let cost: Decimal
    let paid: Bool
}

struct MatchSubEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let playerID: UUID?
    let playerName: String
    let amount: Decimal
    let paid: Bool
}

struct MatchActivity: Equatable, Sendable {
    let playerIDs: [UUID]
    let driverIDs: [UUID]
    let fines: [MatchFineEntry]
    let subs: [MatchSubEntry]
}
