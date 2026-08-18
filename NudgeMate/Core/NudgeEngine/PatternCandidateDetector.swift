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

        guard !eligible.isEmpty else { return [] }

        let rawKeys = eligible.map { blockingKeys(for: $0.normalizedTitle) }
        let keyFrequencies = rawKeys.reduce(into: [String: Int]()) { frequencies, keys in
            for key in keys {
                frequencies[key, default: 0] += 1
            }
        }
        var disjointSet = DisjointSet(count: eligible.count)
        var eventIndicesByKey: [String: [Int]] = [:]

        for (index, event) in eligible.enumerated() {
            let keys = rawKeys[index].filter {
                $0.hasPrefix("exact:") || keyFrequencies[$0, default: 0] <= 256
            }
            let candidates = Set(
                keys.flatMap { eventIndicesByKey[$0, default: []].suffix(64) }
            )

            for candidateIndex in candidates where similarityCalculator.shouldMerge(
                eligible[candidateIndex],
                event,
                threshold: configuration.similarityThreshold
            ) {
                disjointSet.union(index, candidateIndex)
            }

            for key in keys {
                eventIndicesByKey[key, default: []].append(index)
            }
        }

        var groupedIndices: [Int: [Int]] = [:]
        for index in eligible.indices {
            groupedIndices[disjointSet.root(of: index), default: []].append(index)
        }

        return groupedIndices.values
            .map { indices in indices.map { eligible[$0] } }
            .filter { $0.count >= configuration.minimumSampleCount }
            .map { $0.sorted { $0.startDate < $1.startDate } }
            .sorted {
                guard let left = $0.first, let right = $1.first else { return $0.count > $1.count }
                if left.normalizedTitle == right.normalizedTitle {
                    return left.startDate < right.startDate
                }
                return left.normalizedTitle < right.normalizedTitle
            }
    }

    private func blockingKeys(for normalizedTitle: String) -> Set<String> {
        let tokens = normalizedTitle
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return ["_"] }

        var keys = Set(tokens.map { "token:\(String($0.prefix(4)))" })
        keys.insert("exact:\(normalizedTitle)")
        if tokens.count == 1, let token = tokens.first, token.count > 4 {
            keys.insert("suffix:\(String(token.suffix(4)))")
        }
        return keys
    }
}

private struct DisjointSet {
    private var parents: [Int]
    private var ranks: [Int]

    init(count: Int) {
        parents = Array(0..<count)
        ranks = Array(repeating: 0, count: count)
    }

    mutating func root(of value: Int) -> Int {
        if parents[value] != value {
            parents[value] = root(of: parents[value])
        }
        return parents[value]
    }

    mutating func union(_ lhs: Int, _ rhs: Int) {
        let leftRoot = root(of: lhs)
        let rightRoot = root(of: rhs)
        guard leftRoot != rightRoot else { return }

        if ranks[leftRoot] < ranks[rightRoot] {
            parents[leftRoot] = rightRoot
        } else if ranks[leftRoot] > ranks[rightRoot] {
            parents[rightRoot] = leftRoot
        } else {
            parents[rightRoot] = leftRoot
            ranks[leftRoot] += 1
        }
    }
}
