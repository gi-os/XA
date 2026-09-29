import XCTest
import CoreImage
import ImageIO
import AVFoundation
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

    func testNeutralAndSevenStocksWithUniqueIDs() {
        XCTAssertEqual(Sim.presets.count, 7)
        XCTAssertEqual(Sim.presets.first?.id, Sim.neutral.id)
        XCTAssertEqual(Set(Sim.presets.map(\.id)).count, 7)
        XCTAssertEqual(Set(Sim.presets.map(\.name)).count, 7)
    }

    func testNoSimIsNeutral() {
        XCTAssertEqual(FilmCatalog.sim(nil)?.id, Sim.neutral.id)
        XCTAssertEqual(FilmCatalog.sim("gone")?.id, Sim.neutral.id)
    }

    func testTheRecipeNamesTheWholeStack() {
        let r = Recipe.describe(Stack(simID: "nocturne", look: .sixteen, shape: .porthole), megapixels: 2)
        XCTAssertEqual(r, "XA DIGI 2MP · NOCTURNE 800T + SIXTEEN + PORTHOLE")
        let p = Recipe.properties(from: [kCGImagePropertyOrientation as String: 6], recipe: r)
        XCTAssertEqual(p[kCGImagePropertyOrientation as String] as? Int, 1)
        XCTAssertEqual((p[kCGImagePropertyExifDictionary as String] as? [String: Any])?[kCGImagePropertyExifUserComment as String] as? String, r)
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
            // Instant prints print on paper instead of cutting an outline.
            for s in FrameShape.allCases where s != .none && s.instant == nil {
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
        func average(_ img: CIImage) -> Float {
            var v = [Float](repeating: 0, count: 4)
            let f = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: img, kCIInputExtentKey: CIVector(cgRect: img.extent)])!.outputImage!
            Looks.context.render(f, toBitmap: &v, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
            return v[0]
        }
        // Same working space on both sides, so this compares like with like.
        XCTAssertEqual(average(out), average(src), accuracy: 0.03, "grain should not brighten or darken the picture")
    }

    func testSwipingThroughFilmsWraps() {
        let cam = CameraModel(settings: AppSettings())
        cam.stack = Stack(simID: Sim.neutral.id, look: .none, shape: .none)
        cam.stepLook(-1)
        XCTAssertEqual(cam.stack.look, Look.allCases.last)
        cam.stepLook(1)
        XCTAssertEqual(cam.stack.look, Look.none)
        cam.stepSim(1)
        XCTAssertEqual(cam.stack.simID, FilmCatalog.sims[1].id)
        cam.stepSim(-2)
        XCTAssertEqual(cam.stack.simID, FilmCatalog.sims.last?.id)
    }

    func testAShapeLeavesTransparentPixels() {
        let src = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 300, height: 400))
        let out = Shapes.apply(.porthole, to: src)
        var px = [UInt8](repeating: 0, count: 4)
        Looks.context.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 2, y: 2, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        XCTAssertEqual(px[3], 0, "the corner should be empty")
    }

    func testInstantFilmIsAShape() {
        XCTAssertEqual(Stack(simID: "sunday", look: .none, shape: .polaroid).effectiveShape, .polaroid)
        XCTAssertEqual(FrameShape.polaroid.instant, .square)
        XCTAssertEqual(FrameShape.polaRound.instant, .round)
        XCTAssertEqual(FrameShape.instax.instant, .mini)
        XCTAssertEqual(FrameShape.instaxWide.instant, .wide)
        XCTAssertNil(FrameShape.crush.instant)
    }

    func testInstantPrintsHaveTheirFilmsProportions() {
        let src = CIImage(color: .gray).cropped(to: CGRect(x: 0, y: 0, width: 1200, height: 1600))
        let mini = Shapes.instant(src, kind: .mini).extent.size
        XCTAssertEqual(mini.width / mini.height, 54.0 / 86.0, accuracy: 0.02, "Instax Mini is 54 x 86")
        let wide = Shapes.instant(src, kind: .wide).extent.size
        XCTAssertEqual(wide.width / wide.height, 108.0 / 86.0, accuracy: 0.02, "Instax Wide is 108 x 86")
        let pola = Shapes.instant(src, kind: .square).extent.size
        XCTAssertEqual(pola.width / pola.height, 1.12 / 1.276, accuracy: 0.02, "Polaroid: square window, thick chin")
    }

    func testAStackSurvivesARoundTrip() throws {
        let st = Stack(simID: "visage", look: .sixteen, shape: .nova)
        XCTAssertEqual(try JSONDecoder().decode(Stack.self, from: JSONEncoder().encode(st)), st)
    }

    func testEveryFilmHasABox() {
        XCTAssertEqual(FilmCatalog.looks.count, Look.allCases.count)
        XCTAssertEqual(FilmCatalog.shapes.count, FrameShape.allCases.count - 1)
    }

    // MARK: video

    func testEveryVideoLookRendersTwiceInARow() {
        let src = CIImage(color: CIColor(red: 0.6, green: 0.4, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 360, height: 480))
        for l in VideoLook.allCases {
            let fx = VideoFX()
            for i in 0..<3 {
                let out = fx.apply(l, to: src, time: Double(i) / 30, date: Date())
                XCTAssertEqual(out.extent, src.extent, "\(l.title)")
                XCTAssertNotNil(Looks.context.createCGImage(out, from: out.extent), "\(l.title)")
            }
        }
    }

    /// Slit-scan, Motion, Trails and Datamosh keep frames between calls. A minute of frames
    /// must stay a picture, not a recipe that grows every frame (that took the camera down).
    func testLooksThatRememberFramesStayBounded() {
        let e = CGRect(x: 0, y: 0, width: 180, height: 240)
        for l in [VideoLook.slitScan, .motion, .trails, .datamosh] {
            let fx = VideoFX()
            var times: [TimeInterval] = []
            for i in 0..<90 {
                let c = CGFloat(i % 10) / 10
                let src = CIImage(color: CIColor(red: c, green: 0.4, blue: 1 - c)).cropped(to: e)
                let t0 = Date()
                let out = fx.apply(l, to: src, time: Double(i) / 30, date: Date())
                XCTAssertEqual(out.extent.width, e.width, accuracy: 0.5, "\(l.title)")
                XCTAssertNotNil(Looks.context.createCGImage(out, from: e), "\(l.title)")
                times.append(Date().timeIntervalSince(t0))
            }
            // Slit-scan fills its 30-frame memory first, so compare once it is full.
            let middle = times[30..<60].reduce(0, +), last = times[60..<90].reduce(0, +)
            XCTAssertLessThan(last, middle * 2.5 + 0.5, "\(l.title) slows down frame after frame")
        }
    }

    func testHeldLooksRepeatFrames() {
        let fx = VideoFX()
        let a = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let b = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let first = fx.apply(.stopMotion, to: a, time: 0, date: Date())
        let second = fx.apply(.stopMotion, to: b, time: 0.05, date: Date())
        XCTAssertTrue(first === second, "within a sixth of a second the frame is held")
    }

    func testOnlyBrightLightGlows() {
        let e = CGRect(x: 0, y: 0, width: 200, height: 200)
        let dark = CIImage(color: CIColor(red: 0.3, green: 0.3, blue: 0.3)).cropped(to: e)
        let out = SimEngine.glow(dark, halation: 1, tone: Tone(1, 0.3, 0.18), bloom: 1)
        var a = [Float](repeating: 0, count: 4), b = [Float](repeating: 0, count: 4)
        Looks.context.render(dark, toBitmap: &a, rowBytes: 16, bounds: CGRect(x: 100, y: 100, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        Looks.context.render(out, toBitmap: &b, rowBytes: 16, bounds: CGRect(x: 100, y: 100, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        XCTAssertEqual(a[0], b[0], accuracy: 0.001, "a grey wall does not glow")
    }

    func testAFilmSavedBeforeBloomStillLoads() throws {
        var s = Sim.nocturne
        s.bloomAmount = nil
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Sim.self, from: data)
        XCTAssertEqual(back.bloom, 0)
    }

    func testFocusPointsLandInTheSensorFrame() {
        // Portrait, back camera: the top-left of the viewfinder is the sensor's bottom-left.
        let p = FocusGeometry.devicePoint(fromView: CGPoint(x: 0, y: 0), front: false)
        XCTAssertEqual(p.x, 0, accuracy: 0.001); XCTAssertEqual(p.y, 1, accuracy: 0.001)
        let c = FocusGeometry.devicePoint(fromView: CGPoint(x: 0.5, y: 0.5), front: true)
        XCTAssertEqual(c.x, 0.5, accuracy: 0.001); XCTAssertEqual(c.y, 0.5, accuracy: 0.001)
        let clamped = FocusGeometry.devicePoint(fromView: CGPoint(x: 2, y: -1), front: false)
        XCTAssertEqual(clamped.x, 0, accuracy: 0.001); XCTAssertEqual(clamped.y, 0, accuracy: 0.001)
    }

    func testTakeSegmentsBecomeSpans() {
        let segs = [TakeSegment(look: .super8, start: 0), TakeSegment(look: .vhs, start: 4)]
        let spans = TakeSegment.spans(segs, duration: 12)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].1, 4.0 / 12, accuracy: 0.001)
        XCTAssertEqual(spans[1].1, 8.0 / 12, accuracy: 0.001)
    }

    func testTheRecorderWritesAMovie() {
        guard let r = VideoRecorder(size: CGSize(width: 320, height: 240), audio: false) else { return XCTFail("no writer") }
        let img = CIImage(color: .green).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240))
        for i in 0..<15 { r.append(img, at: CMTime(value: CMTimeValue(i), timescale: 30)) }
        let done = expectation(description: "finished")
        var url: URL?
        r.finish { url = $0; done.fulfill() }
        wait(for: [done], timeout: 20)
        XCTAssertNotNil(url)
        if let url { XCTAssertGreaterThan((try? Data(contentsOf: url))?.count ?? 0, 1000) }
    }
}
