import Foundation

struct CalendarScanResult: Sendable {
    var candidates: [PatternCandidate]
    var scannedEventCount: Int
}

struct CalendarScanService: Sendable {
    private let calendar: Calendar
    private let detector: PatternCandidateDetector
    private let estimator: IntervalEstimator
    private let predictionEngine: PredictionEngine
    private let confidenceCalculator: ConfidenceCalculator
    private let similarityCalculator: EventSimilarityCalculator

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        detector = PatternCandidateDetector(calendar: calendar)
        estimator = IntervalEstimator(calendar: calendar)
        predictionEngine = PredictionEngine(calendar: calendar)
        confidenceCalculator = ConfidenceCalculator()
        similarityCalculator = EventSimilarityCalculator()
    }

    func scan(
        events: [CalendarEventSnapshot],
        suppressedSignatures: Set<String> = [],
        knownSignatures: Set<String> = [],
        referenceDate: Date = .now
    ) -> CalendarScanResult {
        let excludedSignatures = suppressedSignatures.union(knownSignatures)
        let candidates = detector.groups(from: events)
            .compactMap { group in
                makeCandidate(
                    from: group,
                    suppressedSignatures: excludedSignatures,
                    referenceDate: referenceDate
                )
            }
            .sorted { lhs, rhs in
                if lhs.confidenceScore == rhs.confidenceScore {
                    return lhs.expectedWindow.center < rhs.expectedWindow.center
                }
                return lhs.confidenceScore > rhs.confidenceScore
            }

        return CalendarScanResult(
            candidates: candidates,
            scannedEventCount: events.count
        )
    }

    private func makeCandidate(
        from group: [CalendarEventSnapshot],
        suppressedSignatures: Set<String>,
        referenceDate: Date
    ) -> PatternCandidate? {
        guard let first = group.first,
              !suppressedSignatures.contains(first.normalizedTitle) else {
            return nil
        }

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

        let prediction = predictionEngine.predict(
            lastOccurrence: lastDate,
            estimate: estimate,
            leadTimeDays: 3,
            now: referenceDate
        )
        let averageSimilarity = group.dropFirst().reduce(0.0) { partial, event in
            partial + similarityCalculator.score(first, event)
        } / Double(max(1, group.count - 1))
        let daysSinceLast = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastDate),
            to: calendar.startOfDay(for: referenceDate)
        ).day ?? 0
        let confidence = confidenceCalculator.calculate(
            ConfidenceInput(
                sampleCount: group.count,
                variationDays: estimate.variationDays,
                baseIntervalDays: estimate.baseIntervalDays,
                averageSimilarity: averageSimilarity,
                daysSinceLastOccurrence: max(0, daysSinceLast),
                confirmedOccurrenceCount: 0
            )
        )
        let title = mostFrequentTitle(in: group)
        let references = group.map { event in
            CandidateEventReference(
                eventIdentifier: event.eventIdentifier,
                calendarIdentifier: event.calendarIdentifier,
                originalTitle: event.title,
                occurredAt: event.startDate,
                isIncluded: true
            )
        }
        let details = [
            "samples=\(group.count)",
            "median=\(estimate.medianIntervalDays)",
            "outliers=\(estimate.outlierCount)"
        ]

        return PatternCandidate(
            id: rhythmID,
            suggestedDisplayName: title,
            normalizedKey: first.normalizedTitle,
            categorySuggestion: .other,
            eventReferences: references,
            sampleCount: group.count,
            intervalSamples: estimate.samples.map(\.days),
            medianIntervalDays: estimate.medianIntervalDays,
            variationDays: estimate.variationDays,
            confidenceScore: confidence.score,
            confidenceBand: confidence.band,
            expectedWindow: prediction.expectedWindow,
            explanation: PredictionExplanation(
                summary: title,
                sampleCount: group.count,
                validSampleCount: estimate.validOccurrenceCount,
                excludedOutlierCount: estimate.outlierCount,
                medianIntervalDays: estimate.medianIntervalDays,
                expectedWindow: prediction.expectedWindow,
                detailLines: details
            ),
            decision: .pending,
            createdAt: referenceDate
        )
    }

    private func mostFrequentTitle(in group: [CalendarEventSnapshot]) -> String {
        Dictionary(grouping: group, by: \.title)
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?.key
            ?? group[0].title
    }
}
