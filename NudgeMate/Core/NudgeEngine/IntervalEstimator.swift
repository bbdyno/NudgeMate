import Foundation

struct IntervalSample: Hashable, Sendable {
    var earlierOccurrenceID: UUID
    var laterOccurrenceID: UUID
    var days: Double
    var weight: Double
    var isOutlier: Bool
}

struct IntervalEstimate: Hashable, Sendable {
    var baseIntervalDays: Int
    var medianIntervalDays: Double
    var variationDays: Int
    var robustSigma: Double
    var samples: [IntervalSample]
    var validOccurrenceCount: Int

    var outlierCount: Int {
        samples.filter(\.isOutlier).count
    }
}

enum IntervalEstimatorError: Error, Equatable {
    case insufficientOccurrences
}

struct IntervalEstimator: Sendable {
    let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func estimate(from occurrences: [RhythmOccurrence]) throws -> IntervalEstimate {
        let eligible = occurrences
            .filter { occurrence in
                occurrence.status != .scheduled
                    && occurrence.status != .invalid
                    && occurrence.status != .removed
                    && occurrence.evidenceWeight > 0
            }
            .sorted { $0.occurredAt < $1.occurredAt }

        let unique = deduplicatedByDay(eligible)
        guard unique.count >= 3 else { throw IntervalEstimatorError.insufficientOccurrences }

        let rawSamples = zip(unique, unique.dropFirst()).compactMap { earlier, later -> IntervalSample? in
            let days = dayDistance(from: earlier.occurredAt, to: later.occurredAt)
            guard days > 0 else { return nil }
            return IntervalSample(
                earlierOccurrenceID: earlier.id,
                laterOccurrenceID: later.id,
                days: days,
                weight: max(0.01, (earlier.evidenceWeight + later.evidenceWeight) / 2),
                isOutlier: false
            )
        }
        guard rawSamples.count >= 2 else { throw IntervalEstimatorError.insufficientOccurrences }

        let values = rawSamples.map(\.days)
        let initialMedian = median(values)
        let deviations = values.map { abs($0 - initialMedian) }
        let mad = median(deviations)
        let robustSigma = 1.4826 * mad
        let threshold = max(3 * robustSigma, initialMedian * 0.35, 3)

        let markedSamples = rawSamples.map { sample in
            var updated = sample
            updated.isOutlier = abs(sample.days - initialMedian) > threshold
            return updated
        }
        let validSamples = markedSamples.filter { !$0.isOutlier }
        guard !validSamples.isEmpty else { throw IntervalEstimatorError.insufficientOccurrences }

        let weighted = weightedMedian(validSamples.map { ($0.days, $0.weight) })
        let validValues = validSamples.map(\.days)
        let iqr = interquartileRange(validValues)
        let rawVariation = ceil(max(robustSigma, iqr / 2, 2))
        let maximumVariation = max(2, Int((weighted * 0.30).rounded(.down)))
        let variation = min(maximumVariation, max(2, Int(rawVariation)))

        return IntervalEstimate(
            baseIntervalDays: max(1, Int(weighted.rounded())),
            medianIntervalDays: weighted,
            variationDays: variation,
            robustSigma: robustSigma,
            samples: markedSamples,
            validOccurrenceCount: unique.count
        )
    }

    private func deduplicatedByDay(_ values: [RhythmOccurrence]) -> [RhythmOccurrence] {
        var seenDays = Set<Date>()
        return values.filter { occurrence in
            let day = calendar.startOfDay(for: occurrence.occurredAt)
            return seenDays.insert(day).inserted
        }
    }

    private func dayDistance(from start: Date, to end: Date) -> Double {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return Double(calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func weightedMedian(_ values: [(value: Double, weight: Double)]) -> Double {
        let sorted = values.sorted { $0.value < $1.value }
        let midpoint = sorted.reduce(0) { $0 + $1.weight } / 2
        var cumulative = 0.0
        for (index, item) in sorted.enumerated() {
            cumulative += item.weight
            if cumulative == midpoint, sorted.indices.contains(index + 1) {
                return (item.value + sorted[index + 1].value) / 2
            }
            if cumulative > midpoint { return item.value }
        }
        return sorted.last?.value ?? 0
    }

    private func interquartileRange(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard sorted.count >= 4 else { return 0 }
        let midpoint = sorted.count / 2
        let lower = Array(sorted[..<midpoint])
        let upper = Array(sorted[(sorted.count.isMultiple(of: 2) ? midpoint : midpoint + 1)...])
        return max(0, median(upper) - median(lower))
    }
}
