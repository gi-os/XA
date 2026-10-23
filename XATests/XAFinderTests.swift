import CoreImage
import XCTest
@testable import XA

final class XAFinderTests: XCTestCase {
    func testFrameSitsInsideTheFinderWithTheFormatsShape() {
        for f in FilmFormat.allCases {
            let r = XAFinder.frame(f)
            XCTAssertGreaterThan(r.minX, 0, "\(f)"); XCTAssertGreaterThan(r.minY, 0, "\(f)")
            XCTAssertLessThan(r.maxX, 1, "\(f)"); XCTAssertLessThan(r.maxY, 1, "\(f)")
            // portrait in the viewfinder (3 wide, 4 high): width/height in real units is the format's short/long
            XCTAssertEqual((r.width * 3) / (r.height * 4), f.aspect, accuracy: 0.01, "\(f)")
            XCTAssertTrue(r.contains(XAFinder.patch(f)), "\(f)")
            // the rangefinder patch sits in the middle of the bright frame
            XCTAssertEqual(XAFinder.patch(f).midX, r.midX, accuracy: 0.001, "\(f)")
            XCTAssertEqual(XAFinder.patch(f).midY, r.midY, accuracy: 0.001, "\(f)")
        }
    }

    func testNeedleRunsDownTheScaleAndIntoTheWarnings() {
        let fast = XAFinder.needle(1.0 / 4000), n500 = XAFinder.needle(1.0 / 500), n60 = XAFinder.needle(1.0 / 60)
        let n1 = XAFinder.needle(1), slow = XAFinder.needle(8)
        XCTAssertLessThan(fast, n500)
        XCTAssertLessThan(n500, n60)
        XCTAssertLessThan(n60, n1)
        XCTAssertLessThan(n1, slow)
        XCTAssertEqual(XAFinder.needle(1.0 / 125), 0.30, accuracy: 0.001)
    }

    func testComposeKeepsTheViewfindersSize() {
        let img = CIImage(color: CIColor(red: 0.4, green: 0.5, blue: 0.6)).cropped(to: CGRect(x: 0, y: 0, width: 360, height: 480))
        for f in FilmFormat.allCases {
            XCTAssertEqual(XAFinder.compose(img, format: f, shift: 0.5).extent, img.extent, "\(f)")
        }
    }

    func testUltraWideSurroundLinesUpAndMatchesColour() {
        let main = CIImage(color: CIColor(red: 0.5, green: 0.4, blue: 0.3)).cropped(to: CGRect(x: 0, y: 0, width: 360, height: 480))
        let wide = CIImage(color: CIColor(red: 0.25, green: 0.4, blue: 0.6)).cropped(to: CGRect(x: 0, y: 0, width: 300, height: 400))
        let g = XAFinder.matchGain(main: main, wide: wide, ratio: 2)
        XCTAssertNotNil(g)
        XCTAssertGreaterThan(g!.x, 1.5)          // the ultra-wide is too blue: red comes up
        XCTAssertLessThan(g!.z, 0.7)
        let out = XAFinder.compose(main, format: .mm35, shift: 0, wide: wide, ratio: 2, gain: g!)
        XCTAssertEqual(out.extent, main.extent)
    }
}
