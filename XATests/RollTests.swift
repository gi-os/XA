import XCTest
@testable import XA

final class RollTests: XCTestCase {
    private func item(_ id: String, _ t: TimeInterval, w: Int = 3000, h: Int = 4000, video: Bool = false) -> RollPiles.Item {
        RollPiles.Item(id: id, date: Date(timeIntervalSince1970: t), width: w, height: h, isVideo: video)
    }

    func testShotsSecondsApartMakeOnePile() {
        // Newest first, as the roll lists them.
        let items = [item("a", 100), item("b", 97), item("c", 92), item("d", 40), item("e", 38)]
        XCTAssertEqual(RollPiles.group(items), [[0, 1, 2], [3, 4]])
    }

    func testTurningThePhoneOrAVideoStartsANewPile() {
        let items = [item("a", 100), item("b", 99, w: 4000, h: 3000), item("c", 98, video: true), item("d", 97)]
        XCTAssertEqual(RollPiles.group(items), [[0], [1], [2], [3]])
    }

    func testAnUnclippedPileLiesFlat() {
        let items = [item("a", 100), item("b", 99), item("c", 98)]
        XCTAssertEqual(RollPiles.group(items, unclipped: ["a"]), [[0], [1, 2]])
    }
}
