import XCTest
@testable import NudgeMate

final class EventNormalizerTests: XCTestCase {
    private let normalizer = EventNormalizer(locale: Locale(identifier: "ko_KR"))

    func testRemovesKoreanBookingWord() {
        XCTAssertEqual(normalizer.normalize("미용실 예약"), "미용실")
    }

    func testRemovesEnglishAppointmentWord() {
        XCTAssertEqual(normalizer.normalize("Haircut Appointment"), "haircut")
    }

    func testRemovesEmojiAndCollapsesWhitespace() {
        XCTAssertEqual(normalizer.normalize("  미용실   예약 ✂️  "), "미용실")
    }

    func testPreservesMeaningfulAlphaNumericTokens() {
        XCTAssertEqual(normalizer.normalize("F45 운동"), "f45 운동")
        XCTAssertEqual(normalizer.normalize("K5 엔진오일 교체"), "k5 엔진오일 교체")
    }

    func testRemovesStandaloneDateTokens() {
        XCTAssertEqual(normalizer.normalize("2026 08 10 미용실"), "미용실")
    }

    func testReturnsEmptyWhenOnlyGenericWordsRemain() {
        XCTAssertEqual(normalizer.normalize("예약 방문 일정"), "")
        XCTAssertEqual(normalizer.normalize(""), "")
    }

    func testAppliesAliasAfterNormalization() {
        let aliased = EventNormalizer(aliases: ["준오헤어 커트": "미용실"])
        XCTAssertEqual(aliased.normalize("준오헤어 커트 예약"), "미용실")
    }

    func testUsesUnicodeCompatibilityNormalization() {
        XCTAssertEqual(normalizer.normalize("Ｈａｉｒｃｕｔ"), "haircut")
    }
}
