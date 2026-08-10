import ActivityKit
import Foundation
import SwiftData
import WidgetKit

@MainActor
final class WidgetActivityCoordinator {
    static let shared = WidgetActivityCoordinator()

    private var modelContainer: ModelContainer?

    private init() {}

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func synchronize(
        modelContext: ModelContext? = nil,
        startLiveActivityFor prepID: UUID? = nil,
        now: Date = .now
    ) async throws {
        guard let context = modelContext ?? modelContainer.map(ModelContext.init) else { return }
        let preps = try context.fetch(
            FetchDescriptor<EventPrep>(sortBy: [SortDescriptor(\.targetDate)])
        )
        let showsDetails = (try? context.fetch(FetchDescriptor<UserSettingsRecord>()).first)
            .map { $0.privacyNotificationMode == .detailed }
            ?? true
        publishWidgetSnapshot(preps: preps, showsDetails: showsDetails, now: now)
        try await reconcileLiveActivities(
            preps: preps,
            startLiveActivityFor: prepID,
            showsDetails: showsDetails,
            now: now
        )
    }

    func clear() async {
        PrepWidgetSnapshotStore.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: NudgeMateSharedConfiguration.widgetKind)
        for activity in Activity<PrepActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func publishWidgetSnapshot(
        preps: [EventPrep],
        showsDetails: Bool,
        now: Date
    ) {
        let items = preps.compactMap { prep -> PrepWidgetItem? in
            guard prep.planState == .active || prep.planState == .ready else { return nil }
            return PrepWidgetItem(
                id: prep.id,
                title: PrepSurfaceContentSanitizer.title(prep.title, showsDetails: showsDetails),
                targetDate: prep.targetDate,
                status: SharedPrepStatus(prep.status),
                nextAction: PrepSurfaceContentSanitizer.nextAction(
                    prep.nextActionNote,
                    showsDetails: showsDetails
                ),
                showsDetails: showsDetails
            )
        }
        let snapshot = PrepWidgetSnapshot.make(items: items, at: now)
        PrepWidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: NudgeMateSharedConfiguration.widgetKind)
    }

    private func reconcileLiveActivities(
        preps: [EventPrep],
        startLiveActivityFor prepID: UUID?,
        showsDetails: Bool,
        now: Date
    ) async throws {
        let prepsByID = Dictionary(uniqueKeysWithValues: preps.map { ($0.id, $0) })
        var activePrepIDs = Set<UUID>()

        for activity in Activity<PrepActivityAttributes>.activities {
            let id = activity.attributes.prepID
            guard let prep = prepsByID[id],
                  prep.status == .inProgress,
                  prep.planState == .active,
                  prep.targetDate > now else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }

            activePrepIDs.insert(id)
            await activity.update(activityContent(for: prep, showsDetails: showsDetails, now: now))
        }

        guard let prepID,
              !activePrepIDs.contains(prepID),
              let prep = prepsByID[prepID],
              prep.status == .inProgress,
              prep.planState == .active,
              prep.targetDate > now,
              ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        for activity in Activity<PrepActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        _ = try Activity.request(
            attributes: PrepActivityAttributes(prepID: prep.id),
            content: activityContent(for: prep, showsDetails: showsDetails, now: now),
            pushType: nil
        )
    }

    private func activityContent(
        for prep: EventPrep,
        showsDetails: Bool,
        now: Date
    ) -> ActivityContent<PrepActivityAttributes.ContentState> {
        let state = PrepActivityAttributes.ContentState(
            title: PrepSurfaceContentSanitizer.title(prep.title, showsDetails: showsDetails),
            targetDate: prep.targetDate,
            status: SharedPrepStatus(prep.status),
            nextAction: PrepSurfaceContentSanitizer.nextAction(
                prep.nextActionNote,
                showsDetails: showsDetails
            ),
            showsDetails: showsDetails,
            updatedAt: prep.updatedAt
        )
        let systemLimit = now.addingTimeInterval(8 * 60 * 60)
        return ActivityContent(
            state: state,
            staleDate: min(prep.targetDate, systemLimit)
        )
    }
}

private extension SharedPrepStatus {
    init(_ status: PrepStatus) {
        switch status {
        case .notReady: self = .notReady
        case .inProgress: self = .inProgress
        case .ready: self = .ready
        }
    }
}
