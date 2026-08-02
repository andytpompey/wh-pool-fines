import Foundation

enum RooBinError: Error, Equatable, Sendable {
    case unauthenticated
    case forbidden
    case validation(message: String)
    case notFound
    case conflict
    case rateLimited
    case expired
    case offline
    case serviceUnavailable
    case unexpected
}

extension RooBinError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            "Please sign in again."
        case .forbidden:
            "You don’t have permission to do that."
        case let .validation(message):
            message
        case .notFound:
            "That item is no longer available."
        case .conflict:
            "This changed elsewhere. Refresh and try again."
        case .rateLimited:
            "Too many attempts. Please wait and try again."
        case .expired:
            "This request has expired. Start again."
        case .offline:
            "You appear to be offline."
        case .serviceUnavailable:
            "RooBin is temporarily unavailable. Please try again."
        case .unexpected:
            "Something went wrong. Please try again."
        }
    }
}
