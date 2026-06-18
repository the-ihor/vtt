import Combine
import Foundation
import StoreKit

/// Region-based feature gating for App Store Review Guideline 5 (Legal).
///
/// On the China mainland App Store, generative-AI / ChatGPT-associated services
/// without an MIIT permit may not be offered (the Administrative Provisions on
/// Deep Synthesis of Internet-based Information Services). The same binary ships
/// to every storefront, so we can't strip OpenAI at build time — instead we read
/// the device's App Store storefront at runtime and, when it is China (`CHN`),
/// hide and disable the OpenAI transcription provider.
///
/// `Storefront.current` reflects the signed-in Apple ID's storefront, which is
/// what App Review uses when testing the China submission.
@MainActor
final class RegionGate: ObservableObject {
    /// Providers that must not be offered in the current storefront.
    @Published private(set) var restricted: Set<SpeechSource> = []

    /// ISO 3166-1 alpha-3 storefront codes where OpenAI must be suppressed.
    private static let openAIRestrictedStorefronts: Set<String> = ["CHN"]

    init() {
        Task { await refresh() }
        // Storefront can change while the app runs (user switches Apple ID region).
        Task { [weak self] in
            for await _ in Storefront.updates {
                await self?.refresh()
            }
        }
    }

    private func refresh() async {
        let code = await Storefront.current?.countryCode
        restricted = code.map(Self.openAIRestrictedStorefronts.contains) == true ? [.openAI] : []
    }
}
