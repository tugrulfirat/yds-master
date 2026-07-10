import Foundation
import StoreKit

/// StoreKit 2 subscription manager: loads the three premium products,
/// handles purchase/restore, and tracks the current entitlement.
///
/// Product IDs must match App Store Connect exactly. Prices (₺40 monthly,
/// ₺150 six-month, ₺250 yearly introductory) are configured in App Store
/// Connect, never hard-coded — the paywall always shows `displayPrice`
/// straight from StoreKit.
@MainActor
final class PremiumStore: ObservableObject {

    enum ProductID {
        static let monthly = "com.tugrulfirat.ydsmaster.premium.monthly"
        static let sixMonths = "com.tugrulfirat.ydsmaster.premium.sixmonths"
        static let yearly = "com.tugrulfirat.ydsmaster.premium.yearly"
        static let all = [yearly, sixMonths, monthly]
    }

    @Published private(set) var isPremium = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInFlight = false
    @Published var lastErrorTR: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            // Keep entitlement fresh across renewals/refunds/family sharing.
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.all)
            // Stable display order: yearly, six-month, monthly.
            products = ProductID.all.compactMap { id in loaded.first { $0.id == id } }
        } catch {
            lastErrorTR = "Abonelik seçenekleri yüklenemedi. İnternet bağlantını kontrol et."
        }
    }

    func refreshEntitlement() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               ProductID.all.contains(transaction.productID) {
                active = true
            }
        }
        isPremium = active
    }

    func purchase(_ product: Product) async {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlement()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastErrorTR = "Satın alma tamamlanamadı. Lütfen tekrar dene."
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPremium {
                lastErrorTR = "Geri yüklenecek bir abonelik bulunamadı."
            }
        } catch {
            lastErrorTR = "Geri yükleme başarısız oldu. Lütfen tekrar dene."
        }
    }
}
