import Foundation

struct AccountDeletionPreflight: Decodable, Equatable, Sendable {
    struct CaptaincyBlocker: Decodable, Equatable, Identifiable, Sendable {
        let teamID: UUID
        let teamName: String
        let otherActiveMembers: Int
        var id: UUID { teamID }

        enum CodingKeys: String, CodingKey {
            case teamID = "teamId"
            case teamName
            case otherActiveMembers
        }
    }

    struct ClosingTeam: Decodable, Equatable, Identifiable, Sendable {
        let teamID: UUID
        let teamName: String
        var id: UUID { teamID }

        enum CodingKeys: String, CodingKey {
            case teamID = "teamId"
            case teamName
        }
    }

    let email: String
    let captaincyBlockers: [CaptaincyBlocker]
    let teamsDeletedWithAccount: [ClosingTeam]
    let historicalFineCount: Int
    let historicalSubCount: Int
    let deletionIsImmediate: Bool
    let historicalAliasPolicy: String
}
