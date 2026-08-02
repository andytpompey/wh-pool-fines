import SwiftUI

struct EditMatchFixtureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var opponent: String
    @State private var venue: MatchSummary.Venue
    @State private var seasonID: UUID?
    @State private var isSaving = false
    @State private var errorMessage: String?

    let matchID: UUID
    let expectedVersion: Int64
    let seasons: [SeasonOption]
    let save: (MatchFixtureDraft) async throws -> Void

    init(
        match: MatchSummary,
        expectedVersion: Int64,
        seasons: [SeasonOption],
        save: @escaping (MatchFixtureDraft) async throws -> Void
    ) {
        matchID = match.id
        self.expectedVersion = expectedVersion
        self.seasons = seasons
        self.save = save
        _date = State(initialValue: match.date)
        _opponent = State(initialValue: match.opponent == "Opponent not set" ? "" : match.opponent)
        _venue = State(initialValue: match.venue)
        _seasonID = State(initialValue: match.seasonID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fixture") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Opponent", text: $opponent)
                        .textInputAutocapitalization(.words)
                    Picker("Venue", selection: $venue) {
                        Text("Home").tag(MatchSummary.Venue.home)
                        Text("Away").tag(MatchSummary.Venue.away)
                    }
                    .pickerStyle(.segmented)
                    Picker("Season", selection: $seasonID) {
                        Text("No season").tag(UUID?.none)
                        ForEach(seasons) { season in
                            Text(season.name).tag(Optional(season.id))
                        }
                    }
                }

                if venue == .home {
                    Section {
                        Label("Home matches cannot have designated drivers.", systemImage: "car")
                    } footer: {
                        Text("Saving as Home clears existing driver selections and reapplies the team’s current subs rules.")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(RooBinTheme.Colors.danger)
                    }
                }
            }
            .navigationTitle("Edit fixture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { performSave() }
                        .disabled(normalisedOpponent.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving { ProgressView("Saving fixture") }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var normalisedOpponent: String {
        opponent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func performSave() {
        guard !normalisedOpponent.isEmpty, !isSaving else { return }
        let draft = MatchFixtureDraft(
            matchID: matchID,
            expectedVersion: expectedVersion,
            date: date,
            opponent: normalisedOpponent,
            venue: venue,
            seasonID: seasonID
        )
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await save(draft)
                dismiss()
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
