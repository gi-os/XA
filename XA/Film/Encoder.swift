import CoreImage
import ImageIO
import UniformTypeIdentifiers
import UIKit

/// Writing a developed photo to a file, safely. The GPU render of a full-size frame can come
/// back black (memory pressure, the app leaving the foreground mid-render) while the small
/// thumbnail from the same image is fine. So the full frame is rendered first, checked against
/// the thumbnail, redone on the CPU if it came back black, and only then encoded.
enum Encoder {
    static let gpu = CIContext(options: [.cacheIntermediates: false])
    static let cpu = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Mean of the brightest channel over a tiny copy of the picture, 0…255.
    static func brightness(_ cg: CGImage) -> Double {
        let n = 16
        var px = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4, space: sRGB,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        var total = 0
        for i in 0..<(n * n) { total += Int(max(px[i * 4], px[i * 4 + 1], px[i * 4 + 2])) }
        return Double(total) / Double(n * n)
    }

    static func render(_ img: CIImage, expectBrightness: Double?) -> CGImage? {
        let e = img.extent.integral
        if let cg = gpu.createCGImage(img, from: e, format: .RGBA8, colorSpace: sRGB) {
            let b = brightness(cg)
            // Black only counts as a failure when the thumbnail says the picture isn't black.
            if b > 1.5 || (expectBrightness ?? 0) < 3 { return cg }
        }
        return cpu.createCGImage(img, from: e, format: .RGBA8, colorSpace: sRGB)
    }

    static func encode(_ cg: CGImage, type: UTType, quality: CGFloat, properties: [String: Any]) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { return nil }
        var p = properties
        if type == .jpeg { p[kCGImageDestinationLossyCompressionQuality as String] = quality }
        CGImageDestinationAddImage(dest, cg, p as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
