import Foundation
import SwiftData

@Model
final class RecurringEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var baseInterval: Int
    var historyDates: [Date]
    var nextPredictedDate: Date
    var isMuted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        baseInterval: Int,
        historyDates: [Date],
        nextPredictedDate: Date,
        isMuted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.baseInterval = max(1, baseInterval)
        self.historyDates = historyDates.sorted()
        self.nextPredictedDate = nextPredictedDate
        self.isMuted = isMuted
    }
}
