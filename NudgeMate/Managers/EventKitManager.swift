import Foundation
import Observation

@MainActor
@Observable
final class EventKitManager {
    private(set) var authorizationState: CalendarAuthorizationState = .notDetermined
    private(set) var availableCalendars: [CalendarDescriptor] = []

    @ObservationIgnored
    private let store: any CalendarStore

    @ObservationIgnored
    private let calendar: Calendar

    @ObservationIgnored
    private let normalizer: EventNormalizer

    init(
        store: any CalendarStore = EventKitCalendarStore(),
        calendar: Calendar = .autoupdatingCurrent,
        normalizer: EventNormalizer = EventNormalizer()
    ) {
        self.store = store
        self.calendar = calendar
        self.normalizer = normalizer
    }

    func refreshAuthorizationState() async {
        authorizationState = await store.authorizationState()
    }

    @discardableResult
    func requestAccess() async throws -> Bool {
        try await store.requestFullAccess()
        await refreshAuthorizationState()
        availableCalendars = try await store.calendars()
        return authorizationState == .fullAccess
    }

    func loadCalendars() async throws -> [CalendarDescriptor] {
        await refreshAuthorizationState()
        guard authorizationState == .fullAccess else {
            if authorizationState == .denied || authorizationState == .restricted {
                throw CalendarError.accessDenied
            }
            if authorizationState == .writeOnly {
                throw CalendarError.writeOnlyAccess
            }
            throw CalendarError.unavailable
        }
        let values = try await store.calendars()
        availableCalendars = values
        return values
    }

    func fetchEvents(
        pastMonths: Int = 12,
        futureDays: Int = 90,
        calendarIdentifiers: Set<String> = [],
        referenceDate: Date = .now
    ) async throws -> [CalendarEventSnapshot] {
        guard (1...24).contains(pastMonths) else { throw CalendarError.unavailable }
        guard let startDate = calendar.date(byAdding: .month, value: -pastMonths, to: referenceDate),
              let endDate = calendar.date(byAdding: .day, value: futureDays, to: referenceDate) else {
            throw CalendarError.unavailable
        }
        let values = try await store.events(
            from: startDate,
            to: endDate,
            calendarIdentifiers: calendarIdentifiers
        )
        return values.map { event in
            var normalized = event
            normalized.normalizedTitle = normalizer.normalize(event.title)
            return normalized
        }
    }

    func fetchEventsFromPastYear(referenceDate: Date = .now) async throws -> [CalendarEventSnapshot] {
        try await fetchEvents(
            pastMonths: 12,
            futureDays: 0,
            referenceDate: referenceDate
        )
    }

    func buildInitialRecurringEvents(
        from events: [CalendarEventSnapshot],
        referenceDate: Date = .now
    ) -> [RecurringEvent] {
        let detector = PatternCandidateDetector(calendar: calendar)
        let groups = detector.groups(from: events.filter { $0.startDate <= referenceDate })
        let estimator = IntervalEstimator(calendar: calendar)

        return groups.compactMap { group in
            let rhythmID = UUID()
            let occurrences = group.map { event in
                RhythmOccurrence(
                    id: UUID(),
                    rhythmID: rhythmID,
                    occurredAt: event.startDate,
                    source: .calendarObserved,
                    status: .observed,
                    evidenceWeight: 0.6,
                    sourceCalendarIdentifier: event.calendarIdentifier,
                    sourceEventIdentifier: event.eventIdentifier,
                    userConfirmed: false,
                    excludedAsOutlier: false,
                    createdAt: referenceDate,
                    updatedAt: referenceDate
                )
            }
            guard let estimate = try? estimator.estimate(from: occurrences),
                  let lastDate = occurrences.map(\.occurredAt).max() else {
                return nil
            }
            let prediction = PredictionEngine(calendar: calendar).predict(
                lastOccurrence: lastDate,
                estimate: estimate,
                leadTimeDays: 3,
                now: referenceDate
            )
            let event = RecurringEvent(
                id: rhythmID,
                title: mostFrequentTitle(group),
                baseInterval: estimate.baseIntervalDays,
                historyDates: occurrences.map(\.occurredAt),
                nextPredictedDate: prediction.expectedWindow.center
            )
            event.variationDays = estimate.variationDays
            event.nextExpectedStartDate = prediction.expectedWindow.start
            event.nextExpectedEndDate = prediction.expectedWindow.end
            event.sourceCalendarIdentifiers = Array(Set(group.map(\.calendarIdentifier))).sorted()
            return event
        }
        .sorted { $0.nextExpectedCenterDate < $1.nextExpectedCenterDate }
    }

    func createCalendarEvent(
        title: String,
        startDate: Date,
        duration: TimeInterval = 3_600,
        calendarIdentifier: String? = nil,
        idempotencyKey: UUID = UUID()
    ) async throws -> String {
        try await store.createEvent(
            CalendarEventDraft(
                title: title,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(max(60, duration)),
                calendarIdentifier: calendarIdentifier,
                idempotencyKey: idempotencyKey
            )
        )
    }

    private func mostFrequentTitle(_ events: [CalendarEventSnapshot]) -> String {
        Dictionary(grouping: events, by: \.title)
            .max { $0.value.count < $1.value.count }?.key
            ?? NudgeMateStrings.Localizable.Calendar.Event.fallbackTitle
    }
}
