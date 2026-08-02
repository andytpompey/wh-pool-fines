import Foundation

struct SeasonOption: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
}

enum SeasonSelection: Equatable, Sendable {
    case all
    case season(UUID)

    func validated(against seasons: [SeasonOption]) -> SeasonSelection {
        guard case let .season(id) = self else {
            return .all
        }
        return seasons.contains(where: { $0.id == id }) ? self : .all
    }
}

struct DashboardPlayerBalance: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let total: Decimal
    let paid: Decimal
    let outstanding: Decimal
}

struct HomeDashboardModel: Equatable, Sendable {
    let teamName: String
    let teamLogoURL: URL?
    let seasons: [SeasonOption]
    let selectedSeason: SeasonSelection
    let total: Decimal
    let paid: Decimal
    let outstanding: Decimal
    let matchCount: Int
    let fineCount: Int
    let subCount: Int
    let playerBalances: [DashboardPlayerBalance]

    static let empty = HomeDashboardModel(
        teamName: "Your team",
        teamLogoURL: nil,
        seasons: [],
        selectedSeason: .all,
        total: 0,
        paid: 0,
        outstanding: 0,
        matchCount: 0,
        fineCount: 0,
        subCount: 0,
        playerBalances: []
    )

    var collectionRate: Int {
        let totalValue = NSDecimalNumber(decimal: total).doubleValue
        guard totalValue > 0 else {
            return 0
        }
        let paidValue = NSDecimalNumber(decimal: paid).doubleValue
        return Int((paidValue / totalValue * 100).rounded())
    }

    var effectiveSeason: SeasonSelection {
        selectedSeason.validated(against: seasons)
    }
}
