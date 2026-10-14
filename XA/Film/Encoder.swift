import CoreImage
import ImageIO
import UniformTypeIdentifiers
import UIKit

/// Writing a developed photo to a file, safely. The GPU render of a full-size frame can come
/// back with black tiles (memory pressure, the app leaving the foreground mid-render) while
/// the small thumbnail from the same image is fine. So the full frame is rendered first,
/// checked against the thumbnail cell by cell, redone on the CPU if any tile came back black,
/// and only then encoded.
enum Encoder {
    static let gpu = CIContext(options: [.cacheIntermediates: false])
    static let cpu = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Mean of the brightest channel over a tiny copy of the picture, 0…255.
    static func brightness(_ cg: CGImage) -> Double {
        let n = 16
        var px = [UInt8](repeating: 0, count: n * n * 4)
        // drawn inside the buffer's scope: `&px` handed to CGContext is only valid for that call
        let drawn = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4, space: sRGB,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .low
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard drawn else { return 0 }
        var total = 0
        for i in 0..<(n * n) { total += Int(max(px[i * 4], px[i * 4 + 1], px[i * 4 + 2])) }
        return Double(total) / Double(n * n)
    }

    static func render(_ img: CIImage, reference: CGImage?) -> CGImage? {
        let e = img.extent.integral
        if let cg = draw(img, e, gpu), verified(cg, reference: reference) {
            return cg
        }
        return draw(img, e, cpu)
    }

    /// Past 16 MP the picture is drawn in tiles. Core Image refuses a render whose buffers pass its
    /// memory limit (a 40 MP drum scan asked for 860 MB at once) and leaves it black; a tile
    /// needs only its own part of every stage.
    private static func draw(_ img: CIImage, _ e: CGRect, _ ctx: CIContext) -> CGImage? {
        let w = Int(e.width), h = Int(e.height)
        guard w > 0, h > 0 else { return nil }
        if w * h <= 16_000_000 { return ctx.createCGImage(img, from: e, format: .RGBA8, colorSpace: sRGB) }
        let rowBytes = w * 4
        guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: rowBytes, space: sRGB,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let base = c.data else { return nil }
        let tile = 2048
        for ty in stride(from: 0, to: h, by: tile) {
            for tx in stride(from: 0, to: w, by: tile) {
                let tw = min(tile, w - tx), th = min(tile, h - ty)
                // the bitmap's rows go down from the top, Core Image's y goes up from the bottom
                let bounds = CGRect(x: e.minX + CGFloat(tx), y: e.minY + CGFloat(h - ty - th), width: CGFloat(tw), height: CGFloat(th))
                autoreleasepool {
                    ctx.render(img, toBitmap: base.advanced(by: ty * rowBytes + tx * 4), rowBytes: rowBytes,
                               bounds: bounds, format: .RGBA8, colorSpace: sRGB)
                }
            }
        }
        return c.makeImage()
    }

    /// The render is only trusted if every part of it agrees with the thumbnail. A full-size
    /// GPU render can come back with black tiles while its overall mean brightness still looks
    /// fine, so the render is shrunk to a grid and each cell is checked against the same cell
    /// of the thumbnail: black in the render but lit in the thumbnail means the render failed,
    /// not that the scene is dark.
    static func verified(_ cg: CGImage, reference: CGImage?) -> Bool {
        guard let ref = reference, let a = cells(cg), let b = cells(ref) else {
            // No reference: fall back to the whole-frame check.
            return brightness(cg) > 1.5
        }
        for i in 0..<a.count where b[i] > 16 && a[i] < 3 { return false }
        return true
    }

    /// Mean of the brightest channel per grid cell, 0…255. A dropped tile shows up as a black
    /// cell even when the rest of the frame is bright.
    private static func cells(_ cg: CGImage, cols: Int = 32, rows: Int = 24) -> [Double]? {
        var px = [UInt8](repeating: 0, count: cols * rows * 4)
        let drawn = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: cols, height: rows, bitsPerComponent: 8,
                                      bytesPerRow: cols * 4, space: sRGB,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .low
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cols, height: rows))
            return true
        }
        guard drawn else { return nil }
        return (0..<(cols * rows)).map { i in Double(max(px[i * 4], px[i * 4 + 1], px[i * 4 + 2])) }
    }

    static func encode(_ cg: CGImage, type: UTType, quality: CGFloat, properties: [String: Any]) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { return nil }
        var p = properties
        if type == .jpeg || type == .heic { p[kCGImageDestinationLossyCompressionQuality as String] = quality }
        CGImageDestinationAddImage(dest, cg, p as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
