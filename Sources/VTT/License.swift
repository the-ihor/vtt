import AppKit
import Foundation

/// Pro entitlement for the direct-download (Developer ID) build, where StoreKit
/// does not handle payment. The user subscribes through Stripe Checkout on the
/// website, copies the Checkout Session ID from the success page, and the app
/// exchanges it for a signed entitlement token from the Cloudflare endpoint.
///
/// Privacy contract: no VTT account and no sign-in. The app stores only the
/// signed entitlement token in the Keychain plus the date of the last successful
/// validation. Revalidation is quiet and has a generous offline grace window so
/// a flaky network never locks a paying user out.
///
/// Compiled into every build, but only the `DIRECT_DISTRIBUTION` builds surface
/// it (see `AppState.isPro` and the Settings Pro tab). The Mac App Store build
/// sells exclusively through StoreKit.
@MainActor
final class LicenseStore: ObservableObject {
    // MARK: - Store configuration (Stripe via Cloudflare)

    /// Serverless entitlement broker. This Cloudflare Pages Function holds the
    /// Stripe secret key and returns only short JSON responses to the app.
    private static let apiBaseURL = URL(string: "https://vtt.the-ihor.com/api/stripe")!

    /// Revalidate quietly when the last check is older than this.
    private static let revalidateAfter: TimeInterval = 3 * 24 * 3600
    /// Keep Pro active without a successful check for up to this long
    /// (offline grace). An explicit "inactive" verdict ends Pro immediately.
    private static let graceWindow: TimeInterval = 14 * 24 * 3600

    private static let tokenAccount = "stripe.entitlementToken"
    private static let instanceIDAccount = "stripe.instanceID"
    private static let validatedAtKey = "stripeEntitlementValidatedAt"
    private static let subscriptionIDKey = "stripeSubscriptionID"

    // MARK: - Published state

    @Published private(set) var isPro = false
    @Published private(set) var working = false
    @Published var lastError: String?
    /// Masked token for display, e.g. "tok_…A1B2".
    @Published private(set) var maskedKey: String?

    init() {
        if let token = Keychain.get(Self.tokenAccount), !token.isEmpty {
            maskedKey = Self.mask(token)
            // Within grace: assume Pro now, then revalidate in the background.
            isPro = Date().timeIntervalSince(lastValidatedAt) < Self.graceWindow
            if Date().timeIntervalSince(lastValidatedAt) > Self.revalidateAfter {
                Task { await revalidate() }
            }
        }
    }

    // MARK: - Actions

    /// Start Stripe Checkout in the browser. After successful payment, the
    /// website shows a Checkout Session ID that the user pastes into `activate`.
    func startCheckout() async {
        working = true
        defer { working = false }
        lastError = nil

        do {
            let response: CheckoutResponse = try await post(
                "checkout",
                body: CheckoutRequest(instanceName: Self.instanceName, instanceID: Self.instanceID)
            )
            NSWorkspace.shared.open(response.url)
        } catch {
            lastError = Self.message(for: error, fallback: "Couldn't start Stripe Checkout.")
        }
    }

    /// Exchange the pasted Stripe success-page code for this Mac's entitlement.
    func activate(_ rawCode: String) async {
        guard let code = Self.activationCode(from: rawCode) else {
            lastError = "That doesn't look like an activation code. Paste the code (it starts with \"cs_\") or the full success-page URL."
            return
        }
        working = true
        defer { working = false }
        lastError = nil

        do {
            let response: ActivationResponse = try await post(
                "activate",
                body: ActivationRequest(
                    checkoutSessionID: code,
                    instanceName: Self.instanceName,
                    instanceID: Self.instanceID
                )
            )
            guard response.active, !response.entitlementToken.isEmpty else {
                lastError = "Activation failed. Check the code and try again."
                return
            }
            Keychain.set(response.entitlementToken, account: Self.tokenAccount)
            UserDefaults.standard.set(response.subscriptionID, forKey: Self.subscriptionIDKey)
            markValidated()
            maskedKey = Self.mask(response.entitlementToken)
            isPro = true
        } catch {
            lastError = Self.message(for: error, fallback: "Couldn't activate the subscription.")
        }
    }

    /// Re-bind an existing Stripe subscription to this Mac using the customer ID
    /// as a support-issued license key. This is the recovery path when the
    /// Keychain was wiped or the user moved to a new Mac, so the old token and
    /// the original checkout code no longer work. The server mints a fresh token
    /// only if that customer has an active VTT subscription.
    func recover(_ rawCustomerID: String) async {
        let customerID = rawCustomerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard customerID.hasPrefix("cus_") else {
            lastError = "Enter your Stripe customer ID — it starts with \"cus_\"."
            return
        }
        working = true
        defer { working = false }
        lastError = nil

        do {
            let response: ActivationResponse = try await post(
                "recover",
                body: RecoverRequest(customerID: customerID, instanceID: Self.instanceID)
            )
            guard response.active, !response.entitlementToken.isEmpty else {
                lastError = "No active VTT subscription was found for that customer ID."
                return
            }
            Keychain.set(response.entitlementToken, account: Self.tokenAccount)
            UserDefaults.standard.set(response.subscriptionID, forKey: Self.subscriptionIDKey)
            markValidated()
            maskedKey = Self.mask(response.entitlementToken)
            isPro = true
        } catch {
            lastError = Self.message(for: error, fallback: "Couldn't recover the subscription.")
        }
    }

    /// Quiet periodic check. Network failures keep the grace window running;
    /// only an explicit inactive verdict revokes Pro.
    func revalidate() async {
        guard let token = Keychain.get(Self.tokenAccount), !token.isEmpty else { return }

        do {
            let response: ValidationResponse = try await post(
                "validate",
                body: TokenRequest(entitlementToken: token, instanceID: Self.instanceID)
            )
            if response.active {
                markValidated()
                if let subscriptionID = response.subscriptionID {
                    UserDefaults.standard.set(subscriptionID, forKey: Self.subscriptionIDKey)
                }
                maskedKey = Self.mask(token)
                isPro = true
            } else {
                isPro = false
            }
        } catch {
            // Offline / transient — leave the grace window in charge.
            isPro = Date().timeIntervalSince(lastValidatedAt) < Self.graceWindow
        }
    }

    /// Open Stripe's hosted Customer Portal for cancellation and billing.
    func openBillingPortal() async {
        guard let token = Keychain.get(Self.tokenAccount), !token.isEmpty else {
            lastError = "Activate your subscription on this Mac first."
            return
        }
        working = true
        defer { working = false }
        lastError = nil

        do {
            let response: PortalResponse = try await post(
                "portal",
                body: TokenRequest(entitlementToken: token, instanceID: Self.instanceID)
            )
            NSWorkspace.shared.open(response.url)
        } catch {
            lastError = Self.message(for: error, fallback: "Couldn't open Stripe billing.")
        }
    }

    /// Drop the local entitlement token. The Stripe subscription is unchanged.
    func deactivate() async {
        Keychain.set(nil, account: Self.tokenAccount)
        UserDefaults.standard.removeObject(forKey: Self.validatedAtKey)
        UserDefaults.standard.removeObject(forKey: Self.subscriptionIDKey)
        maskedKey = nil
        isPro = false
    }

    // MARK: - Cloudflare API

    private struct CheckoutRequest: Encodable {
        let instanceName: String
        let instanceID: String
        enum CodingKeys: String, CodingKey {
            case instanceName = "instance_name"
            case instanceID = "instance_id"
        }
    }

    private struct CheckoutResponse: Decodable {
        let url: URL
    }

    private struct ActivationRequest: Encodable {
        let checkoutSessionID: String
        let instanceName: String
        let instanceID: String
        enum CodingKeys: String, CodingKey {
            case checkoutSessionID = "checkout_session_id"
            case instanceName = "instance_name"
            case instanceID = "instance_id"
        }
    }

    private struct RecoverRequest: Encodable {
        let customerID: String
        let instanceID: String
        enum CodingKeys: String, CodingKey {
            case customerID = "customer_id"
            case instanceID = "instance_id"
        }
    }

    private struct ActivationResponse: Decodable {
        let active: Bool
        let entitlementToken: String
        let subscriptionID: String?
        enum CodingKeys: String, CodingKey {
            case active
            case entitlementToken = "entitlement_token"
            case subscriptionID = "subscription_id"
        }
    }

    private struct TokenRequest: Encodable {
        let entitlementToken: String
        let instanceID: String
        enum CodingKeys: String, CodingKey {
            case entitlementToken = "entitlement_token"
            case instanceID = "instance_id"
        }
    }

    private struct ValidationResponse: Decodable {
        let active: Bool
        let subscriptionID: String?
        enum CodingKeys: String, CodingKey {
            case active
            case subscriptionID = "subscription_id"
        }
    }

    private struct PortalResponse: Decodable {
        let url: URL
    }

    private struct APIError: Decodable {
        let error: String?
    }

    private enum LicenseError: LocalizedError {
        case server(String)

        var errorDescription: String? {
            switch self {
            case .server(let message): message
            }
        }
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        _ endpoint: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = URLRequest(url: Self.apiBaseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let decoded = try? JSONDecoder().decode(APIError.self, from: data),
               let message = decoded.error, !message.isEmpty {
                throw LicenseError.server(message)
            }
            throw LicenseError.server("The subscription server returned \(http.statusCode).")
        }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }

    // MARK: - Helpers

    private var lastValidatedAt: Date {
        Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Self.validatedAtKey))
    }

    private func markValidated() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.validatedAtKey)
    }

    private static var instanceName: String {
        Host.current().localizedName ?? "Mac"
    }

    private static var instanceID: String {
        if let existing = Keychain.get(Self.instanceIDAccount), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        Keychain.set(created, account: Self.instanceIDAccount)
        return created
    }

    private static func activationCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let components = URLComponents(string: trimmed),
           let session = components.queryItems?.first(where: { $0.name == "session_id" })?.value,
           session.hasPrefix("cs_") {
            return session
        }
        return trimmed.hasPrefix("cs_") ? trimmed : nil
    }

    private static func mask(_ token: String) -> String {
        let tail = token.suffix(4)
        return "tok_…\(tail)"
    }

    private static func message(for error: Error, fallback: String) -> String {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return message.isEmpty ? fallback : message
    }
}
