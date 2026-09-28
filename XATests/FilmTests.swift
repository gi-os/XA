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
        XCTAssertEqual(Digicam.size(for: s, megapixels: 8), CGSize(width: 3264, height: 2448))
        XCTAssertEqual(Digicam.size(for: s, megapixels: 12), s)
    }

    func testEveryResolutionOptionIsItsOwnSize() {
        let s = CGSize(width: 4032, height: 3024)
        let sizes = AppSettings.digiOptions.map { Digicam.size(for: s, megapixels: $0).width }
        XCTAssertEqual(Set(sizes).count, sizes.count)
        XCTAssertEqual(sizes, sizes.sorted())
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
        // Portrait and landscape: a landscape photo must not make a corner radius too big.
        for r in [CGRect(x: 0, y: 0, width: 300, height: 400), CGRect(x: 0, y: 0, width: 400, height: 300)] {
            for s in FrameShape.allCases where s != .none {
                let p = s.path(in: r)!
                XCTAssertTrue(r.insetBy(dx: -1, dy: -1).contains(p.boundingBox), "\(s) in \(r.size)")
                XCTAssertTrue(p.contains(CGPoint(x: r.midX, y: r.midY)), "\(s) in \(r.size)")
            }
        }
        XCTAssertNil(FrameShape.none.path(in: CGRect(x: 0, y: 0, width: 10, height: 10)))
    }

    func testTheCapsuleIsWideEnoughToShoot() {
        let r = CGRect(x: 0, y: 0, width: 300, height: 400)
        XCTAssertGreaterThanOrEqual(FrameShape.capsule.path(in: r)!.boundingBox.width, 300 * 0.78)
    }

    func testTheHeartHasTwoLobesAndAPoint() {
        let r = CGRect(x: 0, y: 0, width: 300, height: 300)
        let p = FrameShape.crush.path(in: r)!
        // The cleft between the lobes is outside; each lobe is inside.
        let top = p.boundingBox.minY
        XCTAssertFalse(p.contains(CGPoint(x: r.midX, y: top + 4)))
        XCTAssertTrue(p.contains(CGPoint(x: r.midX - 60, y: top + 30)))
        XCTAssertTrue(p.contains(CGPoint(x: r.midX + 60, y: top + 30)))
    }

    func testGrainIsMonochromeAndCentred() {
        let src = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 200, height: 200))
        let out = FilmGrain.apply(src, amount: 1, size: 0.5)
        var px = [Float](repeating: 0, count: 4)
        Looks.context.render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 100, y: 100, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        XCTAssertEqual(px[0], px[1], accuracy: 0.001)
        XCTAssertEqual(px[1], px[2], accuracy: 0.001)
        var avg = [Float](repeating: 0, count: 4)
        let f = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: out, kCIInputExtentKey: CIVector(cgRect: out.extent)])!.outputImage!
        Looks.context.render(f, toBitmap: &avg, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        XCTAssertEqual(avg[0], px.isEmpty ? 0 : 0.5, accuracy: 0.08, "grain should not brighten or darken the picture")
    }

    func testSwipingThroughFilmsWraps() {
        let cam = CameraModel(settings: AppSettings())
        cam.stack = Stack(simID: nil, look: .none, shape: .none)
        cam.stepLook(-1)
        XCTAssertEqual(cam.stack.look, Look.allCases.last)
        cam.stepLook(1)
        XCTAssertEqual(cam.stack.look, Look.none)
        cam.stepSim(1)
        XCTAssertEqual(cam.stack.simID, FilmCatalog.sims.first?.id)
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
