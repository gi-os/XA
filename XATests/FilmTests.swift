import XCTest
import CoreImage
@testable import XA

final class FilmTests: XCTestCase {
    // MARK: DIGI

    func testDigicamShrinksToTheChosenResolution() {
        let s = CGSize(width: 4032, height: 3024)
        XCTAssertEqual(Digicam.size(for: s, megapixels: 2), CGSize(width: 1600, height: 1200))
        XCTAssertEqual(Digicam.size(for: s, megapixels: 1), CGSize(width: 1152, height: 864))
        XCTAssertEqual(Digicam.size(for: s, megapixels: 5), CGSize(width: 2592, height: 1944))
    }

    func testDigicamLeavesSmallFramesAlone() {
        XCTAssertEqual(Digicam.size(for: CGSize(width: 800, height: 600)), CGSize(width: 800, height: 600))
    }

    // MARK: PRO lenses

    func testTripleCameraGetsHalfOneTwoAndTele() {
        let l = Lenses.stops(switchOvers: [2, 10], maxZoom: 100, multiplier: 0.5)
        XCTAssertEqual(l.map(\.label), [".5", "1", "2", "5"])
        XCTAssertEqual(Lenses.main(switchOvers: [2, 10], multiplier: 0.5), 2)
    }

    func testASingleLensGetsACrop() {
        XCTAssertEqual(Lenses.stops(switchOvers: [], maxZoom: 10, multiplier: 1).map(\.label), ["1", "2"])
    }

    func testTheCropIsNotDuplicatedByATwoTimesTele() {
        XCTAssertEqual(Lenses.stops(switchOvers: [2], maxZoom: 10, multiplier: 1).map(\.label), ["1", "2"])
    }

    // MARK: sims

    func testThereAreSevenPresetsWithUniqueIDs() {
        XCTAssertEqual(Sim.presets.count, 7)
        XCTAssertEqual(Set(Sim.presets.map(\.id)).count, 7)
        XCTAssertEqual(Set(Sim.presets.map(\.name)).count, 7)
    }

    func testASimSurvivesARoundTrip() throws {
        let s = Sim.presets[0]
        let back = try JSONDecoder().decode(Sim.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }

    func testTheNeutralSimLeavesColourAlone() {
        let c = SimEngine.map(Sim.neutral, (0.3, 0.55, 0.8))
        XCTAssertEqual(c.0, 0.3, accuracy: 0.02)
        XCTAssertEqual(c.1, 0.55, accuracy: 0.02)
        XCTAssertEqual(c.2, 0.8, accuracy: 0.02)
    }

    func testAMonoSimHasNoColour() {
        let onyx = Sim.presets.first { $0.mono }!
        let c = SimEngine.map(onyx, (0.9, 0.2, 0.1))
        XCTAssertEqual(c.0, c.1, accuracy: 0.001)
        XCTAssertEqual(c.1, c.2, accuracy: 0.001)
    }

    func testEverySimRenders() {
        let src = CIImage(color: CIColor(red: 0.6, green: 0.4, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 300, height: 400))
        for s in Sim.presets {
            let out = SimEngine.apply(s, to: src, preview: false)
            XCTAssertNotNil(Looks.context.createCGImage(out, from: out.extent), s.name)
        }
    }

    func testTheCubeIsTheRightSize() {
        XCTAssertEqual(SimEngine.cube(for: Sim.neutral).count, 32 * 32 * 32 * 4 * MemoryLayout<Float>.size)
    }

    // MARK: shapes and stacks

    func testEveryShapeSitsInsideTheFrameAndCoversTheMiddle() {
        let r = CGRect(x: 0, y: 0, width: 300, height: 400)
        for s in FrameShape.allCases where s != .none {
            let p = s.path(in: r)!
            XCTAssertTrue(r.insetBy(dx: -1, dy: -1).contains(p.boundingBox), "\(s)")
            XCTAssertTrue(p.contains(CGPoint(x: r.midX, y: r.midY)), "\(s)")
        }
        XCTAssertNil(FrameShape.none.path(in: r))
    }

    func testAShapeLeavesTransparentPixels() {
        let src = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 300, height: 400))
        let out = Shapes.apply(.porthole, to: src)
        var px = [UInt8](repeating: 0, count: 4)
        Looks.context.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 2, y: 2, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        XCTAssertEqual(px[3], 0, "the corner should be empty")
    }

    func testAnInstantSimTakesOverTheShape() {
        let st = Stack(simID: "sunday", look: .none, shape: .crush)
        XCTAssertNil(st.effectiveShape)
        XCTAssertEqual(Stack(simID: "nocturne", look: .none, shape: .crush).effectiveShape, .crush)
    }

    func testAStackSurvivesARoundTrip() throws {
        let st = Stack(simID: "visage", look: .sixteen, shape: .nova)
        XCTAssertEqual(try JSONDecoder().decode(Stack.self, from: JSONEncoder().encode(st)), st)
    }

    func testEveryFilmHasABox() {
        XCTAssertEqual(FilmCatalog.looks.count, Look.allCases.count)
        XCTAssertEqual(FilmCatalog.shapes.count, FrameShape.allCases.count - 1)
    }
}
