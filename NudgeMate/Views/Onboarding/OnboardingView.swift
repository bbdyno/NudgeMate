import SwiftData
import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var page = 0
    @State private var isCalendarFlowPresented = false
    @State private var errorMessage: String?

    private let pages: [(ImageAssetManager.Asset, String, String)] = [
        (.nudgeAlert, L10n.Onboarding.Welcome.title, L10n.Onboarding.Welcome.message),
        (.calendarIcon, L10n.Onboarding.Rhythm.title, L10n.Onboarding.Rhythm.message),
        (.sync, L10n.Onboarding.Permission.title, L10n.Onboarding.Permission.message)
    ]

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 28) {
                        Spacer()
                        SVGAssetImage(asset: value.0)
                            .frame(width: 152, height: 152)
                            .accessibilityHidden(true)
                        Text(value.1)
                            .pretendard(.largeTitle, weight: .bold)
                            .foregroundStyle(ColorTheme.primaryText)
                            .multilineTextAlignment(.center)
                        Text(value.2)
                            .pretendard(.body)
                            .foregroundStyle(ColorTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if page < pages.count - 1 {
                primaryButton(L10n.Common.next) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        page += 1
                    }
                }
            } else {
                VStack(spacing: 12) {
                    primaryButton(L10n.Onboarding.Permission.scan) {
                        isCalendarFlowPresented = true
                    }
                    Button(L10n.Onboarding.Permission.manual) {
                        complete(with: [])
                    }
                    .pretendard(.body, weight: .semibold)
                    .foregroundStyle(ColorTheme.primaryNudge)
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(ColorTheme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $isCalendarFlowPresented) {
            CalendarDiscoveryFlowView {
                isCalendarFlowPresented = false
            }
            .environment(appState)
        }
        .alert(L10n.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.Common.confirm, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .pretendard(.headline, weight: .semibold)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(ColorTheme.primaryNudge, in: Capsule())
    }

    private func complete(with identifiers: Set<String>) {
        do {
            try appState.finishOnboarding(
                selectedCalendarIdentifiers: identifiers,
                modelContext: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
