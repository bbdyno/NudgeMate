import Foundation
import SwiftData

@MainActor
struct AdaptiveRhythmService {
    private let modelContext: ModelContext
    private let calendar: Calendar
    private let normalizer: EventNormalizer
    private let similarityCalculator: EventSimilarityCalculator
    private let estimator: IntervalEstimator
    private let confidenceCalculator: ConfidenceCalculator
    private let predictionEngine: PredictionEngine

    init(
        modelContext: ModelContext,
        calendar: Calendar = .autoupdatingCurrent,
        normalizer: EventNormalizer = EventNormalizer(),
        similarityCalculator: EventSimilarityCalculator = EventSimilarityCalculator()
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.normalizer = normalizer
        self.similarityCalculator = similarityCalculator
        estimator = IntervalEstimator(calendar: calendar)
        confidenceCalculator = ConfidenceCalculator()
        predictionEngine = PredictionEngine(calendar: calendar)
    }

    func seed(
        rhythm: RecurringEvent,
        from references: [CandidateEventReference],
        now: Date = .now
    ) throws {
        let existing = try occurrences(for: rhythm.id)
        let existingEventIdentifiers = Set(existing.compactMap(\.sourceEventIdentifier))

        for reference in references where reference.isIncluded
            && !existingEventIdentifiers.contains(reference.eventIdentifier) {
            modelContext.insert(
                RhythmOccurrenceRecord(
                    value: RhythmOccurrence(
                        id: UUID(),
                        rhythmID: rhythm.id,
                        occurredAt: reference.occurredAt,
                        source: .calendarObserved,
                        status: .observed,
                        evidenceWeight: 0.6,
                        sourceCalendarIdentifier: reference.calendarIdentifier,
                        sourceEventIdentifier: reference.eventIdentifier,
                        userConfirmed: false,
                        excludedAsOutlier: false,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            )
        }

        _ = try recalculate(rhythm, now: now)
    }

    @discardableResult
    func recordCompletion(
        for rhythm: RecurringEvent,
        source: OccurrenceSource,
        at date: Date = .now
    ) throws -> Bool {
        modelContext.insert(
            RhythmOccurrenceRecord(
                value: RhythmOccurrence(
                    id: UUID(),
                    rhythmID: rhythm.id,
                    occurredAt: date,
                    source: source,
                    status: .completed,
                    evidenceWeight: 1,
                    sourceCalendarIdentifier: nil,
                    sourceEventIdentifier: nil,
                    userConfirmed: true,
                    excludedAsOutlier: false,
                    createdAt: date,
                    updatedAt: date
                )
            )
        )

        if rhythm.mode == .adaptive, try recalculate(rhythm, now: date) {
            try modelContext.save()
            return true
        }

        advanceFixedRhythm(rhythm, from: date)
        try modelContext.save()
        return true
    }

    func recordScheduled(
        for rhythm: RecurringEvent,
        at date: Date,
        calendarIdentifier: String?,
        eventIdentifier: String,
        now: Date = .now
    ) throws {
        guard try hasOccurrence(
            rhythmID: rhythm.id,
            sourceEventIdentifier: eventIdentifier
        ) == false else {
            return
        }

        modelContext.insert(
            RhythmOccurrenceRecord(
                value: RhythmOccurrence(
                    id: UUID(),
                    rhythmID: rhythm.id,
                    occurredAt: date,
                    source: .scheduledCalendarEvent,
                    status: .scheduled,
                    evidenceWeight: 0,
                    sourceCalendarIdentifier: calendarIdentifier,
                    sourceEventIdentifier: eventIdentifier,
                    userConfirmed: false,
                    excludedAsOutlier: false,
                    createdAt: now,
                    updatedAt: now
                )
            )
        )
        try modelContext.save()
    }

    func recordSkipped(
        for rhythm: RecurringEvent,
        at date: Date = .now
    ) throws {
        modelContext.insert(
            RhythmOccurrenceRecord(
                value: RhythmOccurrence(
                    id: UUID(),
                    rhythmID: rhythm.id,
                    occurredAt: date,
                    source: .notificationAction,
                    status: .skippedOnce,
                    evidenceWeight: 0,
                    sourceCalendarIdentifier: nil,
                    sourceEventIdentifier: nil,
                    userConfirmed: false,
                    excludedAsOutlier: false,
                    createdAt: date,
                    updatedAt: date
                )
            )
        )
    }

    @discardableResult
    func reconcile(
        events: [CalendarEventSnapshot],
        rhythms: [RecurringEvent],
        selectedCalendarIdentifiers: Set<String>,
        reconcileRemovals: Bool = false,
        now: Date = .now
    ) throws -> [RecurringEvent] {
        let adaptiveRhythms = rhythms.filter { $0.mode == .adaptive }
        guard !adaptiveRhythms.isEmpty else { return [] }

        let allOccurrences = try modelContext.fetch(FetchDescriptor<RhythmOccurrenceRecord>())
        var occurrencesByEventIdentifier: [String: RhythmOccurrenceRecord] = [:]
        for occurrence in allOccurrences where occurrence.source == .calendarObserved {
            if let identifier = occurrence.sourceEventIdentifier {
                occurrencesByEventIdentifier[identifier] = occurrence
            }
        }

        var changedRhythmIDs = Set<UUID>()
        let observedEventIdentifiers = Set(events.map(\.eventIdentifier))
        let oldestReconciledDate = calendar.date(byAdding: .month, value: -12, to: now) ?? .distantPast

        for occurrence in allOccurrences where reconcileRemovals
            && occurrence.source == .calendarObserved
            && occurrence.occurredAt >= oldestReconciledDate
            && occurrence.occurredAt <= now
            && occurrence.sourceCalendarIdentifier.map(selectedCalendarIdentifiers.contains) == true
            && occurrence.sourceEventIdentifier.map({ !observedEventIdentifiers.contains($0) }) == true
            && occurrence.status != .removed {
            occurrence.status = .removed
            occurrence.evidenceWeight = 0
            occurrence.updatedAt = now
            changedRhythmIDs.insert(occurrence.rhythmID)
        }

        for event in events where event.startDate <= now
            && selectedCalendarIdentifiers.contains(event.calendarIdentifier)
            && event.status != .cancelled {
            if let existing = occurrencesByEventIdentifier[event.eventIdentifier] {
                if existing.status != .observed
                    || existing.occurredAt != event.startDate
                    || existing.sourceCalendarIdentifier != event.calendarIdentifier {
                    existing.status = .observed
                    existing.occurredAt = event.startDate
                    existing.evidenceWeight = 0.6
                    existing.sourceCalendarIdentifier = event.calendarIdentifier
                    existing.updatedAt = now
                    changedRhythmIDs.insert(existing.rhythmID)
                }
                continue
            }

            guard let rhythm = bestMatch(for: event, rhythms: adaptiveRhythms) else { continue }
            let occurrence = RhythmOccurrenceRecord(
                value: RhythmOccurrence(
                    id: UUID(),
                    rhythmID: rhythm.id,
                    occurredAt: event.startDate,
                    source: .calendarObserved,
                    status: .observed,
                    evidenceWeight: 0.6,
                    sourceCalendarIdentifier: event.calendarIdentifier,
                    sourceEventIdentifier: event.eventIdentifier,
                    userConfirmed: false,
                    excludedAsOutlier: false,
                    createdAt: now,
                    updatedAt: now
                )
            )
            modelContext.insert(occurrence)
            occurrencesByEventIdentifier[event.eventIdentifier] = occurrence
            changedRhythmIDs.insert(rhythm.id)

            if event.normalizedTitle != rhythm.normalizedName,
               !rhythm.aliases.contains(event.normalizedTitle) {
                rhythm.aliases = Array((rhythm.aliases + [event.normalizedTitle]).suffix(8))
            }
            if !rhythm.sourceCalendarIdentifiers.contains(event.calendarIdentifier) {
                rhythm.sourceCalendarIdentifiers.append(event.calendarIdentifier)
                rhythm.sourceCalendarIdentifiers.sort()
            }
        }

        let changedRhythms = adaptiveRhythms.filter { changedRhythmIDs.contains($0.id) }
        for rhythm in changedRhythms {
            _ = try recalculate(rhythm, now: now)
        }
        if !changedRhythms.isEmpty {
            try modelContext.save()
        }
        return changedRhythms
    }

    @discardableResult
    func recalculate(_ rhythm: RecurringEvent, now: Date = .now) throws -> Bool {
        guard rhythm.mode == .adaptive else { return false }

        let records = try occurrences(for: rhythm.id)
        let values = records.map(\.domainValue)
        let actualOccurrences = values.filter {
            $0.status == .observed || $0.status == .completed
        }
        guard let estimate = try? estimator.estimate(from: values),
              let lastOccurrence = actualOccurrences.map(\.occurredAt).max() else {
            return false
        }

        let prediction = predictionEngine.predict(
            lastOccurrence: lastOccurrence,
            estimate: estimate,
            leadTimeDays: rhythm.leadTimeDays,
            now: now
        )
        let eligible = values.filter {
            ($0.status == .observed || $0.status == .completed) && $0.evidenceWeight > 0
        }
        let averageEvidence = eligible.isEmpty
            ? 0
            : eligible.reduce(0) { $0 + min(1, $1.evidenceWeight + 0.25) } / Double(eligible.count)
        let daysSinceLast = max(
            0,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastOccurrence),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
        )
        let confidence = confidenceCalculator.calculate(
            ConfidenceInput(
                sampleCount: eligible.count,
                variationDays: estimate.variationDays,
                baseIntervalDays: estimate.baseIntervalDays,
                averageSimilarity: averageEvidence,
                daysSinceLastOccurrence: daysSinceLast,
                confirmedOccurrenceCount: eligible.filter(\.userConfirmed).count
            )
        )

        rhythm.baseIntervalDays = estimate.baseIntervalDays
        rhythm.variationDays = estimate.variationDays
        rhythm.confidenceScore = confidence.score
        rhythm.confidenceBand = confidence.band
        rhythm.historyDates = eligible.map(\.occurredAt).sorted()
        rhythm.lastOccurrenceDate = lastOccurrence
        rhythm.nextExpectedStartDate = prediction.expectedWindow.start
        rhythm.nextExpectedCenterDate = prediction.expectedWindow.center
        rhythm.nextExpectedEndDate = prediction.expectedWindow.end
        rhythm.updatedAt = now
        return true
    }

    private func occurrences(for rhythmID: UUID) throws -> [RhythmOccurrenceRecord] {
        try modelContext.fetch(FetchDescriptor<RhythmOccurrenceRecord>())
            .filter { $0.rhythmID == rhythmID }
    }

    private func hasOccurrence(
        rhythmID: UUID,
        sourceEventIdentifier: String
    ) throws -> Bool {
        try occurrences(for: rhythmID).contains {
            $0.sourceEventIdentifier == sourceEventIdentifier
        }
    }

    private func bestMatch(
        for event: CalendarEventSnapshot,
        rhythms: [RecurringEvent]
    ) -> RecurringEvent? {
        let scored = rhythms.compactMap { rhythm -> (RecurringEvent, Double)? in
            let knownNames = Set(
                [rhythm.normalizedName, normalizer.normalize(rhythm.displayName)]
                    + rhythm.aliases.map(normalizer.normalize)
            ).filter { !$0.isEmpty }

            if knownNames.contains(event.normalizedTitle) {
                guard !similarityCalculator.isGenericSingleToken(event.normalizedTitle) else {
                    return nil
                }
                return (rhythm, 1)
            }

            guard rhythm.sourceCalendarIdentifiers.contains(event.calendarIdentifier) else {
                return nil
            }

            let score = knownNames.map { knownName -> Double in
                var representative = event
                representative.normalizedTitle = knownName
                representative.title = knownName
                representative.locationName = nil
                return similarityCalculator.score(representative, event)
            }.max() ?? 0
            return score >= similarityCalculator.configuration.mergeThreshold
                ? (rhythm, score)
                : nil
        }

        return scored.max { $0.1 < $1.1 }?.0
    }

    private func advanceFixedRhythm(_ rhythm: RecurringEvent, from date: Date) {
        rhythm.historyDates.append(date)
        rhythm.historyDates.sort()
        rhythm.lastOccurrenceDate = date
        let center = calendar.date(byAdding: .day, value: rhythm.baseIntervalDays, to: date)
            ?? date.addingTimeInterval(TimeInterval(rhythm.baseIntervalDays * 86_400))
        rhythm.nextPredictedDate = center
        rhythm.updatedAt = date
    }
}

private extension RhythmOccurrenceRecord {
    var domainValue: RhythmOccurrence {
        RhythmOccurrence(
            id: id,
            rhythmID: rhythmID,
            occurredAt: occurredAt,
            source: source,
            status: status,
            evidenceWeight: evidenceWeight,
            sourceCalendarIdentifier: sourceCalendarIdentifier,
            sourceEventIdentifier: sourceEventIdentifier,
            userConfirmed: userConfirmed,
            excludedAsOutlier: excludedAsOutlier,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
