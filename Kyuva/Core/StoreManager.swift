import Foundation
import StoreKit

/// Manages In-App Purchase for Pro features
@MainActor
class StoreManager: ObservableObject {
    
    static let shared = StoreManager()
    
    // Product ID configured in App Store Connect
    static let proProductID = "dev.kikuai.kyuva.pro"
    
    @Published var isPro: Bool = false
    @Published var proProduct: Product?
    @Published var purchaseState: PurchaseState = .ready
    
    enum PurchaseState: Equatable {
        case ready
        case purchasing
        case purchased
        case failed(String)
    }
    
    init() {
        Task {
            await loadProducts()
            await checkPurchaseStatus()
        }
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchasePro() async {
        guard let product = proProduct else { return }
        
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    isPro = true
                    purchaseState = .purchased
                    savePurchaseStatus(true)
                case .unverified:
                    purchaseState = .failed("Purchase could not be verified")
                }
            case .userCancelled:
                purchaseState = .ready
            case .pending:
                purchaseState = .ready
            @unknown default:
                purchaseState = .ready
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkPurchaseStatus()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }
    
    // MARK: - Check Status
    
    func checkPurchaseStatus() async {
        // Check for existing entitlement
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if transaction.productID == Self.proProductID {
                isPro = true
                savePurchaseStatus(true)
                return
            }
        }
        
        // Fallback to local cache
        isPro = loadPurchaseStatus()
    }
    
    // MARK: - Local Cache
    
    private func savePurchaseStatus(_ isPro: Bool) {
        UserDefaults.standard.set(isPro, forKey: "kyuva_pro")
    }
    
    private func loadPurchaseStatus() -> Bool {
        UserDefaults.standard.bool(forKey: "kyuva_pro")
    }
}

// MARK: - Pro Features

extension StoreManager {
    
    /// Features available only in Pro
    enum ProFeature {
        case voiceFollow
        case unlimitedScripts
        case customHotkeys
    }
    
    /// Check if a feature is available
    func isFeatureAvailable(_ feature: ProFeature) -> Bool {
        switch feature {
        case .voiceFollow:
            return isPro
        case .unlimitedScripts:
            return isPro
        case .customHotkeys:
            return isPro
        }
    }
    
    /// Script limit for free version
    var scriptLimit: Int {
        isPro ? Int.max : 3
    }
}
