import XCTest
import CoreImage
@testable import XA

/// The render check: a full-size GPU render can come back with black tiles while its mean
/// brightness still looks fine, so the check compares the render against the thumbnail
/// cell by cell instead of trusting one global number.
final class EncoderTests: XCTestCase {
    private let w = 320, h = 240

    /// A flat frame at one brightness, 0…1.
    private func flat(_ v: CGFloat) -> CGImage {
        let img = CIImage(color: CIColor(red: v, green: v, blue: v)).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        return Encoder.gpu.createCGImage(img, from: img.extent)!
    }

    /// The frame with one black tile punched in, the way a dropped GPU tile looks.
    private func withBlackTile() -> CGImage {
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for y in 100..<140 {
            for x in 140..<180 {
                let i = (y * w + x) * 4
                px[i] = 0; px[i + 1] = 0; px[i + 2] = 0
            }
        }
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: Encoder.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }

    func testCleanRenderVerifies() {
        XCTAssertTrue(Encoder.verified(flat(0.8), reference: flat(0.8)))
    }

    func testBlackTileFailsAgainstLitThumbnail() {
        // Mean brightness of the corrupt frame is ~250: the old whole-frame check passed it.
        XCTAssertGreaterThan(Encoder.brightness(withBlackTile()), 200)
        XCTAssertFalse(Encoder.verified(withBlackTile(), reference: flat(0.8)))
    }

    func testDarkScenePassesWhenBothAreDark() {
        XCTAssertTrue(Encoder.verified(flat(0.02), reference: flat(0.02)))
    }

    func testNilReferenceFallsBackToWholeFrame() {
        XCTAssertTrue(Encoder.verified(flat(0.8), reference: nil))
        XCTAssertFalse(Encoder.verified(flat(0.0), reference: nil))
    }
}
