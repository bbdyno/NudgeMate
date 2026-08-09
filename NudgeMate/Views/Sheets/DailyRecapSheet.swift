import SwiftData
import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct DailyRecapSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \EventPrep.targetDate)
    private var eventPreps: [EventPrep]

    @State private var errorMessage: String?

    private var pendingPreps: [EventPrep] {
        eventPreps.filter { $0.status != .ready && $0.targetDate > .now }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pendingPreps.isEmpty {
                    EmptyStateView(
                        icon: .emptyState,
                        title: L10n.Recap.Empty.title,
                        message: L10n.Recap.Empty.message
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Text(L10n.Recap.introduction)
                                .pretendard(.body)
                                .foregroundStyle(ColorTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 4)

                            ForEach(pendingPreps) { prep in
                                recapRow(for: prep)
                            }
                        }
                        .padding(20)
                    }
                    .background(ColorTheme.background)
                }
            }
            .navigationTitle(L10n.Recap.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) {
                        appState.dismissDailyRecap()
                        dismiss()
                    }
                    .pretendard(.headline, weight: .semibold)
                }
            }
        }
        .alert(L10n.Recap.Error.title, isPresented: errorBinding) {
            Button(L10n.Common.confirm, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
                .pretendard(.body)
        }
    }

    private func recapRow(for prep: EventPrep) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SVGAssetImage(asset: .calendarIcon)
                    .frame(width: 46, height: 46)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(prep.title)
                        .pretendard(.headline, weight: .semibold)
                        .foregroundStyle(ColorTheme.primaryText)
                    Text(prep.targetDate.formatted(date: .abbreviated, time: .omitted))
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }

            HStack(spacing: 10) {
                Button(L10n.Recap.Action.ready) {
                    update(prep, status: .ready)
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTheme.primaryNudge)

                Button(L10n.Recap.Action.notReady) {
                    update(prep, status: .notReady)
                }
                .buttonStyle(.bordered)
                .tint(ColorTheme.secondarySnooze)
            }
            .pretendard(.subheadline, weight: .semibold)
        }
        .padding(16)
        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: prep.status)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func update(_ prep: EventPrep, status: PrepStatus) {
        Task {
            do {
                try await appState.nudgeManager.updatePrep(
                    prep,
                    status: status,
                    modelContext: modelContext
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
