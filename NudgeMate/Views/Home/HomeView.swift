import SwiftData
import SwiftUI
import UIKit

private typealias L10n = NudgeMateStrings.Localizable

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \RecurringEvent.nextExpectedCenterDate)
    private var recurringEvents: [RecurringEvent]

    @Query(sort: \EventPrep.targetDate)
    private var eventPreps: [EventPrep]

    @State private var viewModel = HomeViewModel()
    @State private var nudgeViewModel = NudgeViewModel()
    @State private var isSettingsPresented = false
    @State private var composerDraft: CalendarEventComposerDraft?
    @State private var editingPrep: EventPrep?

    private var activeNudges: [RecurringEvent] {
        recurringEvents.filter { !$0.isMuted }
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            ZStack {
                NudgeScreenBackground()

                VStack(spacing: 0) {
                    Group {
                        if viewModel.isLoading {
                            ProgressView(L10n.Home.loading)
                                .pretendard(.body)
                                .tint(ColorTheme.primaryNudge)
                        } else if viewModel.calendarAccessDenied {
                            calendarPermissionView
                        } else if let errorMessage = viewModel.errorMessage {
                            EmptyStateView(
                                icon: .reminder,
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
                }
            }
            .navigationTitle(L10n.Tab.today)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.Settings.title)
                    .accessibilityIdentifier("home.settings")
                }
            }
        }
        .sheet(isPresented: $appState.isDailyRecapPresented) {
            DailyRecapSheet()
                .environment(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environment(appState)
        }
        .sheet(item: $composerDraft) { draft in
            CalendarEventComposerView(
                draft: draft,
                rhythm: draft.rhythmID.flatMap { rhythmID in
                    recurringEvents.first { $0.id == rhythmID }
                }
            ) { title in
                viewModel.confirmationMessage = L10n.Home.calendarAdded(title)
            }
            .environment(appState)
        }
        .sheet(item: $editingPrep) { prep in
            PrepEditorView(prep: prep)
                .environment(appState)
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
        .task {
            handleNavigation(appState.pendingNavigation)
        }
        .onChange(of: appState.pendingNavigation) { _, destination in
            handleNavigation(destination)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.evaluateDailyRecapPresentation()
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
            icon: .empty,
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
                HomeQuickCaptureCard {
                    composerDraft = CalendarEventComposerDraft(
                        startDate: nextAvailableHour()
                    )
                }
                prepSection
                nudgeSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, NudgeLayoutMetrics.listBottomClearance)
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
                            PrepTrackerCard(prep: prep) {
                                editingPrep = prep
                            }
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
                    icon: .empty,
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
                                composerDraft = draft(for: event)
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
            NudgeSymbolBadge(symbol: .calendar, size: 44)
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

    private func handleNavigation(_ destination: AppNavigationDestination?) {
        guard case let .scheduleRhythm(rhythmID) = destination else { return }
        if let rhythmID,
           let event = recurringEvents.first(where: { $0.id == rhythmID }) {
            composerDraft = draft(for: event)
        } else {
            composerDraft = CalendarEventComposerDraft(startDate: nextAvailableHour())
        }
        appState.consumeNavigation(.scheduleRhythm(rhythmID))
    }

    private func draft(for event: RecurringEvent) -> CalendarEventComposerDraft {
        let nextHour = nextAvailableHour()
        var startDate = max(event.nextPredictedDate, nextHour)
        if let hour = event.defaultEventStartHour {
            let minute = event.defaultEventStartMinute ?? 0
            startDate = Calendar.autoupdatingCurrent.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: event.nextPredictedDate
            ) ?? startDate
            startDate = max(startDate, nextHour)
        }
        return CalendarEventComposerDraft(
            title: event.displayName,
            startDate: startDate,
            durationMinutes: event.defaultEventDurationMinutes,
            calendarIdentifier: event.preferredCalendarIdentifier,
            rhythmID: event.id
        )
    }

    private func nextAvailableHour(from date: Date = .now) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let startOfHour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: startOfHour)
            ?? date.addingTimeInterval(3_600)
    }
}

private struct PrepTrackerCard: View {
    let prep: EventPrep
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    NudgeSymbolBadge(symbol: .calendar, size: 42)

                    Text(L10n.Prep.Card.dayCount(daysRemaining))
                        .pretendard(.headline, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryNudge)
                }

                Spacer(minLength: 0)

                Text(prep.title)
                    .pretendard(.headline, weight: .semibold)
                    .foregroundStyle(ColorTheme.primaryText)
                    .lineLimit(2)

                HStack {
                    Text(prep.status.localizedTitle)
                        .pretendard(.caption, weight: .medium)
                        .foregroundStyle(ColorTheme.secondarySnooze)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }
            .padding(16)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 250 : 190)
            .frame(
                minHeight: dynamicTypeSize.isAccessibilitySize ? 220 : 150,
                alignment: .leading
            )
            .background(
                ColorTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ColorTheme.separator.opacity(0.35), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.Prep.Card.accessibility(
                prep.title,
                daysRemaining,
                prep.status.localizedTitle
            )
        )
        .accessibilityHint(L10n.Prep.Card.openHint)
        .accessibilityIdentifier("home.prep.card")
    }
}

private struct HomeQuickCaptureCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                NudgeSymbolBadge(symbol: .calendar, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.QuickCapture.title)
                        .pretendard(.headline, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryText)
                    Text(L10n.QuickCapture.subtitle)
                        .pretendard(.subheadline)
                        .foregroundStyle(ColorTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ColorTheme.primaryNudge)
            }
            .padding(16)
            .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ColorTheme.primaryNudge.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.quickCapture")
    }
}
