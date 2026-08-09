import Foundation

enum CalendarEventAvailability: String, Codable, Sendable {
    case busy
    case free
    case tentative
    case unavailable
    case unknown
}

enum CalendarEventStatus: String, Codable, Sendable {
    case none
    case confirmed
    case tentative
    case cancelled
}

enum CalendarOrganizerStatus: String, Codable, Sendable {
    case none
    case user
    case other
}

struct CalendarEventSnapshot: Identifiable, Codable, Hashable, Sendable {
    var id: String { eventIdentifier }
    var eventIdentifier: String
    var calendarIdentifier: String
    var calendarTitle: String
    var calendarSourceTitle: String
    var title: String
    var normalizedTitle: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var timeZoneIdentifier: String?
    var locationName: String?
    var hasRecurrenceRules: Bool
    var attendeeCount: Int
    var organizerStatus: CalendarOrganizerStatus
    var availability: CalendarEventAvailability
    var status: CalendarEventStatus
    var lastModifiedDate: Date?
    var hasOnlineMeeting: Bool
    var fingerprint: String
}
