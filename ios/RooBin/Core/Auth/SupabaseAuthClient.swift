import Foundation
import OSLog

actor SupabaseAuthClient {
    private static let logger = Logger(
        subsystem: "com.roobin.app",
        category: "Authentication"
    )

    private struct OTPRequest: Encodable {
        let email: String
        let createUser = true

        enum CodingKeys: String, CodingKey {
            case email
            case createUser = "create_user"
        }
    }

    private struct OTPVerificationRequest: Encodable {
        let email: String
        let token: String
        let type = "email"
    }

    private struct VerificationResponse: Decodable {
        struct User: Decodable { let id: UUID }

        let accessToken: String
        let refreshToken: String
        let expiresIn: TimeInterval
        let user: User

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    private let configuration: RuntimeConfiguration
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: RuntimeConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func requestEmailCode(_ email: String) async throws {
        let body = try encoder.encode(OTPRequest(email: email))
        _ = try await perform(
            path: "auth/v1/otp",
            body: body,
            validationMessage: "We couldn’t send a code. Check the email address and try again."
        )
    }

    func verifyEmailCode(_ code: String, email: String) async throws -> AuthSession {
        let body = try encoder.encode(OTPVerificationRequest(email: email, token: code))
        let data = try await perform(
            path: "auth/v1/verify",
            body: body,
            validationMessage: "The code is invalid or has expired. Request a new code and try again."
        )
        let response: VerificationResponse
        do {
            response = try decoder.decode(VerificationResponse.self, from: data)
        } catch {
            #if DEBUG
            Self.logger.error("Unable to decode a successful OTP verification response: \(String(describing: error), privacy: .public)")
            #endif
            throw RooBinError.unexpected
        }

        return AuthSession(
            userID: response.user.id,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn),
            provider: .email
        )
    }

    private func perform(
        path: String,
        body: Data,
        validationMessage: String
    ) async throws -> Data {
        if configuration.forceSlowNetwork {
            try await Task.sleep(for: .seconds(3))
        }
        if configuration.forceServiceUnavailable { throw RooBinError.serviceUnavailable }
        if configuration.forceOffline { throw RooBinError.offline }
        let url = configuration.supabaseURL.appending(path: path)
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store, no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue(configuration.supabasePublishableKey, forHTTPHeaderField: "apikey")

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw RooBinError.unexpected
            }
            switch response.statusCode {
            case 200..<300:
                return data
            case 400, 422:
                throw RooBinError.validation(message: validationMessage)
            case 401, 403:
                throw RooBinError.serviceUnavailable
            case 429:
                throw RooBinError.rateLimited
            case 500...599:
                throw RooBinError.serviceUnavailable
            default:
                throw RooBinError.unexpected
            }
        } catch let error as RooBinError {
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw RooBinError.offline
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RooBinError.unexpected
        }
    }
}
