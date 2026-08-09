import Foundation
import SwiftData

@Model
final class EventPrep {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetDate: Date
    var status: PrepStatus
    var nextReminderDate: Date
    var linkedCalendarIdentifier: String?
    var linkedEventIdentifier: String?
    var intensity: PrepIntensity
    var nextActionNote: String
    var notificationsEnabled: Bool
    var preferredNotificationHour: Int
    var preferredNotificationMinute: Int
    var planState: PrepPlanState
    var lastAnsweredAt: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        targetDate: Date,
        status: PrepStatus = .notReady,
        nextReminderDate: Date = .now
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.status = status
        self.nextReminderDate = nextReminderDate
        linkedCalendarIdentifier = nil
        linkedEventIdentifier = nil
        intensity = .normal
        nextActionNote = ""
        notificationsEnabled = true
        preferredNotificationHour = 9
        preferredNotificationMinute = 0
        planState = .active
        lastAnsweredAt = nil
        completedAt = nil
        createdAt = .now
        updatedAt = .now
    }

    init(value: PrepPlan) {
        id = value.id
        title = value.title
        targetDate = value.targetDate
        status = PrepStatus(value.readinessStatus)
        nextReminderDate = value.nextCheckInDate ?? value.targetDate
        linkedCalendarIdentifier = value.linkedCalendarIdentifier
        linkedEventIdentifier = value.linkedEventIdentifier
        intensity = value.intensity
        nextActionNote = value.nextActionNote
        notificationsEnabled = value.notificationsEnabled
        preferredNotificationHour = value.preferredNotificationHour
        preferredNotificationMinute = value.preferredNotificationMinute
        planState = value.planState
        lastAnsweredAt = value.lastAnsweredAt
        completedAt = value.completedAt
        createdAt = value.createdAt
        updatedAt = value.updatedAt
    }
}
