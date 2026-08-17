import Foundation
import Observation
import SwiftData

struct HomeDashboardSnapshot: Equatable {
    enum Item: Equatable {
        case prep(UUID)
        case rhythm(UUID)
    }

    let prepIDs: [UUID]
    let rhythmIDs: [UUID]
    let rhythmPreviewIDs: [UUID]
    let priority: Item?

    var itemCount: Int {
        prepIDs.count + rhythmIDs.count
    }

    init(
        rhythms: [RecurringEvent],
        preps: [EventPrep],
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        rhythmPreviewLimit: Int = 2
    ) {
        let startOfToday = calendar.startOfDay(for: now)
        let activePreps = preps
            .filter {
                $0.planState == .active
                    && $0.status != .ready
                    && $0.targetDate >= startOfToday
            }
            .sorted {
                if $0.targetDate == $1.targetDate {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.targetDate < $1.targetDate
            }
        let activeRhythms = rhythms
            .filter { !$0.isMuted }
            .sorted {
                if $0.nextExpectedCenterDate == $1.nextExpectedCenterDate {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.nextExpectedCenterDate < $1.nextExpectedCenterDate
            }

        prepIDs = activePreps.map(\.id)
        rhythmIDs = activeRhythms.map(\.id)
        rhythmPreviewIDs = Array(activeRhythms.prefix(max(0, rhythmPreviewLimit))).map(\.id)

        let prepPriorities = activePreps.map {
            ($0.targetDate, 0, $0.id, Item.prep($0.id))
        }
        let rhythmPriorities = activeRhythms.map {
            ($0.nextExpectedCenterDate, 1, $0.id, Item.rhythm($0.id))
        }
        priority = (prepPriorities + rhythmPriorities)
            .sorted {
                if $0.0 == $1.0 {
                    if $0.1 == $1.1 {
                        return $0.2.uuidString < $1.2.uuidString
                    }
                    return $0.1 < $1.1
                }
                return $0.0 < $1.0
            }
            .first?.3
    }
}

@MainActor
@Observable
final class HomeViewModel {
    private(set) var isLoading = false
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
        errorMessage = nil

        defer {
            isLoading = false
            hasLoaded = true
        }

        // Calendar discovery is an explicit review flow. Home must never recreate a
        // rhythm the user paused or deleted just because the rhythm table is empty.
        await schedulePendingNotifications(
            modelContext: modelContext,
            nudgeManager: nudgeManager
        )
        await eventKitManager.refreshAuthorizationState()
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
