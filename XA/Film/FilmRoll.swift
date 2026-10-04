import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import QuartzCore

/// The film format: how big the negative is, which sets how big grain, halation and the couplers'
/// reach are on the picture (spektrafilm's film_format_mm), and the frame's shape.
enum FilmFormat: String, CaseIterable, Codable {
    case pocket110, half, mm35, mf120

    var title: String {
        switch self {
        case .pocket110: return "110"
        case .half: return "HALF"
        case .mm35: return "35MM"
        case .mf120: return "120"
        }
    }

    /// The negative's long side, in millimetres.
    var longMM: CGFloat {
        switch self {
        case .pocket110: return 17
        case .half: return 24
        case .mm35: return 36
        case .mf120: return 56
        }
    }

    /// Short side over long side.
    var aspect: CGFloat {
        switch self {
        case .pocket110: return 13.0 / 17
        case .half: return 18.0 / 24
        case .mm35: return 24.0 / 36
        case .mf120: return 1
        }
    }

    /// The frame inside a picture of `e`, centred, keeping its orientation.
    func frame(in e: CGRect) -> CGRect {
        let portrait = e.height >= e.width
        let long = max(e.width, e.height), short = min(e.width, e.height)
        var l = long, s = long * aspect
        if s > short { s = short; l = short / aspect }
        let w = portrait ? s : l, h = portrait ? l : s
        return CGRect(x: e.midX - w / 2, y: e.midY - h / 2, width: w, height: h).integral.intersection(e)
    }
}

/// How the lab scans the roll: at a minilab scanner's size, or the whole sensor.
enum FilmScan: String, CaseIterable, Codable {
    case lab, full
    /// A Frontier's large scan of a 35mm frame is 3088 pixels on the long side.
    var longEdge: CGFloat? { self == .lab ? 3088 : nil }
}

/// FILM's camera and lab, in the order the light goes: the point-and-shoot's lens, its flash,
/// a leak and a mist filter (as light, before the film, so the stock colors them); the format;
/// then the lab's printing (color timing and preflash) and its scanner.
struct FilmRecipe: Codable, Equatable {
    var lens: Double = 0.5
    var flash: Double = 0.5
    var leak: Double = 0.3
    var mist: Double = 0
    var format: FilmFormat = .mm35
    var scan: FilmScan = .lab
    /// Print color timing: + warm (less yellow filter density), − cool.
    var warmth: Double = 0
    /// + magenta, − green.
    var tint: Double = 0
    /// Preflashing the paper: softer, lower-contrast highlights.
    var preflash: Double = 0
    /// The film's own physics, 1 = as measured: light bouncing back off the base, the grain, and
    /// stray light in the camera and on the print.
    var halation: Double = 1
    var grain: Double = 1
    var glare: Double = 1
    /// Look through the XA's finder (bright frame, speed scale, rangefinder patch), or a plain one.
    var xaFinder = true
    /// Fill the finder's surround from the ultra-wide (a second camera running). Experimental.
    var ultraWide = false
    /// The lab's auto-correction, as a minilab operator prints a roll: a dull or dim frame is
    /// printed up and a grey, cold one balanced and warmed, the way film never looks sad.
    var labAuto: Double = 0.7

    init() {}

    // Settings saved before a field existed still load, with that field at its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FilmRecipe()
        lens = try c.decodeIfPresent(Double.self, forKey: .lens) ?? d.lens
        flash = try c.decodeIfPresent(Double.self, forKey: .flash) ?? d.flash
        leak = try c.decodeIfPresent(Double.self, forKey: .leak) ?? d.leak
        mist = try c.decodeIfPresent(Double.self, forKey: .mist) ?? d.mist
        format = try c.decodeIfPresent(FilmFormat.self, forKey: .format) ?? d.format
        scan = try c.decodeIfPresent(FilmScan.self, forKey: .scan) ?? d.scan
        warmth = try c.decodeIfPresent(Double.self, forKey: .warmth) ?? d.warmth
        tint = try c.decodeIfPresent(Double.self, forKey: .tint) ?? d.tint
        preflash = try c.decodeIfPresent(Double.self, forKey: .preflash) ?? d.preflash
        halation = try c.decodeIfPresent(Double.self, forKey: .halation) ?? d.halation
        grain = try c.decodeIfPresent(Double.self, forKey: .grain) ?? d.grain
        glare = try c.decodeIfPresent(Double.self, forKey: .glare) ?? d.glare
        xaFinder = try c.decodeIfPresent(Bool.self, forKey: .xaFinder) ?? d.xaFinder
        ultraWide = try c.decodeIfPresent(Bool.self, forKey: .ultraWide) ?? d.ultraWide
        labAuto = try c.decodeIfPresent(Double.self, forKey: .labAuto) ?? d.labAuto
    }
}

/// One roll's settings as FilmLab needs them for one frame.
struct FilmShot {
    var recipe = FilmRecipe()
    var flashFired = false
    var seed = 0
    /// The lab's correction for this frame (exposure and colour as light gains), from LabAuto.
    var lab: CIVector?
}

/// A minilab's auto-correction (a Frontier's or Noritsu's scanner and printer): it reads the
/// frame and prints it to a normal density and a neutral-but-warm balance. Film shot on a grey
/// day comes back bright and pleasant because the lab does this, not because the film sees
/// more; a phone picture taken under cloud, put through the film as it is, comes out dim, flat
/// and blue. Partial, as labs are: real night stays night and a sunset keeps its colour.
enum LabAuto {
    private static let context = CIContext(options: [.workingColorSpace: NSNull(), .cacheIntermediates: false])
    private static let lock = NSLock()
    private static var cached = CIVector(x: 1, y: 1, z: 1)
    private static var cachedAt: CFTimeInterval = 0

    /// Gains for the linear frame `img`. The viewfinder reads a few times a second and eases.
    static func correction(_ img: CIImage, strength: Double, preview: Bool) -> CIVector {
        let s = CGFloat(max(0, min(1, strength)))
        guard s > 0 else { return CIVector(x: 1, y: 1, z: 1) }
        if preview {
            lock.lock(); let c = cached, at = cachedAt; lock.unlock()
            if CACurrentMediaTime() - at < 0.3 { return c }
        }
        guard let a = average(img) else { return CIVector(x: 1, y: 1, z: 1) }
        var v = gains(a, s)
        if preview {
            lock.lock()
            let c = cachedAt == 0 ? v : cached
            v = CIVector(x: c.x * 0.5 + v.x * 0.5, y: c.y * 0.5 + v.y * 0.5, z: c.z * 0.5 + v.z * 0.5)
            cached = v; cachedAt = CACurrentMediaTime()
            lock.unlock()
        }
        return v
    }

    /// The gains from the frame's average (encoded sRGB, as a scanner meters).
    static func gains(_ a: [CGFloat], _ s: CGFloat) -> CIVector {
        func lin(_ x: CGFloat) -> CGFloat { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        let r = max(lin(a[0]), 1e-4), g = max(lin(a[1]), 1e-4), b = max(lin(a[2]), 1e-4)
        let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
        // Density: two thirds of the way to a normal print, and film's habit of being printed
        // from a well-exposed negative (a third of a stop up).
        let stops = max(-0.8, min(1.2, log2(0.16 / y) * 0.65 * s)) + 0.33 * s
        let k = pow(2, stops)
        // Balance: about half of the cast taken out…
        func bal(_ c: CGFloat) -> CGFloat { max(0.8, min(1.25, pow(y / c, 0.45 * s))) }
        var gr = bal(r), gg = bal(g), gb = bal(b)
        // …and a cold frame (cloud, shade) printed a little warm, as the operators did.
        let cool = max(0, min(1, (b / r - 1) * 2))
        gr *= 1 + 0.05 * s * cool
        gb *= 1 - 0.06 * s * cool
        return CIVector(x: k * gr, y: k * gg, z: k * gb)
    }

    // MARK: the scanner's levels and colour

    /// A grey day prints flat: the darkest thing in the frame is a dark grey and the brightest a
    /// dull white, and every colour sits close to grey. A minilab scanner sets its black and white
    /// points from the frame and the operator adds a little colour, so the print snaps.
    /// x = black point, y = white point (encoded), z = saturation.
    private static var scanCached = CIVector(x: 0, y: 1, z: 1)
    private static var scanAt: CFTimeInterval = 0

    static func scan(_ img: CIImage, strength: Double, mono: Bool, preview: Bool, encoded: Bool = false) -> CIVector {
        let s = CGFloat(max(0, min(1, strength)))
        guard s > 0 else { return CIVector(x: 0, y: 1, z: 1) }
        if preview {
            lock.lock(); let c = scanCached, at = scanAt; lock.unlock()
            if CACurrentMediaTime() - at < 0.3 { return c }
        }
        guard let st = stats(img, encoded: encoded) else { return CIVector(x: 0, y: 1, z: 1) }
        var v = levels(lo: st.lo, hi: st.hi, chroma: mono ? 1 : st.chroma, s)
        if preview {
            lock.lock()
            let c = scanAt == 0 ? v : scanCached
            v = CIVector(x: c.x * 0.5 + v.x * 0.5, y: c.y * 0.5 + v.y * 0.5, z: c.z * 0.5 + v.z * 0.5)
            scanCached = v; scanAt = CACurrentMediaTime()
            lock.unlock()
        }
        return v
    }

    /// From the frame's 2nd and 98th percentile (encoded luma) and its mean colourfulness.
    static func levels(lo: CGFloat, hi: CGFloat, chroma: CGFloat, _ s: CGFloat) -> CIVector {
        // black and white points most of the way to where the frame's own ends are, never so far
        // that a real low-key or high-key frame is forced to full range
        let k = 0.75 * s
        let black = min(0.14, max(0, lo - 0.015) * k)
        let white = max(0.8, 1 - max(0, 0.985 - hi) * k)
        // a pale frame gets up to a third more colour; a colourful one none
        let sat = 1 + 0.35 * s * max(0, min(1, (0.16 - chroma) / 0.12))
        return CIVector(x: black, y: white, z: sat)
    }

    /// Levels and saturation on encoded values (`linear`: the image is linear and is encoded around them).
    static func applyScan(_ img: CIImage, _ v: CIVector, linear: Bool) -> CIImage {
        guard v.x > 0.002 || v.y < 0.998 || v.z > 1.002 else { return img }
        let e = img.extent
        var i = linear ? img.applyingFilter("CILinearToSRGBToneCurve") : img
        let k = 1 / max(0.2, v.y - v.x)
        i = i.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0), "inputBiasVector": CIVector(x: -v.x * k, y: -v.x * k, z: -v.x * k, w: 0)])
        if v.z > 1.002 { i = i.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: v.z]) }
        i = i.applyingFilter("CIColorClamp", parameters: ["inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1),
                                                          "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)])
        if linear { i = i.applyingFilter("CISRGBToneCurveToLinear") }
        return i.cropped(to: e)
    }

    private static func stats(_ img: CIImage, encoded: Bool) -> (lo: CGFloat, hi: CGFloat, chroma: CGFloat)? {
        let e = img.extent
        guard e.width > 1, e.height > 1, e.width.isFinite else { return nil }
        let k = 64 / max(e.width, e.height)
        var small = img.transformed(by: CGAffineTransform(scaleX: k, y: k))
        if !encoded { small = small.applyingFilter("CILinearToSRGBToneCurve") }
        let b = small.extent.integral
        let w = Int(b.width), h = Int(b.height)
        guard w > 2, h > 2 else { return nil }
        var px = [Float](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { raw in
            context.render(small, toBitmap: raw.baseAddress!, rowBytes: w * 16, bounds: b, format: .RGBAf, colorSpace: nil)
        }
        var ys: [Float] = []; ys.reserveCapacity(w * h)
        var chroma: Float = 0
        for i in stride(from: 0, to: px.count, by: 4) {
            let r = px[i], g = px[i + 1], bl = px[i + 2]
            guard r.isFinite, g.isFinite, bl.isFinite else { continue }
            ys.append(0.2126 * r + 0.7152 * g + 0.0722 * bl)
            chroma += max(r, max(g, bl)) - min(r, min(g, bl))
        }
        guard ys.count > 16 else { return nil }
        ys.sort()
        let lo = ys[Int(Float(ys.count) * 0.02)], hi = ys[min(ys.count - 1, Int(Float(ys.count) * 0.98))]
        return (CGFloat(max(0, lo)), CGFloat(min(1, hi)), CGFloat(chroma / Float(ys.count)))
    }

    private static func average(_ img: CIImage) -> [CGFloat]? {
        let e = img.extent
        guard e.width > 1, e.height > 1, e.width.isFinite else { return nil }
        let k = 64 / max(e.width, e.height)
        let small = img.transformed(by: CGAffineTransform(scaleX: k, y: k)).applyingFilter("CILinearToSRGBToneCurve")
        let f = CIFilter.areaAverage()
        f.inputImage = small
        f.extent = small.extent
        guard let out = f.outputImage else { return nil }
        var px = [Float](repeating: 0, count: 4)
        context.render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        guard px.allSatisfy({ $0.isFinite }) else { return nil }
        return px.prefix(3).map { CGFloat(max(0, min(1, $0))) }
    }
}

/// The camera: light effects on the scene before it reaches the film.
enum FilmCamera {
    /// `um` is microns of negative per pixel.
    static func apply(_ img: CIImage, _ shot: FilmShot, um: CGFloat) -> CIImage {
        let r = shot.recipe
        let e = img.extent
        var out = img
        if r.lens > 0 { out = lens(out, amount: min(1, r.lens)) }
        if shot.flashFired && r.flash > 0 { out = flash(out, amount: min(1, r.flash)) }
        if r.mist > 0 { out = mist(out, amount: min(1, r.mist), um: um) }
        if r.leak > 0 {
            // Not every frame: the stronger the setting, the more often the back lets light in.
            var g = SeededRandom(shot.seed &* 7919 &+ 17)
            if g.next() < 0.25 + 0.6 * r.leak { out = leak(out, amount: r.leak, rng: &g) }
        }
        return out.cropped(to: e)
    }

    /// A plastic point-and-shoot lens: the corners fall off about a stop and go soft.
    static func lens(_ img: CIImage, amount a: Double) -> CIImage {
        let e = img.extent
        let c = CIVector(x: e.midX, y: e.midY)
        let diag = hypot(e.width, e.height) / 2
        // Falloff: a radial gain, 1 in the middle to (1 − 0.55a) in the corners.
        let g = CIFilter.radialGradient()
        g.center = CGPoint(x: e.midX, y: e.midY)
        g.radius0 = Float(diag * 0.35)
        g.radius1 = Float(diag)
        let edge = CGFloat(1 - 0.55 * a)
        g.color0 = CIColor(red: 1, green: 1, blue: 1)
        g.color1 = CIColor(red: edge, green: edge, blue: edge)
        guard let gain = g.outputImage?.cropped(to: e) else { return img }
        let mul = CIFilter.multiplyCompositing()
        mul.inputImage = img
        mul.backgroundImage = gain
        var out = (mul.outputImage ?? img).cropped(to: e)
        // Soft corners: the same picture blurred, let in toward the edge.
        let blur = out.clampedToExtent().applyingGaussianBlur(sigma: Double(min(e.width, e.height) * 0.004 * a)).cropped(to: e)
        let m = CIFilter.radialGradient()
        m.center = CGPoint(x: c.x, y: c.y)
        m.radius0 = Float(diag * 0.5)
        m.radius1 = Float(diag)
        m.color0 = CIColor(red: 0, green: 0, blue: 0)
        m.color1 = CIColor(red: 1, green: 1, blue: 1)
        if let mask = m.outputImage?.cropped(to: e) {
            let b = CIFilter.blendWithMask()
            b.inputImage = blur
            b.backgroundImage = out
            b.maskImage = mask
            out = (b.outputImage ?? out).cropped(to: e)
        }
        return out
    }

    /// A built-in flash is a small hot cone: the middle of the frame gets it full, the edges and
    /// the room behind fall away.
    static func flash(_ img: CIImage, amount a: Double) -> CIImage {
        let e = img.extent
        let diag = hypot(e.width, e.height) / 2
        let g = CIFilter.radialGradient()
        g.center = CGPoint(x: e.midX, y: e.midY + e.height * 0.05)
        g.radius0 = Float(diag * 0.15)
        g.radius1 = Float(diag * 0.95)
        let hot = CGFloat(pow(2, 0.35 * a)), cold = CGFloat(pow(2, -1.1 * a))
        g.color0 = CIColor(red: hot, green: hot, blue: hot)
        g.color1 = CIColor(red: cold, green: cold, blue: cold)
        guard let gain = g.outputImage?.cropped(to: e) else { return img }
        // Shadows (the room) drop more than the lit subject: the flash's inverse square.
        let lift = CIFilter.gammaAdjust()
        lift.inputImage = img
        lift.power = Float(1 + 0.25 * a)
        let mul = CIFilter.multiplyCompositing()
        mul.inputImage = lift.outputImage ?? img
        mul.backgroundImage = gain
        return (mul.outputImage ?? img).cropped(to: e)
    }

    /// A Pro-Mist style diffusion filter: some of the light spread into a wide glow around
    /// highlights, energy kept (spektrafilm's diffusion_filter, core and halo).
    static func mist(_ img: CIImage, amount a: Double, um: CGFloat) -> CIImage {
        let e = img.extent
        let halo = img.clampedToExtent().applyingGaussianBlur(sigma: Double(180 / um)).cropped(to: e)
        let core = img.clampedToExtent().applyingGaussianBlur(sigma: Double(30 / um)).cropped(to: e)
        let kh = CGFloat(0.16 * a), kc = CGFloat(0.1 * a)
        return mix3(img, 1 - kh - kc, core, kc, halo, kh, e)
    }

    /// Light getting past the back door, and never the same twice. Each one is a different
    /// kind of leak (a glow off one edge, a band across the frame from the film advance, a burnt
    /// corner, or two at once), from a random place, in a random color of light, as light, so
    /// the film turns it the oranges, reds and magentas real leaks come out as.
    static func leak(_ img: CIImage, amount a: Double, rng: inout SeededRandom) -> CIImage {
        let e = img.extent
        var out = img
        let kind = Int(rng.next() * 4)
        let count = kind == 3 ? 2 : 1
        for _ in 0..<count {
            let light: CIImage?
            switch kind == 3 ? Int(rng.next() * 3) : kind {
            case 1: light = band(e, a, &rng)
            case 2: light = corner(e, a, &rng)
            default: light = edgeGlow(e, a, &rng)
            }
            if let light { out = FilmLab.addLight(out, light) }
        }
        return out
    }

    /// The color of the leaking light: mostly warm, sometimes pink-red, sometimes nearly white.
    private static func leakColor(_ s: CGFloat, _ rng: inout SeededRandom) -> CIColor {
        let pick = rng.next()
        let (g, b): (CGFloat, CGFloat)
        if pick < 0.45 { (g, b) = (0.55 + 0.15 * CGFloat(rng.next()), 0.22) }        // orange
        else if pick < 0.7 { (g, b) = (0.25, 0.32 + 0.2 * CGFloat(rng.next())) }   // pink, magenta
        else if pick < 0.88 { (g, b) = (0.8, 0.35) }                               // yellow
        else { (g, b) = (0.9, 0.8) }                                               // almost white
        return CIColor(red: s, green: s * g, blue: s * b)
    }

    private static func edgeGlow(_ e: CGRect, _ a: Double, _ rng: inout SeededRandom) -> CIImage? {
        let side = Int(rng.next() * 4)
        let along = CGFloat(rng.next())
        let p: CGPoint
        switch side {
        case 0: p = CGPoint(x: e.minX, y: e.minY + e.height * along)
        case 1: p = CGPoint(x: e.maxX, y: e.minY + e.height * along)
        case 2: p = CGPoint(x: e.minX + e.width * along, y: e.minY)
        default: p = CGPoint(x: e.minX + e.width * along, y: e.maxY)
        }
        let g = CIFilter.radialGradient()
        g.center = p
        g.radius0 = 0
        g.radius1 = Float(min(e.width, e.height) * CGFloat(0.3 + 0.6 * rng.next()) * CGFloat(0.6 + 0.6 * a))
        g.color0 = leakColor(CGFloat(1 + 3 * a * (0.5 + rng.next())), &rng)
        g.color1 = CIColor(red: 0, green: 0, blue: 0)
        return g.outputImage?.cropped(to: e)
    }

    /// A soft band across the frame, the way a leak through the film gate fogs a strip.
    private static func band(_ e: CGRect, _ a: Double, _ rng: inout SeededRandom) -> CIImage? {
        let vertical = rng.next() < 0.6
        let at = CGFloat(0.05 + 0.9 * rng.next())
        let width = min(e.width, e.height) * CGFloat(0.08 + 0.25 * rng.next())
        let c = leakColor(CGFloat(0.8 + 2.4 * a * (0.5 + rng.next())), &rng)
        let center = vertical ? e.minX + e.width * at : e.minY + e.height * at
        // A band is two gradients back to back, fading out on either side.
        func ramp(_ from: CGFloat, _ to: CGFloat) -> CIImage? {
            let g = CIFilter.linearGradient()
            g.point0 = vertical ? CGPoint(x: from, y: e.midY) : CGPoint(x: e.midX, y: from)
            g.point1 = vertical ? CGPoint(x: to, y: e.midY) : CGPoint(x: e.midX, y: to)
            g.color0 = c
            g.color1 = CIColor(red: 0, green: 0, blue: 0)
            return g.outputImage
        }
        guard let lo = ramp(center, center - width), let hi = ramp(center, center + width) else { return nil }
        let loR = vertical ? CGRect(x: e.minX, y: e.minY, width: center - e.minX, height: e.height) : CGRect(x: e.minX, y: e.minY, width: e.width, height: center - e.minY)
        let hiR = vertical ? CGRect(x: center, y: e.minY, width: e.maxX - center, height: e.height) : CGRect(x: e.minX, y: center, width: e.width, height: e.maxY - center)
        var light = hi.cropped(to: hiR).composited(over: lo.cropped(to: loR)).cropped(to: e)
        // Stronger toward one end, as the light came in from one side.
        let fade = CIFilter.linearGradient()
        let end = rng.next() < 0.5
        fade.point0 = vertical ? CGPoint(x: e.midX, y: end ? e.minY : e.maxY) : CGPoint(x: end ? e.minX : e.maxX, y: e.midY)
        fade.point1 = vertical ? CGPoint(x: e.midX, y: end ? e.maxY : e.minY) : CGPoint(x: end ? e.maxX : e.minX, y: e.midY)
        fade.color0 = CIColor(red: 1, green: 1, blue: 1)
        let f = CGFloat(0.2 + 0.4 * rng.next())
        fade.color1 = CIColor(red: f, green: f, blue: f)
        if let m = fade.outputImage {
            let mul = CIFilter.multiplyCompositing()
            mul.inputImage = light
            mul.backgroundImage = m.cropped(to: e)
            light = (mul.outputImage ?? light).cropped(to: e)
        }
        return light
    }

    /// A burnt corner: the light floods one corner hard.
    private static func corner(_ e: CGRect, _ a: Double, _ rng: inout SeededRandom) -> CIImage? {
        let cx = rng.next() < 0.5 ? e.minX : e.maxX, cy = rng.next() < 0.5 ? e.minY : e.maxY
        let g = CIFilter.radialGradient()
        g.center = CGPoint(x: cx, y: cy)
        g.radius0 = Float(min(e.width, e.height) * 0.05)
        g.radius1 = Float(min(e.width, e.height) * CGFloat(0.4 + 0.5 * rng.next()))
        g.color0 = leakColor(CGFloat(2 + 4 * a), &rng)
        g.color1 = CIColor(red: 0, green: 0, blue: 0)
        return g.outputImage?.cropped(to: e)
    }

    private static func mix3(_ a: CIImage, _ ka: CGFloat, _ b: CIImage, _ kb: CGFloat, _ c: CIImage, _ kc: CGFloat, _ e: CGRect) -> CIImage {
        func k(_ i: CIImage, _ s: CGFloat) -> CIImage {
            let m = CIFilter.colorMatrix()
            m.inputImage = i
            m.rVector = CIVector(x: s, y: 0, z: 0, w: 0); m.gVector = CIVector(x: 0, y: s, z: 0, w: 0)
            m.bVector = CIVector(x: 0, y: 0, z: s, w: 0); m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            return (m.outputImage ?? i).cropped(to: e)
        }
        return FilmLab.addLight(FilmLab.addLight(k(a, ka), k(b, kb)), k(c, kc))
    }
}

/// A small fixed random sequence: a photo keeps its leak.
struct SeededRandom {
    private var s: UInt64
    init(_ seed: Int) { s = UInt64(truncatingIfNeeded: seed) }
    /// SplitMix64: neighbouring seeds give unrelated sequences.
    mutating func next() -> Double {
        s = s &+ 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}
