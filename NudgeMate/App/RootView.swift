import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
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
        }
    }
}
