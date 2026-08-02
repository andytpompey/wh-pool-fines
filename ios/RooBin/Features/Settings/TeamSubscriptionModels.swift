import Foundation

struct CommercialPlayingCycle: Identifiable, Equatable, Sendable, Decodable {
    let id: UUID
    let teamID: UUID
    let name: String
    let sport: String
    let startsOn: String?
    let endsOn: String?
    let status: String
    let entitlementState: String
    let entitlementValidUntil: String?
    let entitlementSource: String?
    let entitlementPurchaser: String?

    enum CodingKeys: String, CodingKey {
        case id, name, sport, status
        case teamID = "team_id"
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case entitlementState = "entitlement_state"
        case entitlementValidUntil = "entitlement_valid_until"
        case entitlementSource = "entitlement_source"
        case entitlementPurchaser = "entitlement_purchaser"
    }

    var hasAccess: Bool { ["active", "trial", "grace", "complimentary"].contains(entitlementState) }
    var hasPurchaseBoundary: Bool { startsOn != nil && endsOn != nil }
}

struct AppStorePurchaseContext: Equatable, Sendable, Decodable {
    let contextID: UUID
    let playingCycleID: UUID
    let productID: String
    let amountMinor: Int
    let currency: String
    let cycleName: String
    let startsOn: String
    let endsOn: String

    enum CodingKeys: String, CodingKey {
        case contextID = "contextId"
        case playingCycleID = "playingCycleId"
        case productID = "productId"
        case amountMinor, currency, cycleName, startsOn, endsOn
    }
}

struct AppStoreVerificationResponse: Equatable, Sendable, Decodable {
    let verified: Bool
    let state: String
    let playingCycleID: UUID
    enum CodingKeys: String, CodingKey {
        case verified, state
        case playingCycleID = "playingCycleId"
    }
}
