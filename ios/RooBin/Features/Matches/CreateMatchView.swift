import SwiftUI

struct CreateMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var opponent = ""
    @State private var venue: MatchSummary.Venue = .home
    @State private var seasonID: UUID?
    @State private var selectedPlayerIDs: Set<UUID> = []
    @State private var driverIDs: Set<UUID> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    let seasons: [SeasonOption]
    let players: [MatchPlayerOption]
    let save: (MatchDraft) async throws -> Void

    var body: some View {
        Form {
            Section("Fixture") {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                TextField("Opponent", text: $opponent)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("createMatch.opponent")

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

            Section("Players") {
                if players.isEmpty {
                    Text("No active team players are available.")
                        .foregroundStyle(RooBinTheme.Colors.secondaryText)
                } else {
                    ForEach(players) { player in
                        Toggle(
                            player.name,
                            isOn: selectionBinding(for: player.id)
                        )
                        .accessibilityIdentifier("createMatch.player.\(player.id)")
                    }
                }
            }

            if venue == .away, !selectedPlayers.isEmpty {
                Section {
                    ForEach(selectedPlayers) { player in
                        Toggle(
                            player.name,
                            isOn: driverBinding(for: player.id)
                        )
                        .accessibilityIdentifier("createMatch.driver.\(player.id)")
                    }
                } header: {
                    Text("Drivers")
                } footer: {
                    Text("Driver selection affects subs only when the team’s rules enable that exemption.")
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(RooBinTheme.Colors.danger)
                }
            }

            Section {
                Button("Create match") {
                    submit()
                }
                .disabled(!canSubmit || isSaving)
                .accessibilityIdentifier("createMatch.submit")
            }
        }
        .navigationTitle("New match")
        .overlay {
            if isSaving {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Creating match")
            }
        }
        .onChange(of: venue) { _, newVenue in
            if newVenue == .home {
                driverIDs.removeAll()
            }
        }
    }

    private var normalisedOpponent: String {
        opponent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedPlayers: [MatchPlayerOption] {
        players.filter { selectedPlayerIDs.contains($0.id) }
    }

    private var canSubmit: Bool {
        !normalisedOpponent.isEmpty && !selectedPlayerIDs.isEmpty
    }

    private func selectionBinding(for playerID: UUID) -> Binding<Bool> {
        Binding {
            selectedPlayerIDs.contains(playerID)
        } set: { selected in
            if selected {
                selectedPlayerIDs.insert(playerID)
            } else {
                selectedPlayerIDs.remove(playerID)
                driverIDs.remove(playerID)
            }
        }
    }

    private func driverBinding(for playerID: UUID) -> Binding<Bool> {
        Binding {
            driverIDs.contains(playerID)
        } set: { selected in
            if selected {
                driverIDs.insert(playerID)
            } else {
                driverIDs.remove(playerID)
            }
        }
    }

    private func submit() {
        isSaving = true
        errorMessage = nil
        let draft = MatchDraft(
            id: UUID(),
            date: date,
            opponent: normalisedOpponent,
            venue: venue,
            seasonID: seasonID,
            playerIDs: selectedPlayerIDs,
            driverIDs: venue == .away ? driverIDs : []
        )

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
