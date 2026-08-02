import Foundation

struct PlayerProfileDTO: Codable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let displayName: String
    let email: String?
    let mobile: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case displayName = "display_name"
        case email
        case mobile
    }
}

struct TeamSummaryDTO: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let logoURL: URL?
    let subsEnabled: Bool
    let subAmount: Decimal

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case logoURL = "logo_url"
        case subsEnabled = "subs_enabled"
        case subAmount = "sub_amount"
    }
}

struct TeamMembershipDTO: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case captain
        case viceCaptain = "vice_captain"
        case member
    }

    enum Status: String, Codable, Sendable {
        case invited
        case active
        case removed
    }

    let id: UUID
    let teamID: UUID
    let playerID: UUID
    let role: Role
    let status: Status

    enum CodingKeys: String, CodingKey {
        case id
        case teamID = "team_id"
        case playerID = "player_id"
        case role
        case status
    }
}

struct MatchAggregateDTO: Codable, Equatable, Sendable {
    struct Player: Codable, Equatable, Sendable {
        let playerID: UUID
        let isDriver: Bool

        enum CodingKeys: String, CodingKey {
            case playerID = "playerId"
            case isDriver
        }
    }

    let id: UUID
    let teamID: UUID
    let date: String
    let seasonID: UUID?
    let opponent: String?
    let submitted: Bool
    let venue: String
    let players: [Player]

    enum CodingKeys: String, CodingKey {
        case id
        case teamID = "teamId"
        case date
        case seasonID = "seasonId"
        case opponent
        case submitted
        case venue
        case players
    }
}

struct MutationResultDTO: Codable, Equatable, Sendable {
    let success: Bool
    let operationID: UUID?

    enum CodingKeys: String, CodingKey {
        case success
        case operationID = "operationId"
    }
}
