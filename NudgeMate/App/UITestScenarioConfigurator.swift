#if DEBUG
import Foundation
import SwiftData

@MainActor
enum UITestScenarioConfigurator {
    static func configureIfNeeded(modelContainer: ModelContainer) throws {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing") else { return }

        let context = ModelContext(modelContainer)
        try clearContent(in: context)

        if arguments.contains("--ui-testing-onboarding") {
            return
        }

        var settings = try SwiftDataSettingsRepository(context: context).load()
        settings.onboardingCompleted = true
        settings.calendarPermissionEducationCompleted = true
        settings.notificationPermissionEducationCompleted = true
        settings.dailyRecapEnabled = false
        settings.dailyRecapFrequency = .off
        settings.updatedAt = .now
        try SwiftDataSettingsRepository(context: context).save(settings)

        guard arguments.contains("--seed-content") else { return }
        seedRhythms(in: context)
        seedPreps(in: context)
        try context.save()
    }

    private static func clearContent(in context: ModelContext) throws {
        for rhythm in try context.fetch(FetchDescriptor<RecurringEvent>()) {
            context.delete(rhythm)
        }
        for prep in try context.fetch(FetchDescriptor<EventPrep>()) {
            context.delete(prep)
        }
        for settings in try context.fetch(FetchDescriptor<UserSettingsRecord>()) {
            context.delete(settings)
        }
        try context.save()
    }

    private static func seedRhythms(in context: ModelContext) {
        let calendar = Calendar.autoupdatingCurrent
        let samples: [(String, RhythmCategory, Int, Int, Bool)] = [
            ("미용실 예약", .personalCare, 35, 9, false),
            ("차량 점검", .vehicle, 120, 24, false),
            ("반려견 예방접종", .pet, 180, 46, false),
            ("치과 정기검진", .health, 150, 63, true)
        ]

        for sample in samples {
            let lastDate = calendar.date(byAdding: .day, value: -sample.2, to: .now) ?? .now
            let nextDate = calendar.date(byAdding: .day, value: sample.3, to: .now) ?? .now
            let rhythm = RecurringEvent(
                title: sample.0,
                baseInterval: sample.2,
                historyDates: [lastDate],
                nextPredictedDate: nextDate,
                isMuted: sample.4
            )
            rhythm.category = sample.1
            rhythm.lifecycleState = sample.4 ? .paused : .active
            context.insert(rhythm)
        }
    }

    private static func seedPreps(in context: ModelContext) {
        let calendar = Calendar.autoupdatingCurrent
        let samples: [(String, Int, PrepStatus, String)] = [
            ("여름 휴가 준비", 18, .inProgress, "숙소 예약 확인하고 렌터카 비교하기"),
            ("부모님 생신", 7, .notReady, "선물 후보 세 가지 정리하기"),
            ("이사 준비", 32, .notReady, "견적 방문 일정 잡기")
        ]

        for sample in samples {
            let targetDate = calendar.date(byAdding: .day, value: sample.1, to: .now) ?? .now
            let prep = EventPrep(
                title: sample.0,
                targetDate: targetDate,
                status: sample.2,
                nextReminderDate: targetDate
            )
            prep.nextActionNote = sample.3
            context.insert(prep)
        }
    }
}
#endif
