import Foundation

struct EventSimilarityConfiguration: Sendable {
    var tokenWeight = 0.50
    var ngramWeight = 0.30
    var locationWeight = 0.10
    var calendarWeight = 0.10
    var mergeThreshold = 0.72
    var genericTokens: Set<String> = [
        "병원", "회의", "예약", "운동", "hospital", "meeting", "appointment", "workout"
    ]
}

struct EventSimilarityCalculator: Sendable {
    let configuration: EventSimilarityConfiguration

    init(configuration: EventSimilarityConfiguration = .init()) {
        self.configuration = configuration
    }

    func score(_ lhs: CalendarEventSnapshot, _ rhs: CalendarEventSnapshot) -> Double {
        guard !lhs.normalizedTitle.isEmpty, !rhs.normalizedTitle.isEmpty else { return 0 }

        let lhsTokens = Set(lhs.normalizedTitle.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.normalizedTitle.split(separator: " ").map(String.init))
        let tokenScore = jaccard(lhsTokens, rhsTokens)
        let ngramScore = diceBigrams(lhs.normalizedTitle, rhs.normalizedTitle)
        let locationScore = optionalTextScore(lhs.locationName, rhs.locationName)
        let calendarScore = lhs.calendarIdentifier == rhs.calendarIdentifier ? 1.0 : 0.0

        var result = configuration.tokenWeight * tokenScore
            + configuration.ngramWeight * ngramScore
            + configuration.locationWeight * locationScore
            + configuration.calendarWeight * calendarScore

        if lhsTokens.count == 1,
           rhsTokens.count == 1,
           let token = lhsTokens.first,
           configuration.genericTokens.contains(token) {
            result = min(result, configuration.mergeThreshold - 0.01)
        }

        return min(1, max(0, result))
    }

    private func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(union.count)
    }

    private func diceBigrams(_ lhs: String, _ rhs: String) -> Double {
        let left = ngrams(lhs, size: 2)
        let right = ngrams(rhs, size: 2)
        guard !left.isEmpty, !right.isEmpty else { return lhs == rhs ? 1 : 0 }
        return (2 * Double(left.intersection(right).count)) / Double(left.count + right.count)
    }

    private func ngrams(_ value: String, size: Int) -> Set<String> {
        let characters = Array(value.replacingOccurrences(of: " ", with: ""))
        guard characters.count >= size else { return value.isEmpty ? [] : [value] }
        return Set((0...(characters.count - size)).map { index in
            String(characters[index..<(index + size)])
        })
    }

    private func optionalTextScore(_ lhs: String?, _ rhs: String?) -> Double {
        guard let lhs, let rhs, !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        let left = lhs.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let right = rhs.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return diceBigrams(left, right)
    }
}
