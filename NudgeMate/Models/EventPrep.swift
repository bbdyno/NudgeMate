import Foundation
import SwiftData

@Model
final class EventPrep {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetDate: Date
    var status: PrepStatus
    var nextReminderDate: Date

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
    }
}
