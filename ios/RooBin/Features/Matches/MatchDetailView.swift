import SwiftUI

struct MatchDetailView: View {
    @State private var selectedPlayerID: UUID?
    @State private var selectedFineTypeID: UUID?
    @State private var isSaving = false
    @State private var isUpdatingParticipants = false
    @State private var errorMessage: String?
    @State private var correctionEntry: LedgerEntry?
    @State private var blockedFine: MatchFineEntry?
    @State private var blockedPlayerName = ""
    @State private var showSubmitReview = false
    @State private var submittedOverride = false
    @State private var showFixtureEditor = false
    @State private var dateOverride: Date?
    @State private var opponentOverride: String?
    @State private var venueOverride: MatchSummary.Venue?
    @State private var seasonIDOverride: UUID??
    @State private var versionOverride: Int64?

    let match: MatchSummary
    let activity: MatchActivity
    let seasons: [SeasonOption]
    let players: [MatchPlayerOption]
    let fineTypes: [FineTypeOption]
    let canEdit: Bool
    let addFine: (UUID, UUID, UUID) async throws -> Void
    let updateParticipants: (UUID, Set<UUID>, Set<UUID>) async throws -> Void
    let reassignFine: (UUID, UUID) async throws -> Void
    let deleteEntry: (LedgerEntry, String) async throws -> Void
    let submitMatch: (UUID) async throws -> Void
    let updateFixture: (MatchFixtureDraft) async throws -> Int64

    var body: some View {
        List {
            Section("Fixture") {
                LabeledContent("Opponent", value: currentOpponent)
                LabeledContent(
                    "Date",
                    value: currentDate.formatted(date: .long, time: .omitted)
                )
                LabeledContent("Venue", value: currentVenue.displayName)
                if let seasonName = currentSeasonName {
                    LabeledContent("Season", value: seasonName)
                }
                LabeledContent(
                    "Status",
                    value: isSubmitted ? "Submitted" : "Draft"
                )
                if canEdit && !isSubmitted {
                    Button("Edit fixture") { showFixtureEditor = true }
                }
            }

            Section("Activity") {
                LabeledContent("Players", value: "\(match.playerCount)")
                LabeledContent("Fines", value: "\(match.fineCount)")
                LabeledContent(
                    "Total",
                    value: NSDecimalNumber(decimal: match.total).doubleValue.formatted(
                        .currency(code: "GBP")
                    )
                )
            }

            if canEdit && !isSubmitted {
                Section {
                    ForEach(players) { player in
                        HStack {
                            Button {
                                togglePlayer(player.id)
                            } label: {
                                Label(
                                    player.name,
                                    systemImage: activity.playerIDs.contains(player.id) ? "checkmark.circle.fill" : "circle"
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .disabled(isUpdatingParticipants)

                            if currentVenue == .away && activity.playerIDs.contains(player.id) {
                                Button {
                                    toggleDriver(player.id)
                                } label: {
                                    Label(
                                        "Driver",
                                        systemImage: activity.driverIDs.contains(player.id) ? "car.fill" : "car"
                                    )
                                }
                                .buttonStyle(.bordered)
                                .tint(activity.driverIDs.contains(player.id) ? RooBinTheme.Colors.accent : .secondary)
                                .disabled(isUpdatingParticipants)
                            }
                        }
                    }
                } header: {
                    Text("Players and drivers")
                } footer: {
                    Text("Away drivers follow the team's configured subs exemption.")
                }
            }

            Section("Fines") {
                if activity.fines.isEmpty {
                    Text("No fines recorded.")
                        .foregroundStyle(RooBinTheme.Colors.secondaryText)
                }
                ForEach(activity.fines) { fine in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(fine.playerName)
                            Text(fine.fineName).font(.caption).foregroundStyle(RooBinTheme.Colors.secondaryText)
                        }
                        Spacer()
                        Text(currency(fine.cost))
                            .foregroundStyle(fine.paid ? RooBinTheme.Colors.success : RooBinTheme.Colors.danger)
                        if canEdit {
                            Button {
                                correctionEntry = ledgerEntry(for: fine)
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Correct or delete \(fine.fineName) for \(fine.playerName)")
                        }
                    }
                }
            }

            Section("Subs") {
                if activity.subs.isEmpty {
                    Text("No subs charged.")
                        .foregroundStyle(RooBinTheme.Colors.secondaryText)
                }
                ForEach(activity.subs) { sub in
                    LabeledContent(sub.playerName, value: currency(sub.amount))
                }
            }

            if canEdit && !isSubmitted {
                Section("Add fine") {
                    Picker("Player", selection: $selectedPlayerID) {
                        Text("Select player").tag(UUID?.none)
                        ForEach(selectedPlayers) { player in
                            Text(player.name).tag(Optional(player.id))
                        }
                    }
                    Picker("Fine", selection: $selectedFineTypeID) {
                        Text("Select fine type").tag(UUID?.none)
                        ForEach(fineTypes) { fineType in
                            Text("\(fineType.name) · \(currency(fineType.cost))").tag(Optional(fineType.id))
                        }
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(RooBinTheme.Colors.danger)
                    }
                    Button("Add fine") { saveFine() }
                        .disabled(selectedPlayerID == nil || selectedFineTypeID == nil || isSaving)
                }
            }

            if canEdit && !isSubmitted {
                Section {
                    Button("Review and submit match") {
                        showSubmitReview = true
                    }
                    .accessibilityIdentifier("match.reviewSubmit")
                } footer: {
                    Text("Submission validates and locks the complete match record.")
                }
            }
        }
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $correctionEntry) { entry in
            FineCorrectionView(
                entry: entry,
                eligiblePlayers: selectedPlayers,
                reassignFine: reassignFine,
                deleteEntry: deleteEntry
            )
        }
        .alert("Fine prevents player removal", isPresented: Binding(
            get: { blockedFine != nil },
            set: { if !$0 { blockedFine = nil } }
        ), presenting: blockedFine) { fine in
            Button("Correct or delete fine") {
                correctionEntry = ledgerEntry(for: fine)
            }
            Button("Cancel", role: .cancel) {}
        } message: { fine in
            Text("\(blockedPlayerName) cannot be removed while \(fine.fineName) (\(currency(fine.cost))) is assigned to them. Paying it does not remove the record.")
        }
        .sheet(isPresented: $showSubmitReview) {
            SubmitMatchReviewView(
                match: displayMatch,
                activity: activity,
                players: players
            ) {
                try await submitMatch(match.id)
                submittedOverride = true
            }
        }
        .sheet(isPresented: $showFixtureEditor) {
            EditMatchFixtureView(
                match: displayMatch,
                expectedVersion: versionOverride ?? match.editVersion,
                seasons: seasons
            ) { draft in
                let newVersion = try await updateFixture(draft)
                dateOverride = draft.date
                opponentOverride = draft.opponent
                venueOverride = draft.venue
                seasonIDOverride = .some(draft.seasonID)
                versionOverride = newVersion
            }
        }
    }

    private var selectedPlayers: [MatchPlayerOption] {
        players.filter { activity.playerIDs.contains($0.id) }
    }

    private func saveFine() {
        guard let selectedPlayerID, let selectedFineTypeID else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await addFine(match.id, selectedPlayerID, selectedFineTypeID)
                self.selectedFineTypeID = nil
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }

    private func togglePlayer(_ playerID: UUID) {
        var playerIDs = Set(activity.playerIDs)
        var driverIDs = Set(activity.driverIDs)
        if playerIDs.contains(playerID) {
            if let fine = activity.fines.first(where: { $0.playerID == playerID }) {
                blockedPlayerName = players.first(where: { $0.id == playerID })?.name ?? fine.playerName
                blockedFine = fine
                return
            }
            playerIDs.remove(playerID)
            driverIDs.remove(playerID)
        } else {
            playerIDs.insert(playerID)
        }
        update(playerIDs: playerIDs, driverIDs: driverIDs)
    }

    private func toggleDriver(_ playerID: UUID) {
        var driverIDs = Set(activity.driverIDs)
        if driverIDs.contains(playerID) { driverIDs.remove(playerID) } else { driverIDs.insert(playerID) }
        update(playerIDs: Set(activity.playerIDs), driverIDs: driverIDs)
    }

    private func update(playerIDs: Set<UUID>, driverIDs: Set<UUID>) {
        isUpdatingParticipants = true
        errorMessage = nil
        Task {
            defer { isUpdatingParticipants = false }
            do {
                try await updateParticipants(match.id, playerIDs, driverIDs)
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }

    private func currency(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).doubleValue.formatted(.currency(code: "GBP"))
    }

    private var isSubmitted: Bool {
        match.submitted || submittedOverride
    }

    private var currentDate: Date { dateOverride ?? match.date }
    private var currentOpponent: String { opponentOverride ?? match.opponent }
    private var currentVenue: MatchSummary.Venue { venueOverride ?? match.venue }
    private var currentSeasonID: UUID? {
        if let seasonIDOverride { return seasonIDOverride }
        return match.seasonID
    }
    private var currentSeasonName: String? {
        currentSeasonID.flatMap { id in seasons.first { $0.id == id }?.name }
    }
    private var displayMatch: MatchSummary {
        MatchSummary(
            id: match.id,
            date: currentDate,
            opponent: currentOpponent,
            venue: currentVenue,
            seasonName: currentSeasonName,
            seasonID: currentSeasonID,
            submitted: isSubmitted,
            editVersion: versionOverride ?? match.editVersion,
            playerCount: match.playerCount,
            fineCount: match.fineCount,
            total: match.total
        )
    }

    private func ledgerEntry(for fine: MatchFineEntry) -> LedgerEntry {
        LedgerEntry(
            id: fine.id,
            matchID: match.id,
            playerID: fine.playerID,
            playerName: fine.playerName,
            label: fine.fineName,
            kind: .fine,
            amount: fine.cost,
            paid: fine.paid,
            date: match.date,
            seasonID: nil
        )
    }
}
