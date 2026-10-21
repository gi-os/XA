import XCTest
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import XA

/// How the phone is held, and the pixels that follow from it (see Hold): every photo comes out
/// upright for the hold it was taken at, selfies mirrored, and a flat phone keeps its last hold.
final class HoldTests: XCTestCase {
    // MARK: the arithmetic

    func testBackAngleToHold() {
        // portrait, top to the left, upside down, top to the right
        XCTAssertEqual([90, 0, 270, 180].map { Hold.turn(backAngle: $0) }, [0, 270, 180, 90])
    }

    func testBackAngleInvertsTheHold() {
        for t: CGFloat in [0, 90, 180, 270] { XCTAssertEqual(Hold.turn(backAngle: Hold.backAngle(turn: t)), t) }
    }

    func testSelfieFramesTurnTheOtherWay() {
        XCTAssertEqual(Hold.frameTurn(90, front: true), 270)
        XCTAssertEqual(Hold.frameTurn(270, front: true), 90)
        XCTAssertEqual(Hold.frameTurn(180, front: true), 180)
        XCTAssertEqual(Hold.frameTurn(0, front: true), 0)
        XCTAssertEqual(Hold.frameTurn(90, front: false), 90)
    }

    func testNormSnapsToQuarterTurns() {
        XCTAssertEqual(Hold.norm(-90), 270)
        XCTAssertEqual(Hold.norm(450), 90)
        XCTAssertEqual(Hold.norm(89.6), 90)
        XCTAssertEqual(Hold.norm(359.8), 0)
    }

    func testFlatHasHysteresis() {
        XCTAssertFalse(Hold.isFlat(z: 0.80, was: false))
        XCTAssertTrue(Hold.isFlat(z: 0.90, was: false))
        XCTAssertTrue(Hold.isFlat(z: 0.80, was: true))
        XCTAssertFalse(Hold.isFlat(z: 0.70, was: true))
        XCTAssertTrue(Hold.isFlat(z: -0.95, was: false), "face down too")
    }

    // MARK: the last hold it was sure of

    func testAFlatPhoneKeepsTheLastHold() {
        var s = HoldState()
        s.gravity(z: 0.1); s.coordinator(turn: 270)
        XCTAssertEqual(s.turn, 270)
        s.gravity(z: 0.95); s.coordinator(turn: 0)
        XCTAssertEqual(s.turn, 270, "what the coordinator says while flat is ignored")
        s.gravity(z: 0.2)
        XCTAssertEqual(s.turn, 0, "picked up again: the coordinator is trusted again")
    }

    func testFlatFromTheStartFollowsTheCoordinator() {
        var s = HoldState()
        s.gravity(z: -0.97); s.coordinator(turn: 90)
        XCTAssertEqual(s.turn, 90)
        XCTAssertEqual(HoldState().turn, 0)
    }

    func testWithoutGravityItIsTheCoordinator() {
        var s = HoldState()
        s.coordinator(turn: 90); XCTAssertEqual(s.turn, 90)
        s.coordinator(turn: 180); XCTAssertEqual(s.turn, 180)
    }

    // MARK: gravity decides

    func testGravityGivesTheHold() {
        // upright, the left edge down (top to the right), upside down, the right edge down
        XCTAssertEqual(Hold.turn(gravityX: 0, y: -1), 0)
        XCTAssertEqual(Hold.turn(gravityX: -1, y: 0), 90)
        XCTAssertEqual(Hold.turn(gravityX: 0, y: 1), 180)
        XCTAssertEqual(Hold.turn(gravityX: 1, y: 0), 270)
        // tilted back 60°, still upright
        XCTAssertEqual(Hold.turn(gravityX: 0.05, y: -0.5), 0)
    }

    func testGravityAgreesWithTheCaptureAngle() {
        // the photo connection angle the hold gives, for each edge down: the coordinator's own
        // numbers for the back camera (90 portrait, 0 top to the left, 180 top to the right)
        XCTAssertEqual(Hold.backAngle(turn: Hold.turn(gravityX: 0, y: -1)), 90)
        XCTAssertEqual(Hold.backAngle(turn: Hold.turn(gravityX: 1, y: 0)), 0)
        XCTAssertEqual(Hold.backAngle(turn: Hold.turn(gravityX: -1, y: 0)), 180)
        XCTAssertEqual(Hold.backAngle(turn: Hold.turn(gravityX: 0, y: 1)), 270)
    }

    func testGravityHoldsOnPastTheDiagonal() {
        func g(_ deg: Double) -> (Double, Double) { (-sin(deg * .pi / 180), -cos(deg * .pi / 180)) }  // turning clockwise
        var (x, y) = g(48)
        XCTAssertEqual(Hold.turn(gravityX: x, y: y, was: 0), 0, "just past 45°: still portrait")
        (x, y) = g(60)
        XCTAssertEqual(Hold.turn(gravityX: x, y: y, was: 0), 90, "well past: landscape")
        (x, y) = g(42)
        XCTAssertEqual(Hold.turn(gravityX: x, y: y, was: 90), 90, "and on the way back it holds on too")
        (x, y) = g(30)
        XCTAssertEqual(Hold.turn(gravityX: x, y: y, was: 90), 0)
    }

    func testGravityBeatsAStuckCoordinator() {
        // the Lock Screen camera: opened in portrait, the coordinator never moved again
        var s = HoldState()
        s.coordinator(turn: 0)
        s.gravity(x: 1, y: 0, z: 0.1)
        XCTAssertEqual(s.turn, 270, "turned to landscape: gravity says so")
        s.coordinator(turn: 0)
        XCTAssertEqual(s.turn, 270, "the coordinator's stale reading doesn't undo it")
        s.gravity(x: 0, y: -1, z: 0)
        XCTAssertEqual(s.turn, 0)
        // and opened in landscape, then held upright
        var t = HoldState()
        t.coordinator(turn: 90)
        t.gravity(x: 0.02, y: -0.98, z: 0.1)
        XCTAssertEqual(t.turn, 0)
    }

    func testFlatKeepsTheLastGravityHold() {
        var s = HoldState()
        s.gravity(x: -0.9, y: 0, z: 0.3)
        XCTAssertEqual(s.turn, 90)
        s.gravity(x: 0.2, y: -0.1, z: 0.97)
        XCTAssertEqual(s.turn, 90, "pointing at the table: which way is up can't be told")
        s.gravity(x: 0, y: 0.9, z: 0.3)
        XCTAssertEqual(s.turn, 180)
    }

    // MARK: pixels: a 4 x 3 frame, every pixel different, top row first

    private let sensor: [[UInt8]] = [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11]]
    private func cw(_ a: [[UInt8]]) -> [[UInt8]] { (0..<a[0].count).map { x in a.indices.reversed().map { y in a[y][x] } } }
    private func turned(_ a: [[UInt8]], _ deg: Int) -> [[UInt8]] { (0..<((deg / 90) % 4)).reduce(a) { m, _ in cw(m) } }
    private func mirrored(_ a: [[UInt8]]) -> [[UInt8]] { a.map { Array($0.reversed()) } }

    private func image(_ rows: [[UInt8]]) -> CIImage {
        var bytes = [UInt8]()
        for r in rows { for v in r { bytes += [v * 20, 0, 0, 255] } }
        return CIImage(bitmapData: Data(bytes), bytesPerRow: rows[0].count * 4,
                       size: CGSize(width: rows[0].count, height: rows.count), format: .RGBA8, colorSpace: nil)
    }

    private func read(_ img: CIImage) -> [[UInt8]] {
        let e = CGRect(x: img.extent.minX.rounded(), y: img.extent.minY.rounded(),
                       width: img.extent.width.rounded(), height: img.extent.height.rounded())
        let w = Int(e.width), h = Int(e.height)
        var out = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CIContext(options: [.useSoftwareRenderer: true, .workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        ctx.render(img, toBitmap: &out, rowBytes: w * 4, bounds: e, format: .RGBA8, colorSpace: nil)
        return (0..<h).map { y in (0..<w).map { x in UInt8((Double(out[(y * w + x) * 4]) / 20).rounded()) } }
    }

    func testRotatedTurnsClockwise() {
        for d in [0, 90, 180, 270] {
            XCTAssertEqual(read(CameraModel.rotated(image(sensor), clockwise: CGFloat(d))), turned(sensor, d), "\(d)°")
        }
    }

    func testAPortraitSelfieIsTheOneSavedToday() {
        let s = read(CameraModel.selfie(image(sensor), turn: 0))
        XCTAssertEqual(s, read(CameraModel.upright(image(sensor), mirror: true)))
        XCTAssertEqual(s, mirrored(turned(sensor, 270)))
    }

    func testASelfieIsTurnedForTheHoldThenMirrored() {
        for t in [0, 90, 180, 270] {
            XCTAssertEqual(read(CameraModel.selfie(image(sensor), turn: CGFloat(t))),
                           mirrored(turned(turned(sensor, 270), t)), "hold \(t)°")
        }
    }

    func testTheSelfieViewfinderAndVideoMatchThePhoto() {
        // the frames are made upright and mirrored first, then turned by the frame turn
        for t in [0, 90, 180, 270] {
            let frame = CameraModel.upright(image(sensor), mirror: true)
            XCTAssertEqual(read(CameraModel.rotated(frame, clockwise: Hold.frameTurn(CGFloat(t), front: true))),
                           read(CameraModel.selfie(image(sensor), turn: CGFloat(t))), "hold \(t)°")
        }
    }

    func testTurningAfterTheMirrorWasWrongInLandscape() {
        // what selfie VIDEO used to do: the same turn after the mirror, 180° off in landscape
        let frame = CameraModel.upright(image(sensor), mirror: true)
        let old = read(CameraModel.rotated(frame, clockwise: 90))
        let right = read(CameraModel.selfie(image(sensor), turn: 90))
        XCTAssertNotEqual(old, right)
        XCTAssertEqual(old, turned(right, 180))
    }

    func testTheBackViewfinderFrameTurnedByTheHoldIsThePhoto() {
        // the photo the camera files at a capture angle, made upright from its tag, is the
        // portrait frame turned by the hold that angle means
        for angle in [0, 90, 180, 270] {
            let portrait = CameraModel.upright(image(sensor), mirror: false)
            XCTAssertEqual(read(CameraModel.rotated(portrait, clockwise: Hold.turn(backAngle: CGFloat(angle)))),
                           turned(sensor, angle), "capture angle \(angle)°")
        }
    }

    func testCoreImageBakesTheCameraFilesTag() throws {
        // no colour management anywhere, so the test values come back as they went in
        let plain = CIContext(options: [.useSoftwareRenderer: true, .workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        let cg = try XCTUnwrap(plain.createCGImage(image(sensor), from: CGRect(x: 0, y: 0, width: 4, height: 3),
                                                   format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
        let out = NSMutableData()
        let d = try XCTUnwrap(CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(d, cg, [kCGImagePropertyOrientation as String: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(d))
        let img = try XCTUnwrap(CIImage(data: out as Data, options: [.applyOrientationProperty: true]))
        XCTAssertEqual(img.extent.size, CGSize(width: 3, height: 4))
        XCTAssertEqual(read(img), turned(sensor, 90))
    }

    func testASelfieKeptAsItCameIsTaggedToShowAsItWasSeen() throws {
        // the camera's file of a selfie: the sensor frame, untagged (a JPEG at full quality)
        let plain = CIContext(options: [.useSoftwareRenderer: true, .workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        let cg = try XCTUnwrap(plain.createCGImage(image(sensor), from: CGRect(x: 0, y: 0, width: 4, height: 3),
                                                   format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
        let file = NSMutableData()
        let d = try XCTUnwrap(CGImageDestinationCreateWithData(file, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(d, cg, [kCGImageDestinationLossyCompressionQuality as String: 1.0] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(d))
        for t in [0, 90, 180, 270] {
            let tagged = CameraModel.selfieOriginal(file as Data, turn: CGFloat(t))
            let shown = try XCTUnwrap(CIImage(data: tagged, options: [.applyOrientationProperty: true]))
            XCTAssertEqual(read(shown), mirrored(turned(sensor, (270 + t) % 360)), "hold \(t)°")
        }
    }

    func testOldLockScreenRecipesDecodeAsPortrait() throws {
        let shot = LockShot(mode: .digi, stack: Stack(simID: nil), megapixels: 2, noise: 0.5, date: DateConfig(), recipe: DigiRecipe(),
                            film: false, filmRecipe: FilmRecipe(), crunch: 0.6, taken: Date(timeIntervalSince1970: 0), front: true)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(shot)) as? [String: Any])
        json.removeValue(forKey: "turn")
        let old = try JSONDecoder().decode(LockShot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.turn)
        var turned = shot; turned.turn = 90
        XCTAssertEqual(try JSONDecoder().decode(LockShot.self, from: JSONEncoder().encode(turned)).turn, 90)
    }
}
