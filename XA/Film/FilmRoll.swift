import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

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
}

/// One roll's settings as FilmLab needs them for one frame.
struct FilmShot {
    var recipe = FilmRecipe()
    var flashFired = false
    var seed = 0
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

    /// Light getting past the back door: warm white flooding in from one edge, as light, so the
    /// film burns it orange and red the way it really does.
    static func leak(_ img: CIImage, amount a: Double, rng: inout SeededRandom) -> CIImage {
        let e = img.extent
        let side = Int(rng.next() * 4)
        let along = rng.next()
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
        g.radius1 = Float(min(e.width, e.height) * CGFloat(0.35 + 0.45 * rng.next()) * CGFloat(0.6 + 0.6 * a))
        let s = CGFloat(1.2 + 2.5 * a)
        g.color0 = CIColor(red: s, green: s * 0.62, blue: s * 0.3)
        g.color1 = CIColor(red: 0, green: 0, blue: 0)
        guard let light = g.outputImage?.cropped(to: e) else { return img }
        return FilmLab.addLight(img, light)
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
    init(_ seed: Int) { s = UInt64(truncatingIfNeeded: seed) &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double((s >> 33) % 1_000_000) / 1_000_000
    }
}
