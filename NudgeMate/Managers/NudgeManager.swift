import Foundation
import Observation
import SwiftData
import UserNotifications

private typealias L10n = NudgeMateStrings.Localizable

enum NudgeNotificationError: LocalizedError {
    case permissionDenied
    case modelContainerUnavailable
    case invalidTargetDate

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return L10n.Notification.Error.permissionDenied
        case .modelContainerUnavailable:
            return L10n.Notification.Error.modelUnavailable
        case .invalidTargetDate:
            return L10n.Notification.Error.invalidTargetDate
        }
    }
}

extension Notification.Name {
    static let scheduleNowRequested = Notification.Name("NudgeMate.scheduleNowRequested")
}

@MainActor
@Observable
final class NudgeManager: NSObject, UNUserNotificationCenterDelegate {
    enum Identifier {
        static let nudgeCategory = "NUDGE_CATEGORY"
        static let prepCategory = "PREP_CATEGORY"
        static let scheduleNow = "SCHEDULE_NOW"
        static let snoozeWeek = "SNOOZE_ONE_WEEK"
        static let skip = "SKIP_NUDGE"
        static let notReady = "PREP_NOT_READY"
        static let ready = "PREP_READY"
    }

    private(set) var notificationsAuthorized = false

    @ObservationIgnored
    private let center: UNUserNotificationCenter

    @ObservationIgnored
    private let calendar: Calendar

    @ObservationIgnored
    private var modelContainer: ModelContainer?

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.center = center
        self.calendar = calendar
        super.init()
        center.delegate = self
        configureNotificationCategories()
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationsAuthorized = true
            return true
        case .denied:
            notificationsAuthorized = false
            throw NudgeNotificationError.permissionDenied
        case .notDetermined:
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            notificationsAuthorized = granted
            guard granted else { throw NudgeNotificationError.permissionDenied }
            return true
        @unknown default:
            notificationsAuthorized = false
            throw NudgeNotificationError.permissionDenied
        }
    }

    func scheduleNudge(for event: RecurringEvent) async throws {
        guard !event.isMuted else {
            cancelNudge(for: event.id)
            return
        }

        try await ensureAuthorization()

        let content = UNMutableNotificationContent()
        content.title = L10n.Notification.Nudge.title(event.title)
        content.body = L10n.Notification.Nudge.body(event.baseInterval)
        content.sound = .default
        content.categoryIdentifier = Identifier.nudgeCategory
        content.userInfo = [
            "type": "nudge",
            "id": event.id.uuidString
        ]

        let request = UNNotificationRequest(
            identifier: nudgeRequestIdentifier(for: event.id),
            content: content,
            trigger: calendarTrigger(for: event.nextPredictedDate)
        )

        center.removePendingNotificationRequests(
            withIdentifiers: [nudgeRequestIdentifier(for: event.id)]
        )
        try await center.add(request)
    }

    func schedulePrepReminder(for prep: EventPrep) async throws {
        guard prep.status != .ready else {
            cancelPrepReminder(for: prep.id)
            return
        }
        guard prep.targetDate > .now else {
            throw NudgeNotificationError.invalidTargetDate
        }

        try await ensureAuthorization()

        let content = UNMutableNotificationContent()
        content.title = L10n.Notification.Prep.title(prep.title)
        content.body = L10n.Notification.Prep.body
        content.sound = .default
        content.categoryIdentifier = Identifier.prepCategory
        content.userInfo = [
            "type": "prep",
            "id": prep.id.uuidString
        ]

        let request = UNNotificationRequest(
            identifier: prepRequestIdentifier(for: prep.id),
            content: content,
            trigger: calendarTrigger(for: prep.nextReminderDate)
        )

        center.removePendingNotificationRequests(
            withIdentifiers: [prepRequestIdentifier(for: prep.id)]
        )
        try await center.add(request)
    }

    func updatePrep(
        _ prep: EventPrep,
        status: PrepStatus,
        modelContext: ModelContext,
        now: Date = .now
    ) async throws {
        prep.status = status

        switch status {
        case .ready:
            cancelPrepReminder(for: prep.id)
        case .notReady, .inProgress:
            prep.nextReminderDate = try nextSpacedReminderDate(
                targetDate: prep.targetDate,
                now: now
            )
            try await schedulePrepReminder(for: prep)
        }

        try modelContext.save()
    }

    func nextSpacedReminderDate(targetDate: Date, now: Date = .now) throws -> Date {
        let daysLeft = targetDate.timeIntervalSince(now) / 86_400
        guard daysLeft > 0 else { throw NudgeNotificationError.invalidTargetDate }
        return now.addingTimeInterval((daysLeft / 2) * 86_400)
    }

    func snooze(_ event: RecurringEvent, modelContext: ModelContext) async throws {
        event.nextPredictedDate = calendar.date(byAdding: .day, value: 7, to: .now)
            ?? Date.now.addingTimeInterval(604_800)
        try modelContext.save()
        try await scheduleNudge(for: event)
    }

    func skip(_ event: RecurringEvent, modelContext: ModelContext) async throws {
        event.nextPredictedDate = recalculatedDate(
            currentPrediction: event.nextPredictedDate,
            intervalInDays: event.baseInterval,
            now: .now
        )
        try modelContext.save()
        try await scheduleNudge(for: event)
    }

    func cancelNudge(for id: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [nudgeRequestIdentifier(for: id)]
        )
    }

    func cancelPrepReminder(for id: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [prepRequestIdentifier(for: id)]
        )
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await processNotificationResponse(response)
    }

    private func processNotificationResponse(_ response: UNNotificationResponse) async {
        guard
            let idValue = response.notification.request.content.userInfo["id"] as? String,
            let id = UUID(uuidString: idValue)
        else { return }

        if response.actionIdentifier == Identifier.scheduleNow {
            NotificationCenter.default.post(
                name: .scheduleNowRequested,
                object: id
            )
            return
        }

        guard let modelContainer else { return }
        let modelContext = ModelContext(modelContainer)

        do {
            switch response.actionIdentifier {
            case Identifier.snoozeWeek:
                if let event = try fetchRecurringEvent(id: id, context: modelContext) {
                    try await snooze(event, modelContext: modelContext)
                }
            case Identifier.skip:
                if let event = try fetchRecurringEvent(id: id, context: modelContext) {
                    try await skip(event, modelContext: modelContext)
                }
            case Identifier.notReady:
                if let prep = try fetchEventPrep(id: id, context: modelContext) {
                    try await updatePrep(
                        prep,
                        status: .notReady,
                        modelContext: modelContext
                    )
                }
            case Identifier.ready:
                if let prep = try fetchEventPrep(id: id, context: modelContext) {
                    try await updatePrep(
                        prep,
                        status: .ready,
                        modelContext: modelContext
                    )
                }
            default:
                break
            }
        } catch {
            // Notification actions cannot present UI. The next foreground refresh retries scheduling.
        }
    }

    private func configureNotificationCategories() {
        let scheduleAction = UNNotificationAction(
            identifier: Identifier.scheduleNow,
            title: L10n.Notification.Action.scheduleNow,
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Identifier.snoozeWeek,
            title: L10n.Notification.Action.snoozeWeek
        )
        let skipAction = UNNotificationAction(
            identifier: Identifier.skip,
            title: L10n.Notification.Action.skip,
            options: [.destructive]
        )
        let nudgeCategory = UNNotificationCategory(
            identifier: Identifier.nudgeCategory,
            actions: [scheduleAction, snoozeAction, skipAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let notReadyAction = UNNotificationAction(
            identifier: Identifier.notReady,
            title: L10n.Notification.Action.notReady
        )
        let readyAction = UNNotificationAction(
            identifier: Identifier.ready,
            title: L10n.Notification.Action.ready
        )
        let prepCategory = UNNotificationCategory(
            identifier: Identifier.prepCategory,
            actions: [readyAction, notReadyAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([nudgeCategory, prepCategory])
    }

    private func ensureAuthorization() async throws {
        if !notificationsAuthorized {
            try await requestAuthorization()
        }
    }

    private func calendarTrigger(for requestedDate: Date) -> UNCalendarNotificationTrigger {
        let deliveryDate = max(requestedDate, Date.now.addingTimeInterval(5))
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: deliveryDate
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func recalculatedDate(
        currentPrediction: Date,
        intervalInDays: Int,
        now: Date
    ) -> Date {
        var prediction = currentPrediction
        repeat {
            prediction = calendar.date(
                byAdding: .day,
                value: max(1, intervalInDays),
                to: prediction
            ) ?? prediction.addingTimeInterval(TimeInterval(max(1, intervalInDays) * 86_400))
        } while prediction <= now
        return prediction
    }

    private func fetchRecurringEvent(
        id: UUID,
        context: ModelContext
    ) throws -> RecurringEvent? {
        let eventID = id
        let descriptor = FetchDescriptor<RecurringEvent>(
            predicate: #Predicate { $0.id == eventID }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchEventPrep(
        id: UUID,
        context: ModelContext
    ) throws -> EventPrep? {
        let prepID = id
        let descriptor = FetchDescriptor<EventPrep>(
            predicate: #Predicate { $0.id == prepID }
        )
        return try context.fetch(descriptor).first
    }

    private func nudgeRequestIdentifier(for id: UUID) -> String {
        "nudge.\(id.uuidString)"
    }

    private func prepRequestIdentifier(for id: UUID) -> String {
        "prep.\(id.uuidString)"
    }
}
