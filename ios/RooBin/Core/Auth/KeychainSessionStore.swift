import Foundation
import OSLog
import Security

actor KeychainSessionStore: SessionStore {
    private static let logger = Logger(
        subsystem: "com.roobin.app",
        category: "SecureSession"
    )

    private let service = "com.roobin.app.auth"
    private let account = "supabase-session"

    func load() throws -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw RooBinError.unexpected
        }
        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            try clear()
            return nil
        }
    }

    func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = query
            attributes.forEach { insert[$0.key] = $0.value }
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                #if DEBUG
                Self.logger.error("Unable to insert secure session; keychain status=\(insertStatus, privacy: .public)")
                #endif
                throw RooBinError.unexpected
            }
        } else if updateStatus != errSecSuccess {
            #if DEBUG
            Self.logger.error("Unable to update secure session; keychain status=\(updateStatus, privacy: .public)")
            #endif
            throw RooBinError.unexpected
        }
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RooBinError.unexpected
        }
    }
}
