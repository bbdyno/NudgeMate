import SwiftData
import UserNotifications

@MainActor
final class NotificationActionRouter {
    static let shared = NotificationActionRouter()

    private weak var nudgeManager: NudgeManager?
    private var modelContainer: ModelContainer?

    private init() {}

    func configure(modelContainer: ModelContainer, nudgeManager: NudgeManager) {
        self.modelContainer = modelContainer
        self.nudgeManager = nudgeManager
    }

    func route(_ response: UNNotificationResponse) async {
        guard let payload = NotificationPayload(
            userInfo: response.notification.request.content.userInfo
        ) else { return }
        guard let modelContainer, let nudgeManager else { return }

        let context = ModelContext(modelContainer)
        do {
            try await nudgeManager.handleNotificationAction(
                response.actionIdentifier,
                payload: payload,
                modelContext: context
            )
        } catch {
            context.insert(
                PendingIntentRecord(
                    kind: pendingKind(for: response.actionIdentifier),
                    domainID: payload.rhythmID ?? payload.prepPlanID,
                    secondaryID: payload.nudgeID,
                    actionIdentifier: response.actionIdentifier
                )
            )
            try? context.save()
        }
    }

    private func pendingKind(for action: String) -> PendingIntentKind {
        switch action {
        case NotificationActionIdentifier.rhythmQuickAdd: return .quickAdd
        case NotificationActionIdentifier.rhythmOpenScheduler: return .openScheduler
        case NotificationActionIdentifier.prepNotReady,
             NotificationActionIdentifier.prepInProgress,
             NotificationActionIdentifier.prepReady:
            return .prepAction
        case NotificationActionIdentifier.recapOpen: return .openRecap
        default: return .rhythmAction
        }
    }
}
