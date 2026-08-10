import SwiftData
import UserNotifications

@MainActor
final class NotificationActionRouter {
    static let shared = NotificationActionRouter()

    private weak var nudgeManager: NudgeManager?
    private var modelContainer: ModelContainer?
    private var navigationHandler: (@MainActor (AppNavigationDestination) -> Void)?

    private init() {}

    func configure(
        modelContainer: ModelContainer,
        nudgeManager: NudgeManager,
        navigationHandler: @escaping @MainActor (AppNavigationDestination) -> Void
    ) {
        self.modelContainer = modelContainer
        self.nudgeManager = nudgeManager
        self.navigationHandler = navigationHandler
        Task { await replayPendingIntents() }
    }

    func route(_ response: UNNotificationResponse) async {
        guard let payload = NotificationPayload(
            userInfo: response.notification.request.content.userInfo
        ) else { return }
        guard let modelContainer, let nudgeManager else { return }

        if let destination = Self.navigationDestination(
            actionIdentifier: response.actionIdentifier,
            payload: payload
        ) {
            if let navigationHandler {
                navigationHandler(destination)
            } else {
                persistPendingIntent(
                    actionIdentifier: response.actionIdentifier,
                    payload: payload,
                    context: ModelContext(modelContainer)
                )
            }
            return
        }

        let context = ModelContext(modelContainer)
        do {
            try await nudgeManager.handleNotificationAction(
                response.actionIdentifier,
                payload: payload,
                modelContext: context
            )
        } catch {
            persistPendingIntent(
                actionIdentifier: response.actionIdentifier,
                payload: payload,
                context: context
            )
        }
    }

    static func navigationDestination(
        actionIdentifier: String,
        payload: NotificationPayload
    ) -> AppNavigationDestination? {
        switch actionIdentifier {
        case NotificationActionIdentifier.rhythmQuickAdd,
             NotificationActionIdentifier.rhythmOpenScheduler:
            return .scheduleRhythm(payload.rhythmID)
        case NotificationActionIdentifier.recapOpen:
            return .recap
        case UNNotificationDefaultActionIdentifier:
            if let rhythmID = payload.rhythmID { return .rhythm(rhythmID) }
            if let prepPlanID = payload.prepPlanID { return .prep(prepPlanID) }
            guard let deepLink = payload.deepLink,
                  let url = URL(string: deepLink) else { return .today }
            return destination(from: url)
        default:
            return nil
        }
    }

    private static func destination(from url: URL) -> AppNavigationDestination? {
        let id = url.pathComponents
            .dropFirst()
            .first
            .flatMap(UUID.init(uuidString:))
        switch url.host?.lowercased() {
        case "rhythm": return .rhythm(id)
        case "prep": return .prep(id)
        case "recap": return .recap
        case "today": return .today
        default: return nil
        }
    }

    private func persistPendingIntent(
        actionIdentifier: String,
        payload: NotificationPayload,
        context: ModelContext
    ) {
        context.insert(
            PendingIntentRecord(
                kind: pendingKind(for: actionIdentifier, payload: payload),
                domainID: payload.rhythmID ?? payload.prepPlanID,
                secondaryID: payload.nudgeID,
                actionIdentifier: actionIdentifier
            )
        )
        try? context.save()
    }

    private func replayPendingIntents() async {
        guard let modelContainer, let nudgeManager else { return }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PendingIntentRecord>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let records = try? context.fetch(descriptor) else { return }

        for record in records {
            do {
                if let destination = destination(for: record) {
                    navigationHandler?(destination)
                } else if let actionIdentifier = record.actionIdentifier {
                    try await nudgeManager.handleNotificationAction(
                        actionIdentifier,
                        payload: NotificationPayload(
                            nudgeID: record.secondaryID,
                            rhythmID: record.kind == .rhythmAction ? record.domainID : nil,
                            prepPlanID: record.kind == .prepAction ? record.domainID : nil
                        ),
                        modelContext: context
                    )
                }
                context.delete(record)
            } catch {
                record.retryCount += 1
            }
        }
        try? context.save()
    }

    private func destination(for record: PendingIntentRecord) -> AppNavigationDestination? {
        switch record.kind {
        case .openScheduler, .quickAdd: return .scheduleRhythm(record.domainID)
        case .openPrep: return .prep(record.domainID)
        case .openRecap: return .recap
        case .rhythmAction, .prepAction: return nil
        }
    }

    private func pendingKind(
        for action: String,
        payload: NotificationPayload
    ) -> PendingIntentKind {
        switch action {
        case NotificationActionIdentifier.rhythmQuickAdd: return .quickAdd
        case NotificationActionIdentifier.rhythmOpenScheduler: return .openScheduler
        case NotificationActionIdentifier.prepNotReady,
             NotificationActionIdentifier.prepInProgress,
             NotificationActionIdentifier.prepReady:
            return .prepAction
        case NotificationActionIdentifier.recapOpen: return .openRecap
        case UNNotificationDefaultActionIdentifier:
            if payload.prepPlanID != nil { return .openPrep }
            if payload.deepLink == "nudgemate://recap" { return .openRecap }
            return .openScheduler
        default:
            return payload.prepPlanID == nil ? .rhythmAction : .prepAction
        }
    }
}
