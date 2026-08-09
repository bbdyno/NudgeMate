import XCTest
@testable import NudgeMate

final class StoreKitConfigurationTests: XCTestCase {
    func testProductIdentifiersAreStable() {
        XCTAssertEqual(
            SubscriptionManager.productIDs,
            [
                "com.nudgemate.pro.monthly",
                "com.nudgemate.pro.yearly",
                "com.nudgemate.pro.lifetime"
            ]
        )
    }

    func testStoreKitConfigurationContainsEveryProduct() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let configurationURL = projectRoot
            .appendingPathComponent("NudgeMate/Resources/NudgeMate.storekit")
        let data = try Data(contentsOf: configurationURL)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = object["products"] as? [[String: Any]] ?? []
        let groups = object["subscriptionGroups"] as? [[String: Any]] ?? []
        let subscriptions = groups.flatMap { $0["subscriptions"] as? [[String: Any]] ?? [] }
        let identifiers = Set((products + subscriptions).compactMap { $0["productID"] as? String })
        XCTAssertEqual(identifiers, SubscriptionManager.productIDs)
    }
}
