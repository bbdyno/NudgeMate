import Foundation
import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

enum InterstitialAdEligibilityDecision: Equatable {
    case eligible
    case proUser
    case consentRequired
    case coolingDown(until: Date)
}

struct InterstitialAdEligibilityPolicy {
    static let cooldown: TimeInterval = 24 * 60 * 60

    func evaluate(
        isPro: Bool,
        canRequestAds: Bool,
        lastPresentedAt: Date?,
        now: Date = .now
    ) -> InterstitialAdEligibilityDecision {
        if isPro {
            return .proUser
        }
        if !canRequestAds {
            return .consentRequired
        }
        if let lastPresentedAt {
            let eligibleAt = lastPresentedAt.addingTimeInterval(Self.cooldown)
            if eligibleAt > now {
                return .coolingDown(until: eligibleAt)
            }
        }
        return .eligible
    }
}

enum AdMobConfiguration {
    static let applicationID = "ca-app-pub-8965771939775493~6712972291"
    static let productionInterstitialAdUnitID = "ca-app-pub-8965771939775493/7478475235"
    static let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"

    static var interstitialAdUnitID: String {
#if DEBUG
        testInterstitialAdUnitID
#else
        productionInterstitialAdUnitID
#endif
    }
}

@MainActor
@Observable
final class AdMobManager: NSObject, FullScreenContentDelegate {
    private(set) var privacyOptionsRequired = false
    private(set) var canRequestAds = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private let eligibilityPolicy: InterstitialAdEligibilityPolicy

    @ObservationIgnored
    private var interstitialAd: InterstitialAd?

    @ObservationIgnored
    private var presentedInterstitialAd: InterstitialAd?

    @ObservationIgnored
    private var interstitialLoadedAt: Date?

    @ObservationIgnored
    private var isLoadingInterstitial = false

    @ObservationIgnored
    private var didPrepareConsentThisLaunch = false

    @ObservationIgnored
    private var didStartMobileAds = false

    @ObservationIgnored
    private var isPro = false

    @ObservationIgnored
    private let lastPresentedAtKey = "NudgeMate.admob.lastRecapInterstitialDate"

    @ObservationIgnored
    private let maximumLoadedAdAge: TimeInterval = 55 * 60

    init(
        defaults: UserDefaults = .standard,
        eligibilityPolicy: InterstitialAdEligibilityPolicy = .init()
    ) {
        self.defaults = defaults
        self.eligibilityPolicy = eligibilityPolicy
        super.init()
    }

    func prepare(isPro: Bool) async {
        self.isPro = isPro
        guard !isPro else {
            discardLoadedAds()
            return
        }
        guard !isDisabledForTesting else { return }

        if !didPrepareConsentThisLaunch {
            didPrepareConsentThisLaunch = true
            await gatherConsent()
        }

        guard !self.isPro,
              canRequestAds,
              eligibilityDecision(now: .now) == .eligible else {
            return
        }
        startMobileAdsIfNeeded()
        await loadInterstitialIfEligible()
    }

    func updateEntitlement(isPro: Bool) async {
        self.isPro = isPro
        if isPro {
            discardLoadedAds()
            return
        }
        await prepare(isPro: false)
    }

    @discardableResult
    func presentRecapInterstitialIfEligible(now: Date = .now) async -> Bool {
        guard eligibilityDecision(now: now) == .eligible else { return false }

        startMobileAdsIfNeeded()

        guard let interstitialAd,
              let loadedAt = interstitialLoadedAt,
              now.timeIntervalSince(loadedAt) <= maximumLoadedAdAge else {
            discardLoadedAds()
            await loadInterstitialIfEligible(now: now)
            return false
        }

        do {
            try interstitialAd.canPresent(from: nil)
            presentedInterstitialAd = interstitialAd
            self.interstitialAd = nil
            interstitialLoadedAt = nil
            interstitialAd.present(from: nil)
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            discardLoadedAds()
            await loadInterstitialIfEligible(now: now)
            return false
        }
    }

    func presentPrivacyOptions() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        refreshConsentState()
        if !isPro,
           canRequestAds,
           eligibilityDecision(now: .now) == .eligible {
            startMobileAdsIfNeeded()
            await loadInterstitialIfEligible()
        }
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        defaults.set(Date.now, forKey: lastPresentedAtKey)
        lastErrorMessage = nil
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        presentedInterstitialAd = nil
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        presentedInterstitialAd = nil
        lastErrorMessage = error.localizedDescription
    }

    private func gatherConsent() async {
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(
                with: RequestParameters()
            )
            refreshConsentState()
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
            refreshConsentState()
            lastErrorMessage = nil
        } catch {
            refreshConsentState()
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshConsentState() {
        let consentInformation = ConsentInformation.shared
        canRequestAds = consentInformation.canRequestAds
        privacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus == .required
    }

    private func startMobileAdsIfNeeded() {
        guard !didStartMobileAds, !isPro, canRequestAds else { return }
        didStartMobileAds = true
        MobileAds.shared.start()
    }

    private func loadInterstitialIfEligible(now: Date = .now) async {
        guard didStartMobileAds,
              !isLoadingInterstitial,
              interstitialAd == nil,
              presentedInterstitialAd == nil,
              eligibilityDecision(now: now) == .eligible else {
            return
        }

        isLoadingInterstitial = true
        defer { isLoadingInterstitial = false }

        do {
            let ad = try await InterstitialAd.load(
                with: AdMobConfiguration.interstitialAdUnitID,
                request: Request()
            )
            guard !isPro, canRequestAds else { return }
            ad.fullScreenContentDelegate = self
            interstitialAd = ad
            interstitialLoadedAt = .now
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func eligibilityDecision(now: Date) -> InterstitialAdEligibilityDecision {
        eligibilityPolicy.evaluate(
            isPro: isPro,
            canRequestAds: canRequestAds,
            lastPresentedAt: defaults.object(forKey: lastPresentedAtKey) as? Date,
            now: now
        )
    }

    private func discardLoadedAds() {
        interstitialAd = nil
        presentedInterstitialAd = nil
        interstitialLoadedAt = nil
    }

    private var isDisabledForTesting: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment["XCTestConfigurationFilePath"] != nil
            || processInfo.arguments.contains("--ui-testing")
    }
}
