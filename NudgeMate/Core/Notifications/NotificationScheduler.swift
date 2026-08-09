import Foundation
import UserNotifications

protocol NotificationScheduling: Sendable {
    func permissionState() async -> NotificationPermissionState
    func requestAuthorization() async throws -> Bool
    func reconcile(_ descriptors: [LocalNotificationDescriptor]) async throws
    func cancel(identifiers: [String]) async
    func cancelAll() async
}

actor LocalNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.center = center
        self.calendar = calendar
    }

    func permissionState() async -> NotificationPermissionState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        switch await permissionState() {
        case .authorized: return true
        case .denied: return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
    }

    func reconcile(_ descriptors: [LocalNotificationDescriptor]) async throws {
        for descriptor in descriptors {
            center.removePendingNotificationRequests(withIdentifiers: [descriptor.identifier])
            let content = UNMutableNotificationContent()
            content.title = descriptor.title
            content.body = descriptor.body
            content.categoryIdentifier = descriptor.categoryIdentifier
            content.userInfo = descriptor.payload.userInfo
            content.sound = .default
            let safeDate = max(descriptor.fireDate, Date.now.addingTimeInterval(5))
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: safeDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(
                UNNotificationRequest(
                    identifier: descriptor.identifier,
                    content: content,
                    trigger: trigger
                )
            )
        }
    }

    func cancel(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
