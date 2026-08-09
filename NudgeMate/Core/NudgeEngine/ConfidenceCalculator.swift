import Foundation

struct ConfidenceInput: Sendable {
    var sampleCount: Int
    var variationDays: Int
    var baseIntervalDays: Int
    var averageSimilarity: Double
    var daysSinceLastOccurrence: Int
    var confirmedOccurrenceCount: Int
}

struct ConfidenceResult: Hashable, Sendable {
    var score: Double
    var band: ConfidenceBand
}

struct ConfidenceCalculator: Sendable {
    func calculate(_ input: ConfidenceInput) -> ConfidenceResult {
        let sampleScore = clamp(Double(input.sampleCount - 2) / 4)
        let variationRatio = Double(input.variationDays) / Double(max(1, input.baseIntervalDays))
        let consistencyScore = clamp(1 - variationRatio / 0.30)
        let similarityScore = clamp(input.averageSimilarity)
        let recencyLimit = max(1, input.baseIntervalDays * 3)
        let recencyScore = clamp(1 - Double(input.daysSinceLastOccurrence) / Double(recencyLimit))
        let confirmationScore = max(0.35, clamp(Double(input.confirmedOccurrenceCount) / 3))

        let score = clamp(
            0.25 * sampleScore
                + 0.35 * consistencyScore
                + 0.20 * similarityScore
                + 0.10 * recencyScore
                + 0.10 * confirmationScore
        )
        let band: ConfidenceBand = if score >= 0.80 {
            .high
        } else if score >= 0.60 {
            .medium
        } else {
            .low
        }
        return ConfidenceResult(score: score, band: band)
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
