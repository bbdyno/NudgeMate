import Foundation
import Observation
import SwiftData

private typealias L10n = NudgeMateStrings.Localizable

@MainActor
@Observable
final class HomeViewModel {
    private(set) var isLoading = false
    private(set) var calendarAccessDenied = false
    private(set) var errorMessage: String?
    var confirmationMessage: String?

    @ObservationIgnored
    private var hasLoaded = false

    func load(
        modelContext: ModelContext,
        eventKitManager: EventKitManager,
        nudgeManager: NudgeManager,
        force: Bool = false
    ) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        calendarAccessDenied = false
        errorMessage = nil

        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            try await eventKitManager.requestAccess()

            let existingDescriptor = FetchDescriptor<RecurringEvent>()
            let existingEvents = try modelContext.fetch(existingDescriptor)

            if existingEvents.isEmpty {
                let calendarEvents = try await eventKitManager.fetchEventsFromPastYear()
                let recurringEvents = eventKitManager.buildInitialRecurringEvents(
                    from: calendarEvents
                )
                recurringEvents.forEach(modelContext.insert)
                try modelContext.save()
            }

            await schedulePendingNotifications(
                modelContext: modelContext,
                nudgeManager: nudgeManager
            )
        } catch CalendarError.accessDenied, CalendarError.writeOnlyAccess {
            calendarAccessDenied = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retry(
        modelContext: ModelContext,
        eventKitManager: EventKitManager,
        nudgeManager: NudgeManager
    ) async {
        hasLoaded = false
        await load(
            modelContext: modelContext,
            eventKitManager: eventKitManager,
            nudgeManager: nudgeManager,
            force: true
        )
    }

    func scheduleNow(
        event: RecurringEvent,
        modelContext: ModelContext,
        eventKitManager: EventKitManager,
        nudgeManager: NudgeManager
    ) async {
        do {
            let startDate = max(event.nextPredictedDate, nextAvailableHour())
            _ = try await eventKitManager.createCalendarEvent(
                title: event.title,
                startDate: startDate
            )

            event.nextPredictedDate = Calendar.autoupdatingCurrent.date(
                byAdding: .day,
                value: event.baseInterval,
                to: startDate
            ) ?? startDate.addingTimeInterval(TimeInterval(event.baseInterval * 86_400))
            try modelContext.save()
            try? await nudgeManager.scheduleNudge(for: event)

            confirmationMessage = L10n.Home.calendarAdded(event.title)
        } catch CalendarError.accessDenied, CalendarError.writeOnlyAccess {
            calendarAccessDenied = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearMessages() {
        errorMessage = nil
        confirmationMessage = nil
    }

    private func schedulePendingNotifications(
        modelContext: ModelContext,
        nudgeManager: NudgeManager
    ) async {
        do {
            try await nudgeManager.requestAuthorization()
        } catch {
            // Calendar-based nudges remain usable in-app when notification permission is off.
            return
        }

        let events = (try? modelContext.fetch(FetchDescriptor<RecurringEvent>())) ?? []
        for event in events where !event.isMuted {
            try? await nudgeManager.scheduleNudge(for: event)
        }

        let preps = (try? modelContext.fetch(FetchDescriptor<EventPrep>())) ?? []
        for prep in preps where prep.status != .ready && prep.targetDate > .now {
            try? await nudgeManager.schedulePrepReminder(for: prep)
        }
    }

    private func nextAvailableHour(from date: Date = .now) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let startOfHour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: startOfHour)
            ?? date.addingTimeInterval(3_600)
    }
}
