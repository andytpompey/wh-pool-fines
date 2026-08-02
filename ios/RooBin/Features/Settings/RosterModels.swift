import Foundation

struct RosterMember: Identifiable, Equatable, Sendable {
    let id: UUID
    let playerID: UUID
    let name: String
    let email: String
    let role: TeamMembershipDTO.Role
}

struct PendingTeamInvite: Identifiable, Equatable, Sendable {
    let id: UUID
    let email: String
    let expiresAt: Date?
}

struct RosterWorkspace: Equatable, Sendable {
    let members: [RosterMember]
    let invites: [PendingTeamInvite]
}
