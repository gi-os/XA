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

    func testAFlatPaleFrameGetsLevelsAndColour() {
        let v = LabAuto.levels(lo: 0.22, hi: 0.78, chroma: 0.05, 0.7)
        XCTAssertGreaterThan(v.x, 0.05)            // black point pulled up
        XCTAssertLessThan(v.y, 0.95)               // white point pulled down
        XCTAssertGreaterThan(v.z, 1.15)            // more colour
    }

    func testAPunchyFrameIsLeftAlone() {
        let v = LabAuto.levels(lo: 0.01, hi: 0.99, chroma: 0.3, 0.7)
        XCTAssertEqual(v.x, 0, accuracy: 0.01); XCTAssertEqual(v.y, 1, accuracy: 0.01); XCTAssertEqual(v.z, 1, accuracy: 0.001)
    }

    func testTheViewfinderCubeMatchesTheLab() {
        // a grey card through the baked cube prints like the full lab, within the cube's interpolation
        let lin = CGColorSpace(name: CGColorSpace.linearSRGB)!
        let grey = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1, colorSpace: lin)!).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 48))
        let ctx = CIContext(options: [.workingColorSpace: lin])
        for st in [FilmStock.all[0], FilmStock.all.first { $0.mono }!] {
            var shot = FilmShot(recipe: FilmRecipe(), seed: 1)
            shot.recipe.grain = 0; shot.recipe.halation = 0; shot.recipe.lens = 0; shot.recipe.labAuto = 0
            let fast = FilmPreview.develop(grey, stock: st, push: 0, seed: 1, shot: shot)!
            let full = FilmLab.develop(grey, stock: st, push: 0, preview: false, seed: 1, shot: shot)
            var a = [Float](repeating: 0, count: 4), b = [Float](repeating: 0, count: 4)
            ctx.render(fast, toBitmap: &a, rowBytes: 16, bounds: CGRect(x: 32, y: 24, width: 1, height: 1), format: .RGBAf, colorSpace: lin)
            ctx.render(full, toBitmap: &b, rowBytes: 16, bounds: CGRect(x: 32, y: 24, width: 1, height: 1), format: .RGBAf, colorSpace: lin)
            for c in 0..<3 { XCTAssertEqual(a[c], b[c], accuracy: 0.02, "\(st.id) channel \(c)") }
        }
    }
}
