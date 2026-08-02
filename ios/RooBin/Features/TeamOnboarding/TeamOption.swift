import Foundation

struct TeamOption: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let role: TeamMembershipDTO.Role
    let unlockCodeResetRequired: Bool
}

extension TeamMembershipDTO.Role {
    var displayName: String {
        switch self {
        case .captain:
            "Captain"
        case .viceCaptain:
            "Vice-captain"
        case .member:
            "Member"
        }
    }
}
