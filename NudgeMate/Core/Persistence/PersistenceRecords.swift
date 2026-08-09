import Foundation
import SwiftData

@Model
final class RhythmOccurrenceRecord {
    @Attribute(.unique) var id: UUID
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

    init(value: RhythmOccurrence) {
        id = value.id
        rhythmID = value.rhythmID
        occurredAt = value.occurredAt
        source = value.source
        status = value.status
        evidenceWeight = value.evidenceWeight
        sourceCalendarIdentifier = value.sourceCalendarIdentifier
        sourceEventIdentifier = value.sourceEventIdentifier
        userConfirmed = value.userConfirmed
        excludedAsOutlier = value.excludedAsOutlier
        createdAt = value.createdAt
        updatedAt = value.updatedAt
    }
}

@Model
final class PatternCandidateRecord {
    @Attribute(.unique) var id: UUID
    var suggestedDisplayName: String
    var normalizedKey: String
    var categorySuggestion: RhythmCategory
    var eventReferencesData: Data
    var sampleCount: Int
    var intervalSamples: [Double]
    var medianIntervalDays: Double
    var variationDays: Int
    var confidenceScore: Double
    var confidenceBand: ConfidenceBand
    var expectedStartDate: Date
    var expectedCenterDate: Date
    var expectedEndDate: Date
    var explanationData: Data
    var decision: CandidateDecision
    var createdAt: Date

    init(value: PatternCandidate, encoder: JSONEncoder = JSONEncoder()) throws {
        id = value.id
        suggestedDisplayName = value.suggestedDisplayName
        normalizedKey = value.normalizedKey
        categorySuggestion = value.categorySuggestion
        eventReferencesData = try encoder.encode(value.eventReferences)
        sampleCount = value.sampleCount
        intervalSamples = value.intervalSamples
        medianIntervalDays = value.medianIntervalDays
        variationDays = value.variationDays
        confidenceScore = value.confidenceScore
        confidenceBand = value.confidenceBand
        expectedStartDate = value.expectedWindow.start
        expectedCenterDate = value.expectedWindow.center
        expectedEndDate = value.expectedWindow.end
        explanationData = try encoder.encode(value.explanation)
        decision = value.decision
        createdAt = value.createdAt
    }

    func domainValue(decoder: JSONDecoder = JSONDecoder()) throws -> PatternCandidate {
        PatternCandidate(
            id: id,
            suggestedDisplayName: suggestedDisplayName,
            normalizedKey: normalizedKey,
            categorySuggestion: categorySuggestion,
            eventReferences: try decoder.decode(
                [CandidateEventReference].self,
                from: eventReferencesData
            ),
            sampleCount: sampleCount,
            intervalSamples: intervalSamples,
            medianIntervalDays: medianIntervalDays,
            variationDays: variationDays,
            confidenceScore: confidenceScore,
            confidenceBand: confidenceBand,
            expectedWindow: DateWindow(
                start: expectedStartDate,
                center: expectedCenterDate,
                end: expectedEndDate
            ),
            explanation: try decoder.decode(
                PredictionExplanation.self,
                from: explanationData
            ),
            decision: decision,
            createdAt: createdAt
        )
    }
}

@Model
final class NudgeInstanceRecord {
    @Attribute(.unique) var id: UUID
    var rhythmID: UUID
    var expectedStartDate: Date
    var expectedCenterDate: Date
    var expectedEndDate: Date
    var scheduledNotificationDate: Date?
    var deliveredDate: Date?
    var state: NudgeState
    var snoozeCount: Int
    var lastAction: NudgeAction?
    var actionTakenAt: Date?
    var linkedCreatedEventIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    init(value: NudgeInstance) {
        id = value.id
        rhythmID = value.rhythmID
        expectedStartDate = value.expectedWindow.start
        expectedCenterDate = value.expectedWindow.center
        expectedEndDate = value.expectedWindow.end
        scheduledNotificationDate = value.scheduledNotificationDate
        deliveredDate = value.deliveredDate
        state = value.state
        snoozeCount = value.snoozeCount
        lastAction = value.lastAction
        actionTakenAt = value.actionTakenAt
        linkedCreatedEventIdentifier = value.linkedCreatedEventIdentifier
        createdAt = value.createdAt
        updatedAt = value.updatedAt
    }
}

@Model
final class PrepCheckInRecord {
    @Attribute(.unique) var id: UUID
    var prepPlanID: UUID
    var askedAt: Date
    var answeredAt: Date?
    var answer: PrepCheckInAnswer
    var remainingDaysAtAnswer: Int?
    var calculatedNextCheckInDate: Date?
    var retryCount: Int
    var source: PrepCheckInSource
    var createdAt: Date

    init(value: PrepCheckIn) {
        id = value.id
        prepPlanID = value.prepPlanID
        askedAt = value.askedAt
        answeredAt = value.answeredAt
        answer = value.answer
        remainingDaysAtAnswer = value.remainingDaysAtAnswer
        calculatedNextCheckInDate = value.calculatedNextCheckInDate
        retryCount = value.retryCount
        source = value.source
        createdAt = value.createdAt
    }
}

@Model
final class UserSettingsRecord {
    @Attribute(.unique) var id: UUID
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

    init(value: UserSettings) {
        id = value.id
        onboardingCompleted = value.onboardingCompleted
        calendarPermissionEducationCompleted = value.calendarPermissionEducationCompleted
        notificationPermissionEducationCompleted = value.notificationPermissionEducationCompleted
        selectedCalendarIdentifiers = value.selectedCalendarIdentifiers
        defaultNotificationHour = value.defaultNotificationHour
        defaultNotificationMinute = value.defaultNotificationMinute
        dailyRecapEnabled = value.dailyRecapEnabled
        dailyRecapHour = value.dailyRecapHour
        dailyRecapMinute = value.dailyRecapMinute
        dailyRecapFrequency = value.dailyRecapFrequency
        privacyNotificationMode = value.privacyNotificationMode
        appearanceTheme = value.appearanceTheme
        preferredLocaleIdentifier = value.preferredLocaleIdentifier
        lastCalendarScanDate = value.lastCalendarScanDate
        calendarScanRangeMonths = value.calendarScanRangeMonths
        createdAt = value.createdAt
        updatedAt = value.updatedAt
    }
}

@Model
final class SuppressedPatternRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var normalizedSignature: String
    var rejectedAt: Date
    var suppressUntil: Date
    var sourceCalendarIdentifiers: [String]
    var reason: SuppressionReason?

    init(value: SuppressedPattern) {
        id = value.id
        normalizedSignature = value.normalizedSignature
        rejectedAt = value.rejectedAt
        suppressUntil = value.suppressUntil
        sourceCalendarIdentifiers = value.sourceCalendarIdentifiers
        reason = value.reason
    }
}

enum PendingIntentKind: String, Codable, Sendable {
    case openScheduler
    case quickAdd
    case rhythmAction
    case prepAction
    case openRecap
}

@Model
final class PendingIntentRecord {
    @Attribute(.unique) var id: UUID
    var kind: PendingIntentKind
    var domainID: UUID?
    var secondaryID: UUID?
    var actionIdentifier: String?
    var createdAt: Date
    var retryCount: Int

    init(
        id: UUID = UUID(),
        kind: PendingIntentKind,
        domainID: UUID? = nil,
        secondaryID: UUID? = nil,
        actionIdentifier: String? = nil,
        createdAt: Date = .now,
        retryCount: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.domainID = domainID
        self.secondaryID = secondaryID
        self.actionIdentifier = actionIdentifier
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
}
