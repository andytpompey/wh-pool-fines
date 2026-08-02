import SwiftUI

struct FineCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlayerID: UUID?
    @State private var unlockCode = ""
    @State private var isWorking = false
    @State private var confirmReassignment = false
    @State private var confirmDeletion = false
    @State private var errorMessage: String?

    let entry: LedgerEntry
    let eligiblePlayers: [MatchPlayerOption]
    let reassignFine: (UUID, UUID) async throws -> Void
    let deleteEntry: (LedgerEntry, String) async throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Affected record") {
                    LabeledContent("Player", value: entry.playerName)
                    LabeledContent("Entry", value: entry.label)
                    LabeledContent("Amount", value: currency(entry.amount))
                    LabeledContent("Status", value: entry.paid ? "Paid" : "Unpaid")
                }

                if entry.kind == .fine {
                    Section {
                        Picker("New player", selection: $selectedPlayerID) {
                            Text("Select player").tag(UUID?.none)
                            ForEach(reassignmentPlayers) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }
                        Button("Review reassignment") {
                            confirmReassignment = true
                        }
                        .disabled(selectedPlayerID == nil || isWorking)
                    } header: {
                        Text("Reassign fine")
                    } footer: {
                        Text("The fine, amount and payment status stay unchanged. The new player must be in this match.")
                    }
                }

                Section {
                    SecureField("Team unlock code", text: $unlockCode)
                        .keyboardType(.numberPad)
                        .textContentType(.password)
                        .privacySensitive()
                    Button("Review permanent deletion", role: .destructive) {
                        confirmDeletion = true
                    }
                    .disabled(unlockCode.count < 4 || isWorking)
                } header: {
                    Text("Delete record")
                } footer: {
                    Text("Deletion permanently removes this \(entry.kind.displayName.lowercased()), changes team totals, and is recorded in the audit log.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(RooBinTheme.Colors.danger)
                    }
                }
            }
            .navigationTitle("Correct entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isWorking)
                }
            }
            .confirmationDialog(
                "Reassign this fine?",
                isPresented: $confirmReassignment,
                titleVisibility: .visible
            ) {
                Button("Reassign fine") { applyReassignment() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Move \(entry.label) (\(currency(entry.amount))) from \(entry.playerName) to \(selectedPlayer?.name ?? "the selected player"). One record will change.")
            }
            .confirmationDialog(
                "Permanently delete this \(entry.kind.displayName.lowercased())?",
                isPresented: $confirmDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete permanently", role: .destructive) { applyDeletion() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes \(entry.label) (\(currency(entry.amount))) for \(entry.playerName) and changes the team totals. This cannot be undone.")
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    private var reassignmentPlayers: [MatchPlayerOption] {
        eligiblePlayers.filter { $0.id != entry.playerID }
    }

    private var selectedPlayer: MatchPlayerOption? {
        eligiblePlayers.first { $0.id == selectedPlayerID }
    }

    private func applyReassignment() {
        guard let selectedPlayerID, !isWorking else { return }
        perform {
            try await reassignFine(entry.id, selectedPlayerID)
        }
    }

    private func applyDeletion() {
        let suppliedCode = unlockCode
        guard suppliedCode.count >= 4, !isWorking else { return }
        perform {
            try await deleteEntry(entry, suppliedCode)
        }
    }

    private func perform(_ operation: @escaping () async throws -> Void) {
        isWorking = true
        errorMessage = nil
        Task {
            defer {
                unlockCode = ""
                isWorking = false
            }
            do {
                try await operation()
                dismiss()
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }

    private func currency(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).doubleValue.formatted(.currency(code: "GBP"))
    }
}
