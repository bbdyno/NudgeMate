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
            await eventKitManager.refreshAuthorizationState()
            guard eventKitManager.authorizationState == .fullAccess else {
                return
            }
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

    func clearMessages() {
        errorMessage = nil
        confirmationMessage = nil
    }

    private func schedulePendingNotifications(
        modelContext: ModelContext,
        nudgeManager: NudgeManager
    ) async {
        guard await nudgeManager.refreshAuthorizationState() == .authorized else {
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
}
