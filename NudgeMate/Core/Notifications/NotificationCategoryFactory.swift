import UserNotifications

enum NotificationCategoryFactory {
    static func categories() -> Set<UNNotificationCategory> {
        let strings = NudgeMateStrings.Localizable.Notification.Action.self
        let quickAdd = UNNotificationAction(
            identifier: NotificationActionIdentifier.rhythmQuickAdd,
            title: strings.scheduleNow
        )
        let openScheduler = UNNotificationAction(
            identifier: NotificationActionIdentifier.rhythmOpenScheduler,
            title: strings.scheduleNow,
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: NotificationActionIdentifier.rhythmSnoozeOneWeek,
            title: strings.snoozeWeek
        )
        let skip = UNNotificationAction(
            identifier: NotificationActionIdentifier.rhythmSkipOnce,
            title: strings.skip,
            options: [.destructive]
        )
        let notReady = UNNotificationAction(
            identifier: NotificationActionIdentifier.prepNotReady,
            title: strings.notReady
        )
        let inProgress = UNNotificationAction(
            identifier: NotificationActionIdentifier.prepInProgress,
            title: NudgeMateStrings.Localizable.Prep.Status.inProgress
        )
        let ready = UNNotificationAction(
            identifier: NotificationActionIdentifier.prepReady,
            title: strings.ready
        )
        let recap = UNNotificationAction(
            identifier: NotificationActionIdentifier.recapOpen,
            title: NudgeMateStrings.Localizable.Common.confirm,
            options: [.foreground]
        )
        return [
            UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.rhythmQuickAdd,
                actions: [quickAdd, snooze, skip],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.rhythmReview,
                actions: [openScheduler, snooze, skip],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.prepCheckIn,
                actions: [notReady, inProgress, ready],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.dailyRecap,
                actions: [recap],
                intentIdentifiers: []
            )
        ]
    }
}
