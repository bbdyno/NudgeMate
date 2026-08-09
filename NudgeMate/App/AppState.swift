import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    let eventKitManager: EventKitManager
    let nudgeManager: NudgeManager
    let subscriptionManager: SubscriptionManager

    var isDailyRecapPresented = false
    var isPaywallPresented = false
    private(set) var isBootstrapped = false
    private(set) var onboardingCompleted = false
    private(set) var selectedCalendarIdentifiers = Set<String>()
    var appErrorMessage: String?

    @ObservationIgnored
    private let calendar: Calendar

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private let lastRecapDateKey = "NudgeMate.lastDailyRecapDate"

    init(
        calendar: Calendar = .autoupdatingCurrent,
        defaults: UserDefaults = .standard
    ) {
        eventKitManager = EventKitManager()
        nudgeManager = NudgeManager()
        subscriptionManager = .shared
        self.calendar = calendar
        self.defaults = defaults
    }

    init(
        eventKitManager: EventKitManager,
        nudgeManager: NudgeManager,
        subscriptionManager: SubscriptionManager,
        calendar: Calendar = .autoupdatingCurrent,
        defaults: UserDefaults = .standard
    ) {
        self.eventKitManager = eventKitManager
        self.nudgeManager = nudgeManager
        self.subscriptionManager = subscriptionManager
        self.calendar = calendar
        self.defaults = defaults
    }

    func configure(modelContainer: ModelContainer) {
        nudgeManager.configure(modelContainer: modelContainer)
        NotificationActionRouter.shared.configure(
            modelContainer: modelContainer,
            nudgeManager: nudgeManager
        )
    }

    func bootstrap(modelContext: ModelContext) {
        guard !isBootstrapped else { return }
        do {
            let settings = try SwiftDataSettingsRepository(context: modelContext).load()
            onboardingCompleted = settings.onboardingCompleted
            selectedCalendarIdentifiers = Set(settings.selectedCalendarIdentifiers)
            isBootstrapped = true
        } catch {
            appErrorMessage = error.localizedDescription
            isBootstrapped = true
        }
    }

    func finishOnboarding(
        selectedCalendarIdentifiers: Set<String>,
        modelContext: ModelContext
    ) throws {
        let repository = SwiftDataSettingsRepository(context: modelContext)
        var settings = try repository.load()
        settings.onboardingCompleted = true
        settings.calendarPermissionEducationCompleted = true
        settings.selectedCalendarIdentifiers = selectedCalendarIdentifiers.sorted()
        settings.lastCalendarScanDate = selectedCalendarIdentifiers.isEmpty ? nil : .now
        settings.updatedAt = .now
        try repository.save(settings)
        self.selectedCalendarIdentifiers = selectedCalendarIdentifiers
        onboardingCompleted = true
    }

    func evaluateDailyRecapPresentation(at date: Date = .now) {
        guard calendar.component(.hour, from: date) >= 22 else { return }

        if let lastDate = defaults.object(forKey: lastRecapDateKey) as? Date,
           calendar.isDate(lastDate, inSameDayAs: date) {
            return
        }

        defaults.set(date, forKey: lastRecapDateKey)
        isDailyRecapPresented = true
    }

    func runDailyRecapClock() async {
        evaluateDailyRecapPresentation()

        while !Task.isCancelled {
            let now = Date.now
            let nextRecapDate = nextTenPM(after: now)
            let waitDuration = max(1, nextRecapDate.timeIntervalSince(now))

            do {
                try await Task.sleep(for: .seconds(waitDuration))
            } catch {
                return
            }

            evaluateDailyRecapPresentation()
        }
    }

    func dismissDailyRecap() {
        isDailyRecapPresented = false
    }

    func presentPaywall() {
        isPaywallPresented = true
    }

    private func nextTenPM(after date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 22
        components.minute = 0
        components.second = 0

        let todayAtTen = calendar.date(from: components) ?? date.addingTimeInterval(60)
        if todayAtTen > date {
            return todayAtTen
        }

        return calendar.date(byAdding: .day, value: 1, to: todayAtTen)
            ?? date.addingTimeInterval(86_400)
    }
}
