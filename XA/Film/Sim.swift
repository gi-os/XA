import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// A color, 0…1, that can be saved.
struct Tone: Codable, Equatable, Hashable {
    var r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    static let neutral = Tone(0.5, 0.5, 0.5)
}

/// What a sim prints the photograph on.
enum SimFrame: String, Codable, CaseIterable {
    case none, instant, round
}

/// A film simulation: every dial the editor shows, saved as data.
/// Colour work collapses into one 32³ colour cube; grain, halation and vignette run after it.
struct Sim: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    var iso: String = "400"
    var exposures: Int = 36

    // COLOR
    var warmth: Double = 0          // −1 cool … +1 warm
    var tint: Double = 0            // −1 green … +1 magenta
    var saturation: Double = 0      // −1 … +1
    var redHue: Double = 0, redSat: Double = 0
    var greenHue: Double = 0, greenSat: Double = 0
    var blueHue: Double = 0, blueSat: Double = 0
    var shadowTone: Tone = .neutral, shadowAmount: Double = 0
    var highlightTone: Tone = .neutral, highlightAmount: Double = 0
    var mono: Bool = false

    // TONE
    var contrast: Double = 0        // −1 … +1
    var curve: [Double] = [0, 0.25, 0.5, 0.75, 1]   // y at x = 0, ¼, ½, ¾, 1
    var fade: Double = 0            // lifts the blacks
    var rolloff: Double = 0         // highlight shoulder

    // GRAIN
    var grain: Double = 0
    var grainSize: Double = 0.3
    var halation: Double = 0
    var halationTone: Tone = Tone(1, 0.3, 0.18)
    /// White glow around bright light. Optional so films saved before it existed still load.
    var bloomAmount: Double? = nil
    var bloom: Double {
        get { bloomAmount ?? 0 }
        set { bloomAmount = newValue }
    }
    var vignette: Double = 0

    var frame: SimFrame = .none
    var box: BoxDesign = BoxDesign()
    /// Saved stacks remember the look and shape too.
    var look: Int? = nil
    var shape: Int? = nil
    /// A real film stock developed by FilmLab instead of the colour dials.
    var stock: String? = nil
    /// Display only: the push the loaded box shows. Never saved.
    var shownPush: Int? = nil

    var title: String { "\(name) \(iso)".uppercased() }
    var isPreset: Bool { Sim.presets.contains { $0.id == id } }

    /// The camera's own colour, no film emulation: what DIGI does with nothing loaded.
    static let neutral: Sim = {
        var s = Sim(id: "neutral", name: "Neutral", iso: "100", exposures: 36)
        s.box = BoxDesign(bg: "#1C3F7A", fg: "#E8F0FF", accent: "#E8F0FF", second: "#2A5296", font: .shareTech, pattern: .plain)
        return s
    }()
    static var neutralPreset: Sim { neutral }
    var isNeutral: Bool { id == Sim.neutral.id }

    /// Neutral, then the seven XA stocks. Names and boxes are XA's own; the looks are what the
    /// films they are modelled on are known for.
    static let presets: [Sim] = [neutral] + stocks + [nocturne, visage, prima, amethyst, sunday, onyx]

    /// The film stocks, developed for real (FilmLab).
    static let stocks: [Sim] = FilmStock.all.map { st in
        var s = Sim(id: st.id, name: st.name, iso: "\(st.rated)\(st.suffix)", exposures: 36)
        s.stock = st.id
        s.mono = st.mono
        return s
    }

    /// Tungsten-balanced cinema stock: cool daylight, red halation round every highlight.
    static let nocturne: Sim = {
        var s = Sim(id: "nocturne", name: "Nocturne", iso: "800T", exposures: 36)
        s.bloom = 0.3
        s.warmth = -0.55; s.tint = -0.08; s.saturation = 0.08; s.contrast = 0.12
        s.redHue = -0.08; s.blueHue = 0.12; s.blueSat = 0.1
        s.shadowTone = Tone(0.18, 0.46, 0.52); s.shadowAmount = 0.45
        s.highlightTone = Tone(0.95, 0.72, 0.5); s.highlightAmount = 0.2
        s.fade = 0.06; s.rolloff = 0.5
        s.grain = 0.45; s.grainSize = 0.35; s.halation = 0.75; s.vignette = 0.2
        s.box = BoxDesign(bg: "#0E1A22", fg: "#EAF2F5", accent: "#D8412F", second: "#6FB6C9", font: .oxanium, pattern: .plain)
        return s
    }()

    /// Portrait pro stock: soft contrast, forgiving skin, pastel greens.
    static let visage: Sim = {
        var s = Sim(id: "visage", name: "Visage", iso: "800", exposures: 36)
        s.bloom = 0.25
        s.warmth = 0.12; s.saturation = -0.12; s.contrast = -0.18
        s.redHue = 0.08; s.redSat = -0.08; s.greenHue = -0.15; s.greenSat = -0.2; s.blueHue = -0.08
        s.highlightTone = Tone(0.98, 0.84, 0.72); s.highlightAmount = 0.25
        s.shadowTone = Tone(0.42, 0.44, 0.58); s.shadowAmount = 0.2
        s.fade = 0.12; s.rolloff = 0.7
        s.grain = 0.3; s.grainSize = 0.3; s.vignette = 0.1
        s.box = BoxDesign(bg: "#F3E7C9", fg: "#4A3A6A", accent: "#D98BB5", second: "#7F78D2", font: .cormorant, pattern: .split)
        return s
    }()

    /// Consumer 400 from the green box: punchy, cool-green shadows, bright blues.
    static let prima: Sim = {
        var s = Sim(id: "prima", name: "Prima X", iso: "400", exposures: 36)
        s.bloom = 0.1
        s.warmth = 0.04; s.tint = -0.1; s.saturation = 0.22; s.contrast = 0.2
        s.greenHue = 0.1; s.greenSat = 0.2; s.blueSat = 0.15; s.redSat = 0.1
        s.shadowTone = Tone(0.3, 0.55, 0.48); s.shadowAmount = 0.3
        s.fade = 0.03; s.rolloff = 0.3
        s.grain = 0.4; s.grainSize = 0.4
        s.box = BoxDesign(bg: "#3F9A45", fg: "#FFFFFF", accent: "#8E1E6E", second: "#E24DA0", font: .archivo, pattern: .swoosh)
        return s
    }()

    /// A purple cast: greens swing to violet, shadows go plum.
    static let amethyst: Sim = {
        var s = Sim(id: "amethyst", name: "Amethyst", iso: "400", exposures: 36)
        s.bloom = 0.15
        s.warmth = -0.2; s.tint = 0.45; s.saturation = 0.1; s.contrast = 0.1
        s.greenHue = 1; s.greenSat = -0.25; s.blueHue = 0.35; s.redHue = -0.1
        s.shadowTone = Tone(0.45, 0.22, 0.62); s.shadowAmount = 0.6
        s.highlightTone = Tone(0.96, 0.74, 0.9); s.highlightAmount = 0.3
        s.fade = 0.08; s.grain = 0.35
        s.box = BoxDesign(bg: "#C9B6F2", fg: "#2A124F", accent: "#7A2BD1", second: "#F1B6E6", font: .unbounded, pattern: .band)
        return s
    }()

    /// Instant film: low contrast, milky blacks, teal shadows, printed on a white frame.
    static let sunday: Sim = {
        var s = Sim(id: "sunday", name: "Sunday", iso: "600", exposures: 36)
        s.bloom = 0.35
        s.warmth = 0.18; s.saturation = -0.1; s.contrast = -0.28
        s.shadowTone = Tone(0.25, 0.52, 0.55); s.shadowAmount = 0.4
        s.highlightTone = Tone(0.98, 0.9, 0.74); s.highlightAmount = 0.25
        s.fade = 0.28; s.rolloff = 0.85
        s.grain = 0.18; s.vignette = 0.25
        s.box = BoxDesign(bg: "#F7F5F0", fg: "#1A1A1A", accent: "#E07A5F", second: "#7FC8C4", font: .nunito, pattern: .plain)
        return s
    }()

    /// High-contrast black and white, pushed two stops.
    static let onyx: Sim = {
        var s = Sim(id: "onyx", name: "Onyx", iso: "3200", exposures: 36)
        s.bloom = 0.2
        s.mono = true; s.contrast = 0.6
        s.curve = [0, 0.18, 0.5, 0.84, 1]
        s.grain = 0.8; s.grainSize = 0.6; s.vignette = 0.3
        s.box = BoxDesign(bg: "#F4F1EA", fg: "#0A0A0A", accent: "#8A8A8A", second: "#0A0A0A", font: .bebas, pattern: .split)
        return s
    }()
}

enum SimEngine {
    private static let lock = NSLock()
    private static var cubes: [Sim: Data] = [:]

    /// One colour through every colour dial. Also what the cube is built from.
    static func map(_ s: Sim, _ c: Looks.RGB) -> Looks.RGB {
        var r: Float = c.0, g: Float = c.1, b: Float = c.2
        // White balance.
        let w = Float(s.warmth), t = Float(s.tint)
        r *= 1 + 0.12 * w + 0.03 * t
        b *= 1 - 0.12 * w + 0.03 * t
        g *= 1 - 0.06 * t
        r = clamp(r); g = clamp(g); b = clamp(b)
        // Hue and saturation per colour band.
        if !s.mono {
            let hv = hsv(r, g, b)
            var h: Float = hv.0
            var sat: Float = hv.1
            let v: Float = hv.2
            let wr = band(h, 0), wg = band(h, 1.0 / 3.0), wb = band(h, 2.0 / 3.0)
            let shiftR: Float = wr * Float(s.redHue)
            let shiftG: Float = wg * Float(s.greenHue)
            let shiftB: Float = wb * Float(s.blueHue)
            h += (shiftR + shiftG + shiftB) * 0.25
            h = h - floor(h)
            let sR: Float = wr * Float(s.redSat)
            let sG: Float = wg * Float(s.greenSat)
            let sB: Float = wb * Float(s.blueSat)
            sat *= 1 + sR + sG + sB
            sat *= 1 + Float(s.saturation)
            sat = clamp(sat)
            (r, g, b) = rgb(h, sat, v)
        }
        // Tone, per channel.
        r = tone(r, s); g = tone(g, s); b = tone(b, s)
        if s.mono {
            let l = Looks.luma((r, g, b))
            return (clamp(l), clamp(l), clamp(l))
        }
        // Split tone by luminance.
        let l = Looks.luma((r, g, b))
        let ws: Float = (1 - l) * (1 - l) * Float(s.shadowAmount) * 0.5
        let wh: Float = l * l * Float(s.highlightAmount) * 0.5
        r += Float(s.shadowTone.r - 0.5) * ws + Float(s.highlightTone.r - 0.5) * wh
        g += Float(s.shadowTone.g - 0.5) * ws + Float(s.highlightTone.g - 0.5) * wh
        b += Float(s.shadowTone.b - 0.5) * ws + Float(s.highlightTone.b - 0.5) * wh
        return (clamp(r), clamp(g), clamp(b))
    }

    static func tone(_ x0: Float, _ s: Sim) -> Float {
        var x = x0
        let k = Float(s.contrast)
        if k != 0 {
            // A smooth S that keeps 0 and 1 where they are.
            let sx: Float = x * x * (3 - 2 * x)
            x = x + (sx - x) * k * 1.4
        }
        x = curve(x, s.curve)
        if s.rolloff > 0 {
            let knee: Float = 1 - 0.4 * Float(s.rolloff)
            if x > knee {
                let span: Float = 1 - knee
                x = knee + span * tanh((x - knee) / span)
            }
        }
        let f: Float = Float(s.fade) * 0.2
        x = f + x * (1 - f)
        return clamp(x)
    }

    static func curve(_ x: Float, _ ys: [Double]) -> Float {
        guard ys.count >= 2 else { return x }
        let n = ys.count - 1
        let p: Float = clamp(x) * Float(n)
        let i = min(n - 1, Int(p))
        let f: Float = p - Float(i)
        let a = Float(ys[i]), b = Float(ys[i + 1])
        return a + (b - a) * f
    }

    /// How much hue `h` belongs to the band centred on `c` (0…1 around the wheel).
    static func band(_ h: Float, _ c: Float) -> Float {
        var d = abs(h - c)
        d = min(d, 1 - d)
        let sigma: Float = 1.0 / 11.0
        return exp(-(d * d) / (2 * sigma * sigma))
    }

    static func clamp(_ v: Float) -> Float { min(1, max(0, v)) }

    static func hsv(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        let mx = max(r, g, b), mn = min(r, g, b)
        let d = mx - mn
        var h: Float = 0
        if d > 0.00001 {
            if mx == r { h = (g - b) / d } else if mx == g { h = 2 + (b - r) / d } else { h = 4 + (r - g) / d }
            h /= 6
            if h < 0 { h += 1 }
        }
        let s: Float = mx > 0 ? d / mx : 0
        return (h, s, mx)
    }

    static func rgb(_ h: Float, _ s: Float, _ v: Float) -> (Float, Float, Float) {
        if s <= 0 { return (v, v, v) }
        let hh: Float = (h - floor(h)) * 6
        let i = Int(hh) % 6
        let f: Float = hh - floor(hh)
        let p: Float = v * (1 - s)
        let q: Float = v * (1 - s * f)
        let t: Float = v * (1 - s * (1 - f))
        switch i {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }

    static func cube(for s: Sim) -> Data {
        var key = s
        key.box = BoxDesign(); key.name = ""; key.id = ""; key.iso = ""
        key.grain = 0; key.grainSize = 0; key.halation = 0; key.bloomAmount = nil; key.vignette = 0; key.look = nil; key.shape = nil; key.frame = .none
        lock.lock()
        if let d = cubes[key] { lock.unlock(); return d }
        lock.unlock()
        let d = Looks.makeCube { map(s, $0) }
        lock.lock()
        if cubes.count > 24 { cubes.removeAll() }
        cubes[key] = d
        lock.unlock()
        return d
    }

    /// The whole sim on an image: cube, then halation, grain and vignette.
    static func apply(_ s: Sim, to img: CIImage, preview: Bool, push: Int = 0, seed: Int? = nil, shot: FilmShot? = nil) -> CIImage {
        if let st = FilmStock.stock(s.stock) {
            return FilmLab.develop(img, stock: st, push: push, preview: preview, seed: seed ?? Int.random(in: 0..<100_000), shot: shot)
        }
        let e = img.extent
        let clean = Sanitize.apply(img)
        let lit = (s.halation > 0 || s.bloom > 0) ? Sanitize.apply(glow(clean, halation: s.halation, tone: s.halationTone, bloom: s.bloom)) : clean
        let f = CIFilter.colorCubeWithColorSpace()
        f.inputImage = lit
        f.cubeDimension = 32
        f.cubeData = cube(for: s)
        if let cs = CGColorSpace(name: CGColorSpace.sRGB) { f.colorSpace = cs }
        var out = (f.outputImage ?? img).cropped(to: e)
        if s.grain > 0 { out = grain(out, amount: s.grain, size: s.grainSize) }
        if s.vignette > 0 {
            let v = CIFilter.vignetteEffect()
            v.inputImage = out
            v.center = CGPoint(x: e.midX, y: e.midY)
            let diag: CGFloat = hypot(e.width, e.height)
            v.radius = Float(diag * 0.55)
            v.intensity = Float(s.vignette * 0.9)
            v.falloff = 0.6
            out = (v.outputImage ?? out).cropped(to: e)
        }
        return Sanitize.apply(out, floor: 0)
    }

    /// How far each pixel goes past `threshold`, in linear light, colour kept. With an HDR
    /// photo a lamp is several times brighter than white paper, so only real light sources glow.
    static func excess(_ img: CIImage, over threshold: CGFloat) -> CIImage {
        let k: CGFloat = 1 / max(0.05, 1 - threshold)
        let m = CIFilter.colorMatrix()
        m.inputImage = img
        m.rVector = CIVector(x: k, y: 0, z: 0, w: 0)
        m.gVector = CIVector(x: 0, y: k, z: 0, w: 0)
        m.bVector = CIVector(x: 0, y: 0, z: k, w: 0)
        m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        m.biasVector = CIVector(x: -threshold * k, y: -threshold * k, z: -threshold * k, w: 0)
        let c = CIFilter.colorClamp()
        c.inputImage = m.outputImage
        c.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        c.maxComponents = CIVector(x: 8, y: 8, z: 8, w: 1)
        return c.outputImage ?? img
    }

    /// A long-tailed glow: four blurs, tight to wide, summed. Worked at a quarter size (glow is
    /// all low frequency) and scaled back up.
    static func spread(_ src: CIImage, extent e: CGRect, widths: [CGFloat], weights: [CGFloat]) -> CIImage? {
        let q: CGFloat = 0.25
        let small = src.transformed(by: CGAffineTransform(scaleX: q, y: q)).clampedToExtent()
        let diag: CGFloat = hypot(e.width, e.height) * q
        var sum: CIImage?
        for (w, wt) in zip(widths, weights) {
            let b = CIFilter.gaussianBlur()
            b.inputImage = small
            b.radius = Float(diag * w)
            guard let blurred = b.outputImage else { continue }
            let m = CIFilter.colorMatrix()
            m.inputImage = blurred
            m.rVector = CIVector(x: wt, y: 0, z: 0, w: 0)
            m.gVector = CIVector(x: 0, y: wt, z: 0, w: 0)
            m.bVector = CIVector(x: 0, y: 0, z: wt, w: 0)
            m.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            guard let layer = m.outputImage else { continue }
            if let s0 = sum {
                let add = CIFilter.additionCompositing(); add.inputImage = layer; add.backgroundImage = s0
                sum = add.outputImage
            } else { sum = layer }
        }
        return sum?.transformed(by: CGAffineTransform(scaleX: 1 / q, y: 1 / q)).cropped(to: e)
    }

    /// Bloom: white light scattering round bright sources, in their own colour.
    /// Halation: the red ring from light bouncing off the film base into the red layer. The
    /// core stays white (it is already clipped), so the red shows as a ring around it.
    static func glow(_ img: CIImage, halation: Double, tone: Tone, bloom: Double) -> CIImage {
        let e = img.extent
        var out = img
        if bloom > 0, let g = spread(excess(img, over: 0.72), extent: e, widths: [0.004, 0.012, 0.035, 0.09], weights: [0.35, 0.3, 0.22, 0.13]) {
            let t = CIFilter.colorMatrix(); t.inputImage = g
            let a = CGFloat(bloom) * 0.9
            t.rVector = CIVector(x: a, y: 0, z: 0, w: 0)
            t.gVector = CIVector(x: 0, y: a * 0.97, z: 0, w: 0)
            t.bVector = CIVector(x: 0, y: 0, z: a * 0.9, w: 0)
            t.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            if let tinted = t.outputImage {
                let add = CIFilter.additionCompositing(); add.inputImage = tinted; add.backgroundImage = out
                out = (add.outputImage ?? out).cropped(to: e)
            }
        }
        if halation > 0 {
            // The glow's brightness, not its colour: halation is red whatever the light was.
            let lum = CIFilter.colorMatrix(); lum.inputImage = excess(img, over: 0.86)
            let l = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
            lum.rVector = l; lum.gVector = l; lum.bVector = l
            lum.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            if let bright = lum.outputImage, let g = spread(bright, extent: e, widths: [0.003, 0.01, 0.03], weights: [0.42, 0.35, 0.23]) {
                let t = CIFilter.colorMatrix(); t.inputImage = g
                let a = CGFloat(halation) * 1.4
                t.rVector = CIVector(x: CGFloat(tone.r) * a, y: 0, z: 0, w: 0)
                t.gVector = CIVector(x: 0, y: CGFloat(tone.g) * a, z: 0, w: 0)
                t.bVector = CIVector(x: 0, y: 0, z: CGFloat(tone.b) * a, w: 0)
                t.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
                if let tinted = t.outputImage {
                    let add = CIFilter.additionCompositing(); add.inputImage = tinted; add.backgroundImage = out
                    out = (add.outputImage ?? out).cropped(to: e)
                }
            }
        }
        return out
    }

    static func grain(_ img: CIImage, amount: Double, size: Double) -> CIImage {
        FilmGrain.apply(img, amount: amount, size: size)
    }
}
