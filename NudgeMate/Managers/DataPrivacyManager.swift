import Foundation
import SwiftData

struct NudgeMateDataExport: Codable {
    var formatVersion: Int
    var exportedAt: Date
    var rhythms: [ExportedRhythm]
    var preparations: [ExportedPreparation]
    var settings: ExportedSettings?
    var suppressedPatterns: [ExportedSuppression]
}

struct ExportedRhythm: Codable {
    var id: UUID
    var name: String
    var category: String
    var mode: String
    var origin: String
    var intervalDays: Int
    var variationDays: Int
    var confidence: Double
    var historyDates: [Date]
    var nextWindow: DateWindow
    var notificationsEnabled: Bool
    var lifecycleState: String
}

struct ExportedPreparation: Codable {
    var id: UUID
    var title: String
    var targetDate: Date
    var status: String
    var intensity: String
    var nextActionNote: String
    var nextReminderDate: Date
    var notificationsEnabled: Bool
    var planState: String
}

struct ExportedSettings: Codable {
    var selectedCalendarIdentifiers: [String]
    var dailyRecapEnabled: Bool
    var dailyRecapHour: Int
    var dailyRecapMinute: Int
    var dailyRecapFrequency: String
    var privacyNotificationMode: String
    var appearanceTheme: String
}

struct ExportedSuppression: Codable {
    var signature: String
    var rejectedAt: Date
    var suppressUntil: Date
    var reason: String?
}

@MainActor
struct DataPrivacyManager {
    func makeExportFile(modelContext: ModelContext) throws -> URL {
        let rhythms = try modelContext.fetch(FetchDescriptor<RecurringEvent>())
        let preparations = try modelContext.fetch(FetchDescriptor<EventPrep>())
        let settings = try modelContext.fetch(FetchDescriptor<UserSettingsRecord>()).first
        let suppressions = try modelContext.fetch(FetchDescriptor<SuppressedPatternRecord>())

        let payload = NudgeMateDataExport(
            formatVersion: 1,
            exportedAt: .now,
            rhythms: rhythms.map {
                ExportedRhythm(
                    id: $0.id,
                    name: $0.displayName,
                    category: $0.category.rawValue,
                    mode: $0.mode.rawValue,
                    origin: $0.origin.rawValue,
                    intervalDays: $0.baseIntervalDays,
                    variationDays: $0.variationDays,
                    confidence: $0.confidenceScore,
                    historyDates: $0.historyDates,
                    nextWindow: DateWindow(
                        start: $0.nextExpectedStartDate,
                        center: $0.nextExpectedCenterDate,
                        end: $0.nextExpectedEndDate
                    ),
                    notificationsEnabled: $0.notificationsEnabled,
                    lifecycleState: $0.lifecycleState.rawValue
                )
            },
            preparations: preparations.map {
                ExportedPreparation(
                    id: $0.id,
                    title: $0.title,
                    targetDate: $0.targetDate,
                    status: $0.status.rawValue,
                    intensity: $0.intensity.rawValue,
                    nextActionNote: $0.nextActionNote,
                    nextReminderDate: $0.nextReminderDate,
                    notificationsEnabled: $0.notificationsEnabled,
                    planState: $0.planState.rawValue
                )
            },
            settings: settings.map {
                ExportedSettings(
                    selectedCalendarIdentifiers: $0.selectedCalendarIdentifiers,
                    dailyRecapEnabled: $0.dailyRecapEnabled,
                    dailyRecapHour: $0.dailyRecapHour,
                    dailyRecapMinute: $0.dailyRecapMinute,
                    dailyRecapFrequency: $0.dailyRecapFrequency.rawValue,
                    privacyNotificationMode: $0.privacyNotificationMode.rawValue,
                    appearanceTheme: $0.appearanceTheme.rawValue
                )
            },
            suppressedPatterns: suppressions.map {
                ExportedSuppression(
                    signature: $0.normalizedSignature,
                    rejectedAt: $0.rejectedAt,
                    suppressUntil: $0.suppressUntil,
                    reason: $0.reason?.rawValue
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NudgeMate-\(formatter.string(from: .now)).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    func deleteAllData(modelContext: ModelContext) throws {
        try deleteAll(RecurringEvent.self, context: modelContext)
        try deleteAll(EventPrep.self, context: modelContext)
        try deleteAll(RhythmOccurrenceRecord.self, context: modelContext)
        try deleteAll(PatternCandidateRecord.self, context: modelContext)
        try deleteAll(NudgeInstanceRecord.self, context: modelContext)
        try deleteAll(PrepCheckInRecord.self, context: modelContext)
        try deleteAll(UserSettingsRecord.self, context: modelContext)
        try deleteAll(SuppressedPatternRecord.self, context: modelContext)
        try deleteAll(PendingIntentRecord.self, context: modelContext)
        try modelContext.save()
    }

    private func deleteAll<T: PersistentModel>(
        _ type: T.Type,
        context: ModelContext
    ) throws {
        let values = try context.fetch(FetchDescriptor<T>())
        values.forEach(context.delete)
    }
}
