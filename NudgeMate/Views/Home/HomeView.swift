import SwiftData
import SwiftUI

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

    private var snapshot: HomeDashboardSnapshot {
        HomeDashboardSnapshot(rhythms: recurringEvents, preps: eventPreps)
    }

    private var activeNudges: [RecurringEvent] {
        let ids = Set(snapshot.rhythmIDs)
        return recurringEvents.filter { ids.contains($0.id) }
    }

    private var activePreps: [EventPrep] {
        let ids = Set(snapshot.prepIDs)
        return eventPreps.filter { ids.contains($0.id) }
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            ZStack {
                NudgeScreenBackground()

                if viewModel.isLoading {
                    ProgressView(L10n.Home.loading)
                        .pretendard(.body)
                        .tint(ColorTheme.primaryNudge)
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
                    HomeDashboard(
                        snapshot: snapshot,
                        preps: activePreps,
                        nudges: activeNudges,
                        onOpenSettings: { isSettingsPresented = true },
                        onViewAllPreps: { appState.navigate(to: .preps) },
                        onViewAllRhythms: { appState.navigate(to: .rhythms) },
                        onOpenPrep: { editingPrep = $0 },
                        onSchedule: { composerDraft = draft(for: $0) },
                        onSnooze: snooze,
                        onSkip: skip,
                        onToggleMute: toggleMute,
                        onDelete: delete
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
                Task {
                    try? await appState.nudgeManager.synchronizeWidgetsAndActivities(modelContext: modelContext)
                }
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

    private func snooze(_ event: RecurringEvent) {
        Task {
            await nudgeViewModel.snooze(
                event,
                modelContext: modelContext,
                nudgeManager: appState.nudgeManager
            )
        }
    }

    private func skip(_ event: RecurringEvent) {
        Task {
            await nudgeViewModel.skip(
                event,
                modelContext: modelContext,
                nudgeManager: appState.nudgeManager
            )
        }
    }

    private func toggleMute(_ event: RecurringEvent) {
        Task {
            await nudgeViewModel.toggleMuted(
                event,
                modelContext: modelContext,
                nudgeManager: appState.nudgeManager
            )
        }
    }

    private func delete(_ event: RecurringEvent) {
        nudgeViewModel.delete(
            event,
            modelContext: modelContext,
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

private struct HomeDashboard: View {
    let snapshot: HomeDashboardSnapshot
    let preps: [EventPrep]
    let nudges: [RecurringEvent]
    let onOpenSettings: () -> Void
    let onViewAllPreps: () -> Void
    let onViewAllRhythms: () -> Void
    let onOpenPrep: (EventPrep) -> Void
    let onSchedule: (RecurringEvent) -> Void
    let onSnooze: (RecurringEvent) -> Void
    let onSkip: (RecurringEvent) -> Void
    let onToggleMute: (RecurringEvent) -> Void
    let onDelete: (RecurringEvent) -> Void

    var body: some View {
        let previewIDs = Set(snapshot.rhythmPreviewIDs)
        let rhythmPreview = nudges.filter { previewIDs.contains($0.id) }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HomeGreetingHeader(onOpenSettings: onOpenSettings)
                HomeWeekCalendar(
                    preps: preps,
                    nudges: nudges,
                    itemCount: snapshot.itemCount
                )
                HomeSummaryBanner(itemCount: snapshot.itemCount)

                HomePrioritySection(
                    priority: snapshot.priority,
                    preps: preps,
                    nudges: nudges,
                    onViewAll: snapshot.priority.isRhythm ? onViewAllRhythms : onViewAllPreps,
                    onOpenPrep: onOpenPrep,
                    onSchedule: onSchedule,
                    onSnooze: onSnooze,
                    onSkip: onSkip,
                    onToggleMute: onToggleMute,
                    onDelete: onDelete
                )

                HomeRhythmSection(
                    nudges: rhythmPreview,
                    onViewAll: onViewAllRhythms,
                    onSchedule: onSchedule,
                    onSnooze: onSnooze,
                    onSkip: onSkip,
                    onToggleMute: onToggleMute,
                    onDelete: onDelete
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, NudgeLayoutMetrics.listBottomClearance)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("home.dashboard")
    }
}

private extension HomeDashboardSnapshot.Item? {
    var isRhythm: Bool {
        guard case .some(.rhythm) = self else { return false }
        return true
    }
}

private struct HomeGreetingHeader: View {
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now, format: .dateTime.month().day().weekday(.wide))
                    .pretendard(.caption, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryNudge)

                Text(L10n.Home.Today.greeting)
                    .pretendard(.title2, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(action: onOpenSettings) {
                NudgeAssetIcon(name: "glyph_settings", size: 19)
                    .foregroundStyle(ColorTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(ColorTheme.separator, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Settings.title)
            .accessibilityIdentifier("home.settings")
        }
        .padding(.horizontal, 4)
    }
}

private struct HomeWeekCalendar: View {
    let preps: [EventPrep]
    let nudges: [RecurringEvent]
    let itemCount: Int

    private var dates: [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? calendar.startOfDay(for: .now)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(Date.now, format: .dateTime.year().month(.wide))
                    .pretendard(.subheadline, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryText)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(ColorTheme.accentCoral)
                        .frame(width: 6, height: 6)
                    Text(L10n.Home.Today.itemCount(itemCount))
                        .pretendard(.caption2, weight: .medium)
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 2) {
                ForEach(dates, id: \.self) { date in
                    HomeWeekDay(
                        date: date,
                        isToday: Calendar.autoupdatingCurrent.isDateInToday(date),
                        hasItem: hasItem(on: date)
                    )
                }
            }
        }
        .padding(14)
        .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ColorTheme.separator, lineWidth: 1)
        }
        .shadow(color: ColorTheme.primaryText.opacity(0.035), radius: 10, y: 4)
    }

    private func hasItem(on date: Date) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        return preps.contains { calendar.isDate($0.targetDate, inSameDayAs: date) }
            || nudges.contains { calendar.isDate($0.nextPredictedDate, inSameDayAs: date) }
    }
}

private struct HomeWeekDay: View {
    let date: Date
    let isToday: Bool
    let hasItem: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(date, format: .dateTime.weekday(.narrow))
                .pretendard(.caption2, weight: .medium)
                .foregroundStyle(isToday ? Color.white.opacity(0.84) : ColorTheme.secondaryText)

            Text(date, format: .dateTime.day())
                .pretendard(.subheadline, weight: .bold)
                .foregroundStyle(isToday ? Color.white : dayColor)

            Circle()
                .fill(isToday ? Color.white : ColorTheme.accentCoral)
                .frame(width: 4, height: 4)
                .opacity(hasItem ? 1 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            isToday ? ColorTheme.primaryNudge : Color.clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var dayColor: Color {
        let weekday = Calendar.autoupdatingCurrent.component(.weekday, from: date)
        if weekday == 1 { return ColorTheme.secondarySnooze }
        if weekday == 7 { return ColorTheme.primaryNudge }
        return ColorTheme.primaryText
    }
}

private struct HomeSummaryBanner: View {
    let itemCount: Int

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.Home.Today.summaryLabel)
                    .pretendard(.caption2, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryNudge)

                Text(
                    itemCount == 0
                        ? L10n.Home.Today.summaryEmpty
                        : L10n.Home.Today.summaryTitle(itemCount)
                )
                    .pretendard(.headline, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if itemCount > 0 {
                    Text(L10n.Home.Today.summaryDuration)
                        .pretendard(.caption2)
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }

            Spacer(minLength: 0)

            HomeCalendarArtwork()
                .frame(width: 128, height: 104)
                .accessibilityHidden(true)
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .background(ColorTheme.brandSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ColorTheme.primaryNudge.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.summary")
        .accessibilityValue("\(itemCount)")
    }
}

private struct HomeCalendarArtwork: View {
    var body: some View {
        Canvas { context, size in
            let base = CGRect(x: 4, y: size.height * 0.72, width: size.width - 8, height: size.height * 0.23)
            context.fill(
                Path(ellipseIn: base),
                with: .color(ColorTheme.primaryNudge.opacity(0.10))
            )

            let card = CGRect(x: size.width * 0.28, y: size.height * 0.18, width: size.width * 0.55, height: size.height * 0.68)
            context.fill(
                Path(roundedRect: card, cornerRadius: 14),
                with: .color(ColorTheme.cardBackground)
            )

            let header = CGRect(x: card.minX, y: card.minY, width: card.width, height: card.height * 0.30)
            var headerPath = Path()
            headerPath.addRoundedRect(in: header, cornerSize: CGSize(width: 14, height: 14))
            context.fill(headerPath, with: .color(ColorTheme.primaryNudge))

            let coral = CGRect(x: card.minX + 14, y: card.minY + card.height * 0.43, width: 19, height: 8)
            context.fill(Path(ellipseIn: coral), with: .color(ColorTheme.accentCoral))

            let line1 = CGRect(x: card.minX + 42, y: card.minY + card.height * 0.43, width: 21, height: 7)
            let line2 = CGRect(x: card.minX + 14, y: card.minY + card.height * 0.63, width: 49, height: 7)
            context.fill(Path(roundedRect: line1, cornerRadius: 4), with: .color(ColorTheme.backgroundDeep))
            context.fill(Path(roundedRect: line2, cornerRadius: 4), with: .color(ColorTheme.backgroundDeep))

            let sun = CGRect(x: size.width * 0.73, y: 2, width: 30, height: 30)
            context.fill(Path(ellipseIn: sun), with: .color(ColorTheme.accentCoral.opacity(0.88)))

            var sparkle = Path()
            let center = CGPoint(x: size.width * 0.18, y: size.height * 0.33)
            sparkle.move(to: CGPoint(x: center.x, y: center.y - 10))
            sparkle.addLine(to: CGPoint(x: center.x + 4, y: center.y - 3))
            sparkle.addLine(to: CGPoint(x: center.x + 11, y: center.y))
            sparkle.addLine(to: CGPoint(x: center.x + 4, y: center.y + 3))
            sparkle.addLine(to: CGPoint(x: center.x, y: center.y + 10))
            sparkle.addLine(to: CGPoint(x: center.x - 4, y: center.y + 3))
            sparkle.addLine(to: CGPoint(x: center.x - 11, y: center.y))
            sparkle.addLine(to: CGPoint(x: center.x - 4, y: center.y - 3))
            sparkle.closeSubpath()
            context.fill(sparkle, with: .color(ColorTheme.accentAmber))
        }
    }
}

private struct HomePrioritySection: View {
    let priority: HomeDashboardSnapshot.Item?
    let preps: [EventPrep]
    let nudges: [RecurringEvent]
    let onViewAll: () -> Void
    let onOpenPrep: (EventPrep) -> Void
    let onSchedule: (RecurringEvent) -> Void
    let onSnooze: (RecurringEvent) -> Void
    let onSkip: (RecurringEvent) -> Void
    let onToggleMute: (RecurringEvent) -> Void
    let onDelete: (RecurringEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(
                title: L10n.Home.Today.prepSection,
                actionTitle: L10n.Home.Today.viewAll,
                action: onViewAll,
                accessibilityIdentifier: "home.priority.viewAll",
                titleAccessibilityIdentifier: "home.priority"
            )

            switch priority {
            case let .prep(id):
                if let prep = preps.first(where: { $0.id == id }) {
                    HomePrepCard(prep: prep) { onOpenPrep(prep) }
                } else {
                    HomeCompactEmptyState(message: L10n.Home.Priority.empty)
                }
            case let .rhythm(id):
                if let event = nudges.first(where: { $0.id == id }) {
                    HomeRhythmRow(
                        event: event,
                        onSchedule: { onSchedule(event) },
                        onSnooze: { onSnooze(event) },
                        onSkip: { onSkip(event) },
                        onToggleMute: { onToggleMute(event) },
                        onDelete: { onDelete(event) }
                    )
                    .background(
                        ColorTheme.cardBackground,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(ColorTheme.separator, lineWidth: 1)
                    }
                } else {
                    HomeCompactEmptyState(message: L10n.Home.Priority.empty)
                }
            case nil:
                HomeCompactEmptyState(message: L10n.Home.Priority.empty)
            }
        }
    }
}

private struct HomePrepCard: View {
    let prep: EventPrep
    let action: () -> Void

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

    private var progress: Double {
        switch prep.status {
        case .notReady: 0.25
        case .inProgress: 0.55
        case .ready: 1
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 13) {
                HomeDateBadge(date: prep.targetDate)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text(L10n.Prep.Card.dayCount(daysRemaining))
                            .pretendard(.caption2, weight: .bold)
                            .foregroundStyle(ColorTheme.secondarySnooze)
                        Text(prep.status.localizedTitle)
                            .pretendard(.caption2, weight: .medium)
                            .foregroundStyle(ColorTheme.secondaryText)
                    }

                    Text(prep.title)
                        .pretendard(.headline, weight: .bold)
                        .foregroundStyle(ColorTheme.primaryText)
                        .lineLimit(2)

                    if !prep.nextActionNote.isEmpty {
                        Text(L10n.Home.Today.nextAction(prep.nextActionNote))
                            .pretendard(.caption)
                            .foregroundStyle(ColorTheme.secondaryText)
                            .lineLimit(2)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(ColorTheme.progressTrack)
                            Capsule()
                                .fill(ColorTheme.primaryNudge)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(prep.status.localizedTitle)
                            .pretendard(.caption2)
                            .foregroundStyle(ColorTheme.secondaryText)
                        Spacer()
                        Text(L10n.Home.Today.continuePrep)
                            .pretendard(.caption2, weight: .bold)
                            .foregroundStyle(ColorTheme.primaryNudge)
                    }
                }
            }
            .padding(14)
            .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ColorTheme.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.Prep.Card.accessibility(prep.title, daysRemaining, prep.status.localizedTitle)
        )
        .accessibilityHint(L10n.Prep.Card.openHint)
        .accessibilityIdentifier("home.prep.card")
    }
}

private struct HomeDateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(date, format: .dateTime.month(.abbreviated))
                .pretendard(.caption2, weight: .bold)
                .foregroundStyle(ColorTheme.secondarySnooze)
            Text(date, format: .dateTime.day())
                .pretendard(.title3, weight: .bold)
                .foregroundStyle(ColorTheme.secondarySnooze)
        }
        .frame(width: 52, height: 62)
        .background(ColorTheme.selectionFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct HomeRhythmSection: View {
    let nudges: [RecurringEvent]
    let onViewAll: () -> Void
    let onSchedule: (RecurringEvent) -> Void
    let onSnooze: (RecurringEvent) -> Void
    let onSkip: (RecurringEvent) -> Void
    let onToggleMute: (RecurringEvent) -> Void
    let onDelete: (RecurringEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(
                title: L10n.Home.Today.rhythmSection,
                actionTitle: L10n.Home.Today.viewAll,
                action: onViewAll,
                accessibilityIdentifier: "home.rhythms.viewAll",
                titleAccessibilityIdentifier: "home.rhythms.title"
            )

            if nudges.isEmpty {
                HomeCompactEmptyState(message: L10n.Home.Nudge.emptyMessage)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(nudges.enumerated()), id: \.element.id) { index, event in
                        HomeRhythmRow(
                            event: event,
                            onSchedule: { onSchedule(event) },
                            onSnooze: { onSnooze(event) },
                            onSkip: { onSkip(event) },
                            onToggleMute: { onToggleMute(event) },
                            onDelete: { onDelete(event) }
                        )

                        if index < nudges.count - 1 {
                            Divider()
                                .overlay(ColorTheme.separator)
                                .padding(.leading, 65)
                        }
                    }
                }
                .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(ColorTheme.separator, lineWidth: 1)
                }
            }
        }
    }
}

private struct HomeRhythmRow: View {
    let event: RecurringEvent
    let onSchedule: () -> Void
    let onSnooze: () -> Void
    let onSkip: () -> Void
    let onToggleMute: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        HStack(spacing: 10) {
            NudgeSymbolBadge(symbol: .category(event.category), size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.Home.Today.interval(event.baseInterval))
                    .pretendard(.caption2, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryNudge)
                Text(event.title)
                    .pretendard(.subheadline, weight: .bold)
                    .foregroundStyle(ColorTheme.primaryText)
                    .lineLimit(1)
                Text(L10n.Home.Today.expectedDate(event.nextPredictedDate.formatted(.relative(presentation: .named))))
                    .pretendard(.caption2)
                    .foregroundStyle(ColorTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button(L10n.Home.Today.schedule, action: onSchedule)
                .pretendard(.caption2, weight: .bold)
                .foregroundStyle(Color.white)
                .frame(minWidth: 70, minHeight: 44)
                .background(ColorTheme.primaryNudge, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .buttonStyle(.plain)

            Menu {
                Button(L10n.Nudge.Action.snooze, action: onSnooze)
                Button(L10n.Nudge.Action.skip, action: onSkip)
                    .accessibilityIdentifier("nudge.skip")
                Button(
                    event.isMuted ? L10n.Nudge.Action.enable : L10n.Nudge.Action.disable,
                    action: onToggleMute
                )
                .accessibilityIdentifier("nudge.toggleMute")
                Divider()
                Button(L10n.Nudge.Action.delete, role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
                .accessibilityIdentifier("nudge.delete")
            } label: {
                NudgeAssetIcon(name: "glyph_more", size: 17)
                    .foregroundStyle(ColorTheme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.Common.moreActions)
            .accessibilityIdentifier("nudge.moreActions")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .confirmationDialog(
            L10n.Selection.deleteTitle(1),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.Nudge.Action.delete, role: .destructive, action: onDelete)
                .accessibilityIdentifier("nudge.confirmDelete")
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Selection.deleteMessage)
        }
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let actionTitle: String
    let action: () -> Void
    let accessibilityIdentifier: String
    let titleAccessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .pretendard(.headline, weight: .bold)
                .foregroundStyle(ColorTheme.primaryText)
                .accessibilityIdentifier(titleAccessibilityIdentifier)
            Spacer()
            Button(actionTitle, action: action)
                .pretendard(.caption2)
                .foregroundStyle(ColorTheme.secondaryText)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(.horizontal, 4)
    }
}

private struct HomeCompactEmptyState: View {
    let message: String

    var body: some View {
        Text(message)
            .pretendard(.subheadline)
            .foregroundStyle(ColorTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ColorTheme.separator, lineWidth: 1)
            }
    }
}
