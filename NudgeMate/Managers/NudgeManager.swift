import Foundation
import Observation
import SwiftData

enum NudgeNotificationError: LocalizedError {
    case permissionDenied
    case invalidTargetDate

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return NudgeMateStrings.Localizable.Notification.Error.permissionDenied
        case .invalidTargetDate:
            return NudgeMateStrings.Localizable.Notification.Error.invalidTargetDate
        }
    }
}

@MainActor
@Observable
final class NudgeManager {
    private(set) var notificationsAuthorized = false

    @ObservationIgnored
    private let scheduler: any NotificationScheduling

    @ObservationIgnored
    private let calendar: Calendar

    @ObservationIgnored
    private var modelContainer: ModelContainer?

    @ObservationIgnored
    private let widgetActivityCoordinator: WidgetActivityCoordinator

    init(
        scheduler: any NotificationScheduling = LocalNotificationScheduler(),
        calendar: Calendar = .autoupdatingCurrent,
        widgetActivityCoordinator: WidgetActivityCoordinator? = nil
    ) {
        self.scheduler = scheduler
        self.calendar = calendar
        self.widgetActivityCoordinator = widgetActivityCoordinator ?? .shared
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        widgetActivityCoordinator.configure(modelContainer: modelContainer)
    }

    @discardableResult
    func refreshAuthorizationState() async -> NotificationPermissionState {
        let state = await scheduler.permissionState()
        notificationsAuthorized = state == .authorized
        return state
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        let granted = try await scheduler.requestAuthorization()
        notificationsAuthorized = granted
        guard granted else { throw NudgeNotificationError.permissionDenied }
        return true
    }

    func scheduleNudge(
        for event: RecurringEvent,
        privacyMode: PrivacyNotificationMode? = nil
    ) async throws {
        guard !event.isMuted else {
            await scheduler.cancel(identifiers: [nudgeRequestIdentifier(for: event.id)])
            return
        }
        try await ensureAuthorization()

        let resolvedPrivacyMode = privacyMode ?? configuredPrivacyMode()
        let strings = NudgeMateStrings.Localizable.Notification.self
        let title = resolvedPrivacyMode == .generic
            ? strings.Generic.title
            : strings.Nudge.title(event.title)
        let body = resolvedPrivacyMode == .generic
            ? strings.Generic.body
            : strings.Nudge.body(event.baseIntervalDays)
        let leadDate = calendar.date(
            byAdding: .day,
            value: -max(0, event.leadTimeDays),
            to: event.nextExpectedStartDate
        ) ?? event.nextExpectedStartDate
        let fireDate = date(
            leadDate,
            hour: event.notificationHour,
            minute: event.notificationMinute
        )
        let descriptor = LocalNotificationDescriptor(
            identifier: nudgeRequestIdentifier(for: event.id),
            title: title,
            body: body,
            categoryIdentifier: NotificationCategoryIdentifier.rhythmReview,
            payload: NotificationPayload(
                rhythmID: event.id,
                deepLink: "nudgemate://rhythm/\(event.id.uuidString)"
            ),
            fireDate: fireDate
        )
        try await scheduler.reconcile([descriptor])
    }

    func schedulePrepReminder(
        for prep: EventPrep,
        privacyMode: PrivacyNotificationMode? = nil
    ) async throws {
        guard prep.status != .ready, prep.notificationsEnabled else {
            await scheduler.cancel(identifiers: [prepRequestIdentifier(for: prep.id)])
            return
        }
        guard prep.targetDate > .now else { throw NudgeNotificationError.invalidTargetDate }
        try await ensureAuthorization()

        let resolvedPrivacyMode = privacyMode ?? configuredPrivacyMode()
        let strings = NudgeMateStrings.Localizable.Notification.self
        let descriptor = LocalNotificationDescriptor(
            identifier: prepRequestIdentifier(for: prep.id),
            title: resolvedPrivacyMode == .generic ? strings.Generic.title : strings.Prep.title(prep.title),
            body: resolvedPrivacyMode == .generic ? strings.Generic.body : strings.Prep.body,
            categoryIdentifier: NotificationCategoryIdentifier.prepCheckIn,
            payload: NotificationPayload(
                prepPlanID: prep.id,
                deepLink: "nudgemate://prep/\(prep.id.uuidString)"
            ),
            fireDate: date(
                prep.nextReminderDate,
                hour: prep.preferredNotificationHour,
                minute: prep.preferredNotificationMinute
            )
        )
        try await scheduler.reconcile([descriptor])
    }

    func updatePrep(
        _ prep: EventPrep,
        status: PrepStatus,
        modelContext: ModelContext,
        now: Date = .now
    ) async throws {
        prep.status = status
        prep.lastAnsweredAt = now
        prep.updatedAt = now

        let result = PrepScheduleCalculator(calendar: calendar).nextCheckIn(
            now: now,
            targetDate: prep.targetDate,
            status: status.readinessStatus,
            intensity: prep.intensity
        )
        switch result {
        case .stopped:
            prep.planState = .ready
            prep.completedAt = now
            await scheduler.cancel(identifiers: [prepRequestIdentifier(for: prep.id)])
        case let .scheduled(date), let .finalCheck(date):
            prep.planState = .active
            prep.nextReminderDate = date
            try await schedulePrepReminder(for: prep)
        case .targetPassed:
            prep.planState = .targetPassed
            await scheduler.cancel(identifiers: [prepRequestIdentifier(for: prep.id)])
        }
        try modelContext.save()
        try? await widgetActivityCoordinator.synchronize(
            modelContext: modelContext,
            startLiveActivityFor: status == .inProgress ? prep.id : nil,
            now: now
        )
    }

    func nextSpacedReminderDate(targetDate: Date, now: Date = .now) throws -> Date {
        let result = PrepScheduleCalculator(calendar: calendar).nextCheckIn(
            now: now,
            targetDate: targetDate,
            status: .notReady,
            intensity: .normal
        )
        switch result {
        case let .scheduled(date), let .finalCheck(date): return date
        case .stopped, .targetPassed: throw NudgeNotificationError.invalidTargetDate
        }
    }

    func snooze(_ event: RecurringEvent, modelContext: ModelContext) async throws {
        event.nextExpectedStartDate = addingDays(7, to: event.nextExpectedStartDate)
        event.nextExpectedCenterDate = addingDays(7, to: event.nextExpectedCenterDate)
        event.nextExpectedEndDate = addingDays(7, to: event.nextExpectedEndDate)
        event.updatedAt = .now
        try modelContext.save()
        try await scheduleNudge(for: event)
    }

    func skip(_ event: RecurringEvent, modelContext: ModelContext) async throws {
        try AdaptiveRhythmService(
            modelContext: modelContext,
            calendar: calendar
        ).recordSkipped(for: event)
        event.nextExpectedStartDate = addingDays(event.baseIntervalDays, to: event.nextExpectedStartDate)
        event.nextExpectedCenterDate = addingDays(event.baseIntervalDays, to: event.nextExpectedCenterDate)
        event.nextExpectedEndDate = addingDays(event.baseIntervalDays, to: event.nextExpectedEndDate)
        event.updatedAt = .now
        try modelContext.save()
        try await scheduleNudge(for: event)
    }

    func complete(
        _ event: RecurringEvent,
        source: OccurrenceSource = .userConfirmed,
        modelContext: ModelContext,
        now: Date = .now
    ) async throws {
        try AdaptiveRhythmService(
            modelContext: modelContext,
            calendar: calendar
        ).recordCompletion(for: event, source: source, at: now)
        try await scheduleNudge(for: event)
    }

    func recordScheduledOccurrence(
        for event: RecurringEvent,
        at date: Date,
        calendarIdentifier: String?,
        eventIdentifier: String,
        modelContext: ModelContext
    ) throws {
        try AdaptiveRhythmService(
            modelContext: modelContext,
            calendar: calendar
        ).recordScheduled(
            for: event,
            at: date,
            calendarIdentifier: calendarIdentifier,
            eventIdentifier: eventIdentifier
        )
    }

    func cancelNudge(for id: UUID) {
        Task { await scheduler.cancel(identifiers: [nudgeRequestIdentifier(for: id)]) }
    }

    func cancelPrepReminder(for id: UUID) {
        Task { await scheduler.cancel(identifiers: [prepRequestIdentifier(for: id)]) }
    }

    func cancelAll() async {
        await scheduler.cancelAll()
    }

    func synchronizeWidgetsAndActivities(
        modelContext: ModelContext? = nil
    ) async throws {
        try await widgetActivityCoordinator.synchronize(modelContext: modelContext)
    }

    func clearWidgetsAndActivities() async {
        await widgetActivityCoordinator.clear()
    }

    func reconcileDailyRecap(settings: UserSettings, now: Date = .now) async {
        let identifiers = (0..<14).map { "recap.\($0)" }
        await scheduler.cancel(identifiers: identifiers)
        guard settings.dailyRecapEnabled,
              settings.dailyRecapFrequency != .off,
              await scheduler.permissionState() == .authorized else {
            return
        }

        var descriptors: [LocalNotificationDescriptor] = []
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  isRecapDay(day, frequency: settings.dailyRecapFrequency) else {
                continue
            }
            let fireDate = date(
                day,
                hour: settings.dailyRecapHour,
                minute: settings.dailyRecapMinute
            )
            guard fireDate > now else { continue }
            descriptors.append(
                LocalNotificationDescriptor(
                    identifier: "recap.\(offset)",
                    title: settings.privacyNotificationMode == .generic
                        ? NudgeMateStrings.Localizable.Notification.Generic.title
                        : NudgeMateStrings.Localizable.Notification.Recap.title,
                    body: settings.privacyNotificationMode == .generic
                        ? NudgeMateStrings.Localizable.Notification.Generic.body
                        : NudgeMateStrings.Localizable.Notification.Recap.body,
                    categoryIdentifier: NotificationCategoryIdentifier.dailyRecap,
                    payload: NotificationPayload(deepLink: "nudgemate://recap"),
                    fireDate: fireDate
                )
            )
        }
        try? await scheduler.reconcile(descriptors)
    }

    func reconcileAll(settings: UserSettings) async {
        try? await synchronizeWidgetsAndActivities()
        guard await scheduler.permissionState() == .authorized else {
            await reconcileDailyRecap(settings: settings)
            return
        }
        guard let modelContainer else {
            await reconcileDailyRecap(settings: settings)
            return
        }
        let context = ModelContext(modelContainer)
        let rhythms = (try? context.fetch(FetchDescriptor<RecurringEvent>())) ?? []
        for rhythm in rhythms {
            try? await scheduleNudge(
                for: rhythm,
                privacyMode: settings.privacyNotificationMode
            )
        }
        let preps = (try? context.fetch(FetchDescriptor<EventPrep>())) ?? []
        for prep in preps where prep.targetDate > .now {
            try? await schedulePrepReminder(
                for: prep,
                privacyMode: settings.privacyNotificationMode
            )
        }
        await reconcileDailyRecap(settings: settings)
    }

    func handleNotificationAction(
        _ actionIdentifier: String,
        payload: NotificationPayload,
        modelContext: ModelContext
    ) async throws {
        switch actionIdentifier {
        case NotificationActionIdentifier.rhythmSnoozeOneWeek:
            if let event = try fetchRhythm(payload.rhythmID, context: modelContext) {
                try await snooze(event, modelContext: modelContext)
            }
        case NotificationActionIdentifier.rhythmSkipOnce:
            if let event = try fetchRhythm(payload.rhythmID, context: modelContext) {
                try await skip(event, modelContext: modelContext)
            }
        case NotificationActionIdentifier.prepNotReady:
            if let prep = try fetchPrep(payload.prepPlanID, context: modelContext) {
                try await updatePrep(prep, status: .notReady, modelContext: modelContext)
            }
        case NotificationActionIdentifier.prepInProgress:
            if let prep = try fetchPrep(payload.prepPlanID, context: modelContext) {
                try await updatePrep(prep, status: .inProgress, modelContext: modelContext)
            }
        case NotificationActionIdentifier.prepReady:
            if let prep = try fetchPrep(payload.prepPlanID, context: modelContext) {
                try await updatePrep(prep, status: .ready, modelContext: modelContext)
            }
        default:
            return
        }
    }

    private func ensureAuthorization() async throws {
        if await scheduler.permissionState() == .authorized {
            notificationsAuthorized = true
            return
        }
        try await requestAuthorization()
    }

    private func configuredPrivacyMode() -> PrivacyNotificationMode {
        guard let modelContainer else { return .detailed }
        let context = ModelContext(modelContainer)
        return (try? SwiftDataSettingsRepository(context: context).load().privacyNotificationMode)
            ?? .detailed
    }

    private func fetchRhythm(_ id: UUID?, context: ModelContext) throws -> RecurringEvent? {
        guard let id else { return nil }
        let value = id
        return try context.fetch(
            FetchDescriptor<RecurringEvent>(predicate: #Predicate { $0.id == value })
        ).first
    }

    private func fetchPrep(_ id: UUID?, context: ModelContext) throws -> EventPrep? {
        guard let id else { return nil }
        let value = id
        return try context.fetch(
            FetchDescriptor<EventPrep>(predicate: #Predicate { $0.id == value })
        ).first
    }

    private func date(_ value: Date, hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: min(23, max(0, hour)), minute: min(59, max(0, minute)), second: 0, of: value)
            ?? value
    }

    private func addingDays(_ days: Int, to value: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: value)
            ?? value.addingTimeInterval(TimeInterval(days * 86_400))
    }

    private func isRecapDay(
        _ date: Date,
        frequency: DailyRecapFrequency
    ) -> Bool {
        switch frequency {
        case .daily: true
        case .threeTimesWeekly: [2, 4, 6].contains(calendar.component(.weekday, from: date))
        case .weekly: calendar.component(.weekday, from: date) == 1
        case .off: false
        }
    }

    private func nudgeRequestIdentifier(for id: UUID) -> String {
        "rhythm.\(id.uuidString)"
    }

    private func prepRequestIdentifier(for id: UUID) -> String {
        "prep.\(id.uuidString)"
    }
}
