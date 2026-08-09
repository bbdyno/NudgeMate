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
                VStack(spacing: 22) {
                    SVGAssetImage(asset: .paywallHero)
                        .frame(width: 180, height: 144)
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
                                pricingCard(product)
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
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(ColorTheme.primaryNudge, in: Capsule())
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
                        HStack(spacing: 16) {
                            Button(L10n.Paywall.terms) {
                                if let url = AppConfiguration.termsOfServiceURL { openURL(url) }
                            }
                            if let url = AppConfiguration.privacyPolicyURL {
                                Button(L10n.Paywall.privacy) {
                                    openURL(url)
                                }
                            }
                        }
                    }
                    .pretendard(.footnote)
                    .foregroundStyle(ColorTheme.secondaryText)
                }
                .padding(20)
            }
            .background(ColorTheme.background)
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
            SVGAssetImage(asset: .featureCheck)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            Text(title)
                .pretendard(.body, weight: .medium)
        }
    }

    private func pricingCard(_ product: Product) -> some View {
        let id = SubscriptionProductID(rawValue: product.id)
        let isSelected = id == selectedProductID
        return Button {
            guard let id else { return }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                selectedProductID = id
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(productTitle(for: id))
                            .pretendard(.headline, weight: .semibold)
                        if id == .yearly {
                            Text(L10n.Paywall.bestValue)
                                .pretendard(.caption2, weight: .bold)
                                .foregroundStyle(ColorTheme.proAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ColorTheme.proAccent.opacity(0.14), in: Capsule())
                        }
                    }
                    if let trial = introductoryOfferText(product) {
                        Text(trial)
                            .pretendard(.caption)
                            .foregroundStyle(ColorTheme.secondarySnooze)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .pretendard(.headline, weight: .bold)
                    .foregroundStyle(isSelected ? ColorTheme.primaryNudge : ColorTheme.primaryText)
            }
            .padding(16)
            .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? ColorTheme.primaryNudge : ColorTheme.separator.opacity(0.5), lineWidth: isSelected ? 2 : 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
