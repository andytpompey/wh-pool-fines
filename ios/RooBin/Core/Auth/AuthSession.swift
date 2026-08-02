import Foundation

enum AuthProvider: String, Codable, CaseIterable, Sendable {
    case email
    case apple
    case google
}

struct AuthSession: Codable, Equatable, Sendable {
    let userID: UUID
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let provider: AuthProvider

    var isExpired: Bool {
        expiresAt <= Date()
    }
}

protocol SessionStore: Sendable {
    func load() async throws -> AuthSession?
    func save(_ session: AuthSession) async throws
    func clear() async throws
}

actor EphemeralSessionStore: SessionStore {
    private var session: AuthSession?

    func load() -> AuthSession? {
        session
    }

    func save(_ session: AuthSession) {
        self.session = session
    }

    func clear() {
        session = nil
    }
}
