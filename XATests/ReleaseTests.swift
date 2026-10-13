import XCTest
import CoreImage
@testable import XA

/// Checks for the release fixes: each one failed before its fix.
final class ReleaseTests: XCTestCase {
    private func spread(_ img: CIImage, at r: CGRect) -> (mean: Float, sd: Float) {
        let w = Int(r.width), h = Int(r.height)
        var px = [Float](repeating: 0, count: w * h * 4)
        Looks.context.render(img, toBitmap: &px, rowBytes: w * 16, bounds: r, format: .RGBAf, colorSpace: nil)
        let ys = stride(from: 0, to: px.count, by: 4).map { px[$0] }
        let mean = ys.reduce(0, +) / Float(ys.count)
        let sd = sqrt(ys.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(ys.count))
        return (mean, sd)
    }

    /// Film grain shows (its random source's alpha used to wipe it out).
    func testGrainIsLive() {
        let src = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256))
        let out = FilmGrain.apply(src, amount: 1, size: 0.5, seed: 3)
        let s = spread(out, at: CGRect(x: 96, y: 96, width: 64, height: 64))
        XCTAssertGreaterThan(s.sd, 0.005, "grain should show")
    }

    /// A DIGI sim with grain puts it on the photo.
    func testSimGrainIsLive() {
        var sim = Sim.neutral
        sim.id = "test-grain"; sim.grain = 0.6; sim.grainSize = 0.4
        let src = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256))
        let out = SimEngine.apply(sim, to: src, preview: false, seed: 7)
        let s = spread(out, at: CGRect(x: 96, y: 96, width: 64, height: 64))
        XCTAssertGreaterThan(s.sd, 0.005, "a sim's grain should show")
    }

    /// The same grain twice for the same shot: a photo developed again (the Lock Screen's
    /// leftovers) comes out the same.
    func testGrainIsSeeded() {
        let src = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 128, height: 128))
        let r = CGRect(x: 32, y: 32, width: 16, height: 16)
        let a = spread(FilmGrain.apply(src, amount: 1, size: 0.5, seed: 11), at: r)
        let b = spread(FilmGrain.apply(src, amount: 1, size: 0.5, seed: 11), at: r)
        XCTAssertEqual(a.mean, b.mean, accuracy: 1e-5)
        XCTAssertEqual(a.sd, b.sd, accuracy: 1e-5)
    }

    /// An 18% gray card needs no correction from the lab: it meters linear frames as linear.
    /// (Read as display values it metered about half a stop dark and printed every frame up.)
    func testTheLabLeavesAGrayCardAlone() {
        let v = LabAuto.gains([0.4614, 0.4614, 0.4614], 0.7)   // 18% gray, sRGB-encoded
        XCTAssertEqual(v.y, 1, accuracy: 0.03)
        let lin = CGColorSpace(name: CGColorSpace.linearSRGB)!
        let gray = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1, colorSpace: lin)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
        let c = LabAuto.correction(gray, strength: 0.7, preview: false)
        XCTAssertEqual(c.y, 1, accuracy: 0.03)
        XCTAssertEqual(c.x, c.z, accuracy: 0.03, "a neutral card stays neutral")
    }

    /// The Lock Screen's settings fit the intent's 4 KB app context, quotes escaped and all.
    func testLockSettingsFitTheAppContext() throws {
        var l = LockSettings()
        l.favoritesDigi = (0..<40).map { "custom-\($0)abcdefgh" }
        l.favoritesFilm = FilmStock.all.map(\.id)
        let s = try XCTUnwrap(l.encoded())
        var c = XAContext()
        c.settings = s
        let whole = try JSONEncoder().encode(c)
        XCTAssertLessThanOrEqual(whole.count, 4096)
        let back = try XCTUnwrap(LockSettings.decode(s))
        XCTAssertEqual(back.digiMegapixels, l.digiMegapixels)
        XCTAssertEqual(back.filmStack, l.filmStack)
    }

    /// A context written by an older build (missing fields, a field of the wrong type) still
    /// applies what it has.
    func testLockSettingsDecodeFieldByField() throws {
        let old = #"{"digiMegapixels": 5, "crunch": "oops", "mode": "film"}"#
        let l = try XCTUnwrap(LockSettings.decode(old))
        XCTAssertEqual(l.digiMegapixels, 5)
        XCTAssertEqual(l.crunch, LockSettings().crunch)
        XCTAssertEqual(l.mode, .film)
    }

    /// The ribbon copes with a mode it doesn't offer (the Lock Screen camera has no VIDEO).
    func testTheRibbonLandsOnAModeItOffers() {
        let modes: [CaptureMode] = [.digi, .film, .pro]
        XCTAssertTrue(modes.contains(ModeRibbon.target(.video, drag: 0, modes)))
        XCTAssertEqual(ModeRibbon.target(.digi, drag: -ModeRibbon.pitch, modes), .film)
    }
}
