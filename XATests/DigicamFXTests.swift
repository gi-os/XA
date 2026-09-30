import XCTest
import CoreImage
import ImageIO
@testable import XA

final class DigicamFXTests: XCTestCase {
    private func props(flash: Int? = nil, iso: Int? = nil, time: Double? = nil) -> [String: Any] {
        var exif: [String: Any] = [:]
        if let flash { exif[kCGImagePropertyExifFlash as String] = flash }
        if let iso { exif[kCGImagePropertyExifISOSpeedRatings as String] = [iso] }
        if let time { exif[kCGImagePropertyExifExposureTime as String] = time }
        return [kCGImagePropertyExifDictionary as String: exif]
    }

    func testFlashFiredReadsBitZero() {
        XCTAssertTrue(DigicamFX.Conditions(properties: props(flash: 0x19)).flashFired)   // fired, auto
        XCTAssertFalse(DigicamFX.Conditions(properties: props(flash: 0x18)).flashFired)  // auto, did not fire
        XCTAssertFalse(DigicamFX.Conditions(properties: [:]).flashFired)
    }

    func testNightStaysLowAndOnlyInTheDark() {
        XCTAssertEqual(DigicamFX.Conditions(properties: props(iso: 100, time: 1.0 / 120)).night, 0)
        let dark = DigicamFX.Conditions(properties: props(iso: 3200, time: 1.0 / 15)).night
        XCTAssertGreaterThan(dark, 0)
        XCTAssertLessThanOrEqual(dark, 0.35)
        XCTAssertEqual(DigicamFX.Conditions(properties: props(flash: 1, iso: 3200)).night, 0, "the flash lit it: not a night shot")
    }

    func testEffectsKeepTheFrame() {
        let img = CIImage(color: CIColor(red: 0.5, green: 0.4, blue: 0.3)).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240))
        for out in [DigicamFX.partyFlash(img), DigicamFX.night(img, amount: 0.3), DigicamFX.lens(img), DigicamFX.jpeg(img)] {
            XCTAssertEqual(out.extent, img.extent)
        }
        let flashed = DigicamFX.partyFlash(img)
        let ctx = CIContext()
        var px = [UInt8](repeating: 0, count: 4)
        ctx.render(flashed, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        var mid = [UInt8](repeating: 0, count: 4)
        ctx.render(flashed, toBitmap: &mid, rowBytes: 4, bounds: CGRect(x: 160, y: 120, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        XCTAssertLessThan(Int(px[1]), Int(mid[1]), "flash falls off toward the corners")
    }

    func testFlashShadowsGoGreen() {
        let dark = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let out = DigicamFX.partyFlash(dark)
        var px = [Float](repeating: 0, count: 4)
        CIContext().render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 32, y: 32, width: 1, height: 1), format: .RGBAf, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        XCTAssertGreaterThan(px[1], px[0] + 0.02, "a dark grey comes out green")
        XCTAssertGreaterThan(px[1], px[2], "green, not blue")
    }

    func testSoundsAreShortAndNotSilent() {
        for s in [Synth.hunt(), Synth.fastMetal()] {
            XCTAssertLessThan(Double(s.count) / Synth.rate, 0.4)
            let peak = s.map { abs($0) }.max() ?? 0
            XCTAssertGreaterThan(peak, 0.3)
            XCTAssertLessThanOrEqual(peak, 1)
        }
        let wav = Synth.wav([0, 0.5, -0.5])
        XCTAssertEqual(wav.count, 44 + 6)
        XCTAssertEqual(String(data: wav.prefix(4), encoding: .ascii), "RIFF")
    }
}
