import Foundation
import StoreKit

/// StoreKit 2 tip jar. Three consumable "supporter pack" tips — pure
/// gratitude, zero gameplay effect, no dark patterns. Buying any pack marks
/// the profile as a supporter (cosmetic badge on the home screen).
@MainActor
final class StoreService: ObservableObject {

    static let productIDs = [
        "com.plantify.supporter.seedling",
        "com.plantify.supporter.gardener",
        "com.plantify.supporter.oak",
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var lastThankYou: Date?

    private var updatesTask: Task<Void, Never>?

    func start() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    self?.lastThankYou = .now
                }
            }
        }
        Task { await loadProducts() }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        products = (try? await Product.products(for: Self.productIDs))?
            .sorted { $0.price < $1.price } ?? []
    }

    /// Returns true when the purchase completed (verified).
    func purchase(_ product: Product) async -> Bool {
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            lastThankYou = .now
            return true
        default:
            return false
        }
    }
}
