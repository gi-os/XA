import XCTest
@testable import XA

/// Ported from Roll's ExposureTest.kt. Exposure arithmetic is wrong quietly: a rebalance off
/// by a stop hands back a photograph a stop dark.
final class ExposureTests: XCTestCase {
    private let shutterRange: ClosedRange<Int64> = 1_000...30_000_000_000
    private let isoRange: ClosedRange<Int> = 50...3200

    func testFastShuttersReadAsFractions() {
        XCTAssertEqual(Exposure.shutterLabel(Exposure.stopToNanos(125)), "1/125")
        XCTAssertEqual(Exposure.shutterLabel(Exposure.stopToNanos(8000)), "1/8000")
    }

    func testSlowShuttersReadInSeconds() {
        XCTAssertEqual(Exposure.shutterLabel(Exposure.nanosPerSecond), "1.0\"")
        XCTAssertEqual(Exposure.shutterLabel(2 * Exposure.nanosPerSecond), "2.0\"")
        XCTAssertEqual(Exposure.shutterLabel(30 * Exposure.nanosPerSecond), "30\"")
    }

    func testANonsenseExposureReadsAsNothing() {
        XCTAssertEqual(Exposure.shutterLabel(0), "—")
        XCTAssertEqual(Exposure.shutterLabel(-1), "—")
    }

    func testTheDialClampsInsteadOfWrapping() {
        XCTAssertEqual(Exposure.stepIndex(size: Exposure.shutterStops.count, index: 0, notches: -6), 0)
        let last = Exposure.shutterStops.count - 1
        XCTAssertEqual(Exposure.stepIndex(size: Exposure.shutterStops.count, index: last, notches: 9), last)
    }

    func testAnEmptyOrStaleIndexCannotThrow() {
        XCTAssertEqual(Exposure.stepIndex(size: 0, index: 5, notches: 2), 0)
        XCTAssertGreaterThan(Exposure.shutterAt(9999), 0)
        XCTAssertGreaterThan(Exposure.isoAt(-3), 0)
    }

    func testLeavingAutoStartsAtTheStopNearestTheMeter() {
        let metered = Exposure.stopToNanos(60)
        XCTAssertEqual(Exposure.shutterAt(Exposure.nearestShutterIndex(metered)), Exposure.stopToNanos(60))
        XCTAssertEqual(Exposure.isoAt(Exposure.nearestIsoIndex(390)), 400)
    }

    func testIsoWithinTheSensorAsksForNoBoost() {
        let r = Exposure.splitIso(1600, sensorMax: 3200)
        XCTAssertEqual(r.iso, 1600); XCTAssertEqual(r.boost, 100)
    }

    func testIsoPastTheSensorBecomesGainAfterTheReadout() {
        let r = Exposure.splitIso(6400, sensorMax: 3200)
        XCTAssertEqual(r.iso, 3200); XCTAssertEqual(r.boost, 200)
    }

    func testTheBoostHasTheAPIsOwnCeiling() {
        let r = Exposure.splitIso(1_000_000, sensorMax: 100)
        XCTAssertEqual(r.iso, 100); XCTAssertLessThanOrEqual(r.boost, 3199)
    }

    func testHoldingTheShutterOpenLetsTheMeterDropTheIso() {
        let r = Exposure.rebalance(meteredShutter: Exposure.stopToNanos(60), meteredIso: 800, heldShutter: Exposure.stopToNanos(30), heldIso: nil, shutterRange: shutterRange, isoRange: isoRange)
        XCTAssertEqual(r.shutter, Exposure.stopToNanos(30)); XCTAssertEqual(r.iso, 400)
    }

    func testHoldingTheIsoDownLetsTheMeterSlowTheShutter() {
        let r = Exposure.rebalance(meteredShutter: Exposure.stopToNanos(60), meteredIso: 800, heldShutter: nil, heldIso: 400, shutterRange: shutterRange, isoRange: isoRange)
        XCTAssertEqual(r.iso, 400); XCTAssertEqual(Exposure.shutterLabel(r.shutter), "1/30")
    }

    func testFullManualTakesBothAsGiven() {
        let r = Exposure.rebalance(meteredShutter: Exposure.stopToNanos(60), meteredIso: 800, heldShutter: Exposure.stopToNanos(1000), heldIso: 100, shutterRange: shutterRange, isoRange: isoRange)
        XCTAssertEqual(r.shutter, Exposure.stopToNanos(1000)); XCTAssertEqual(r.iso, 100)
    }

    func testAutoChangesNothing() {
        let r = Exposure.rebalance(meteredShutter: Exposure.stopToNanos(60), meteredIso: 800, heldShutter: nil, heldIso: nil, shutterRange: shutterRange, isoRange: isoRange)
        XCTAssertEqual(r.shutter, Exposure.stopToNanos(60)); XCTAssertEqual(r.iso, 800)
    }

    func testTheClampIsWhereTheExposureStopsBeingHoldable() {
        let r = Exposure.rebalance(meteredShutter: Exposure.stopToNanos(2000), meteredIso: 50, heldShutter: 30 * Exposure.nanosPerSecond, heldIso: nil, shutterRange: shutterRange, isoRange: isoRange)
        XCTAssertEqual(r.shutter, 30 * Exposure.nanosPerSecond); XCTAssertEqual(r.iso, 50)
        XCTAssertFalse(Exposure.withinRange(shutter: r.shutter, iso: 20, shutterRange: shutterRange, isoRange: isoRange))
    }

    func testOnlyAutoLeavesTheMeterInCharge() {
        XCTAssertFalse(ExposureMode.auto.manualAe)
        XCTAssertTrue(ExposureMode.shutter.manualAe)
        XCTAssertTrue(ExposureMode.iso.manualAe)
        XCTAssertTrue(ExposureMode.manual.manualAe)
    }

    func testEachModeHoldsTheHalfItIsNamedFor() {
        XCTAssertTrue(ExposureMode.shutter.holdsShutter); XCTAssertFalse(ExposureMode.shutter.holdsIso)
        XCTAssertTrue(ExposureMode.iso.holdsIso); XCTAssertFalse(ExposureMode.iso.holdsShutter)
        XCTAssertTrue(ExposureMode.manual.holdsShutter && ExposureMode.manual.holdsIso)
        XCTAssertFalse(ExposureMode.auto.holdsShutter || ExposureMode.auto.holdsIso)
        XCTAssertEqual(ExposureMode.from(holdsShutter: true, holdsIso: false), .shutter)
    }
}
