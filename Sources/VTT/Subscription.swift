import Foundation
import StoreKit

/// StoreKit 2 wrapper for the auto-renewable subscription that removes the free
/// daily dictation limit.
///
/// VTT's plans are deliberately modular: each subscription unlocks one
/// capability, billed separately, so users only pay for what they use. This
/// store handles the *Unlimited Dictation* plan (speech-to-text). Future
/// modules (e.g. pipelines) will be their own products and their own stores —
/// subscribing here never bundles or pre-charges for them.
///
/// Entitlement is the source of truth: `isPro` is derived from
/// `Transaction.currentEntitlements`, which Apple signs and verifies, so the
/// paid unlock can't be forged locally even though the free-tier usage counter
/// (see `AppState`) is tracked client-side.
@MainActor
final class SubscriptionStore: ObservableObject {
    /// User-facing name of this plan. Scoped to the feature it unlocks so it
    /// reads honestly alongside future, separate plans.
    static let planName = "Unlimited Dictation"

    /// App Store Connect product identifier for the $9.99/mo dictation plan.
    /// Feature-scoped (`.dictation.`) so future modules get their own IDs.
    /// Must match the product configured in App Store Connect.
    static let monthlyProductID = "com.theihor.vtt.dictation.monthly"

    /// The loaded monthly subscription product, once fetched from the App Store.
    @Published private(set) var monthly: Product?

    /// Whether the user currently holds an active VTT Pro entitlement.
    @Published private(set) var isPro = false

    /// True while a purchase or restore is in flight.
    @Published private(set) var working = false

    /// Last user-facing error from a load/purchase/restore attempt.
    @Published var lastError: String?

    init() {
        // Listen for transactions made elsewhere (renewals, refunds, Ask-to-Buy
        // approvals, purchases on another device) for the app's lifetime.
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    /// Fetch the product and recompute entitlement. Safe to call repeatedly.
    func refresh() async {
        await loadProducts()
        await updateEntitlement()
    }

    private func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.monthlyProductID])
            monthly = products.first
        } catch {
            lastError = "Couldn't reach the App Store: \(error.localizedDescription)"
        }
    }

    /// Recompute `isPro` from the current set of verified entitlements.
    private func updateEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.monthlyProductID, transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    func purchase() async {
        guard let monthly else {
            lastError = "Subscription isn't available right now."
            return
        }
        working = true
        defer { working = false }
        do {
            switch try await monthly.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await updateEntitlement()
                } else {
                    lastError = "Purchase couldn't be verified."
                }
            case .userCancelled:
                break
            case .pending:
                lastError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        working = true
        defer { working = false }
        do {
            try await AppStore.sync()
            await updateEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await updateEntitlement()
    }

    /// Localized price from the App Store (e.g. "$9.99"), or a placeholder
    /// before the product loads.
    var displayPrice: String { monthly?.displayPrice ?? "$9.99" }
}
