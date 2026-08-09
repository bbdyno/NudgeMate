import Foundation

struct DateWindow: Codable, Hashable, Sendable {
    var start: Date
    var center: Date
    var end: Date
}

enum RhythmMode: String, Codable, CaseIterable, Sendable {
    case fixed
    case adaptive
}

enum RhythmOrigin: String, Codable, CaseIterable, Sendable {
    case manual
    case discovered
}

enum RhythmLifecycleState: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case archived
    case needsReview
    case pausedPremiumOverflow
}

enum RhythmCategory: String, Codable, CaseIterable, Sendable {
    case personalCare
    case health
    case vehicle
    case home
    case pet
    case finance
    case work
    case other
}

enum ConfidenceBand: String, Codable, CaseIterable, Sendable {
    case high
    case medium
    case low
}

struct RhythmPattern: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
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
    var lastOccurrenceDate: Date?
    var expectedWindow: DateWindow
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
}

enum OccurrenceSource: String, Codable, CaseIterable, Sendable {
    case calendarObserved
    case userConfirmed
    case manual
    case notificationAction
    case dailyRecap
    case scheduledCalendarEvent
}

enum OccurrenceStatus: String, Codable, CaseIterable, Sendable {
    case observed
    case scheduled
    case completed
    case skippedOnce
    case invalid
    case removed
}

struct RhythmOccurrence: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var rhythmID: UUID
    var occurredAt: Date
    var source: OccurrenceSource
    var status: OccurrenceStatus
    var evidenceWeight: Double
    var sourceCalendarIdentifier: String?
    var sourceEventIdentifier: String?
    var userConfirmed: Bool
    var excludedAsOutlier: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum CandidateDecision: String, Codable, CaseIterable, Sendable {
    case pending
    case accepted
    case rejected
    case snoozed
    case modified
}

struct CandidateEventReference: Codable, Hashable, Sendable {
    var eventIdentifier: String
    var calendarIdentifier: String
    var originalTitle: String
    var occurredAt: Date
    var isIncluded: Bool
}

struct PredictionExplanation: Codable, Hashable, Sendable {
    var summary: String
    var sampleCount: Int
    var validSampleCount: Int
    var excludedOutlierCount: Int
    var medianIntervalDays: Double
    var expectedWindow: DateWindow
    var detailLines: [String]
}

struct PatternCandidate: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var suggestedDisplayName: String
    var normalizedKey: String
    var categorySuggestion: RhythmCategory
    var eventReferences: [CandidateEventReference]
    var sampleCount: Int
    var intervalSamples: [Double]
    var medianIntervalDays: Double
    var variationDays: Int
    var confidenceScore: Double
    var confidenceBand: ConfidenceBand
    var expectedWindow: DateWindow
    var explanation: PredictionExplanation
    var decision: CandidateDecision
    var createdAt: Date
}

enum NudgeState: String, Codable, CaseIterable, Sendable {
    case planned
    case scheduled
    case due
    case snoozed
    case acted
    case expired
    case cancelled
}

enum NudgeAction: String, Codable, CaseIterable, Sendable {
    case addEvent
    case openScheduler
    case snoozeThreeDays
    case snoozeOneWeek
    case snoozeTwoWeeks
    case chooseDate
    case skipOnce
    case predictionIncorrect
    case stopRhythm
    case markCompleted
}

struct NudgeInstance: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var rhythmID: UUID
    var expectedWindow: DateWindow
    var scheduledNotificationDate: Date?
    var deliveredDate: Date?
    var state: NudgeState
    var snoozeCount: Int
    var lastAction: NudgeAction?
    var actionTakenAt: Date?
    var linkedCreatedEventIdentifier: String?
    var createdAt: Date
    var updatedAt: Date
}

enum PrepReadinessStatus: String, Codable, CaseIterable, Sendable {
    case notReady
    case inProgress
    case ready
}

enum PrepIntensity: String, Codable, CaseIterable, Sendable {
    case low
    case normal
    case high
}

enum PrepPlanState: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case ready
    case targetPassed
    case archived
    case cancelled
    case pausedPremiumOverflow
}

struct PrepPlan: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var targetDate: Date
    var linkedCalendarIdentifier: String?
    var linkedEventIdentifier: String?
    var readinessStatus: PrepReadinessStatus
    var intensity: PrepIntensity
    var nextActionNote: String
    var nextCheckInDate: Date?
    var notificationsEnabled: Bool
    var preferredNotificationHour: Int
    var preferredNotificationMinute: Int
    var planState: PrepPlanState
    var lastAnsweredAt: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
}

enum PrepCheckInAnswer: String, Codable, CaseIterable, Sendable {
    case notReady
    case inProgress
    case ready
    case planChanged
    case noResponse
}

enum PrepCheckInSource: String, Codable, CaseIterable, Sendable {
    case app
    case notification
    case dailyRecap
}

struct PrepCheckIn: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var prepPlanID: UUID
    var askedAt: Date
    var answeredAt: Date?
    var answer: PrepCheckInAnswer
    var remainingDaysAtAnswer: Int?
    var calculatedNextCheckInDate: Date?
    var retryCount: Int
    var source: PrepCheckInSource
    var createdAt: Date
}

enum PrivacyNotificationMode: String, Codable, CaseIterable, Sendable {
    case detailed
    case generic
}

enum DailyRecapFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case threeTimesWeekly
    case weekly
    case off
}

enum AppearanceTheme: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
    case pro
}

struct UserSettings: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var onboardingCompleted: Bool
    var calendarPermissionEducationCompleted: Bool
    var notificationPermissionEducationCompleted: Bool
    var selectedCalendarIdentifiers: [String]
    var defaultNotificationHour: Int
    var defaultNotificationMinute: Int
    var dailyRecapEnabled: Bool
    var dailyRecapHour: Int
    var dailyRecapMinute: Int
    var dailyRecapFrequency: DailyRecapFrequency
    var privacyNotificationMode: PrivacyNotificationMode
    var appearanceTheme: AppearanceTheme
    var preferredLocaleIdentifier: String?
    var lastCalendarScanDate: Date?
    var calendarScanRangeMonths: Int
    var createdAt: Date
    var updatedAt: Date
}

enum SuppressionReason: String, Codable, CaseIterable, Sendable {
    case unrelatedEvents
    case nonRecurring
    case workEvent
    case notInterested
}

struct SuppressedPattern: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var normalizedSignature: String
    var rejectedAt: Date
    var suppressUntil: Date
    var sourceCalendarIdentifiers: [String]
    var reason: SuppressionReason?
}
