import SwiftUI

struct SubmitMatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?

    let match: MatchSummary
    let activity: MatchActivity
    let players: [MatchPlayerOption]
    let submit: () async throws -> Void

    var body: some View {
        NavigationStack {
            List {
                if !missingInformation.isEmpty {
                    Section {
                        ForEach(missingInformation, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(RooBinTheme.Colors.danger)
                        }
                    } header: {
                        Text("Resolve before submitting")
                    }
                }

                Section("Fixture") {
                    LabeledContent("Opponent", value: match.opponent)
                    LabeledContent("Date", value: match.date.formatted(date: .long, time: .omitted))
                    LabeledContent("Venue", value: match.venue.displayName)
                    LabeledContent("Season", value: match.seasonName ?? "No season")
                }

                Section("Players") {
                    ForEach(selectedPlayers) { player in
                        HStack {
                            Text(player.name)
                            Spacer()
                            if activity.driverIDs.contains(player.id) {
                                Label("Driver", systemImage: "car.fill")
                                    .font(.caption)
                            }
                        }
                    }
                    if selectedPlayers.isEmpty { Text("No players selected") }
                }

                Section("Fines") {
                    if activity.fines.isEmpty { Text("No fines recorded") }
                    ForEach(activity.fines) { fine in
                        LabeledContent(
                            "\(fine.playerName) · \(fine.fineName)",
                            value: currency(fine.cost)
                        )
                    }
                }

                Section("Subs") {
                    if activity.subs.isEmpty { Text("No subs charged") }
                    ForEach(activity.subs) { sub in
                        LabeledContent(sub.playerName, value: currency(sub.amount))
                    }
                }

                Section("Result") {
                    LabeledContent("Players", value: "\(activity.playerIDs.count)")
                    LabeledContent("Fines", value: "\(activity.fines.count)")
                    LabeledContent("Subs", value: "\(activity.subs.count)")
                    LabeledContent("Total", value: currency(total))
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(RooBinTheme.Colors.danger)
                    }
                }

                Section {
                    Button("Submit and lock match") {
                        showConfirmation = true
                    }
                    .disabled(!missingInformation.isEmpty || isSubmitting)
                } footer: {
                    Text("After submission, ordinary editing is locked. Reopening the match requires the protected team unlock flow.")
                }
            }
            .navigationTitle("Review match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
            }
            .confirmationDialog(
                "Submit and lock this match?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Submit and lock") { performSubmission() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This locks ordinary editing for \(activity.playerIDs.count) players, \(activity.fines.count) fines and \(activity.subs.count) subs totalling \(currency(total)).")
            }
            .overlay {
                if isSubmitting {
                    ProgressView("Submitting match")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private var selectedPlayers: [MatchPlayerOption] {
        let ids = Set(activity.playerIDs)
        return players.filter { ids.contains($0.id) }
    }

    private var missingInformation: [String] {
        var warnings: [String] = []
        if match.opponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || match.opponent == "Opponent not set" {
            warnings.append("Add an opponent.")
        }
        if activity.playerIDs.isEmpty { warnings.append("Select at least one player.") }
        let playerIDs = Set(activity.playerIDs)
        if activity.fines.contains(where: { $0.playerID == nil || !playerIDs.contains($0.playerID!) }) {
            warnings.append("Assign every fine to a player in this match.")
        }
        if activity.subs.contains(where: { $0.playerID == nil || !playerIDs.contains($0.playerID!) }) {
            warnings.append("Assign every sub to a player in this match.")
        }
        return warnings
    }

    private var total: Decimal {
        activity.fines.reduce(Decimal.zero) { $0 + $1.cost }
            + activity.subs.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func performSubmission() {
        guard !isSubmitting, missingInformation.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            defer { isSubmitting = false }
            do {
                try await submit()
                dismiss()
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
}
