import AppKit
import Foundation

/// Pro entitlement for the direct-download (Developer ID) build, where StoreKit
/// doesn't work: the user buys a subscription on the website (Lemon Squeezy,
/// merchant of record) and receives a license key, which this store activates
/// and periodically revalidates against the Lemon Squeezy License API.
///
/// Privacy contract: no account, no sign-in. The only things stored are the
/// key and its activation instance ID (both in the Keychain) plus the date of
/// the last successful validation. Revalidation is quiet and has a generous
/// offline grace window so a flaky network never locks a paying user out.
///
/// Compiled into every build, but only the `DIRECT_DISTRIBUTION` builds surface
/// it (see `AppState.isPro` and the Settings Pro tab) — the Mac App Store build
/// sells exclusively through StoreKit.
@MainActor
final class LicenseStore: ObservableObject {
    // MARK: - Store configuration (Lemon Squeezy)

    /// Lemon Squeezy store ID — Settings → General in the LS dashboard.
    /// TODO: fill in (Settings → General → Store ID).
    static let storeID = 0
    /// Product ID of the "VTT — Unlimited Dictation" subscription.
    static let productID = 1139605
    /// Checkout page for the subscription (the product's "Share" URL on the
    /// store's custom domain).
    static let buyURL = URL(string: "https://lsq-store.the-ihor.com")!
    /// Customer portal where subscribers manage/cancel billing.
    static let manageURL = URL(string: "https://lsq-store.the-ihor.com/billing")!

    /// Revalidate quietly when the last check is older than this.
    private static let revalidateAfter: TimeInterval = 3 * 24 * 3600
    /// Keep Pro active without a successful check for up to this long
    /// (offline grace). An explicit "invalid" verdict ends Pro immediately.
    private static let graceWindow: TimeInterval = 14 * 24 * 3600

    private static let keyAccount = "ls.licenseKey"
    private static let instanceAccount = "ls.instanceID"
    private static let validatedAtKey = "licenseValidatedAt"

    // MARK: - Published state

    @Published private(set) var isPro = false
    @Published private(set) var working = false
    @Published var lastError: String?
    /// Masked key for display, e.g. "XXXX…-A1B2".
    @Published private(set) var maskedKey: String?

    init() {
        if let key = Keychain.get(Self.keyAccount), !key.isEmpty {
            maskedKey = Self.mask(key)
            // Within grace: assume Pro now, then revalidate in the background.
            isPro = Date().timeIntervalSince(lastValidatedAt) < Self.graceWindow
            if Date().timeIntervalSince(lastValidatedAt) > Self.revalidateAfter {
                Task { await revalidate() }
            }
        }
    }

    // MARK: - Actions

    /// Activate a key the user pasted. On success the key becomes this Mac's
    /// entitlement; on failure `lastError` explains why.
    func activate(_ rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        working = true
        defer { working = false }
        lastError = nil

        do {
            let instanceName = Host.current().localizedName ?? "Mac"
            let response = try await call(
                "activate",
                form: ["license_key": key, "instance_name": instanceName]
            )
            guard response.activated == true, response.errorMessage == nil else {
                lastError = response.errorMessage ?? "Activation failed. Check the key and try again."
                return
            }
            guard belongsToUs(response) else {
                lastError = "This key is for a different product."
                return
            }
            Keychain.set(key, account: Self.keyAccount)
            Keychain.set(response.instance?.id, account: Self.instanceAccount)
            markValidated()
            maskedKey = Self.mask(key)
            isPro = true
        } catch {
            lastError = "Couldn't reach the license server: \(error.localizedDescription)"
        }
    }

    /// Quiet periodic check. Network failures keep the grace window running;
    /// only an explicit "invalid" verdict revokes Pro.
    func revalidate() async {
        guard let key = Keychain.get(Self.keyAccount), !key.isEmpty else { return }
        var form = ["license_key": key]
        if let instance = Keychain.get(Self.instanceAccount) { form["instance_id"] = instance }

        do {
            let response = try await call("validate", form: form)
            if response.valid == true, belongsToUs(response) {
                markValidated()
                isPro = true
            } else {
                // The server affirmatively rejected the key (expired, disabled,
                // refunded, deactivated) — no grace for that.
                isPro = false
            }
        } catch {
            // Offline / transient — leave the grace window in charge.
            isPro = Date().timeIntervalSince(lastValidatedAt) < Self.graceWindow
        }
    }

    /// Release this Mac's activation slot and drop Pro locally.
    func deactivate() async {
        guard let key = Keychain.get(Self.keyAccount), !key.isEmpty else { return }
        working = true
        defer { working = false }
        lastError = nil

        if let instance = Keychain.get(Self.instanceAccount) {
            // Best effort: free the slot server-side, but always clear locally.
            _ = try? await call("deactivate", form: ["license_key": key, "instance_id": instance])
        }
        Keychain.set(nil, account: Self.keyAccount)
        Keychain.set(nil, account: Self.instanceAccount)
        UserDefaults.standard.removeObject(forKey: Self.validatedAtKey)
        maskedKey = nil
        isPro = false
    }

    // MARK: - Lemon Squeezy License API

    private struct Response: Decodable {
        struct LicenseKey: Decodable { let status: String? }
        struct Instance: Decodable { let id: String? }
        struct Meta: Decodable {
            let storeId: Int?
            let productId: Int?
            enum CodingKeys: String, CodingKey {
                case storeId = "store_id"
                case productId = "product_id"
            }
        }

        let activated: Bool?
        let valid: Bool?
        let errorMessage: String?
        let licenseKey: LicenseKey?
        let instance: Instance?
        let meta: Meta?

        enum CodingKeys: String, CodingKey {
            case activated, valid, instance, meta
            case errorMessage = "error"
            case licenseKey = "license_key"
        }
    }

    private func call(_ endpoint: String, form: [String: String]) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://api.lemonsqueezy.com/v1/licenses/\(endpoint)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        // LS returns the same JSON shape on 4xx (with `error` set), so decode
        // regardless of status code.
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Reject keys from other stores/products (the API is shared LS-wide).
    /// Product IDs are globally unique, so that check alone is sufficient;
    /// each ID is enforced only when configured.
    private func belongsToUs(_ response: Response) -> Bool {
        if Self.productID != 0, response.meta?.productId != Self.productID { return false }
        if Self.storeID != 0, response.meta?.storeId != Self.storeID { return false }
        return true
    }

    // MARK: - Helpers

    private var lastValidatedAt: Date {
        Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Self.validatedAtKey))
    }

    private func markValidated() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.validatedAtKey)
    }

    private static func mask(_ key: String) -> String {
        let tail = key.suffix(4)
        return "••••-\(tail)"
    }
}
