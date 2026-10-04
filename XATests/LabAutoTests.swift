import XCTest
@testable import XA

final class LabAutoTests: XCTestCase {
    func testAGreyColdDayIsPrintedUpAndWarmer() {
        // an overcast frame: dim and blue (sRGB-encoded averages)
        let v = LabAuto.gains([0.30, 0.33, 0.40], 0.7)
        XCTAssertGreaterThan(v.y, 1.2)            // printed brighter
        XCTAssertGreaterThan(v.x, v.z)            // and warmer
    }

    func testANormalFrameIsLeftNearlyAlone() {
        let v = LabAuto.gains([0.45, 0.44, 0.43], 0.7)
        XCTAssertEqual(v.y, 1.2, accuracy: 0.15)  // only film's third of a stop
        XCTAssertEqual(v.x / v.z, 1, accuracy: 0.08)
    }

    func testNightStaysNight() {
        let v = LabAuto.gains([0.05, 0.05, 0.05], 0.7)
        XCTAssertLessThan(v.y, 3.0)                // corrected only part of the way
    }

    func testOffDoesNothing() {
        let v = LabAuto.gains([0.2, 0.3, 0.5], 0)
        XCTAssertEqual(v.x, 1, accuracy: 1e-6); XCTAssertEqual(v.y, 1, accuracy: 1e-6); XCTAssertEqual(v.z, 1, accuracy: 1e-6)
    }
}
