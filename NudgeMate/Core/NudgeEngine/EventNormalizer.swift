import Foundation

struct EventNormalizer: Sendable {
    private let locale: Locale
    private let aliases: [String: String]

    private let koreanStopwords: Set<String> = [
        "예약", "방문", "일정", "약속", "캘린더", "리마인더"
    ]

    private let englishStopwords: Set<String> = [
        "appointment", "booking", "visit", "schedule", "scheduled", "event", "reminder"
    ]

    init(locale: Locale = Locale(identifier: "ko_KR"), aliases: [String: String] = [:]) {
        self.locale = locale
        self.aliases = aliases
    }

    func normalize(_ title: String) -> String {
        let compatibilityNormalized = title.precomposedStringWithCompatibilityMapping
        let folded = compatibilityNormalized.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale
        )

        let scalarFiltered = folded.unicodeScalars.map { scalar -> Character in
            if scalar.properties.isEmojiPresentation {
                return " "
            }
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(String(scalar))
            }
            return " "
        }

        let tokens = String(scalarFiltered)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !isDateOrTimeToken($0) }
            .filter { !koreanStopwords.contains($0) && !englishStopwords.contains($0) }

        let normalized = tokens.joined(separator: " ")
        return aliases[normalized] ?? normalized
    }

    func tokens(in normalizedTitle: String) -> Set<String> {
        Set(normalizedTitle.split(whereSeparator: \.isWhitespace).map(String.init))
    }

    private func isDateOrTimeToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return true }
        if token.allSatisfy(\.isNumber) { return true }

        let lowercased = token.lowercased()
        if lowercased.range(
            of: #"^(am|pm)?\d{1,2}(am|pm)$"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return false
    }
}
