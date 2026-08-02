import Foundation

enum AppEnvironment: String, Sendable {
    case local
    case staging
    case production
}

struct RuntimeConfiguration: Equatable, Sendable {
    let environment: AppEnvironment
    let supabaseURL: URL
    let supabasePublishableKey: String
    let forceOffline: Bool
    let forceExpiredSession: Bool
    let forceServiceUnavailable: Bool
    let forceSlowNetwork: Bool
    let pauseAfterLogoUpload: Bool

    static func load(bundle: Bundle = .main) throws -> RuntimeConfiguration {
        guard
            let environmentValue = bundle.object(
                forInfoDictionaryKey: "ROOBIN_ENVIRONMENT"
            ) as? String,
            let environment = AppEnvironment(rawValue: environmentValue),
            let urlValue = bundle.object(
                forInfoDictionaryKey: "SUPABASE_URL"
            ) as? String,
            let url = URL(string: urlValue),
            let key = bundle.object(
                forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY"
            ) as? String,
            !key.isEmpty
        else {
            throw RooBinError.validation(
                message: "This build is missing its environment configuration."
            )
        }

        if environment != .local, url.scheme != "https" {
            throw RooBinError.validation(
                message: "This build requires a secure backend connection."
            )
        }

        return RuntimeConfiguration(
            environment: environment,
            supabaseURL: url,
            supabasePublishableKey: key,
            forceOffline: {
                #if DEBUG
                ProcessInfo.processInfo.environment["ROOBIN_FORCE_OFFLINE"] == "1"
                #else
                false
                #endif
            }(),
            forceExpiredSession: {
                #if DEBUG
                ProcessInfo.processInfo.environment["ROOBIN_FORCE_EXPIRED_SESSION"] == "1"
                #else
                false
                #endif
            }(),
            forceServiceUnavailable: {
                #if DEBUG
                ProcessInfo.processInfo.environment["ROOBIN_FORCE_SERVICE_UNAVAILABLE"] == "1"
                #else
                false
                #endif
            }(),
            forceSlowNetwork: {
                #if DEBUG
                ProcessInfo.processInfo.environment["ROOBIN_FORCE_SLOW_NETWORK"] == "1"
                #else
                false
                #endif
            }(),
            pauseAfterLogoUpload: {
                #if DEBUG
                ProcessInfo.processInfo.environment["ROOBIN_PAUSE_AFTER_LOGO_UPLOAD"] == "1"
                #else
                false
                #endif
            }()
        )
    }
}
