import Foundation

enum AppConfiguration {
    static let freeAdaptiveRhythmLimit = 3
    static let freeActivePrepLimit = 1

    static let termsOfServiceURL = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )
    static var privacyPolicyURL: URL? {
        configuredURL(forInfoDictionaryKey: "NudgeMatePrivacyPolicyURL")
    }
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")

    private static func configuredURL(forInfoDictionaryKey key: String) -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !rawValue.isEmpty else {
            return nil
        }
        return URL(string: rawValue)
    }
}

enum FeatureAccessDecision: Equatable {
    case allowed
    case requiresPro
}

struct EntitlementPolicy {
    func adaptiveRhythmCreation(
        activeAdaptiveCount: Int,
        isPro: Bool
    ) -> FeatureAccessDecision {
        isPro || activeAdaptiveCount < AppConfiguration.freeAdaptiveRhythmLimit
            ? .allowed
            : .requiresPro
    }

    func prepCreation(
        activePrepCount: Int,
        isPro: Bool
    ) -> FeatureAccessDecision {
        isPro || activePrepCount < AppConfiguration.freeActivePrepLimit
            ? .allowed
            : .requiresPro
    }
}
