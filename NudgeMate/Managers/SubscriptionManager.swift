import Foundation
import Observation
import StoreKit

private typealias L10n = NudgeMateStrings.Localizable

enum SubscriptionProductID: String, CaseIterable, Sendable {
    case monthly = "com.nudgemate.pro.monthly"
    case yearly = "com.nudgemate.pro.yearly"
    case lifetime = "com.nudgemate.pro.lifetime"

    fileprivate var displayOrder: Int {
        switch self {
        case .monthly: return 0
        case .yearly: return 1
        case .lifetime: return 2
        }
    }
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case pending
    case cancelled
}

enum EntitlementState: Equatable, Sendable {
    case free
    case proSubscription
    case proLifetime
    case pending
    case unknown
}

enum SubscriptionError: LocalizedError {
    case productsUnavailable
    case productNotSupported
    case purchasesNotAllowed
    case failedVerification
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            return L10n.Subscription.Error.productsUnavailable
        case .productNotSupported:
            return L10n.Subscription.Error.productNotSupported
        case .purchasesNotAllowed:
            return L10n.Subscription.Error.purchasesNotAllowed
        case .failedVerification:
            return L10n.Subscription.Error.failedVerification
        case .unknownPurchaseResult:
            return L10n.Subscription.Error.unknownPurchaseResult
        }
    }
}

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    static let productIDs = Set(SubscriptionProductID.allCases.map(\.rawValue))

    private(set) var products: [Product] = []
    private(set) var activeProductIDs: Set<String> = []
    private(set) var isPro = false
    private(set) var entitlementState: EntitlementState = .unknown
    private(set) var isLoadingProducts = false
    private(set) var purchasingProductID: String?
    private(set) var lastErrorMessage: String?

    var isPurchasing: Bool {
        purchasingProductID != nil
    }

    @ObservationIgnored
    private var transactionUpdatesTask: Task<Void, Never>?

    init(automaticallyStarts: Bool = true) {
        guard automaticallyStarts else { return }

        observeTransactionUpdates()
        Task { [weak self] in
            await self?.prepare()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func prepare() async {
        do {
            try await fetchProducts()
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        await refreshEntitlements()
    }

    func fetchProducts() async throws {
        guard !isLoadingProducts else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetchedProducts = try await Product.products(
                for: SubscriptionProductID.allCases.map(\.rawValue)
            )

            guard !fetchedProducts.isEmpty else {
                throw SubscriptionError.productsUnavailable
            }

            products = fetchedProducts.sorted { lhs, rhs in
                order(for: lhs.id) < order(for: rhs.id)
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func product(for productID: SubscriptionProductID) -> Product? {
        products.first { $0.id == productID.rawValue }
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        guard Self.productIDs.contains(product.id) else {
            throw SubscriptionError.productNotSupported
        }
        guard AppStore.canMakePayments else {
            throw SubscriptionError.purchasesNotAllowed
        }

        purchasingProductID = product.id
        lastErrorMessage = nil
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()

            switch result {
            case let .success(verificationResult):
                let transaction = try verified(verificationResult)
                guard Self.productIDs.contains(transaction.productID) else {
                    throw SubscriptionError.productNotSupported
                }

                await refreshEntitlements()
                await transaction.finish()
                return .purchased

            case .pending:
                entitlementState = .pending
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                throw SubscriptionError.unknownPurchaseResult
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func restorePurchases() async throws {
        lastErrorMessage = nil

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func refreshEntitlements() async {
        var entitledProductIDs = Set<String>()
        var encounteredVerificationFailure = false

        if #available(iOS 18.4, *) {
            for productID in Self.productIDs {
                for await result in Transaction.currentEntitlements(for: productID) {
                    switch result {
                    case let .verified(transaction):
                        if isActive(transaction) {
                            entitledProductIDs.insert(transaction.productID)
                        }
                    case .unverified:
                        encounteredVerificationFailure = true
                    }
                }
            }
        } else {
            for await result in Transaction.currentEntitlements {
                switch result {
                case let .verified(transaction):
                    if isActive(transaction) {
                        entitledProductIDs.insert(transaction.productID)
                    }
                case .unverified:
                    encounteredVerificationFailure = true
                }
            }
        }

        activeProductIDs = entitledProductIDs
        isPro = !entitledProductIDs.isEmpty
        if entitledProductIDs.contains(SubscriptionProductID.lifetime.rawValue) {
            entitlementState = .proLifetime
        } else if !entitledProductIDs.isEmpty {
            entitlementState = .proSubscription
        } else {
            entitlementState = .free
        }

        if encounteredVerificationFailure {
            lastErrorMessage = SubscriptionError.failedVerification.localizedDescription
        }
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private func observeTransactionUpdates() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled, let self else { return }

                do {
                    let transaction = try self.verified(result)
                    guard Self.productIDs.contains(transaction.productID) else { continue }

                    await self.refreshEntitlements()
                    await transaction.finish()
                } catch {
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private nonisolated func verified<T>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case let .verified(value):
            return value
        case .unverified:
            throw SubscriptionError.failedVerification
        }
    }

    private func isActive(_ transaction: Transaction, now: Date = .now) -> Bool {
        guard Self.productIDs.contains(transaction.productID) else { return false }
        guard transaction.revocationDate == nil, !transaction.isUpgraded else { return false }

        if let expirationDate = transaction.expirationDate {
            return expirationDate > now
        }
        return true
    }

    private func order(for productID: String) -> Int {
        SubscriptionProductID(rawValue: productID)?.displayOrder ?? .max
    }
}
