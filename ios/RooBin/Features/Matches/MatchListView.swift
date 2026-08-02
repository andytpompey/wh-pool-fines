import SwiftUI

struct MatchListView: View {
    let matches: [MatchSummary]
    let seasons: [SeasonOption]
    let players: [MatchPlayerOption]
    let fineTypes: [FineTypeOption]
    let activity: [UUID: MatchActivity]
    let canCreate: Bool
    let errorMessage: String?
    let refresh: () async -> Void
    let createMatch: (MatchDraft) async throws -> Void
    let addFine: (UUID, UUID, UUID) async throws -> Void
    let updateMatchParticipants: (UUID, Set<UUID>, Set<UUID>) async throws -> Void
    let reassignFine: (UUID, UUID) async throws -> Void
    let deleteEntry: (LedgerEntry, String) async throws -> Void
    let submitMatch: (UUID) async throws -> Void
    let updateMatchFixture: (MatchFixtureDraft) async throws -> Int64

    var body: some View {
        NavigationStack {
            List(matches) { match in
                NavigationLink(value: match) {
                    MatchRow(match: match)
                }
                .accessibilityIdentifier("matches.row.\(match.id)")
            }
            .overlay {
                if matches.isEmpty {
                    ContentUnavailableView {
                        Label("No matches yet", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Create a fixture to start recording players, fines and subs.")
                    }
                    .accessibilityIdentifier("matches.empty")
                }
            }
            .refreshable {
                await refresh()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if canCreate {
                    NavigationLink {
                        CreateMatchView(seasons: seasons, players: players, save: createMatch)
                    } label: {
                        Label("New match", systemImage: "plus")
                    }
                    .accessibilityIdentifier("matches.create")
                }
            }
            .navigationDestination(for: MatchSummary.self) { match in
                let currentMatch = matches.first { $0.id == match.id } ?? match
                MatchDetailView(
                    match: currentMatch,
                    activity: activity[currentMatch.id] ?? MatchActivity(playerIDs: [], driverIDs: [], fines: [], subs: []),
                    seasons: seasons,
                    players: players,
                    fineTypes: fineTypes,
                    canEdit: canCreate,
                    addFine: addFine,
                    updateParticipants: updateMatchParticipants,
                    reassignFine: reassignFine,
                    deleteEntry: deleteEntry,
                    submitMatch: submitMatch,
                    updateFixture: updateMatchFixture
                )
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(RooBinTheme.Colors.danger)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
}

private struct MatchRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let match: MatchSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    matchHeading
                    matchState
                }
            } else {
                HStack {
                    matchHeading
                    Spacer()
                    matchState
                }
            }

            Text(match.date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(RooBinTheme.Colors.secondaryText)
            Text(match.venue.displayName)
                .font(.subheadline)
                .foregroundStyle(RooBinTheme.Colors.secondaryText)

            Text("\(match.playerCount) players · \(match.fineCount) fines · \(currency(match.total))")
                .font(.caption)
                .foregroundStyle(RooBinTheme.Colors.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var matchHeading: some View {
                Text(match.opponent)
                    .font(.headline)
    }

    private var matchState: some View {
                Text(match.submitted ? "Submitted" : "Draft")
                    .font(.caption.bold())
                    .foregroundStyle(
                        match.submitted
                            ? RooBinTheme.Colors.success
                            : RooBinTheme.Colors.accent
                    )
    }

    private func currency(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).doubleValue.formatted(
            .currency(code: "GBP")
        )
    }
}
