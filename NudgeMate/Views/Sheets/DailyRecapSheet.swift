import SwiftData
import SwiftUI

private typealias L10n = NudgeMateStrings.Localizable

struct DailyRecapSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \EventPrep.targetDate)
    private var eventPreps: [EventPrep]

    @Query(sort: \RecurringEvent.nextExpectedCenterDate)
    private var rhythms: [RecurringEvent]

    @State private var errorMessage: String?

    private var pendingPreps: [EventPrep] {
        eventPreps.filter { $0.status != .ready && $0.targetDate > .now }
    }

    private var dueRhythms: [RecurringEvent] {
        let endOfToday = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: 1,
            to: Calendar.autoupdatingCurrent.startOfDay(for: .now)
        ) ?? .now
        return rhythms.filter {
            !$0.isMuted && $0.nextExpectedStartDate < endOfToday
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pendingPreps.isEmpty && dueRhythms.isEmpty {
                    EmptyStateView(
                        icon: .empty,
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

                            ForEach(dueRhythms) { rhythm in
                                rhythmRecapRow(for: rhythm)
                            }
                        }
                        .padding(20)
                    }
                    .background(NudgeScreenBackground())
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
                NudgeSymbolBadge(symbol: .calendar, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(prep.title)
                        .pretendard(.headline, weight: .semibold)
                        .foregroundStyle(ColorTheme.primaryText)
                    Text(prep.targetDate.formatted(date: .abbreviated, time: .omitted))
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }

            RecapActionRow(
                primaryTitle: L10n.Recap.Action.ready,
                secondaryTitle: L10n.Recap.Action.notReady,
                onPrimary: { update(prep, status: .ready) },
                onSecondary: { update(prep, status: .notReady) }
            )
        }
        .nudgeCardSurface()
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: prep.status)
    }

    private func rhythmRecapRow(for rhythm: RecurringEvent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                NudgeSymbolBadge(symbol: .reminder, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rhythm.displayName)
                        .pretendard(.headline, weight: .semibold)
                    Text(L10n.Recap.Rhythm.message(rhythm.baseIntervalDays))
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }
            RecapActionRow(
                primaryTitle: L10n.Recap.Action.done,
                secondaryTitle: L10n.Recap.Action.snoozed,
                onPrimary: { complete(rhythm) },
                onSecondary: {
                    Task {
                        do {
                            try await appState.nudgeManager.snooze(
                                rhythm,
                                modelContext: modelContext
                            )
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            )
        }
        .nudgeCardSurface()
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

    private func complete(_ rhythm: RecurringEvent) {
        let previousHistoryDates = rhythm.historyDates
        let previousLastOccurrenceDate = rhythm.lastOccurrenceDate
        let previousNextPredictedDate = rhythm.nextPredictedDate
        let previousUpdatedAt = rhythm.updatedAt
        let now = Date.now
        rhythm.historyDates.append(now)
        rhythm.lastOccurrenceDate = now
        let center = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: rhythm.baseIntervalDays,
            to: now
        ) ?? now.addingTimeInterval(TimeInterval(rhythm.baseIntervalDays * 86_400))
        rhythm.nextPredictedDate = center
        rhythm.updatedAt = now
        Task {
            do {
                try modelContext.save()
            } catch {
                rhythm.historyDates = previousHistoryDates
                rhythm.lastOccurrenceDate = previousLastOccurrenceDate
                rhythm.nextPredictedDate = previousNextPredictedDate
                rhythm.updatedAt = previousUpdatedAt
                errorMessage = error.localizedDescription
                return
            }

            do {
                try await appState.nudgeManager.scheduleNudge(for: rhythm)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct RecapActionRow: View {
    let primaryTitle: String
    let secondaryTitle: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                primaryButton
                secondaryButton
            }

            VStack(spacing: 8) {
                primaryButton
                    .frame(maxWidth: .infinity)
                secondaryButton
                    .frame(maxWidth: .infinity)
            }
        }
        .pretendard(.subheadline, weight: .semibold)
    }

    private var primaryButton: some View {
        Button(primaryTitle, action: onPrimary)
            .buttonStyle(.borderedProminent)
            .tint(ColorTheme.primaryNudge)
    }

    private var secondaryButton: some View {
        Button(secondaryTitle, action: onSecondary)
            .buttonStyle(.bordered)
            .tint(ColorTheme.secondarySnooze)
    }
}
