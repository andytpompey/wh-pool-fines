import Foundation

struct LedgerEntry: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case fine
        case sub

        var displayName: String {
            rawValue.capitalized
        }
    }

    let id: UUID
    let matchID: UUID
    let playerID: UUID?
    let playerName: String
    let label: String
    let kind: Kind
    let amount: Decimal
    let paid: Bool
    let date: Date
    let seasonID: UUID?
}

enum LedgerPaymentFilter: String, CaseIterable, Sendable {
    case all
    case unpaid
    case paid

    var displayName: String {
        rawValue.capitalized
    }
}
