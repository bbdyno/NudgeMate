import EventKit
import Foundation
import Observation

private typealias L10n = NudgeMateStrings.Localizable

enum CalendarError: LocalizedError, Equatable {
    case accessDenied
    case writeOnlyAccess
    case unavailable
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return L10n.Calendar.Error.accessDenied
        case .writeOnlyAccess:
            return L10n.Calendar.Error.writeOnly
        case .unavailable:
            return L10n.Calendar.Error.unavailable
        case let .saveFailed(message):
            return L10n.Calendar.Error.saveFailed(message)
        }
    }
}

enum CalendarAuthorizationState: Equatable {
    case notDetermined
    case fullAccess
    case writeOnly
    case denied
    case restricted
}

@MainActor
@Observable
final class EventKitManager {
    private(set) var authorizationState: CalendarAuthorizationState

    @ObservationIgnored
    private let eventStore: EKEventStore

    @ObservationIgnored
    private let calendar: Calendar

    private let ignoredKeywords: Set<String> = [
        "the", "a", "an", "and", "or", "with", "for", "at", "in", "on",
        "appointment", "meeting", "event", "calendar", "reminder",
        "일정", "미팅", "회의", "약속", "캘린더", "리마인더", "그리고", "에서"
    ]

    init(
        eventStore: EKEventStore = EKEventStore(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.eventStore = eventStore
        self.calendar = calendar
        authorizationState = Self.mapAuthorizationStatus(
            EKEventStore.authorizationStatus(for: .event)
        )
    }

    func refreshAuthorizationState() {
        authorizationState = Self.mapAuthorizationStatus(
            EKEventStore.authorizationStatus(for: .event)
        )
    }

    @discardableResult
    func requestAccess() async throws -> Bool {
        refreshAuthorizationState()

        switch authorizationState {
        case .fullAccess:
            return true
        case .denied, .restricted:
            throw CalendarError.accessDenied
        case .writeOnly:
            throw CalendarError.writeOnlyAccess
        case .notDetermined:
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                refreshAuthorizationState()

                guard granted, authorizationState == .fullAccess else {
                    if authorizationState == .denied || authorizationState == .restricted {
                        throw CalendarError.accessDenied
                    }
                    throw CalendarError.unavailable
                }
                return true
            } catch let error as CalendarError {
                throw error
            } catch {
                refreshAuthorizationState()
                if authorizationState == .denied || authorizationState == .restricted {
                    throw CalendarError.accessDenied
                }
                throw CalendarError.unavailable
            }
        }
    }

    func fetchEventsFromPastYear(referenceDate: Date = .now) async throws -> [EKEvent] {
        try validateReadableAccess()

        guard let startDate = calendar.date(byAdding: .month, value: -12, to: referenceDate) else {
            throw CalendarError.unavailable
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: referenceDate,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay || $0.startDate <= referenceDate }
            .filter { $0.status != .canceled && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.startDate < $1.startDate }
    }

    func buildInitialRecurringEvents(
        from events: [EKEvent],
        referenceDate: Date = .now
    ) -> [RecurringEvent] {
        let tokenFrequency = events.reduce(into: [String: Int]()) { counts, event in
            Set(keywords(in: event.title)).forEach { counts[$0, default: 0] += 1 }
        }
        let repeatingKeywords = Set(
            tokenFrequency.compactMap { keyword, count in count >= 2 ? keyword : nil }
        )

        let groupedEvents = Dictionary(grouping: events) { event -> String in
            keywords(in: event.title)
                .filter(repeatingKeywords.contains)
                .sorted()
                .prefix(3)
                .joined(separator: "|")
        }

        return groupedEvents.compactMap { signature, grouped -> RecurringEvent? in
            guard !signature.isEmpty else { return nil }

            let dates = uniqueDayDates(from: grouped.map(\.startDate))
            guard dates.count >= 2 else { return nil }

            let intervals = zip(dates, dates.dropFirst()).compactMap { earlier, later -> Int? in
                let days = calendar.dateComponents([.day], from: earlier, to: later).day ?? 0
                return (1...366).contains(days) ? days : nil
            }
            guard !intervals.isEmpty else { return nil }

            let average = Double(intervals.reduce(0, +)) / Double(intervals.count)
            let baseInterval = max(1, Int(average.rounded()))
            let title = mostFrequentTitle(in: grouped)
            let nextDate = nextPrediction(
                after: dates.last ?? referenceDate,
                intervalInDays: baseInterval,
                referenceDate: referenceDate
            )

            return RecurringEvent(
                title: title,
                baseInterval: baseInterval,
                historyDates: dates,
                nextPredictedDate: nextDate
            )
        }
        .sorted { $0.nextPredictedDate < $1.nextPredictedDate }
    }

    func repeatingKeywords(in events: [EKEvent]) -> [String] {
        let counts = events.reduce(into: [String: Int]()) { result, event in
            Set(keywords(in: event.title)).forEach { result[$0, default: 0] += 1 }
        }

        return counts
            .filter { $0.value >= 2 }
            .sorted {
                if $0.value == $1.value { return $0.key < $1.key }
                return $0.value > $1.value
            }
            .map(\.key)
    }

    func createCalendarEvent(
        title: String,
        startDate: Date,
        duration: TimeInterval = 3_600
    ) async throws {
        try validateReadableAccess()

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw CalendarError.unavailable
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = calendar
        event.notes = L10n.Calendar.Event.predictedNote

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
        } catch {
            throw CalendarError.saveFailed(error.localizedDescription)
        }
    }

    private func validateReadableAccess() throws {
        refreshAuthorizationState()
        switch authorizationState {
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

    private func keywords(in title: String) -> [String] {
        title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { token in
                token.count >= 2
                    && !ignoredKeywords.contains(token)
                    && !token.allSatisfy(\.isNumber)
            }
    }

    private func uniqueDayDates(from dates: [Date]) -> [Date] {
        let groupedByDay = Dictionary(grouping: dates) { calendar.startOfDay(for: $0) }
        return groupedByDay.values
            .compactMap { $0.min() }
            .sorted()
    }

    private func mostFrequentTitle(in events: [EKEvent]) -> String {
        let counts = Dictionary(grouping: events) {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return counts.max { lhs, rhs in lhs.value.count < rhs.value.count }?.key
            ?? events.first?.title
            ?? L10n.Calendar.Event.fallbackTitle
    }

    private func nextPrediction(
        after lastDate: Date,
        intervalInDays: Int,
        referenceDate: Date
    ) -> Date {
        var prediction = calendar.date(
            byAdding: .day,
            value: intervalInDays,
            to: lastDate
        ) ?? lastDate.addingTimeInterval(TimeInterval(intervalInDays * 86_400))

        while prediction <= referenceDate {
            prediction = calendar.date(
                byAdding: .day,
                value: intervalInDays,
                to: prediction
            ) ?? prediction.addingTimeInterval(TimeInterval(intervalInDays * 86_400))
        }
        return prediction
    }

    private static func mapAuthorizationStatus(
        _ status: EKAuthorizationStatus
    ) -> CalendarAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess, .authorized:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        @unknown default:
            return .denied
        }
    }
}
