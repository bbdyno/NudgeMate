import Foundation

struct PatternDetectionConfiguration: Sendable {
    var minimumSampleCount = 3
    var similarityThreshold = 0.72
}

struct PatternCandidateDetector: Sendable {
    let calendar: Calendar
    let configuration: PatternDetectionConfiguration
    let similarityCalculator: EventSimilarityCalculator

    init(
        calendar: Calendar,
        configuration: PatternDetectionConfiguration = .init(),
        similarityCalculator: EventSimilarityCalculator = .init()
    ) {
        self.calendar = calendar
        self.configuration = configuration
        self.similarityCalculator = similarityCalculator
    }

    func groups(from events: [CalendarEventSnapshot]) -> [[CalendarEventSnapshot]] {
        let eligible = events
            .filter { !$0.normalizedTitle.isEmpty && !$0.hasRecurrenceRules && $0.status != .cancelled }
            .sorted {
                if $0.normalizedTitle == $1.normalizedTitle { return $0.startDate < $1.startDate }
                return $0.normalizedTitle < $1.normalizedTitle
            }

        var groups: [[CalendarEventSnapshot]] = []
        for event in eligible {
            if let index = groups.firstIndex(where: { group in
                guard let representative = group.first else { return false }
                return representative.normalizedTitle == event.normalizedTitle
                    || similarityCalculator.score(representative, event) >= configuration.similarityThreshold
            }) {
                groups[index].append(event)
            } else {
                groups.append([event])
            }
        }

        return groups
            .filter { $0.count >= configuration.minimumSampleCount }
            .map { $0.sorted { $0.startDate < $1.startDate } }
    }
}
