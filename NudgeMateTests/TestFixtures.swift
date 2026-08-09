import Foundation
@testable import NudgeMate

enum TestFixtures {
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static func date(
        year: Int = 2026,
        month: Int = 1,
        day: Int,
        hour: Int = 9,
        calendar: Calendar? = nil
    ) -> Date {
        let calendar = calendar ?? utcCalendar
        return calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        ) ?? Date(timeIntervalSince1970: 0)
    }

    static func snapshot(
        title: String,
        normalizedTitle: String,
        day: Int = 1,
        calendarIdentifier: String = "personal",
        location: String? = nil
    ) -> CalendarEventSnapshot {
        let start = date(day: day)
        return CalendarEventSnapshot(
            eventIdentifier: UUID().uuidString,
            calendarIdentifier: calendarIdentifier,
            calendarTitle: "Personal",
            calendarSourceTitle: "iCloud",
            title: title,
            normalizedTitle: normalizedTitle,
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            isAllDay: false,
            timeZoneIdentifier: "UTC",
            locationName: location,
            hasRecurrenceRules: false,
            attendeeCount: 0,
            organizerStatus: .user,
            availability: .busy,
            status: .confirmed,
            lastModifiedDate: nil,
            hasOnlineMeeting: false,
            fingerprint: UUID().uuidString
        )
    }

    static func occurrences(intervals: [Int]) -> [RhythmOccurrence] {
        var current = date(day: 1)
        var dates = [current]
        for interval in intervals {
            current = utcCalendar.date(byAdding: .day, value: interval, to: current) ?? current
            dates.append(current)
        }
        return dates.map { date in
            RhythmOccurrence(
                id: UUID(),
                rhythmID: UUID(),
                occurredAt: date,
                source: .userConfirmed,
                status: .completed,
                evidenceWeight: 1,
                sourceCalendarIdentifier: nil,
                sourceEventIdentifier: nil,
                userConfirmed: true,
                excludedAsOutlier: false,
                createdAt: date,
                updatedAt: date
            )
        }
    }
}
