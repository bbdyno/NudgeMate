import UIKit
import XCTest
@testable import NudgeMate

final class NudgeSymbolTests: XCTestCase {
    func testEveryCategoryUsesAnAvailableDistinctSystemSymbol() {
        let symbolNames = RhythmCategory.allCases.map(\.systemSymbolName)

        XCTAssertEqual(Set(symbolNames).count, RhythmCategory.allCases.count)
        for symbolName in symbolNames {
            XCTAssertNotNil(UIImage(systemName: symbolName), "Missing SF Symbol: \(symbolName)")
        }
    }

    func testEverySharedAppSymbolIsAvailable() {
        let symbols: [NudgeSymbol] = [
            .calendar,
            .reminder,
            .empty,
            .refresh,
            .success,
            .pro,
            .privacy
        ]

        for symbol in symbols {
            XCTAssertNotNil(UIImage(systemName: symbol.systemName), "Missing SF Symbol: \(symbol.systemName)")
        }
    }
}
