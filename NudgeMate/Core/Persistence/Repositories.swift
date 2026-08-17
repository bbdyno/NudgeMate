import Foundation
import SwiftData

@MainActor
protocol RhythmRepository {
    func fetchAll() throws -> [RhythmPattern]
    func fetch(id: UUID) throws -> RhythmPattern?
    func upsert(_ rhythm: RhythmPattern) throws
    func delete(id: UUID) throws
}

@MainActor
protocol PrepRepository {
    func fetchAll() throws -> [PrepPlan]
    func fetch(id: UUID) throws -> PrepPlan?
    func upsert(_ prep: PrepPlan) throws
    func delete(id: UUID) throws
}

@MainActor
protocol SettingsRepository {
    func load() throws -> UserSettings
    func save(_ settings: UserSettings) throws
}

@MainActor
struct RhythmDeletionService {
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func delete(_ rhythms: [RecurringEvent], in context: ModelContext, now: Date = .now) throws {
        guard !rhythms.isEmpty else { return }

        let rhythmIDs = Set(rhythms.map(\.id))
        let normalizer = EventNormalizer()
        let signatures = Set(
            rhythms
                .filter { $0.origin == .discovered }
                .flatMap { [$0.normalizedName, normalizer.normalize($0.displayName)] }
                .filter { !$0.isEmpty }
        )

        do {
            let occurrences = try context.fetch(FetchDescriptor<RhythmOccurrenceRecord>())
            occurrences
                .filter { rhythmIDs.contains($0.rhythmID) }
                .forEach(context.delete)

            let instances = try context.fetch(FetchDescriptor<NudgeInstanceRecord>())
            instances
                .filter { rhythmIDs.contains($0.rhythmID) }
                .forEach(context.delete)

            if !signatures.isEmpty {
                let candidates = try context.fetch(FetchDescriptor<PatternCandidateRecord>())
                candidates
                    .filter { signatures.contains($0.normalizedKey) }
                    .forEach(context.delete)

                let suppressUntil = calendar.date(byAdding: .year, value: 100, to: now)
                    ?? now.addingTimeInterval(3_155_760_000)
                let existingSuppressions = try context.fetch(
                    FetchDescriptor<SuppressedPatternRecord>()
                )

                for signature in signatures {
                    let calendarIDs = Array(
                        Set(
                            rhythms
                                .filter {
                                    $0.normalizedName == signature
                                        || normalizer.normalize($0.displayName) == signature
                                }
                                .flatMap(\.sourceCalendarIdentifiers)
                        )
                    ).sorted()

                    if let suppression = existingSuppressions.first(where: {
                        $0.normalizedSignature == signature
                    }) {
                        suppression.rejectedAt = now
                        suppression.suppressUntil = max(suppression.suppressUntil, suppressUntil)
                        suppression.sourceCalendarIdentifiers = calendarIDs
                        suppression.reason = .notInterested
                    } else {
                        context.insert(
                            SuppressedPatternRecord(
                                value: SuppressedPattern(
                                    id: UUID(),
                                    normalizedSignature: signature,
                                    rejectedAt: now,
                                    suppressUntil: suppressUntil,
                                    sourceCalendarIdentifiers: calendarIDs,
                                    reason: .notInterested
                                )
                            )
                        )
                    }
                }
            }

            rhythms.forEach(context.delete)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

@MainActor
struct PrepDeletionService {
    func delete(_ preps: [EventPrep], in context: ModelContext) throws {
        guard !preps.isEmpty else { return }
        let prepIDs = Set(preps.map(\.id))

        do {
            let checkIns = try context.fetch(FetchDescriptor<PrepCheckInRecord>())
            checkIns
                .filter { prepIDs.contains($0.prepPlanID) }
                .forEach(context.delete)
            preps.forEach(context.delete)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

@MainActor
final class SwiftDataRhythmRepository: RhythmRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [RhythmPattern] {
        let descriptor = FetchDescriptor<RecurringEvent>(
            sortBy: [SortDescriptor(\.nextExpectedCenterDate)]
        )
        return try context.fetch(descriptor).map(\.domainValue)
    }

    func fetch(id: UUID) throws -> RhythmPattern? {
        let rhythmID = id
        let descriptor = FetchDescriptor<RecurringEvent>(
            predicate: #Predicate { $0.id == rhythmID }
        )
        return try context.fetch(descriptor).first?.domainValue
    }

    func upsert(_ rhythm: RhythmPattern) throws {
        if let record = try fetchRecord(id: rhythm.id) {
            record.update(with: rhythm)
        } else {
            context.insert(RecurringEvent(value: rhythm))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let record = try fetchRecord(id: id) else { return }
        context.delete(record)
        try context.save()
    }

    private func fetchRecord(id: UUID) throws -> RecurringEvent? {
        let rhythmID = id
        return try context.fetch(
            FetchDescriptor<RecurringEvent>(
                predicate: #Predicate { $0.id == rhythmID }
            )
        ).first
    }
}

@MainActor
final class SwiftDataPrepRepository: PrepRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [PrepPlan] {
        let descriptor = FetchDescriptor<EventPrep>(
            sortBy: [SortDescriptor(\.targetDate)]
        )
        return try context.fetch(descriptor).map(\.domainValue)
    }

    func fetch(id: UUID) throws -> PrepPlan? {
        try fetchRecord(id: id)?.domainValue
    }

    func upsert(_ prep: PrepPlan) throws {
        if let record = try fetchRecord(id: prep.id) {
            record.update(with: prep)
        } else {
            context.insert(EventPrep(value: prep))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let record = try fetchRecord(id: id) else { return }
        context.delete(record)
        try context.save()
    }

    private func fetchRecord(id: UUID) throws -> EventPrep? {
        let prepID = id
        return try context.fetch(
            FetchDescriptor<EventPrep>(
                predicate: #Predicate { $0.id == prepID }
            )
        ).first
    }
}

@MainActor
final class SwiftDataSettingsRepository: SettingsRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load() throws -> UserSettings {
        if let record = try context.fetch(FetchDescriptor<UserSettingsRecord>()).first {
            return record.domainValue
        }

        let now = Date.now
        let settings = UserSettings(
            id: UUID(),
            onboardingCompleted: false,
            calendarPermissionEducationCompleted: false,
            notificationPermissionEducationCompleted: false,
            selectedCalendarIdentifiers: [],
            defaultNotificationHour: 9,
            defaultNotificationMinute: 0,
            dailyRecapEnabled: true,
            dailyRecapHour: 22,
            dailyRecapMinute: 0,
            dailyRecapFrequency: .daily,
            privacyNotificationMode: .detailed,
            appearanceTheme: .system,
            preferredLocaleIdentifier: nil,
            lastCalendarScanDate: nil,
            calendarScanRangeMonths: 12,
            createdAt: now,
            updatedAt: now
        )
        context.insert(UserSettingsRecord(value: settings))
        try context.save()
        return settings
    }

    func save(_ settings: UserSettings) throws {
        if let record = try context.fetch(FetchDescriptor<UserSettingsRecord>()).first {
            record.update(with: settings)
        } else {
            context.insert(UserSettingsRecord(value: settings))
        }
        try context.save()
    }
}

private extension RecurringEvent {
    var domainValue: RhythmPattern {
        RhythmPattern(
            id: id,
            displayName: displayName,
            normalizedName: normalizedName,
            category: category,
            mode: mode,
            origin: origin,
            aliases: aliases,
            sourceCalendarIdentifiers: sourceCalendarIdentifiers,
            baseIntervalDays: baseIntervalDays,
            variationDays: variationDays,
            confidenceScore: confidenceScore,
            confidenceBand: confidenceBand,
            lastOccurrenceDate: lastOccurrenceDate,
            expectedWindow: DateWindow(
                start: nextExpectedStartDate,
                center: nextExpectedCenterDate,
                end: nextExpectedEndDate
            ),
            leadTimeDays: leadTimeDays,
            notificationHour: notificationHour,
            notificationMinute: notificationMinute,
            preferredCalendarIdentifier: preferredCalendarIdentifier,
            defaultEventDurationMinutes: defaultEventDurationMinutes,
            defaultEventStartHour: defaultEventStartHour,
            defaultEventStartMinute: defaultEventStartMinute,
            notificationsEnabled: notificationsEnabled,
            lifecycleState: lifecycleState,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(with value: RhythmPattern) {
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
        updatedAt = value.updatedAt
    }
}

private extension EventPrep {
    var domainValue: PrepPlan {
        PrepPlan(
            id: id,
            title: title,
            targetDate: targetDate,
            linkedCalendarIdentifier: linkedCalendarIdentifier,
            linkedEventIdentifier: linkedEventIdentifier,
            readinessStatus: status.readinessStatus,
            intensity: intensity,
            nextActionNote: nextActionNote,
            nextCheckInDate: nextReminderDate,
            notificationsEnabled: notificationsEnabled,
            preferredNotificationHour: preferredNotificationHour,
            preferredNotificationMinute: preferredNotificationMinute,
            planState: planState,
            lastAnsweredAt: lastAnsweredAt,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(with value: PrepPlan) {
        title = value.title
        targetDate = value.targetDate
        linkedCalendarIdentifier = value.linkedCalendarIdentifier
        linkedEventIdentifier = value.linkedEventIdentifier
        status = PrepStatus(value.readinessStatus)
        intensity = value.intensity
        nextActionNote = value.nextActionNote
        nextReminderDate = value.nextCheckInDate ?? value.targetDate
        notificationsEnabled = value.notificationsEnabled
        preferredNotificationHour = value.preferredNotificationHour
        preferredNotificationMinute = value.preferredNotificationMinute
        planState = value.planState
        lastAnsweredAt = value.lastAnsweredAt
        completedAt = value.completedAt
        updatedAt = value.updatedAt
    }
}

private extension UserSettingsRecord {
    var domainValue: UserSettings {
        UserSettings(
            id: id,
            onboardingCompleted: onboardingCompleted,
            calendarPermissionEducationCompleted: calendarPermissionEducationCompleted,
            notificationPermissionEducationCompleted: notificationPermissionEducationCompleted,
            selectedCalendarIdentifiers: selectedCalendarIdentifiers,
            defaultNotificationHour: defaultNotificationHour,
            defaultNotificationMinute: defaultNotificationMinute,
            dailyRecapEnabled: dailyRecapEnabled,
            dailyRecapHour: dailyRecapHour,
            dailyRecapMinute: dailyRecapMinute,
            dailyRecapFrequency: dailyRecapFrequency,
            privacyNotificationMode: privacyNotificationMode,
            appearanceTheme: appearanceTheme,
            preferredLocaleIdentifier: preferredLocaleIdentifier,
            lastCalendarScanDate: lastCalendarScanDate,
            calendarScanRangeMonths: calendarScanRangeMonths,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(with value: UserSettings) {
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
        updatedAt = value.updatedAt
    }
}
