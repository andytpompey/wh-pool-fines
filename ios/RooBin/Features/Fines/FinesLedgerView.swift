import SwiftUI

struct FinesLedgerView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var paymentFilter: LedgerPaymentFilter = .all
    @State private var kindFilter: LedgerEntry.Kind?
    @State private var playerID: UUID?
    @State private var seasonID: UUID?
    @State private var pendingEntry: LedgerEntry?
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var correctionEntry: LedgerEntry?

    let entries: [LedgerEntry]
    let seasons: [SeasonOption]
    let players: [MatchPlayerOption]
    let activity: [UUID: MatchActivity]
    let canManagePayments: Bool
    let updatePaymentStatus: ([LedgerEntry], Bool) async throws -> Void
    let reassignFine: (UUID, UUID) async throws -> Void
    let deleteEntry: (LedgerEntry, String) async throws -> Void
    let refresh: () async -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filters

                List(filteredEntries) { entry in
                    ledgerRow(entry)
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canManagePayments {
                                Button(entry.paid ? "Mark unpaid" : "Mark paid") {
                                    pendingEntry = entry
                                }
                                .tint(entry.paid ? RooBinTheme.Colors.danger : RooBinTheme.Colors.success)
                            }
                        }
                        .contextMenu {
                            if canManagePayments {
                                Button(entry.paid ? "Mark unpaid" : "Mark paid") {
                                    pendingEntry = entry
                                }
                            }
                        }
                        .accessibilityIdentifier("ledger.row.\(entry.id)")
                }
                .overlay {
                    if filteredEntries.isEmpty {
                        ContentUnavailableView {
                            Label("No ledger entries", systemImage: "sterlingsign.circle")
                        } description: {
                            Text("Try another filter or record activity in a match.")
                        }
                        .accessibilityIdentifier("ledger.empty")
                    }
                }
                .refreshable {
                    await refresh()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                pendingEntry.map { $0.paid ? "Mark this entry unpaid?" : "Mark this entry paid?" } ?? "Update payment status?",
                isPresented: Binding(
                    get: { pendingEntry != nil },
                    set: { if !$0 { pendingEntry = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingEntry
            ) { entry in
                Button(entry.paid ? "Mark unpaid" : "Mark paid") {
                    applyPaymentUpdate(entry)
                }
                Button("Cancel", role: .cancel) {}
            } message: { entry in
                Text("\(entry.playerName) · \(entry.kind.displayName) · \(currency(entry.amount)). This change will update one record.")
            }
            .alert("Payment status not updated", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .sheet(item: $correctionEntry) { entry in
                FineCorrectionView(
                    entry: entry,
                    eligiblePlayers: matchPlayers(for: entry),
                    reassignFine: reassignFine,
                    deleteEntry: deleteEntry
                )
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack {
                Picker("Payment status", selection: $paymentFilter) {
                    ForEach(LedgerPaymentFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ledger.paymentFilter")

                Picker("Entry type", selection: $kindFilter) {
                    Text("All types").tag(LedgerEntry.Kind?.none)
                    ForEach(LedgerEntry.Kind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(Optional(kind))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ledger.kindFilter")

                Picker("Player", selection: $playerID) {
                    Text("All players").tag(UUID?.none)
                    ForEach(players) { player in
                        Text(player.name).tag(Optional(player.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ledger.playerFilter")

                Picker("Season", selection: $seasonID) {
                    Text("All seasons").tag(UUID?.none)
                    ForEach(seasons) { season in
                        Text(season.name).tag(Optional(season.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ledger.seasonFilter")
            }
            .padding(.horizontal)
            .padding(.vertical, RooBinTheme.Spacing.compact)
        }
    }

    private var filteredEntries: [LedgerEntry] {
        entries.filter { entry in
            let paymentMatches = switch paymentFilter {
            case .all: true
            case .paid: entry.paid
            case .unpaid: !entry.paid
            }
            return paymentMatches
                && (kindFilter == nil || entry.kind == kindFilter)
                && (playerID == nil || entry.playerID == playerID)
                && (seasonID == nil || entry.seasonID == seasonID)
        }
    }

    private func ledgerRow(_ entry: LedgerEntry) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: RooBinTheme.Spacing.compact) {
                    ledgerIdentity(entry)
                    amountAndState(entry, alignment: .leading)
                    if canManagePayments { entryMenu(entry) }
                }
            } else {
                HStack {
                    ledgerIdentity(entry)
                    Spacer()
                    amountAndState(entry, alignment: .trailing)
                    if canManagePayments { entryMenu(entry) }
                }
            }
        }
        .accessibilityElement(children: canManagePayments ? .contain : .combine)
    }

    private func ledgerIdentity(_ entry: LedgerEntry) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.playerName)
                    .font(.headline)
                Text("\(entry.kind.displayName) · \(entry.label)")
                    .font(.subheadline)
                    .foregroundStyle(RooBinTheme.Colors.secondaryText)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(RooBinTheme.Colors.secondaryText)
            }
    }

    private func amountAndState(_ entry: LedgerEntry, alignment: HorizontalAlignment) -> some View {
            VStack(alignment: alignment, spacing: 4) {
                Text(
                    NSDecimalNumber(decimal: entry.amount).doubleValue.formatted(
                        .currency(code: "GBP")
                    )
                )
                .font(.headline)
                .lineLimit(1)
                Text(entry.paid ? "Paid" : "Unpaid")
                    .font(.caption.bold())
                    .foregroundStyle(
                        entry.paid
                            ? RooBinTheme.Colors.success
                            : RooBinTheme.Colors.danger
                    )
            }
    }

    private func entryMenu(_ entry: LedgerEntry) -> some View {
                Menu {
                    Button(entry.paid ? "Mark unpaid" : "Mark paid") {
                        pendingEntry = entry
                    }
                    Button(entry.kind == .fine ? "Correct or delete fine" : "Delete sub") {
                        correctionEntry = entry
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .disabled(isUpdating)
                .accessibilityLabel("Actions for \(entry.label)")
                .accessibilityHint("Change payment status, reassign, or delete this entry")
    }

    private func applyPaymentUpdate(_ entry: LedgerEntry) {
        guard !isUpdating else { return }
        isUpdating = true
        Task {
            defer { isUpdating = false }
            do {
                try await updatePaymentStatus([entry], !entry.paid)
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

    private func matchPlayers(for entry: LedgerEntry) -> [MatchPlayerOption] {
        let playerIDs = Set(activity[entry.matchID]?.playerIDs ?? [])
        return players.filter { playerIDs.contains($0.id) }
    }
}
