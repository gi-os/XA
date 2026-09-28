import XCTest
import CoreImage
@testable import XA

final class LooksTests: XCTestCase {
    func testTitlesAreUnique() {
        XCTAssertEqual(Set(Look.allCases.map(\.title)).count, Look.allCases.count)
    }

    func testCubeSize() {
        XCTAssertEqual(Looks.sixteenCube.count, 32 * 32 * 32 * 4 * MemoryLayout<Float>.size)
    }

    func testPaletteColorsMapToThemselves() {
        for c in Looks.sixteen {
            let n = Looks.nearest(c, in: Looks.sixteen)
            XCTAssertEqual(n.0, c.0); XCTAssertEqual(n.1, c.1); XCTAssertEqual(n.2, c.2)
        }
    }

    func testEveryLookKeepsTheFrameShape() {
        let src = CIImage(color: CIColor(red: 0.6, green: 0.4, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 400, height: 300))
        for l in Look.allCases {
            let out = Looks.apply(l, to: src)
            XCTAssertEqual(out.extent.width / out.extent.height, 400.0 / 300.0, accuracy: 0.02, "\(l.title)")
            XCTAssertNotNil(Looks.context.createCGImage(out, from: out.extent), "\(l.title) did not render")
        }
    }
}
