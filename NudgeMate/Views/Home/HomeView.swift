import SwiftData
import SwiftUI
import UIKit

private typealias L10n = NudgeMateStrings.Localizable

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \RecurringEvent.nextPredictedDate)
    private var recurringEvents: [RecurringEvent]

    @Query(sort: \EventPrep.targetDate)
    private var eventPreps: [EventPrep]

    @State private var viewModel = HomeViewModel()
    @State private var nudgeViewModel = NudgeViewModel()

    private var activeNudges: [RecurringEvent] {
        recurringEvents.filter { !$0.isMuted }
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView(L10n.Home.loading)
                        .pretendard(.body)
                        .tint(ColorTheme.primaryNudge)
                } else if viewModel.calendarAccessDenied {
                    calendarPermissionView
                } else if let errorMessage = viewModel.errorMessage {
                    EmptyStateView(
                        icon: .nudgeAlert,
                        title: L10n.Home.Error.loadTitle,
                        message: errorMessage,
                        actionTitle: L10n.Common.retry
                    ) {
                        Task { await retry() }
                    }
                } else {
                    dashboard
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.App.name)
                        .pretendard(.headline, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryText)
                }
            }
        }
        .sheet(isPresented: $appState.isDailyRecapPresented) {
            DailyRecapSheet()
                .environment(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.load(
                modelContext: modelContext,
                eventKitManager: appState.eventKitManager,
                nudgeManager: appState.nudgeManager
            )
        }
        .task {
            await appState.runDailyRecapClock()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.evaluateDailyRecapPresentation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduleNowRequested)) { notification in
            guard
                let id = notification.object as? UUID,
                let event = recurringEvents.first(where: { $0.id == id })
            else { return }

            Task {
                await scheduleNow(event)
            }
        }
        .alert(L10n.App.name, isPresented: messageBinding) {
            Button(L10n.Common.confirm) {
                viewModel.clearMessages()
                nudgeViewModel.clearError()
            }
        } message: {
            Text(viewModel.confirmationMessage ?? nudgeViewModel.errorMessage ?? "")
                .pretendard(.body)
        }
    }

    private var calendarPermissionView: some View {
        EmptyStateView(
            icon: .emptyState,
            title: L10n.Home.Permission.title,
            message: L10n.Home.Permission.message,
            actionTitle: L10n.Home.Permission.openSettings
        ) {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    }

    private var dashboard: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                prepSection
                nudgeSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await retry()
        }
    }

    private var prepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: L10n.Home.Prep.title,
                subtitle: L10n.Home.Prep.subtitle
            )

            if eventPreps.isEmpty {
                compactEmptyMessage(L10n.Home.Prep.empty)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(eventPreps) { prep in
                            PrepTrackerCard(prep: prep)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private var nudgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: L10n.Home.Nudge.title,
                subtitle: L10n.Home.Nudge.subtitle
            )

            if activeNudges.isEmpty {
                EmptyStateView(
                    icon: .emptyState,
                    title: L10n.Home.Nudge.emptyTitle,
                    message: L10n.Home.Nudge.emptyMessage
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(activeNudges) { event in
                        NudgeCardView(
                            event: event,
                            onSchedule: {
                                Task { await scheduleNow(event) }
                            },
                            onSnooze: {
                                Task {
                                    await nudgeViewModel.snooze(
                                        event,
                                        modelContext: modelContext,
                                        nudgeManager: appState.nudgeManager
                                    )
                                }
                            },
                            onSkip: {
                                Task {
                                    await nudgeViewModel.skip(
                                        event,
                                        modelContext: modelContext,
                                        nudgeManager: appState.nudgeManager
                                    )
                                }
                            },
                            onToggleMute: {
                                Task {
                                    await nudgeViewModel.toggleMuted(
                                        event,
                                        modelContext: modelContext,
                                        nudgeManager: appState.nudgeManager
                                    )
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.84), value: activeNudges.count)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .pretendard(.title2, weight: .bold)
                .foregroundStyle(ColorTheme.primaryText)
            Text(subtitle)
                .pretendard(.subheadline)
                .foregroundStyle(ColorTheme.secondaryText)
        }
    }

    private func compactEmptyMessage(_ message: String) -> some View {
        HStack(spacing: 12) {
            SVGAssetImage(asset: .calendarIcon)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            Text(message)
                .pretendard(.subheadline)
                .foregroundStyle(ColorTheme.secondaryText)
            Spacer()
        }
        .padding(16)
        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.confirmationMessage != nil || nudgeViewModel.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearMessages()
                    nudgeViewModel.clearError()
                }
            }
        )
    }

    private func retry() async {
        await viewModel.retry(
            modelContext: modelContext,
            eventKitManager: appState.eventKitManager,
            nudgeManager: appState.nudgeManager
        )
    }

    private func scheduleNow(_ event: RecurringEvent) async {
        await viewModel.scheduleNow(
            event: event,
            modelContext: modelContext,
            eventKitManager: appState.eventKitManager,
            nudgeManager: appState.nudgeManager
        )
    }
}

private struct PrepTrackerCard: View {
    let prep: EventPrep

    private var daysRemaining: Int {
        max(
            0,
            Calendar.autoupdatingCurrent.dateComponents(
                [.day],
                from: Calendar.autoupdatingCurrent.startOfDay(for: .now),
                to: Calendar.autoupdatingCurrent.startOfDay(for: prep.targetDate)
            ).day ?? 0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SVGAssetImage(asset: .calendarIcon)
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)

                Text(L10n.Prep.Card.dayCount(daysRemaining))
                    .pretendard(.headline, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryNudge)
            }

            Spacer(minLength: 0)

            Text(prep.title)
                .pretendard(.headline, weight: .semibold)
                .foregroundStyle(ColorTheme.primaryText)
                .lineLimit(2)

            Text(prep.status.localizedTitle)
                .pretendard(.caption, weight: .medium)
                .foregroundStyle(ColorTheme.secondarySnooze)
        }
        .padding(16)
        .frame(width: 190, height: 150, alignment: .leading)
        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTheme.separator.opacity(0.35), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.Prep.Card.accessibility(
                prep.title,
                daysRemaining,
                prep.status.localizedTitle
            )
        )
    }
}
