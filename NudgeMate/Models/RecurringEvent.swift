import Foundation
import SwiftData

@Model
final class RecurringEvent {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var normalizedName: String
    var category: RhythmCategory
    var mode: RhythmMode
    var origin: RhythmOrigin
    var aliases: [String]
    var sourceCalendarIdentifiers: [String]
    var baseIntervalDays: Int
    var variationDays: Int
    var confidenceScore: Double
    var confidenceBand: ConfidenceBand
    var historyDates: [Date]
    var lastOccurrenceDate: Date?
    var nextExpectedStartDate: Date
    var nextExpectedCenterDate: Date
    var nextExpectedEndDate: Date
    var leadTimeDays: Int
    var notificationHour: Int
    var notificationMinute: Int
    var preferredCalendarIdentifier: String?
    var defaultEventDurationMinutes: Int
    var defaultEventStartHour: Int?
    var defaultEventStartMinute: Int?
    var notificationsEnabled: Bool
    var lifecycleState: RhythmLifecycleState
    var createdAt: Date
    var updatedAt: Date

    var title: String {
        get { displayName }
        set { displayName = newValue }
    }

    var baseInterval: Int {
        get { baseIntervalDays }
        set { baseIntervalDays = max(1, newValue) }
    }

    var nextPredictedDate: Date {
        get { nextExpectedCenterDate }
        set {
            nextExpectedCenterDate = newValue
            nextExpectedStartDate = newValue.addingTimeInterval(TimeInterval(-variationDays * 86_400))
            nextExpectedEndDate = newValue.addingTimeInterval(TimeInterval(variationDays * 86_400))
        }
    }

    var isMuted: Bool {
        get { !notificationsEnabled || lifecycleState != .active }
        set {
            notificationsEnabled = !newValue
            lifecycleState = newValue ? .paused : .active
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        baseInterval: Int,
        historyDates: [Date],
        nextPredictedDate: Date,
        isMuted: Bool = false
    ) {
        self.id = id
        displayName = title
        normalizedName = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        category = .other
        mode = .adaptive
        origin = .discovered
        aliases = []
        sourceCalendarIdentifiers = []
        baseIntervalDays = max(1, baseInterval)
        let initialVariationDays = max(
            2,
            Int((Double(max(1, baseInterval)) * 0.1).rounded(.up))
        )
        variationDays = initialVariationDays
        confidenceScore = 0.5
        confidenceBand = .low
        self.historyDates = historyDates.sorted()
        lastOccurrenceDate = historyDates.max()
        nextExpectedCenterDate = nextPredictedDate
        nextExpectedStartDate = nextPredictedDate.addingTimeInterval(
            TimeInterval(-initialVariationDays * 86_400)
        )
        nextExpectedEndDate = nextPredictedDate.addingTimeInterval(
            TimeInterval(initialVariationDays * 86_400)
        )
        leadTimeDays = 3
        notificationHour = 9
        notificationMinute = 0
        preferredCalendarIdentifier = nil
        defaultEventDurationMinutes = 60
        defaultEventStartHour = nil
        defaultEventStartMinute = nil
        notificationsEnabled = !isMuted
        lifecycleState = isMuted ? .paused : .active
        createdAt = .now
        updatedAt = .now
    }

    init(value: RhythmPattern) {
        id = value.id
        displayName = value.displayName
        normalizedName = value.normalizedName
        category = value.category
        mode = value.mode
        origin = value.origin
        aliases = value.aliases
        sourceCalendarIdentifiers = value.sourceCalendarIdentifiers
        baseIntervalDays = value.baseIntervalDays
        variationDays = value.variationDays
        confidenceScore = value.confidenceScore
        confidenceBand = value.confidenceBand
        historyDates = []
        lastOccurrenceDate = value.lastOccurrenceDate
        nextExpectedStartDate = value.expectedWindow.start
        nextExpectedCenterDate = value.expectedWindow.center
        nextExpectedEndDate = value.expectedWindow.end
        leadTimeDays = value.leadTimeDays
        notificationHour = value.notificationHour
        notificationMinute = value.notificationMinute
        preferredCalendarIdentifier = value.preferredCalendarIdentifier
        defaultEventDurationMinutes = value.defaultEventDurationMinutes
        defaultEventStartHour = value.defaultEventStartHour
        defaultEventStartMinute = value.defaultEventStartMinute
        notificationsEnabled = value.notificationsEnabled
        lifecycleState = value.lifecycleState
        createdAt = value.createdAt
        updatedAt = value.updatedAt
    }
}
