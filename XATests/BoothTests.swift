import CoreImage
import UIKit
import XCTest
@testable import XA

final class BoothTests: XCTestCase {
    private func grey(_ w: CGFloat, _ h: CGFloat) -> CIImage {
        CIImage(color: CIColor(red: 0.5, green: 0.45, blue: 0.4)).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    }

    func testBoothIsTheFifthMode() {
        XCTAssertEqual(CaptureMode.allCases.last, .booth)
        XCTAssertTrue(CaptureMode.booth.developed)
        XCTAssertFalse(CaptureMode.booth.usesFilm)
    }

    func testEverySkinKeepsTheFrameAndBrightens() {
        let src = grey(300, 400)
        for skin in BoothSkin.allCases {
            let out = Booth.skin(src, skin, eyes: Booth.Eyes(points: [CGPoint(x: 120, y: 260), CGPoint(x: 180, y: 260)], span: 60))
            XCTAssertEqual(out.extent, src.extent, "\(skin)")
            var px = [Float](repeating: 0, count: 4)
            CIContext().render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 150, y: 200, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
            XCTAssertTrue(px.allSatisfy { $0.isFinite }, "\(skin)")
            XCTAssertGreaterThanOrEqual(px[0], 0.5, "\(skin) should not darken")
        }
    }

    func testBoothDevelopsFullSize() {
        var d = DevelopSettings()
        d.booth = .glow
        let (out, alpha) = Darkroom.develop(grey(4032, 3024), d, date: Date(), preview: false)
        XCTAssertEqual(out.extent.size, CGSize(width: 4032, height: 3024))
        XCTAssertFalse(alpha)
    }

    func testEveryLayoutMakesASheet() {
        let shot = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
        }
        for l in BoothLayout.allCases {
            let s = Booth.sheet(Array(repeating: shot, count: 4), layout: l, date: Date(), number: 7)
            XCTAssertNotNil(s, "\(l)")
            XCTAssertEqual(s?.size, Booth.sheetSize(l))
        }
        XCTAssertNil(Booth.sheet([], layout: .sheet, date: Date(), number: 1))
    }

    func testLayoutsWrap() {
        XCTAssertEqual(BoothLayout.sheet.step(1), .grid)
        XCTAssertEqual(BoothLayout.sheet.step(-1), .strip)
        XCTAssertEqual(BoothLayout.strip.step(1), .sheet)
    }
}
