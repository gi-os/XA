import XCTest
import StoreKitTest
@testable import XA

/// The tip jar against the local StoreKit file (StoreKit/Tips.storekit): the three tips load in
/// price order, and a tip goes through and is counted.
@MainActor
final class TipJarTests: XCTestCase {
    func testTipsLoadAndATipGoesThrough() async throws {
        let session = try SKTestSession(configurationFileNamed: "Tips")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        let jar = TipJar.shared
        await jar.load()
        // StoreKit's local test store isn't reachable from every command-line simulator run
        // (SKTestSession logs SKInternalErrorDomain 3 and offers nothing): run it from Xcode.
        if jar.products.isEmpty { throw XCTSkip("StoreKit's local test store isn't available in this run; run TipJarTests from Xcode") }
        XCTAssertEqual(jar.products.map(\.id), TipJar.ids, "small, medium, large, cheapest first")
        let before = jar.tips
        await jar.buy(try XCTUnwrap(jar.products.first))
        XCTAssertEqual(jar.tips, before + 1)
        XCTAssertTrue(jar.thanked)
        XCTAssertNil(jar.buying)
    }

    func testReviewPromptWaitsForRealUse() {
        let d = UserDefaults.standard
        for k in ["review.shots", "review.days", "review.version"] { d.removeObject(forKey: k) }
        XCTAssertFalse(ReviewPrompt.due)
        for _ in 0..<25 { ReviewPrompt.noteShot() }
        XCTAssertFalse(ReviewPrompt.due, "25 pictures on one day isn't three days of use")
        d.set(["1", "2", "3"], forKey: "review.days")
        XCTAssertTrue(ReviewPrompt.due)
        ReviewPrompt.asked()
        XCTAssertFalse(ReviewPrompt.due, "once a version")
        for k in ["review.shots", "review.days", "review.version"] { d.removeObject(forKey: k) }
    }
}
