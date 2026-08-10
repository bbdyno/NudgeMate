import ActivityKit
import Foundation

enum NudgeMateSharedConfiguration {
    static let appGroupIdentifier = "group.com.bbdyno.app.nudgemate"
    static let widgetKind = "NudgeMatePrepWidget"
    static let snapshotDefaultsKey = "widget.prep.snapshot.v1"
}

enum PrepSurfaceContentSanitizer {
    static let maximumTitleLength = 80
    static let maximumNextActionLength = 160

    static func title(_ value: String, showsDetails: Bool) -> String {
        sanitized(value, maximumLength: maximumTitleLength, showsDetails: showsDetails)
    }

    static func nextAction(_ value: String, showsDetails: Bool) -> String {
        sanitized(value, maximumLength: maximumNextActionLength, showsDetails: showsDetails)
    }

    private static func sanitized(
        _ value: String,
        maximumLength: Int,
        showsDetails: Bool
    ) -> String {
        guard showsDetails else { return "" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maximumLength))
    }
}

enum SharedPrepStatus: String, Codable, Hashable, Sendable {
    case notReady
    case inProgress
    case ready
}

struct PrepWidgetItem: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let targetDate: Date
    let status: SharedPrepStatus
    let nextAction: String
    let showsDetails: Bool

    var deepLinkURL: URL? {
        URL(string: "nudgemate://prep/\(id.uuidString)")
    }

    func daysRemaining(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }
}

struct PrepWidgetSnapshot: Codable, Hashable, Sendable {
    let generatedAt: Date
    let items: [PrepWidgetItem]

    static let empty = PrepWidgetSnapshot(generatedAt: .distantPast, items: [])

    static func make(
        items: [PrepWidgetItem],
        at date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        limit: Int = 3
    ) -> PrepWidgetSnapshot {
        let startOfToday = calendar.startOfDay(for: date)
        let visibleItems = items
            .filter { $0.status != .ready && $0.targetDate >= startOfToday }
            .sorted {
                if $0.targetDate == $1.targetDate {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.targetDate < $1.targetDate
            }
        return PrepWidgetSnapshot(
            generatedAt: date,
            items: Array(visibleItems.prefix(max(0, limit)))
        )
    }
}

struct PrepActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let title: String
        let targetDate: Date
        let status: SharedPrepStatus
        let nextAction: String
        let showsDetails: Bool
        let updatedAt: Date
    }

    let prepID: UUID

    var deepLinkURL: URL? {
        URL(string: "nudgemate://prep/\(prepID.uuidString)")
    }
}
