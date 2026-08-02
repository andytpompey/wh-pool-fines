import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(AuthSession)
    }

    private(set) var state: State = .restoring
    private(set) var selectedTeamID: UUID?

    func restore(using store: any SessionStore) async {
        do {
            guard let session = try await store.load(), !session.isExpired else {
                try? await store.clear()
                state = .signedOut
                return
            }
            state = .signedIn(session)
        } catch {
            state = .signedOut
        }
    }

    func apply(_ session: AuthSession, using store: any SessionStore) async throws {
        try await store.save(session)
        state = .signedIn(session)
    }

    func selectTeam(_ teamID: UUID?) {
        selectedTeamID = teamID
    }

    func signOut(using store: any SessionStore) async {
        try? await store.clear()
        selectedTeamID = nil
        state = .signedOut
    }
}
