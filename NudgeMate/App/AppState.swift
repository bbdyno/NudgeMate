import Foundation
import Observation
import SwiftData

enum AppNavigationDestination: Equatable {
    case today
    case rhythm(UUID?)
    case scheduleRhythm(UUID?)
    case prep(UUID?)
    case recap
}

@MainActor
@Observable
final class AppState {
    let eventKitManager: EventKitManager
    let nudgeManager: NudgeManager
    let subscriptionManager: SubscriptionManager

    var isDailyRecapPresented = false
    var isPaywallPresented = false
    var pendingNavigation: AppNavigationDestination?
    private(set) var isBootstrapped = false
    private(set) var onboardingCompleted = false
    private(set) var selectedCalendarIdentifiers = Set<String>()
    private(set) var appearanceTheme: AppearanceTheme = .system
    private(set) var dailyRecapEnabled = true
    private(set) var dailyRecapHour = 22
    private(set) var dailyRecapMinute = 0
    private(set) var dailyRecapFrequency: DailyRecapFrequency = .daily
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
            nudgeManager: nudgeManager,
            navigationHandler: { [weak self] destination in
                self?.navigate(to: destination)
            }
        )
    }

    func bootstrap(modelContext: ModelContext) {
        guard !isBootstrapped else { return }
        do {
            let settings = try SwiftDataSettingsRepository(context: modelContext).load()
            onboardingCompleted = settings.onboardingCompleted
            selectedCalendarIdentifiers = Set(settings.selectedCalendarIdentifiers)
            appearanceTheme = settings.appearanceTheme
            applyRecapSettings(settings)
            isBootstrapped = true
            configureUITestPresentation()
            Task { await nudgeManager.reconcileAll(settings: settings) }
        } catch {
            appErrorMessage = error.localizedDescription
            isBootstrapped = true
            configureUITestPresentation()
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

    func updateSettings(_ settings: UserSettings) {
        selectedCalendarIdentifiers = Set(settings.selectedCalendarIdentifiers)
        appearanceTheme = settings.appearanceTheme
        applyRecapSettings(settings)
        Task { await nudgeManager.reconcileAll(settings: settings) }
    }

    func resetAfterDataDeletion() {
        selectedCalendarIdentifiers = []
        appearanceTheme = .system
        onboardingCompleted = false
        isBootstrapped = false
        isDailyRecapPresented = false
        pendingNavigation = nil
    }

    func evaluateDailyRecapPresentation(at date: Date = .now) {
        guard dailyRecapEnabled,
              dailyRecapFrequency != .off,
              isRecapDay(date),
              isAtOrAfterRecapTime(date) else { return }

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
            let nextRecapDate = nextRecapDate(after: now)
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

    func navigate(to destination: AppNavigationDestination) {
        pendingNavigation = destination
    }

    func consumeNavigation(_ destination: AppNavigationDestination) {
        guard pendingNavigation == destination else { return }
        pendingNavigation = nil
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "nudgemate" else { return }
        let id = url.pathComponents
            .dropFirst()
            .first
            .flatMap(UUID.init(uuidString:))
        switch url.host?.lowercased() {
        case "rhythm": navigate(to: .rhythm(id))
        case "prep": navigate(to: .prep(id))
        case "recap": navigate(to: .recap)
        case "today": navigate(to: .today)
        default: break
        }
    }

    private func nextRecapDate(after date: Date) -> Date {
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = dailyRecapHour
            components.minute = dailyRecapMinute
            components.second = 0
            guard let candidate = calendar.date(from: components),
                  candidate > date,
                  isRecapDay(candidate) else { continue }
            return candidate
        }
        return date.addingTimeInterval(86_400)
    }

    private func applyRecapSettings(_ settings: UserSettings) {
        dailyRecapEnabled = settings.dailyRecapEnabled
        dailyRecapHour = settings.dailyRecapHour
        dailyRecapMinute = settings.dailyRecapMinute
        dailyRecapFrequency = settings.dailyRecapFrequency
    }

    private func isAtOrAfterRecapTime(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour > dailyRecapHour || (hour == dailyRecapHour && minute >= dailyRecapMinute)
    }

    private func isRecapDay(_ date: Date) -> Bool {
        switch dailyRecapFrequency {
        case .daily: true
        case .threeTimesWeekly: [2, 4, 6].contains(calendar.component(.weekday, from: date))
        case .weekly: calendar.component(.weekday, from: date) == 1
        case .off: false
        }
    }

    private func configureUITestPresentation() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--open-paywall") {
            isPaywallPresented = true
        } else if arguments.contains("--open-recap") {
            pendingNavigation = .recap
        }
#endif
    }
}
