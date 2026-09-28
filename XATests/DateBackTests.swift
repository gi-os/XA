import XCTest
@testable import XA

/// Ported from Roll's DateStampTest.kt. The text is the part of a stamp that can be checked
/// without a screen, and the palette is the other half.
final class DateBackTests: XCTestCase {
    private func at(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    func testMonthDayApostropheYear() {
        XCTAssertEqual(DateBack.format(at(2021, 11, 5)), "11  5 '21")
    }

    func testSingleDigitsAreSpacePaddedNotZeroPadded() {
        XCTAssertEqual(DateBack.format(at(1999, 3, 7)), " 3  7 '99")
    }

    func testTwoDigitDaysAndMonthsKeepTheSameWidth() {
        XCTAssertEqual(DateBack.format(at(2026, 12, 25)), "12 25 '26")
        XCTAssertEqual(DateBack.format(at(2026, 1, 1)).count, 9)
        XCTAssertEqual(DateBack.format(at(2026, 12, 31)).count, 9)
    }

    func testTheYearIsTwoDigitsAndWrapsAtTheCentury() {
        XCTAssertEqual(DateBack.format(at(2000, 1, 1)), " 1  1 '00")
        XCTAssertEqual(DateBack.format(at(2008, 1, 1)), " 1  1 '08")
    }

    func testQuartzPutsTheYearFirstAndPadsWithZeroes() {
        XCTAssertEqual(DateBack.format(at(1999, 12, 29), style: .quartz), "'99 12 29")
        XCTAssertEqual(DateBack.format(at(2021, 11, 5), style: .quartz), "'21 11 05")
    }

    func testTheCamcorderStampUsesSlashesAndFourDigits() {
        XCTAssertEqual(DateBack.format(at(2015, 8, 31), style: .camcorder), "08/31/2015")
        XCTAssertEqual(DateBack.format(at(2026, 1, 1), style: .camcorder), "01/01/2026")
    }

    func testOtherFormatsOverrideTheStylesOwn() {
        XCTAssertEqual(DateBack.format(at(2026, 9, 28), style: .quartz, format: .dmy), "28.09.26")
        XCTAssertEqual(DateBack.format(at(2026, 9, 28), style: .dots, format: .long), "SEP 28 2026")
    }

    // MARK: the palette

    private func chroma(_ c: RGBA8) -> Int { max(c.r, c.g, c.b) - min(c.r, c.g, c.b) }

    func testInColourEveryRollStyleKeepsItsOwnLamp() {
        for style in [DateStyle.dots, .quartz, .camcorder] {
            let ink = DateBack.inkFor(style, mono: false)
            XCTAssertGreaterThan(chroma(ink.lamp), 60, "\(style) went grey")
            XCTAssertGreaterThan(ink.lamp.r, ink.lamp.b, "\(style) lamp is not warm")
        }
    }

    func testOnABlackAndWhitePhotographTheLampIsNeutral() {
        for style in DateStyle.allCases {
            let ink = DateBack.inkFor(style, mono: true)
            XCTAssertEqual(chroma(ink.lamp), 0, "\(style) still has a hue on a mono frame")
            XCTAssertEqual(chroma(ink.halo), 0, "\(style) halo is not neutral")
        }
    }

    func testTheMonoStampReadsOnWhiteAsWellAsOnBlack() {
        // Marker is dark ink on its own tape, so it reads either way already.
        for style in DateStyle.allCases where style != .marker {
            let ink = DateBack.inkFor(style, mono: true)
            XCTAssertGreaterThan(ink.lamp.r, 200, "\(style) lamp is not light")
            XCTAssertLessThan(ink.halo.r, 40, "\(style) halo is not dark")
            XCTAssertGreaterThanOrEqual(ink.halo.a, 100, "\(style) halo is too faint")
        }
    }

    // MARK: following the frame

    func testAWalkAlongAStraightLineIsTheLine() {
        let w = PathWalker(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        XCTAssertEqual(w.length, 100, accuracy: 0.001)
        let p = w.point(at: 25)
        XCTAssertEqual(p.position.x, 25, accuracy: 0.001)
        XCTAssertEqual(p.angle, 0, accuracy: 0.001)
    }

    func testAWalkClampsAtTheEnds() {
        let w = PathWalker(points: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 10)])
        XCTAssertEqual(w.point(at: -5).position.y, 0, accuracy: 0.001)
        XCTAssertEqual(w.point(at: 50).position.y, 10, accuracy: 0.001)
    }

    func testTheCircleArcRunsLeftToRightAlongTheBottom() {
        let pts = DateBack.circleArc(center: CGPoint(x: 50, y: 50), radius: 40, from: 112, to: 18)
        XCTAssertLessThan(pts.first!.x, pts.last!.x)
        let mid = PathWalker(points: pts).point(at: PathWalker(points: pts).length / 2)
        // Heading right and up at the lower right, so glyph tops point at the centre.
        XCTAssertLessThan(mid.angle, 0)
        XCTAssertGreaterThan(mid.angle, -.pi / 2)
    }

    func testEveryStyleRendersIntoAnImage() {
        let cfg = { (s: DateStyle, p: DatePlacement) in DateConfig(style: s, placement: p, format: .own, time: false) }
        for s in DateStyle.allCases {
            for shape in [FrameShape.none, .porthole, .crush] {
                let img = DateBack.overlay(size: CGSize(width: 300, height: 400), date: at(2026, 9, 28), config: cfg(s, .follow), shape: shape, mono: false)
                XCTAssertNotNil(img, "\(s) on \(shape)")
            }
        }
        XCTAssertNil(DateBack.overlay(size: CGSize(width: 300, height: 400), date: Date(), config: cfg(.quartz, .off), shape: .none, mono: false))
    }
}
