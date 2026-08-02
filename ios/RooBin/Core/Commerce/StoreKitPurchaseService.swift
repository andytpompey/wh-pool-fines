import Foundation
import StoreKit

@MainActor
final class StoreKitPurchaseService {
    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
    }

    func purchase(
        context: AppStorePurchaseContext,
        verifyOnServer: (String) async throws -> AppStoreVerificationResponse
    ) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [context.productID]).first else {
            throw RooBinError.validation(message: "This App Store purchase is not currently available.")
        }
        let result = try await product.purchase(options: [.appAccountToken(context.contextID)])
        switch result {
        case let .success(verification):
            let signedTransaction = verification.jwsRepresentation
            let transaction = try Self.verified(verification)
            let response = try await verifyOnServer(signedTransaction)
            guard response.verified, response.playingCycleID == context.playingCycleID, response.state == "active" else {
                throw RooBinError.serviceUnavailable
            }
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw RooBinError.unexpected
        }
    }

    func restore(
        verifyOnServer: (String) async throws -> AppStoreVerificationResponse
    ) async throws -> Int {
        try await AppStore.sync()
        var restored = 0
        for await result in Transaction.currentEntitlements {
            let signedTransaction = result.jwsRepresentation
            let transaction = try Self.verified(result)
            guard transaction.productType == .nonRenewable else { continue }
            let response = try await verifyOnServer(signedTransaction)
            if response.verified { restored += 1 }
            await transaction.finish()
        }
        return restored
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value): value
        case .unverified: throw RooBinError.validation(message: "The App Store transaction could not be verified on this device.")
        }
    }
}
