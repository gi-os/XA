import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers

/// The small faults of a 2000s digicam, applied to DIGI photos only (never the viewfinder,
/// never PRO). Every one is kept low: a hint of the camera, not a filter.
enum DigicamFX {
    /// What the photo's own metadata says about how it was taken.
    struct Conditions: Equatable {
        var flashFired = false
        var iso: Double = 0
        var exposure: Double = 0

        init(flashFired: Bool = false, iso: Double = 0, exposure: Double = 0) {
            self.flashFired = flashFired; self.iso = iso; self.exposure = exposure
        }

        init(properties p: [String: Any]) {
            let exif = p[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            // EXIF Flash: bit 0 set when it fired.
            if let f = exif[kCGImagePropertyExifFlash as String] as? Int { flashFired = f & 1 == 1 }
            if let isos = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Double], let first = isos.first { iso = first }
            else if let isos = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let first = isos.first { iso = Double(first) }
            if let t = exif[kCGImagePropertyExifExposureTime as String] as? Double { exposure = t }
        }

        /// 0 in good light, rising to a low ceiling in the dark. The flash lights the scene,
        /// so a flash shot is never a night shot.
        var night: Double {
            guard !flashFired else { return 0 }
            let fromISO: Double = min(1, max(0, (iso - 640) / 2560))
            let fromTime: Double = exposure >= 1.0 / 10 ? 0.25 : 0
            return min(1, fromISO + fromTime) * 0.35
        }
    }

    /// The whole set, in the order a camera's ISP would do it.
    /// Pixel looks (Pocket and friends) skip the lens and the JPEG: blocks and blur would
    /// spoil the pixels.
    static func apply(_ img: CIImage, _ c: Conditions, pixel: Bool = false) -> CIImage {
        var out = img
        if c.flashFired { out = partyFlash(out) }
        if c.night > 0 { out = night(out, amount: c.night) }
        if !pixel {
            out = lens(out)
            out = jpeg(out)
        }
        return out
    }

    /// Flash from the camera body: what is near is blown bright and flat, a little cool, and
    /// the room behind falls off into the dark.
    static func partyFlash(_ img: CIImage) -> CIImage {
        let e = img.extent
        // The colour of a point-and-shoot flash on cheap colour negative: whites a touch warm,
        // faces bright and a little hot, and the shadows sliding green. One cube does it all.
        let cube = CIFilter.colorCubeWithColorSpace()
        cube.inputImage = img
        cube.cubeDimension = Float(flashCubeSize)
        cube.cubeData = flashCube
        if let cs = CGColorSpace(name: CGColorSpace.sRGB) { cube.colorSpace = cs }
        let out = (cube.outputImage ?? img).cropped(to: e)
        // Falloff: the far side of the room loses about a stop.
        let dark = CIFilter.exposureAdjust(); dark.inputImage = out; dark.ev = -0.9
        let mask = CIFilter.radialGradient()
        mask.center = CGPoint(x: e.midX, y: e.midY)
        mask.radius0 = Float(min(e.width, e.height) * 0.34)
        mask.radius1 = Float(hypot(e.width, e.height) * 0.62)
        mask.color0 = CIColor(red: 1, green: 1, blue: 1); mask.color1 = CIColor(red: 0, green: 0, blue: 0)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = out; blend.backgroundImage = dark.outputImage; blend.maskImage = mask.outputImage?.cropped(to: e)
        return (blend.outputImage ?? out).cropped(to: e)
    }

    static let flashCubeSize = 32
    /// Built once: a gentle S-curve with hot highlights, a warm lift in the brights and a green
    /// (slightly teal) cast that grows as the tone gets darker.
    static let flashCube: Data = {
        let n = flashCubeSize
        var d = [Float](repeating: 0, count: n * n * n * 4)
        func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float { let t = min(1, max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t) }
        var i = 0
        for bi in 0..<n { for gi in 0..<n { for ri in 0..<n {
            var r = Float(ri) / Float(n - 1), g = Float(gi) / Float(n - 1), b = Float(bi) / Float(n - 1)
            let l = 0.299 * r + 0.587 * g + 0.114 * b
            // Contrast and a little push, highlights running out to white early.
            func curve(_ x: Float) -> Float { let y = x + 0.22 * x * (1 - x) * (x - 0.35) * 2.2 + 0.06 * x; return min(1, max(0, y * 1.04)) }
            r = curve(r); g = curve(g); b = curve(b)
            // Shadows go green: strongest in the darks, gone by the mid-tones.
            let shadow = 1 - smooth(0.05, 0.5, l)
            g += 0.045 * shadow; b += 0.012 * shadow; r -= 0.02 * shadow
            // Brights a touch warm, like the flash tube on negative film.
            let bright = smooth(0.55, 0.95, l)
            r += 0.02 * bright; b -= 0.025 * bright
            // A little more colour in the middle.
            let m = (r + g + b) / 3
            r = m + (r - m) * 1.08; g = m + (g - m) * 1.08; b = m + (b - m) * 1.08
            d[i] = min(1, max(0, r)); d[i + 1] = min(1, max(0, g)); d[i + 2] = min(1, max(0, b)); d[i + 3] = 1
            i += 4
        } } }
        return d.withUnsafeBufferPointer { Data(buffer: $0) }
    }()

    /// Low light: the noise reduction smears fine detail a little and leaves faint colored
    /// blotches in the shadows. `amount` stays small (≤ 0.35).
    static func night(_ img: CIImage, amount: Double) -> CIImage {
        let e = img.extent
        let a = CGFloat(amount)
        let med = CIFilter.median(); med.inputImage = img
        let waxy = (med.outputImage ?? img).cropped(to: e)
        let mix = CIFilter.dissolveTransition(); mix.inputImage = img; mix.targetImage = waxy; mix.time = Float(min(1, a * 2.2))
        var out = (mix.outputImage ?? img).cropped(to: e)
        out = Digicam.colorNoise(out, amount: a * 0.09)
        return out
    }

    /// A cheap zoom lens, barely: a touch of barrel bulge and corners a little soft.
    static func lens(_ img: CIImage) -> CIImage {
        let e = img.extent
        let bulge = CIFilter.bumpDistortion()
        bulge.inputImage = img.clampedToExtent()
        bulge.center = CGPoint(x: e.midX, y: e.midY)
        bulge.radius = Float(hypot(e.width, e.height) * 0.62)
        bulge.scale = 0.035
        let bent = (bulge.outputImage ?? img).cropped(to: e)
        let blur = CIFilter.gaussianBlur(); blur.inputImage = bent.clampedToExtent()
        blur.radius = Float(max(0.6, min(e.width, e.height) / 1400))
        let soft = (blur.outputImage ?? bent).cropped(to: e)
        let mask = CIFilter.radialGradient()
        mask.center = CGPoint(x: e.midX, y: e.midY)
        mask.radius0 = Float(hypot(e.width, e.height) * 0.3)
        mask.radius1 = Float(hypot(e.width, e.height) * 0.52)
        mask.color0 = CIColor(red: 1, green: 1, blue: 1); mask.color1 = CIColor(red: 0, green: 0, blue: 0)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = bent; blend.backgroundImage = soft; blend.maskImage = mask.outputImage?.cropped(to: e)
        return (blend.outputImage ?? bent).cropped(to: e)
    }

    /// One pass through a low-quality JPEG before the real save: faint blocks in flat areas
    /// and a little smeared color, the way the camera's own encoder left them.
    static let jpegQuality: CGFloat = 0.42
    static func jpeg(_ img: CIImage) -> CIImage {
        let e = img.extent
        let origin = img.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
        // Rendered the safe way: a GPU frame that comes back with black tiles is redone on the CPU.
        let k: CGFloat = 64 / max(e.width, 1)
        let tiny = origin.transformed(by: CGAffineTransform(scaleX: k, y: k))
        let reference = Encoder.gpu.createCGImage(tiny, from: tiny.extent.integral)
        guard let cg = Encoder.render(origin, reference: reference) else { return img }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return img }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(dest), let back = CIImage(data: data as Data) else { return img }
        return back.transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY))
    }
}
