import Foundation

struct ManagedSeason: Identifiable, Equatable, Sendable, Decodable {
    let id: UUID
    let name: String
    let type: String
    let source: String?
    let matchCount: Int
}
