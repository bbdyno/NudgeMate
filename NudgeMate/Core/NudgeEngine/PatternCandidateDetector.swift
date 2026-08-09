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

        var groupsByBlockingKey: [String: [[CalendarEventSnapshot]]] = [:]
        for event in eligible {
            let key = blockingKey(for: event.normalizedTitle)
            var groups = groupsByBlockingKey[key, default: []]
            if let index = groups.firstIndex(where: { group in
                guard let representative = group.first else { return false }
                return representative.normalizedTitle == event.normalizedTitle
                    || similarityCalculator.score(representative, event) >= configuration.similarityThreshold
            }) {
                groups[index].append(event)
            } else {
                groups.append([event])
            }
            groupsByBlockingKey[key] = groups
        }

        return groupsByBlockingKey.values.flatMap { $0 }
            .filter { $0.count >= configuration.minimumSampleCount }
            .map { $0.sorted { $0.startDate < $1.startDate } }
    }

    private func blockingKey(for normalizedTitle: String) -> String {
        let tokens = normalizedTitle
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
            .filter { !$0.isEmpty }
            .sorted()
        guard let token = tokens.first else { return "_" }
        return String(token.prefix(4))
    }
}
