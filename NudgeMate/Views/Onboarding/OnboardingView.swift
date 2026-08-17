import SwiftData
import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var isCalendarFlowPresented = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            NudgeScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.Onboarding.Welcome.title)
                        .pretendard(.largeTitle, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.Onboarding.Welcome.message)
                        .pretendard(.body)
                        .foregroundStyle(ColorTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    OnboardingProductPreview()
                        .padding(.top, 28)

                    OnboardingTrustNote()
                        .padding(.top, 18)

                    OnboardingActions(
                        onScan: { isCalendarFlowPresented = true },
                        onManual: { complete(with: []) }
                    )
                    .padding(.top, 26)
                    .padding(.bottom, 18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.screen")
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

private struct OnboardingProductPreview: View {
    private let dates = ["10", "11", "12", "13", "14"]

    private var days: [String] {
        L10n.Onboarding.Preview.days.components(separatedBy: ",")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.Onboarding.Preview.week)
                        .pretendard(.caption, weight: .semibold)
                        .foregroundStyle(Color.white.opacity(0.72))
                    Text(L10n.Onboarding.Preview.count)
                        .pretendard(.title3, weight: .bold)
                        .foregroundStyle(Color.white)
                }

                HStack(spacing: 0) {
                    ForEach(days.indices, id: \.self) { index in
                        VStack(spacing: 6) {
                            Text(days[index])
                                .pretendard(.caption2, weight: .medium)
                                .foregroundStyle(Color.white.opacity(0.68))
                            Text(dates[index])
                                .pretendard(.subheadline, weight: .bold)
                                .foregroundStyle(Color.white)
                                .frame(width: 34, height: 34)
                                .background(
                                    index == 2 ? Color.white.opacity(0.19) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(18)
            .background(ColorTheme.primaryNudge)

            VStack(spacing: 0) {
                OnboardingPredictionRow(
                    month: 8,
                    day: 19,
                    eyebrow: L10n.Onboarding.Preview.PersonalCare.interval,
                    title: L10n.Onboarding.Preview.PersonalCare.title,
                    timing: L10n.Onboarding.Preview.PersonalCare.timing,
                    color: ColorTheme.accentCoral
                )

                Rectangle()
                    .fill(ColorTheme.separator)
                    .frame(height: 1)
                    .padding(.leading, 78)

                OnboardingPredictionRow(
                    month: 9,
                    day: 3,
                    eyebrow: L10n.Onboarding.Preview.Vehicle.interval,
                    title: L10n.Onboarding.Preview.Vehicle.title,
                    timing: L10n.Onboarding.Preview.Vehicle.timing,
                    color: ColorTheme.primaryNudge
                )
            }
            .background(ColorTheme.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(ColorTheme.separator, lineWidth: 1)
        }
        .shadow(color: ColorTheme.primaryText.opacity(0.07), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Onboarding.Preview.accessibility)
    }
}

private struct OnboardingPredictionRow: View {
    let month: Int
    let day: Int
    let eyebrow: String
    let title: String
    let timing: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(previewDate, format: .dateTime.month(.abbreviated))
                    .pretendard(.caption2, weight: .bold)
                    .foregroundStyle(color)
                Text(previewDate, format: .dateTime.day())
                    .pretendard(.subheadline, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryText)
            }
            .frame(width: 58, height: 58)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .pretendard(.caption, weight: .bold)
                    .foregroundStyle(color)
                Text(title)
                    .pretendard(.headline, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryText)
                Text(timing)
                    .pretendard(.caption)
                    .foregroundStyle(ColorTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var previewDate: Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: month, day: day)
        ) ?? .now
    }
}

private struct OnboardingTrustNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ColorTheme.success)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            Text(L10n.Onboarding.Rhythm.message)
                .pretendard(.caption)
                .foregroundStyle(ColorTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingActions: View {
    let onScan: () -> Void
    let onManual: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onScan) {
                Text(L10n.Onboarding.Permission.scan)
                    .pretendard(.headline, weight: .bold)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(NudgePrimaryButtonStyle())
            .accessibilityIdentifier("onboarding.scan")

            Button(action: onManual) {
                Text(L10n.Onboarding.Permission.manual)
                    .pretendard(.subheadline, weight: .semibold)
                    .foregroundStyle(ColorTheme.primaryNudge)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding.manual")
        }
    }
}
