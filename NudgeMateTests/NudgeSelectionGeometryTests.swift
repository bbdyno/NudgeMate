import CoreGraphics
@testable import NudgeMate
import XCTest

final class NudgeSelectionGeometryTests: XCTestCase {
    func testFindsItemAtTouchLocation() {
        let first = UUID()
        let second = UUID()
        let frames = [
            first: CGRect(x: 20, y: 100, width: 300, height: 80),
            second: CGRect(x: 20, y: 196, width: 300, height: 80)
        ]

        XCTAssertEqual(
            NudgeSelectionGeometry.itemID(
                at: CGPoint(x: 120, y: 130),
                itemFrames: frames
            ),
            first
        )
    }

    func testDragSegmentReturnsEveryCrossedItemInVisualOrder() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let frames = [
            first: CGRect(x: 20, y: 100, width: 300, height: 80),
            second: CGRect(x: 20, y: 196, width: 300, height: 80),
            third: CGRect(x: 20, y: 292, width: 300, height: 80)
        ]

        XCTAssertEqual(
            NudgeSelectionGeometry.itemIDs(
                between: CGPoint(x: 140, y: 120),
                and: CGPoint(x: 140, y: 340),
                itemFrames: frames
            ),
            [first, second, third]
        )
    }

    func testDragOutsideCardsReturnsNoItems() {
        let frames = [UUID(): CGRect(x: 20, y: 100, width: 300, height: 80)]

        XCTAssertTrue(
            NudgeSelectionGeometry.itemIDs(
                between: CGPoint(x: 340, y: 20),
                and: CGPoint(x: 340, y: 80),
                itemFrames: frames
            ).isEmpty
        )
    }
}
