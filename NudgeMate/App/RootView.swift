import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

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
            appState.startCalendarChangeObservation(modelContext: modelContext)
            if appState.onboardingCompleted {
                await appState.prepareMonetization()
            }
            await appState.synchronizeAdaptiveRhythms(modelContext: modelContext)
            try? await appState.nudgeManager.synchronizeWidgetsAndActivities(modelContext: modelContext)
        }
        .onChange(of: appState.subscriptionManager.isPro) { _, _ in
            guard appState.isBootstrapped, appState.onboardingCompleted else { return }
            Task { await appState.updateAdEntitlement() }
        }
        .onChange(of: appState.onboardingCompleted) { _, isCompleted in
            guard isCompleted else { return }
            Task { await appState.prepareMonetization() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await appState.synchronizeAdaptiveRhythms(modelContext: modelContext)
            }
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
