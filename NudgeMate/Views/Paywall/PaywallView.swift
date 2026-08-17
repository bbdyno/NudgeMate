import StoreKit
import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedProductID: SubscriptionProductID = .yearly
    @State private var message: String?

    private var manager: SubscriptionManager {
        appState.subscriptionManager
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ArtworkAssetImage(asset: .paywallHero)
                        .frame(width: 168, height: 134)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text(L10n.Paywall.title)
                            .pretendard(.title, weight: .bold)
                            .multilineTextAlignment(.center)
                        Text(L10n.Paywall.subtitle)
                            .pretendard(.body)
                            .foregroundStyle(ColorTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        feature(L10n.Paywall.Feature.rhythms)
                        feature(L10n.Paywall.Feature.preps)
                        feature(L10n.Paywall.Feature.notifications)
                        feature(L10n.Paywall.Feature.insights)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if manager.isLoadingProducts && manager.products.isEmpty {
                        ProgressView(L10n.Paywall.loading)
                            .tint(ColorTheme.primaryNudge)
                            .frame(minHeight: 160)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(manager.products, id: \.id) { product in
                                PaywallPricingCard(
                                    title: productTitle(
                                        for: SubscriptionProductID(rawValue: product.id)
                                    ),
                                    trial: introductoryOfferText(product),
                                    price: product.displayPrice,
                                    isBestValue: SubscriptionProductID(rawValue: product.id) == .yearly,
                                    isSelected: SubscriptionProductID(rawValue: product.id) == selectedProductID
                                ) {
                                    selectProduct(product)
                                }
                            }
                        }
                    }

                    Button {
                        purchaseSelectedProduct()
                    } label: {
                        Group {
                            if manager.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(L10n.Paywall.continue)
                            }
                        }
                        .pretendard(.headline, weight: .semibold)
                        .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(NudgePrimaryButtonStyle())
                    .disabled(manager.isPurchasing || selectedProduct == nil)
                    .opacity(selectedProduct == nil ? 0.5 : 1)

                    VStack(spacing: 12) {
                        Button(L10n.Paywall.restore) {
                            Task {
                                do {
                                    try await manager.restorePurchases()
                                    message = manager.isPro
                                        ? L10n.Paywall.Restore.success
                                        : L10n.Paywall.Restore.none
                                } catch {
                                    message = error.localizedDescription
                                }
                            }
                        }
                        Button(L10n.Paywall.manage) {
                            if let url = AppConfiguration.manageSubscriptionsURL { openURL(url) }
                        }
                        PaywallLegalLinks(
                            showPrivacy: AppConfiguration.privacyPolicyURL != nil,
                            onOpenTerms: {
                                if let url = AppConfiguration.termsOfServiceURL { openURL(url) }
                            },
                            onOpenPrivacy: {
                                if let url = AppConfiguration.privacyPolicyURL { openURL(url) }
                            }
                        )
                    }
                    .pretendard(.footnote)
                    .foregroundStyle(ColorTheme.secondaryText)
                }
                .padding(20)
            }
            .background(NudgeScreenBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                        .disabled(manager.isPurchasing)
                }
            }
        }
        .task {
            if manager.products.isEmpty {
                await manager.prepare()
            }
            chooseAvailableDefault()
        }
        .onChange(of: manager.isPro) { _, isPro in
            if isPro { dismiss() }
        }
        .alert(L10n.App.name, isPresented: Binding(
            get: { message != nil || manager.lastErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    message = nil
                    manager.clearError()
                }
            }
        )) {
            Button(L10n.Common.confirm, role: .cancel) {}
        } message: {
            Text(message ?? manager.lastErrorMessage ?? "")
        }
    }

    private var selectedProduct: Product? {
        manager.product(for: selectedProductID)
    }

    private func feature(_ title: String) -> some View {
        HStack(spacing: 12) {
            NudgeSymbolImage(symbol: .success, pointSize: 24)
                .frame(width: 28, height: 28)
            Text(title)
                .pretendard(.body, weight: .medium)
        }
    }

    private func selectProduct(_ product: Product) {
        let id = SubscriptionProductID(rawValue: product.id)
        guard let id else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            selectedProductID = id
        }
    }

    private func productTitle(for id: SubscriptionProductID?) -> String {
        switch id {
        case .monthly: L10n.Paywall.Plan.monthly
        case .yearly: L10n.Paywall.Plan.yearly
        case .lifetime: L10n.Paywall.Plan.lifetime
        case nil: L10n.Paywall.Plan.pro
        }
    }

    private func introductoryOfferText(_ product: Product) -> String? {
        guard let subscription = product.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            return nil
        }
        return L10n.Paywall.freeTrial(offer.period.value)
    }

    private func chooseAvailableDefault() {
        if manager.product(for: .yearly) != nil {
            selectedProductID = .yearly
        } else if let first = manager.products.first,
                  let id = SubscriptionProductID(rawValue: first.id) {
            selectedProductID = id
        }
    }

    private func purchaseSelectedProduct() {
        guard let product = selectedProduct else { return }
        Task {
            do {
                let outcome = try await manager.purchase(product)
                switch outcome {
                case .purchased:
                    dismiss()
                case .pending:
                    message = L10n.Paywall.pending
                case .cancelled:
                    break
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

private struct PaywallPricingCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let trial: String?
    let price: String
    let isBestValue: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        heading
                        trialLabel
                        priceLabel
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            heading
                            trialLabel
                        }
                        Spacer(minLength: 8)
                        priceLabel
                    }
                }
            }
            .padding(16)
            .background(
                ColorTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? ColorTheme.primaryNudge : ColorTheme.separator.opacity(0.5),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var heading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                titleLabel
                if isBestValue { bestValueBadge }
            }

            VStack(alignment: .leading, spacing: 6) {
                titleLabel
                if isBestValue { bestValueBadge }
            }
        }
    }

    private var titleLabel: some View {
        Text(title)
            .pretendard(.headline, weight: .semibold)
            .foregroundStyle(ColorTheme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var bestValueBadge: some View {
        Text(L10n.Paywall.bestValue)
            .pretendard(.caption2, weight: .bold)
            .foregroundStyle(ColorTheme.proAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(ColorTheme.proAccent.opacity(0.14), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var trialLabel: some View {
        if let trial {
            Text(trial)
                .pretendard(.caption)
                .foregroundStyle(ColorTheme.secondarySnooze)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var priceLabel: some View {
        Text(price)
            .pretendard(.headline, weight: .bold)
            .foregroundStyle(isSelected ? ColorTheme.primaryNudge : ColorTheme.primaryText)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct PaywallLegalLinks: View {
    let showPrivacy: Bool
    let onOpenTerms: () -> Void
    let onOpenPrivacy: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                termsButton
                if showPrivacy { privacyButton }
            }

            VStack(spacing: 10) {
                termsButton
                if showPrivacy { privacyButton }
            }
        }
    }

    private var termsButton: some View {
        Button(L10n.Paywall.terms, action: onOpenTerms)
    }

    private var privacyButton: some View {
        Button(L10n.Paywall.privacy, action: onOpenPrivacy)
    }
}
