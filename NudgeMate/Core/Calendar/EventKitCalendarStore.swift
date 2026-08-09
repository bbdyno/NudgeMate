import CryptoKit
import EventKit
import Foundation
import UIKit

actor EventKitCalendarStore: CalendarStore {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func authorizationState() -> CalendarAuthorizationState {
        Self.authorizationState(for: EKEventStore.authorizationStatus(for: .event))
    }

    func requestFullAccess() async throws {
        switch authorizationState() {
        case .fullAccess:
            return
        case .denied, .restricted:
            throw CalendarError.accessDenied
        case .writeOnly:
            throw CalendarError.writeOnlyAccess
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToEvents()
            guard granted, authorizationState() == .fullAccess else {
                throw CalendarError.accessDenied
            }
        }
    }

    func calendars() throws -> [CalendarDescriptor] {
        try validateReadableAccess()
        return eventStore.calendars(for: .event)
            .map(descriptor)
            .sorted {
                if $0.sourceTitle == $1.sourceTitle { return $0.title < $1.title }
                return $0.sourceTitle < $1.sourceTitle
            }
    }

    func events(
        from startDate: Date,
        to endDate: Date,
        calendarIdentifiers: Set<String>
    ) throws -> [CalendarEventSnapshot] {
        try validateReadableAccess()
        try Task.checkCancellation()

        let selectedCalendars = eventStore.calendars(for: .event).filter {
            calendarIdentifiers.isEmpty || calendarIdentifiers.contains($0.calendarIdentifier)
        }
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )

        return try eventStore.events(matching: predicate).compactMap { event in
            try Task.checkCancellation()
            guard event.status != .canceled else { return nil }
            return snapshot(event)
        }
    }

    func createEvent(_ draft: CalendarEventDraft) throws -> String {
        try validateReadableAccess()
        let calendar: EKCalendar
        if let identifier = draft.calendarIdentifier,
           let selected = eventStore.calendar(withIdentifier: identifier),
           selected.allowsContentModifications {
            calendar = selected
        } else if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
                  defaultCalendar.allowsContentModifications {
            calendar = defaultCalendar
        } else {
            throw CalendarError.calendarNotWritable
        }

        let marker = "[NudgeMate:\(draft.idempotencyKey.uuidString)]"
        let duplicatePredicate = eventStore.predicateForEvents(
            withStart: draft.startDate.addingTimeInterval(-86_400),
            end: draft.endDate.addingTimeInterval(86_400),
            calendars: [calendar]
        )
        if let existing = eventStore.events(matching: duplicatePredicate).first(where: {
            $0.notes?.contains(marker) == true
        }) {
            return existing.eventIdentifier
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = draft.title
        event.startDate = draft.startDate
        event.endDate = max(draft.startDate.addingTimeInterval(60), draft.endDate)
        event.calendar = calendar
        event.notes = marker

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            guard let identifier = event.eventIdentifier else {
                throw CalendarError.saveFailed("missingIdentifier")
            }
            return identifier
        } catch let error as CalendarError {
            throw error
        } catch {
            throw CalendarError.saveFailed(error.localizedDescription)
        }
    }

    private func validateReadableAccess() throws {
        switch authorizationState() {
        case .fullAccess:
            return
        case .denied, .restricted:
            throw CalendarError.accessDenied
        case .writeOnly:
            throw CalendarError.writeOnlyAccess
        case .notDetermined:
            throw CalendarError.unavailable
        }
    }

    private func descriptor(_ calendar: EKCalendar) -> CalendarDescriptor {
        let reason: CalendarExclusionReason?
        switch calendar.type {
        case .birthday:
            reason = .birthdays
        case .subscription:
            reason = .subscribed
        default:
            if !calendar.allowsContentModifications {
                reason = calendar.title.localizedCaseInsensitiveContains("holiday")
                    || calendar.title.localizedCaseInsensitiveContains("공휴일")
                    ? .holidays
                    : .readOnly
            } else {
                reason = nil
            }
        }
        return CalendarDescriptor(
            identifier: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title,
            sourceType: String(calendar.source.sourceType.rawValue),
            colorHex: UIColor(cgColor: calendar.cgColor).hexRGB,
            allowsContentModifications: calendar.allowsContentModifications,
            isImmutable: calendar.isImmutable,
            defaultExclusionReason: reason
        )
    }

    private func snapshot(_ event: EKEvent) -> CalendarEventSnapshot? {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let identifier = event.eventIdentifier else { return nil }
        let limitedLocation = event.location?
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)
            .map { String($0.prefix(64)) }
        let rawFingerprint = [
            identifier,
            event.calendar.calendarIdentifier,
            title,
            String(event.startDate.timeIntervalSince1970),
            String(event.endDate.timeIntervalSince1970),
            String(event.lastModifiedDate?.timeIntervalSince1970 ?? 0)
        ].joined(separator: "|")

        return CalendarEventSnapshot(
            eventIdentifier: identifier,
            calendarIdentifier: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            calendarSourceTitle: event.calendar.source.title,
            title: title,
            normalizedTitle: "",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            timeZoneIdentifier: event.timeZone?.identifier,
            locationName: limitedLocation,
            hasRecurrenceRules: !(event.recurrenceRules?.isEmpty ?? true),
            attendeeCount: event.attendees?.count ?? 0,
            organizerStatus: event.organizer?.isCurrentUser == true ? .user : (event.organizer == nil ? .none : .other),
            availability: Self.availability(event.availability),
            status: Self.status(event.status),
            lastModifiedDate: event.lastModifiedDate,
            hasOnlineMeeting: event.url != nil,
            fingerprint: SHA256.hash(data: Data(rawFingerprint.utf8)).map { String(format: "%02x", $0) }.joined()
        )
    }

    private static func authorizationState(for status: EKAuthorizationStatus) -> CalendarAuthorizationState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly
        @unknown default: return .denied
        }
    }

    private static func availability(_ value: EKEventAvailability) -> CalendarEventAvailability {
        switch value {
        case .busy: return .busy
        case .free: return .free
        case .tentative: return .tentative
        case .unavailable: return .unavailable
        case .notSupported: return .unknown
        @unknown default: return .unknown
        }
    }

    private static func status(_ value: EKEventStatus) -> CalendarEventStatus {
        switch value {
        case .none: return .none
        case .confirmed: return .confirmed
        case .tentative: return .tentative
        case .canceled: return .cancelled
        @unknown default: return .none
        }
    }
}

private extension UIColor {
    var hexRGB: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "#808080" }
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
