import Foundation

enum NotificationCategoryIdentifier {
    static let rhythmQuickAdd = "RHYTHM_QUICK_ADD"
    static let rhythmReview = "RHYTHM_REVIEW"
    static let prepCheckIn = "PREP_CHECKIN"
    static let dailyRecap = "DAILY_RECAP"
}

enum NotificationActionIdentifier {
    static let rhythmQuickAdd = "rhythm.quickAdd"
    static let rhythmOpenScheduler = "rhythm.openScheduler"
    static let rhythmSnoozeOneWeek = "rhythm.snoozeOneWeek"
    static let rhythmSkipOnce = "rhythm.skipOnce"
    static let prepNotReady = "prep.notReady"
    static let prepInProgress = "prep.inProgress"
    static let prepReady = "prep.ready"
    static let recapOpen = "recap.open"
}

struct NotificationPayload: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var nudgeID: UUID?
    var rhythmID: UUID?
    var prepPlanID: UUID?
    var deepLink: String?

    init(
        schemaVersion: Int = currentSchemaVersion,
        nudgeID: UUID? = nil,
        rhythmID: UUID? = nil,
        prepPlanID: UUID? = nil,
        deepLink: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.nudgeID = nudgeID
        self.rhythmID = rhythmID
        self.prepPlanID = prepPlanID
        self.deepLink = deepLink
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let schemaVersion = userInfo["schemaVersion"] as? Int,
              schemaVersion == Self.currentSchemaVersion else { return nil }
        self.schemaVersion = schemaVersion
        nudgeID = Self.uuid(userInfo["nudgeID"])
        rhythmID = Self.uuid(userInfo["rhythmID"])
        prepPlanID = Self.uuid(userInfo["prepPlanID"])
        deepLink = userInfo["deepLink"] as? String
        guard nudgeID != nil || rhythmID != nil || prepPlanID != nil || deepLink != nil else { return nil }
    }

    var userInfo: [String: Any] {
        var value: [String: Any] = ["schemaVersion": schemaVersion]
        if let nudgeID { value["nudgeID"] = nudgeID.uuidString }
        if let rhythmID { value["rhythmID"] = rhythmID.uuidString }
        if let prepPlanID { value["prepPlanID"] = prepPlanID.uuidString }
        if let deepLink { value["deepLink"] = deepLink }
        return value
    }

    private static func uuid(_ value: Any?) -> UUID? {
        guard let string = value as? String else { return nil }
        return UUID(uuidString: string)
    }
}

struct LocalNotificationDescriptor: Hashable, Sendable {
    var identifier: String
    var title: String
    var body: String
    var categoryIdentifier: String
    var payload: NotificationPayload
    var fireDate: Date
}

enum NotificationPermissionState: Sendable {
    case notDetermined
    case authorized
    case denied
}
