import CoreImage
import CoreImage.CIFilterBuiltins

/// The filters, in Core Image. Each one runs on the live viewfinder and again on the full
/// photograph, so what you see is what gets saved.
enum Look: Int, CaseIterable, Identifiable, Codable {
    case none, film, sixteen, gameboy, dither, halftone, thermal, purikura, gbcolor

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "CLEAN"
        case .film: return "GRAIN"
        case .sixteen: return "SIXTEEN"
        case .gameboy: return "POCKET"
        case .dither: return "1-BIT"
        case .halftone: return "PRESS"
        case .thermal: return "HEAT"
        case .purikura: return "BOOTH"
        case .gbcolor: return "POCKET COLOR"
        }
    }

    /// Black and white, so a date back on top goes neutral too (Roll's light-reports#25).
    var mono: Bool { self == .dither }

    /// Pixel filters are worked at a small width and blown back up with no smoothing.
    var pixelWidth: CGFloat? {
        switch self {
        case .sixteen: return 320
        case .gameboy: return 160
        case .dither: return 360
        case .gbcolor: return 128
        default: return nil
        }
    }
}

enum Looks {
    static let context = CIContext(options: [.cacheIntermediates: false])

    static func apply(_ look: Look, to src: CIImage, outputWidth: CGFloat? = nil) -> CIImage {
        let input = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
        let extent = input.extent
        switch look {
        case .none: return input
        case .film: return film(input)
        case .halftone:
            let f = CIFilter.cmykHalftone()
            f.inputImage = input
            f.width = Float(max(4, extent.width / 170))
            f.center = CGPoint(x: extent.midX, y: extent.midY)
            f.sharpness = 0.8
            return (f.outputImage ?? input).cropped(to: extent)
        case .thermal: return cube(thermalCube, input).cropped(to: extent)
        case .purikura: return purikura(input)
        case .sixteen, .gameboy, .dither, .gbcolor:
            let w = look.pixelWidth!
            let k = w / extent.width
            var small = input.transformed(by: CGAffineTransform(scaleX: k, y: k))
            let smallExtent = small.extent
            switch look {
            case .gameboy:
                small = grey(small)
                small = dither(small, 0.35)
                small = cube(gameboyCube, small)
            case .dither:
                small = grey(small)
                small = dither(small, 0.6)
                small = cube(oneBitCube, small)
            case .gbcolor:
                // Roll's GB Color: the Game Boy Camera's grid with fifteen-bit colour, five
                // levels a channel, a hard contrast push and that screen's slightly sour cast.
                small = dither(small, 0.26)
                small = cube(gbColorCube, small)
            default:
                small = dither(small, 0.25)
                small = cube(sixteenCube, small)
            }
            let out = outputWidth ?? extent.width
            let up = out / w
            return small.cropped(to: smallExtent).samplingNearest().transformed(by: CGAffineTransform(scaleX: up, y: up))
        }
    }

    // MARK: pieces

    private static func grey(_ i: CIImage) -> CIImage {
        let f = CIFilter.colorControls(); f.inputImage = i; f.saturation = 0; f.contrast = 1.1
        return f.outputImage ?? i
    }

    private static func dither(_ i: CIImage, _ amount: Float) -> CIImage {
        let f = CIFilter.dither(); f.inputImage = i; f.intensity = amount
        return (f.outputImage ?? i).cropped(to: i.extent)
    }

    private static func cube(_ data: Data, _ i: CIImage) -> CIImage {
        let f = CIFilter.colorCube(); f.inputImage = i; f.cubeDimension = 32; f.cubeData = data
        return f.outputImage ?? i
    }

    /// Grain: a consumer colour negative. Warm, soft in the highlights, lifted blacks, and real
    /// grain: clumped, monochrome and strongest in the midtones, the way silver halide is.
    private static func film(_ input: CIImage) -> CIImage {
        let e = input.extent
        let warm = CIFilter.temperatureAndTint(); warm.inputImage = input
        warm.neutral = CIVector(x: 6500, y: 0); warm.targetNeutral = CIVector(x: 5700, y: 8)
        let tone = CIFilter.toneCurve(); tone.inputImage = warm.outputImage
        tone.point0 = CGPoint(x: 0, y: 0.06); tone.point1 = CGPoint(x: 0.25, y: 0.23); tone.point2 = CGPoint(x: 0.5, y: 0.52)
        tone.point3 = CGPoint(x: 0.75, y: 0.8); tone.point4 = CGPoint(x: 1, y: 0.94)
        let cc = CIFilter.colorControls(); cc.inputImage = tone.outputImage; cc.saturation = 1.06; cc.contrast = 1.02
        let vig = CIFilter.vignette(); vig.inputImage = cc.outputImage?.cropped(to: e); vig.intensity = 0.45; vig.radius = Float(max(e.width, e.height) / 700)
        return FilmGrain.apply((vig.outputImage ?? input).cropped(to: e), amount: 0.6, size: 0.45)
    }

    private static func purikura(_ input: CIImage) -> CIImage {
        let e = input.extent
        let bloom = CIFilter.bloom(); bloom.inputImage = input; bloom.radius = Float(e.width / 90); bloom.intensity = 0.9
        let cc = CIFilter.colorControls(); cc.inputImage = bloom.outputImage?.cropped(to: e); cc.brightness = 0.06; cc.saturation = 1.35; cc.contrast = 0.92
        let tint = CIFilter.colorMatrix(); tint.inputImage = cc.outputImage
        tint.biasVector = CIVector(x: 0.05, y: 0.0, z: 0.04, w: 0)
        return (tint.outputImage ?? input).cropped(to: e)
    }

    // MARK: color cubes

    typealias RGB = (Float, Float, Float)

    /// The same sixteen colors as m-cas: a 15-bit palette from a handheld with the backlight off.
    private static func palette(_ v: [Int]) -> [RGB] {
        var out: [RGB] = []
        var i = 0
        while i + 2 < v.count {
            let r: Float = Float(v[i]) / 255
            let g: Float = Float(v[i + 1]) / 255
            let b: Float = Float(v[i + 2]) / 255
            out.append((r, g, b))
            i += 3
        }
        return out
    }

    /// The same sixteen colors as m-cas: a 15-bit palette from a handheld with the backlight off.
    static let sixteen: [RGB] = palette([
        8, 8, 16, 24, 24, 48, 40, 48, 88, 64, 80, 136, 48, 160, 136, 136, 216, 176, 248, 240, 200, 224, 200, 144,
        160, 104, 48, 88, 48, 32, 224, 64, 64, 248, 152, 56, 248, 216, 72, 240, 128, 160, 128, 88, 176, 168, 168, 184
    ])

    static let gameboy: [RGB] = palette([15, 56, 15, 48, 98, 48, 139, 172, 15, 155, 188, 15])

    static func makeCube(_ map: (RGB) -> RGB) -> Data {
        let n = 32
        var v = [Float](repeating: 0, count: n * n * n * 4)
        var i = 0
        for b in 0..<n { for g in 0..<n { for r in 0..<n {
            let top: Float = Float(n - 1)
            let rf: Float = Float(r) / top
            let gf: Float = Float(g) / top
            let bf: Float = Float(b) / top
            let c = map((rf, gf, bf))
            v[i] = c.0; v[i + 1] = c.1; v[i + 2] = c.2; v[i + 3] = 1
            i += 4
        } } }
        return v.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func nearest(_ c: RGB, in pal: [RGB]) -> RGB {
        var best = pal[0], bd = Float.greatestFiniteMagnitude
        for p in pal {
            let dr: Float = c.0 - p.0
            let dg: Float = c.1 - p.1
            let db: Float = c.2 - p.2
            let d: Float = 3 * dr * dr + 4 * dg * dg + 2 * db * db
            if d < bd { bd = d; best = p }
        }
        return best
    }

    static func luma(_ c: RGB) -> Float {
        let r: Float = 0.299 * c.0
        let g: Float = 0.587 * c.1
        let b: Float = 0.114 * c.2
        return r + g + b
    }

    static let sixteenCube = makeCube { nearest($0, in: sixteen) }
    static let gameboyCube = makeCube { gameboy[min(3, Int(luma($0) * 4))] }
    static let gbColorCube = makeCube { c in
        func q(_ v: Float) -> Float {
            let pushed: Float = min(0.999, max(0, (v - 0.5) * 1.3 + 0.5))
            return floor(pushed * 5) / 4
        }
        let r: Float = min(1, q(c.0) * 0.98)
        let g: Float = min(1, q(c.1) * 1.02)
        let b: Float = min(1, q(c.2) * 0.90)
        return (r, g, b)
    }
    static let oneBitDark: RGB = (0.06, 0.06, 0.1)
    static let oneBitLight: RGB = (0.97, 0.94, 0.78)
    static let oneBitCube = makeCube { luma($0) < 0.5 ? oneBitDark : oneBitLight }
    static let thermalCube: Data = {
        let ramp: [RGB] = palette([0, 0, 26, 51, 0, 153, 178, 0, 178, 255, 51, 51, 255, 153, 0, 255, 242, 77, 255, 255, 255])
        return makeCube { c in
            let t = min(0.9999, max(0, luma(c))) * Float(ramp.count - 1)
            let i = Int(t), f = t - Float(i)
            let a = ramp[i], b = ramp[min(ramp.count - 1, i + 1)]
            let r: Float = a.0 + (b.0 - a.0) * f
            let g: Float = a.1 + (b.1 - a.1) * f
            let bl: Float = a.2 + (b.2 - a.2) * f
            return (r, g, bl)
        }
    }()
}
