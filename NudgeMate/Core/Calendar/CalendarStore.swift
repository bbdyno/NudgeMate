import Foundation

enum CalendarAuthorizationState: Equatable, Sendable {
    case notDetermined
    case fullAccess
    case writeOnly
    case denied
    case restricted
}

enum CalendarError: LocalizedError, Equatable {
    case accessDenied
    case writeOnlyAccess
    case unavailable
    case calendarNotWritable
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return NudgeMateStrings.Localizable.Calendar.Error.accessDenied
        case .writeOnlyAccess:
            return NudgeMateStrings.Localizable.Calendar.Error.writeOnly
        case .unavailable, .calendarNotWritable:
            return NudgeMateStrings.Localizable.Calendar.Error.unavailable
        case let .saveFailed(message):
            return NudgeMateStrings.Localizable.Calendar.Error.saveFailed(message)
        }
    }
}

enum CalendarExclusionReason: String, Codable, Sendable {
    case birthdays
    case holidays
    case subscribed
    case readOnly
}

struct CalendarDescriptor: Identifiable, Codable, Hashable, Sendable {
    var id: String { identifier }
    var identifier: String
    var title: String
    var sourceTitle: String
    var sourceType: String
    var colorHex: String
    var allowsContentModifications: Bool
    var isImmutable: Bool
    var defaultExclusionReason: CalendarExclusionReason?
}

struct CalendarEventDraft: Hashable, Sendable {
    var title: String
    var startDate: Date
    var endDate: Date
    var calendarIdentifier: String?
    var idempotencyKey: UUID
}

protocol CalendarStore: Sendable {
    func authorizationState() async -> CalendarAuthorizationState
    func requestFullAccess() async throws
    func calendars() async throws -> [CalendarDescriptor]
    func events(
        from startDate: Date,
        to endDate: Date,
        calendarIdentifiers: Set<String>
    ) async throws -> [CalendarEventSnapshot]
    func createEvent(_ draft: CalendarEventDraft) async throws -> String
}
