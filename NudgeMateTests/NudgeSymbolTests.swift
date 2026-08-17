import UIKit
import XCTest
@testable import NudgeMate

final class NudgeSymbolTests: XCTestCase {
    func testEveryCategoryUsesAnAvailableDistinctBrandGlyph() {
        let assetNames = RhythmCategory.allCases.map(\.iconAssetName)

        XCTAssertEqual(Set(assetNames).count, RhythmCategory.allCases.count)
        for assetName in assetNames {
            XCTAssertNotNil(UIImage(named: assetName), "Missing brand glyph: \(assetName)")
        }
    }

    func testEverySharedAppBrandGlyphIsAvailable() {
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
            XCTAssertNotNil(UIImage(named: symbol.assetName), "Missing brand glyph: \(symbol.assetName)")
        }
    }

    func testEveryNavigationAndActionBrandGlyphIsAvailable() {
        let assetNames = [
            "glyph_tab_today",
            "glyph_tab_rhythms",
            "glyph_tab_prep",
            "glyph_tab_more",
            "glyph_add",
            "glyph_more",
            "glyph_select_all",
            "glyph_clear_selection",
            "glyph_disclosure",
            "glyph_settings"
        ]

        for assetName in assetNames {
            XCTAssertNotNil(UIImage(named: assetName), "Missing brand glyph: \(assetName)")
        }
    }
}
