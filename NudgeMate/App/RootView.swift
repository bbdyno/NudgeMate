import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var appState = appState

        Group {
            if !appState.isBootstrapped {
                ProgressView()
                    .tint(ColorTheme.primaryNudge)
                    .accessibilityLabel(NudgeMateStrings.Localizable.Common.loading)
            } else if !appState.onboardingCompleted {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task {
            appState.bootstrap(modelContext: modelContext)
            try? await appState.nudgeManager.synchronizeWidgetsAndActivities(modelContext: modelContext)
        }
        .sheet(isPresented: $appState.isPaywallPresented) {
            PaywallView()
                .environment(appState)
                .presentationDetents([.large])
                .interactiveDismissDisabled(appState.subscriptionManager.isPurchasing)
        }
        .onOpenURL { url in
            appState.handleDeepLink(url)
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appState.appearanceTheme {
        case .system: nil
        case .light: .light
        case .dark, .pro: .dark
        }
    }
}
