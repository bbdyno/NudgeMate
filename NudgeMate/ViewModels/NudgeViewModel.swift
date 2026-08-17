import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class NudgeViewModel {
    private(set) var errorMessage: String?

    func snooze(
        _ event: RecurringEvent,
        modelContext: ModelContext,
        nudgeManager: NudgeManager
    ) async {
        do {
            try await nudgeManager.snooze(event, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skip(
        _ event: RecurringEvent,
        modelContext: ModelContext,
        nudgeManager: NudgeManager
    ) async {
        do {
            try await nudgeManager.skip(event, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMuted(
        _ event: RecurringEvent,
        modelContext: ModelContext,
        nudgeManager: NudgeManager
    ) async {
        let wasMuted = event.isMuted
        event.isMuted.toggle()

        do {
            try modelContext.save()
            if event.isMuted {
                nudgeManager.cancelNudge(for: event.id)
            } else {
                try await nudgeManager.scheduleNudge(for: event)
            }
        } catch {
            event.isMuted = wasMuted
            errorMessage = error.localizedDescription
        }
    }

    func delete(
        _ event: RecurringEvent,
        modelContext: ModelContext,
        nudgeManager: NudgeManager
    ) {
        let eventID = event.id
        do {
            try RhythmDeletionService().delete([event], in: modelContext)
            nudgeManager.cancelNudge(for: eventID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
