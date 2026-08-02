import StoreKit
import SwiftUI

struct TeamSubscriptionView: View {
    let canPurchase: Bool
    let load: () async throws -> [CommercialPlayingCycle]
    let beginPurchase: (UUID) async throws -> AppStorePurchaseContext
    let verifyTransaction: (String) async throws -> AppStoreVerificationResponse

    @State private var cycles: [CommercialPlayingCycle] = []
    @State private var workingCycleID: UUID?
    @State private var isRestoring = false
    @State private var message: String?
    @State private var error: String?
    private let store = StoreKitPurchaseService()

    var body: some View {
        List {
            Section {
                Text("£10 per team per playing cycle")
                    .font(.headline)
                Text("One captain purchase covers every authorised member and all League, Cup and Plate records linked to that cycle.")
                    .font(.subheadline)
                    .foregroundStyle(RooBinTheme.Colors.secondaryText)
            }

            Section("Playing cycles") {
                if cycles.isEmpty {
                    Text("Create a season and set its cycle dates before purchasing access.")
                        .foregroundStyle(RooBinTheme.Colors.secondaryText)
                }
                ForEach(cycles) { cycle in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(cycle.name).font(.headline)
                                Text(boundaryText(cycle)).font(.caption).foregroundStyle(RooBinTheme.Colors.secondaryText)
                                if let purchaser = cycle.entitlementPurchaser {
                                    Text("Purchaser: \(purchaser)").font(.caption2).foregroundStyle(RooBinTheme.Colors.secondaryText)
                                }
                            }
                            Spacer()
                            Text(cycle.entitlementState.capitalized)
                                .font(.caption.bold())
                                .foregroundStyle(cycle.hasAccess ? .green : RooBinTheme.Colors.secondaryText)
                        }
                        if !cycle.hasAccess && canPurchase {
                            Button(workingCycleID == cycle.id ? "Purchasing…" : "Purchase with App Store") {
                                purchase(cycle)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!cycle.hasPurchaseBoundary || workingCycleID != nil || isRestoring)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button(isRestoring ? "Restoring…" : "Restore App Store purchases") { restore() }
                    .disabled(isRestoring || workingCycleID != nil)
                if let message { Label(message, systemImage: "checkmark.circle").foregroundStyle(.green) }
                if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(RooBinTheme.Colors.danger) }
            } footer: {
                Text("Purchases are verified by Apple and RooBin before team access is activated. Web purchases remain available through RooBin on the web.")
            }
        }
        .navigationTitle("Team subscription")
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func boundaryText(_ cycle: CommercialPlayingCycle) -> String {
        guard let start = cycle.startsOn, let end = cycle.endsOn else { return "Cycle dates required" }
        return "\(start) to \(end)"
    }

    private func purchase(_ cycle: CommercialPlayingCycle) {
        workingCycleID = cycle.id; error = nil; message = nil
        Task {
            defer { workingCycleID = nil }
            do {
                let context = try await beginPurchase(cycle.id)
                switch try await store.purchase(context: context, verifyOnServer: verifyTransaction) {
                case .purchased: message = "Access activated for \(cycle.name)."
                case .pending: message = "Purchase is pending App Store approval."
                case .cancelled: break
                }
                await refresh()
            } catch let value as LocalizedError { error = value.errorDescription }
            catch { self.error = RooBinError.unexpected.localizedDescription }
        }
    }

    private func restore() {
        isRestoring = true; error = nil; message = nil
        Task {
            defer { isRestoring = false }
            do {
                let count = try await store.restore(verifyOnServer: verifyTransaction)
                message = count == 1 ? "Restored 1 purchase." : "Restored \(count) purchases."
                await refresh()
            } catch let value as LocalizedError { error = value.errorDescription }
            catch { self.error = RooBinError.unexpected.localizedDescription }
        }
    }

    private func refresh() async {
        do { cycles = try await load(); error = nil }
        catch let value as LocalizedError { error = value.errorDescription }
        catch { self.error = RooBinError.unexpected.localizedDescription }
    }
}
