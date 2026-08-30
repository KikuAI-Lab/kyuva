import Combine
import Foundation
import StoreKit
#if os(macOS)
import AppKit
#endif

enum ProAccessState: Equatable {
    case openPreview
    case purchased
    case trial(daysRemaining: Int)
    case locked

    var hasAccess: Bool {
        switch self {
        case .openPreview, .purchased, .trial:
            return true
        case .locked:
            return false
        }
    }
}

struct ProAccessPolicy {
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    static func evaluate(
        commerceEnabled: Bool,
        hasVerifiedPurchase: Bool,
        trialStartedAt: Date?,
        now: Date
    ) -> ProAccessState {
        guard commerceEnabled else { return .openPreview }
        guard !hasVerifiedPurchase else { return .purchased }
        guard let trialStartedAt else { return .locked }

        let elapsed = max(0, now.timeIntervalSince(trialStartedAt))
        let remaining = trialDuration - elapsed
        guard remaining > 0 else { return .locked }

        let daysRemaining = max(1, Int(ceil(remaining / (24 * 60 * 60))))
        return .trial(daysRemaining: daysRemaining)
    }
}

enum ProPurchaseOutcome: Equatable {
    case purchased
    case pending
    case cancelled
    case unavailable
    case failed
}

/// StoreKit 2 boundary for one cross-platform, lifetime Pro entitlement.
///
/// Commerce intentionally remains disabled until the App Store Connect product,
/// agreements, review metadata, and owner approval are all in place. While it is
/// disabled, Pro features remain an open preview and no StoreKit request is made.
@MainActor
final class ProEntitlementStore: ObservableObject {
    static let shared = ProEntitlementStore()
    static let lifetimeProductID = "com.kikuai.kyuva.pro.lifetime"
    nonisolated static var commerceEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["KYUVA_LOCAL_STOREKIT_TESTING"] == "1"
        #else
        false
        #endif
    }

    private static let trialStartedAtKey = "proTrialStartedAt"

    @Published private(set) var accessState: ProAccessState
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var isProcessingTransaction = false

    private let userDefaults: UserDefaults
    private let now: () -> Date
    private let isCommerceEnabled: Bool
    private var hasVerifiedPurchase = false
    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        commerceEnabled: Bool = ProEntitlementStore.commerceEnabled
    ) {
        self.userDefaults = userDefaults
        self.now = now
        self.isCommerceEnabled = commerceEnabled
        self.accessState = ProAccessPolicy.evaluate(
            commerceEnabled: commerceEnabled,
            hasVerifiedPurchase: false,
            trialStartedAt: userDefaults.object(forKey: Self.trialStartedAtKey) as? Date,
            now: now()
        )

        guard commerceEnabled else { return }
        transactionUpdatesTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var displayPrice: String? {
        lifetimeProduct?.displayPrice
    }

    func prepare() async {
        guard isCommerceEnabled else {
            refreshAccessState()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            lifetimeProduct = try await Product.products(
                for: [Self.lifetimeProductID]
            ).first { $0.type == .nonConsumable }
        } catch {
            lifetimeProduct = nil
        }

        await refreshVerifiedEntitlement()
    }

    func startTrial() {
        guard isCommerceEnabled else { return }
        guard userDefaults.object(forKey: Self.trialStartedAtKey) == nil else {
            refreshAccessState()
            return
        }

        userDefaults.set(now(), forKey: Self.trialStartedAtKey)
        refreshAccessState()
    }

    #if os(macOS)
    func purchaseLifetime(confirmIn window: NSWindow? = nil) async -> ProPurchaseOutcome {
        guard let window else { return .unavailable }
        return await purchaseLifetime { product in
            if #available(macOS 15.2, *) {
                return try await product.purchase(confirmIn: window)
            }
            return try await product.purchase()
        }
    }
    #else
    func purchaseLifetime() async -> ProPurchaseOutcome {
        await purchaseLifetime { product in
            try await product.purchase()
        }
    }
    #endif

    private func purchaseLifetime(
        using purchase: (Product) async throws -> Product.PurchaseResult
    ) async -> ProPurchaseOutcome {
        guard isCommerceEnabled, let lifetimeProduct else {
            return .unavailable
        }
        guard !isProcessingTransaction else { return .pending }

        isProcessingTransaction = true
        defer { isProcessingTransaction = false }

        do {
            switch try await purchase(lifetimeProduct) {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshVerifiedEntitlement()
                return .purchased
            case .success(.unverified):
                return .failed
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    func restorePurchases() async -> Bool {
        guard isCommerceEnabled else { return false }
        guard !isProcessingTransaction else { return false }

        isProcessingTransaction = true
        defer { isProcessingTransaction = false }

        do {
            try await AppStore.sync()
            await refreshVerifiedEntitlement()
            return hasVerifiedPurchase
        } catch {
            return false
        }
    }

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.lifetimeProductID else { continue }

            await transaction.finish()
            await refreshVerifiedEntitlement()
        }
    }

    private func refreshVerifiedEntitlement() async {
        var isPurchased = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.lifetimeProductID else { continue }
            guard transaction.revocationDate == nil else { continue }

            isPurchased = true
            break
        }

        hasVerifiedPurchase = isPurchased
        refreshAccessState()
    }

    private func refreshAccessState() {
        accessState = ProAccessPolicy.evaluate(
            commerceEnabled: isCommerceEnabled,
            hasVerifiedPurchase: hasVerifiedPurchase,
            trialStartedAt: userDefaults.object(forKey: Self.trialStartedAtKey) as? Date,
            now: now()
        )
    }
}
