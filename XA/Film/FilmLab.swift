import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// A film stock XA develops for real: two tables baked from spektrafilm (scene light →
/// negative density, negative → print), with everything that depends on neighbouring pixels
/// done here around them. See tools/filmsim for how the tables are made and how the effects
/// below were fitted against spektrafilm's full simulation.
struct FilmStock: Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    /// Box speed.
    let rated: Int
    /// "T" for tungsten stock, else empty.
    let suffix: String
    /// Grain strength in density (RMS) at box speed.
    let grain: Double
    /// Halation strength, 1 = the fitted default.
    let halation: Double
    /// What an underexposed frame turns once the lab has lifted it: density added to each record
    /// of the negative where it is thin. More on the green record prints green; less on the blue
    /// takes away the print paper's own blue. Fuji stocks go green to cyan, Kodak consumer stocks
    /// green to olive, Portra and Ektar hold on longer.
    var toe = CIVector(x: 0, y: 0.05, z: -0.03)
    /// Black and white: one silver layer, so grain and glow have no colour and the print is neutral.
    var mono = false

    /// The speed you shoot at, pushed or pulled `push` stops, as a film speed on the 1/3 scale.
    func ei(_ push: Int) -> Int { FilmStock.nearestISO(Double(rated) * pow(2, Double(push))) }

    static let isoScale = [12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800,
                           1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800]
    static func nearestISO(_ v: Double) -> Int {
        isoScale.min(by: { abs(log2(Double($0) / v)) < abs(log2(Double($1) / v)) }) ?? Int(v)
    }

    /// The DX code along the cassette: 12 cells, silver (true) or black. Cells 0 and 6 are the
    /// contacts; 1–5 carry the speed as its step on the 1/3 scale.
    static func dx(_ iso: Int) -> [Bool] {
        let step = (isoScale.firstIndex(of: iso) ?? 0) + 1
        return [true, step & 1 == 1, step >> 1 & 1 == 1, step >> 2 & 1 == 1, step >> 3 & 1 == 1, step >> 4 & 1 == 1,
                true, false, true, true, false, true]
    }

    static let pushRange = -2...2

    static let all: [FilmStock] = [
        // Grain is RMS density at a lab scan's pixel, spread out the way the stocks are known for:
        // Ektar the finest, Portra fine, consumer 200 and 400 visibly grainy, 500T and 1600 coarse.
        FilmStock(id: "bowery400", name: "Bowery", rated: 400, suffix: "", grain: 0.010, halation: 1,
                  toe: CIVector(x: 0, y: 0.035, z: -0.025)),
        FilmStock(id: "bowery800", name: "Bowery", rated: 800, suffix: "", grain: 0.015, halation: 1,
                  toe: CIVector(x: 0, y: 0.04, z: -0.025)),
        FilmStock(id: "coney200", name: "Coney", rated: 200, suffix: "", grain: 0.013, halation: 1,
                  toe: CIVector(x: 0.01, y: 0.06, z: -0.04)),
        FilmStock(id: "chelsea100", name: "Chelsea", rated: 100, suffix: "", grain: 0.006, halation: 0.9,
                  toe: CIVector(x: 0, y: 0.025, z: -0.01)),
        FilmStock(id: "prospect200", name: "Prospect", rated: 200, suffix: "", grain: 0.013, halation: 1,
                  toe: CIVector(x: 0.05, y: 0.06, z: 0)),
        FilmStock(id: "canal500t", name: "Canal", rated: 500, suffix: "T", grain: 0.017, halation: 1.5,
                  toe: CIVector(x: 0.03, y: 0.04, z: 0.01)),
        FilmStock(id: "orchard400", name: "Orchard", rated: 400, suffix: "", grain: 0.015, halation: 1,
                  toe: CIVector(x: 0.06, y: 0.07, z: 0)),
        // Natura 1600 (Superia 1600 in Japan's box), read from Fujifilm's datasheet: tools/filmsim/natura.
        FilmStock(id: "ludlow1600", name: "Ludlow", rated: 1600, suffix: "", grain: 0.023, halation: 1.1,
                  toe: CIVector(x: 0.03, y: 0.1, z: -0.07)),
        // Black and white (tools/filmsim/bw): curves shaped like the published ones.
        // Tri-X 400: classic, punchy, visible grain.
        FilmStock(id: "bleecker400", name: "Bleecker", rated: 400, suffix: "", grain: 0.021, halation: 0.35,
                  toe: CIVector(x: 0, y: 0, z: 0), mono: true),
        // Delta 3200: big smooth grain, soft, a slower film pushed.
        FilmStock(id: "delancey3200", name: "Delancey", rated: 3200, suffix: "", grain: 0.034, halation: 0.35,
                  toe: CIVector(x: 0, y: 0, z: 0), mono: true),
        // T-MAX P3200: crisp, contrasty, finer and sharper grain.
        FilmStock(id: "essexp3200", name: "Essex", rated: 3200, suffix: "P", grain: 0.026, halation: 0.3,
                  toe: CIVector(x: 0, y: 0, z: 0), mono: true),
    ]
    static func stock(_ id: String?) -> FilmStock? { all.first { $0.id == id } }
}

enum FilmLab {
    /// Effect strengths fitted against spektrafilm's full simulation (tools/filmsim/fitted.json).
    /// Sizes are microns on a 35mm negative, so they hold at any resolution.
    struct Fit {
        static let scatterWeight: Float = 0.295, scatterUM: CGFloat = 13.04
        static let halationR: CGFloat = 0.072, halationG: CGFloat = 0.012, halationUM: CGFloat = 42.88
        static let couplerK: Float = 0.56, couplerUM: CGFloat = 7.64
        static let couplerTailK: Float = 0.089, couplerTailUM: CGFloat = 193.6
        static let dyeBlurUM: CGFloat = 14.4
        static let grainClumpUM: CGFloat = 7, grainChroma: Float = 0.06, grainTop: Float = 0.7
        static let sharpen: Float = 0.774, sharpenUM: CGFloat = 20.95
        /// Used only when a stock has no calibrated exposure of its own (stocks.json "ev").
        static let exposureEV: Double = -1.5
    }

    struct Tables {
        let size: Int
        let film: Data
        let print: Data
        let dmin: CIVector
        let dmax: CIVector
        /// The exposure that prints an 18% grey card as 18% grey (tools/filmsim/calibrate_ev.py).
        let ev: Double
        /// The density the lab adds back when printing a pushed or pulled roll, per push.
        let pushOffset: [Int: CIVector]
        /// Where an 18% grey card lands on the negative (mean code value): what "thin" is measured from.
        let greyCode: Double
    }

    private static let lock = NSLock()
    private static var cache: [String: Tables] = [:]
    private static let meta: [String: [String: Any]] = {
        guard let url = bundle.url(forResource: "stocks", withExtension: "json"),
              let d = try? Data(contentsOf: url),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: [String: Any]] else { return [:] }
        return j
    }()
    /// The app's bundle, also from the Lock Screen camera and from tests.
    static var bundle: Bundle {
        if Bundle.main.url(forResource: "stocks", withExtension: "json") != nil { return Bundle.main }
        return Bundle(for: BundleToken.self)
    }
    private final class BundleToken {}

    static func tables(_ id: String) -> Tables? {
        lock.lock(); defer { lock.unlock() }
        if let t = cache[id] { return t }
        guard let m = meta[id], let n = m["size"] as? Int,
              let dmin = m["dmin"] as? [Double], let dmax = m["dmax"] as? [Double],
              let film = rgba(id + "_film", n), let print = rgba(id + "_print", n) else { return nil }
        var offsets: [Int: CIVector] = [:]
        for (k, v) in (m["push_offset"] as? [String: [Double]]) ?? [:] where v.count == 3 {
            if let p = Int(k) { offsets[p] = CIVector(x: v[0], y: v[1], z: v[2]) }
        }
        let t = Tables(size: n, film: film, print: print,
                       dmin: CIVector(x: dmin[0], y: dmin[1], z: dmin[2]), dmax: CIVector(x: dmax[0], y: dmax[1], z: dmax[2]),
                       ev: (m["ev"] as? Double) ?? Fit.exposureEV, pushOffset: offsets,
                       greyCode: (m["grey_code"] as? Double) ?? 0.48)
        cache[id] = t
        return t
    }

    /// RGB Float32 on disk → the RGBA Float32 a colour cube wants.
    private static func rgba(_ name: String, _ n: Int) -> Data? {
        guard let url = bundle.url(forResource: name, withExtension: "bin"), let d = try? Data(contentsOf: url),
              d.count == n * n * n * 3 * 4 else { return nil }
        var out = [Float](repeating: 1, count: n * n * n * 4)
        d.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Float.self)
            for i in 0..<(n * n * n) {
                out[i * 4] = src[i * 3]; out[i * 4 + 1] = src[i * 3 + 1]; out[i * 4 + 2] = src[i * 3 + 2]
            }
        }
        return out.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static let densityKernel = CIColorKernel(source: """
    kernel vec4 xaDensity(__sample c, __sample bc, __sample bt, float kc, float kt, float gam, vec3 off, vec3 dmin, vec3 dmax, vec3 timing, float pre, vec3 toe, float lift, float grey) {
        vec3 code = c.rgb + kc * (c.rgb - bc.rgb) + kt * (c.rgb - bt.rgb);
        // Thin negative (an underexposed part of the frame, two stops down and more): the lab
        // scanner lifts it, and it comes up muddy and off-color, in the stock's own way.
        float thin = 1.0 - smoothstep(grey - 0.28, grey - 0.06, (code.r + code.g + code.b) / 3.0);
        code = code + thin * (toe + vec3(lift));
        vec3 D = code * (dmax - dmin) + dmin;
        D = max(D, vec3(0.0)) * gam + min(D, vec3(0.0)) + off;
        // The lab's printing: color timing is filter density in each printing light, the same as
        // density on the negative; a preflash is a little even light on the paper, which the
        // densest parts of the negative (the highlights) feel most.
        D = D + timing;
        D = -log(pow(vec3(10.0), -D) + vec3(pre)) / 2.302585;
        return vec4((D - dmin) / (dmax - dmin), 1.0);
    }
    """)

    /// Two lights added (alpha stays 1).
    static func addLight(_ a: CIImage, _ b: CIImage) -> CIImage {
        let e = a.extent
        return addLightKernel?.apply(extent: e, arguments: [a, b]) ?? a
    }

    /// What the sensor clipped, given back: the brightest parts pushed up to the light they
    /// really were, so a lamp or a window throws a halo the way it does on film (spektrafilm's
    /// highlight boost).
    private static let boostKernel = CIColorKernel(source: """
    kernel vec4 xaBoost(__sample c, float ev, float range) {
        float m = max(c.r, max(c.g, c.b));
        float t = smoothstep(1.0 - range, 1.0, m);
        return vec4(c.rgb * exp2(ev * t), 1.0);
    }
    """)

    private static let addLightKernel = CIColorKernel(source: """
    kernel vec4 xaAddLight(__sample a, __sample b) { return vec4(a.rgb + b.rgb, 1.0); }
    """)

    /// Grain in three layers, as the film is built: red and green at the fitted clump size, the
    /// blue layer twice as coarse (spektrafilm's particle_scale 1.6, 1.6, 3.2). Each layer has a
    /// fast emulsion of bigger grains under its slow one, and the thin parts of the negative (the
    /// shadows) are made mostly by the fast, coarse grains.
    private static let grainKernel = CIColorKernel(source: """
    kernel vec4 xaGrain(__sample c, __sample a, __sample b, __sample cc, float rms, float chroma, float top, vec3 norm, vec3 dmin, vec3 dmax) {
        vec3 D = c.rgb * (dmax - dmin) + dmin;
        float l = sqrt(1.0 - chroma);
        float k = sqrt(chroma);
        vec3 fine = vec3(l * (a.r - 0.5) + k * (a.g - 0.5) , l * (a.r - 0.5) + k * (a.b - 0.5), l * (b.r - 0.5) + k * (b.a - 0.5)) * vec3(norm.x, norm.x, norm.y);
        vec3 coarse = vec3(l * (b.r - 0.5) + k * (b.g - 0.5), l * (b.r - 0.5) + k * (b.b - 0.5), l * (cc.r - 0.5) + k * (cc.a - 0.5)) * vec3(norm.y, norm.y, norm.z);
        vec3 d = max(D - dmin, vec3(0.02));
        vec3 n = mix(fine, coarse, 0.6 * exp(-d / 0.35));
        vec3 q = d / top;
        vec3 amp = rms * sqrt(d) / (vec3(1.0) + q * q);
        D = D + n * amp;
        return vec4((D - dmin) / (dmax - dmin), 1.0);
    }
    """)

    /// Develop a frame (linear, Core Image's working space) on `stock`, shot `push` stops over
    /// or under box speed. `seed` fixes the grain of a photo; the viewfinder passes a fresh one.
    /// Tests can look at each stage.
    static var trace: ((String, CIImage) -> Void)?

    static func develop(_ input: CIImage, stock: FilmStock, push: Int, preview: Bool, seed: Int, shot: FilmShot? = nil, flat: Bool = false) -> CIImage {
        // The viewfinder: the film baked into one cube (FilmPreview), not the whole lab per frame.
        if preview && !flat, let fast = FilmPreview.develop(input, stock: stock, push: push, seed: seed, shot: shot) { return fast }
        guard let t = tables(stock.id) else { return input }
        let e = input.extent
        guard e.width > 1, e.height > 1, e.width.isFinite, e.height.isFinite else { return input }
        var img = input.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
        let full = CGRect(origin: .zero, size: e.size)
        // Microns of negative per pixel: the format sets how big grain and glow are on the picture.
        let um: CGFloat = (shot?.recipe.format.longMM ?? 36) * 1000 / max(e.width, e.height)
        func blur(_ i: CIImage, _ microns: CGFloat) -> CIImage {
            let r = microns / um
            guard r > 0.3 else { return i }
            return i.clampedToExtent().applyingGaussianBlur(sigma: Double(r)).cropped(to: full)
        }
        func scale(_ i: CIImage, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CIImage {
            let m = CIFilter.colorMatrix()
            m.inputImage = i
            m.rVector = CIVector(x: r, y: 0, z: 0, w: 0); m.gVector = CIVector(x: 0, y: g, z: 0, w: 0)
            m.bVector = CIVector(x: 0, y: 0, z: b, w: 0); m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            return (m.outputImage ?? i).cropped(to: full)
        }
        // Exposure: a push is shot at a faster speed, so the negative gets less light.
        let gain = CGFloat(pow(2, t.ev - Double(push)))
        trace?("input", img)
        // The camera: lens, flash, mist and leaks, as light on the scene before the film.
        if let shot { img = FilmCamera.apply(img, shot, um: um) }
        // The lab's correction: printed to a normal density and balance (see LabAuto).
        if let c = shot?.lab { img = scale(img, c.x, c.y, c.z) }
        let scene = img
        img = scale(img, gain, gain, gain)
        let r = shot?.recipe
        // Stray light in the camera: a few percent of the frame's light veils it, most where it
        // is brightest (spektrafilm's film glare, 3%).
        let filmGlare = CGFloat(0.03 * (r?.glare ?? 0))
        if filmGlare > 0 { img = addLight(img, scale(veil(img, full), filmGlare, filmGlare, filmGlare)) }
        trace?("exposed", img)
        // Light spreading in the emulsion, then the red halo from the film base.
        if !flat {
            let mix = CIFilter.dissolveTransition()
            mix.inputImage = img; mix.targetImage = blur(img, Fit.scatterUM); mix.time = Fit.scatterWeight
            img = (mix.outputImage ?? img).cropped(to: full)
        }
        trace?("scattered", img)
        let h = CGFloat(stock.halation * (r?.halation ?? 1))
        // The halo is light only. (Compositing it with CIAdditionCompositing doubled the alpha, and
        // Core Image then halved every colour un-premultiplying it: a stop of lost exposure.)
        // Light goes through the base, bounces off the back and comes back wider each time: three
        // bounces, each half the last and √k as wide (spektrafilm's n_bounces 3, decay 0.5), from
        // the scene with its clipped highlights given back.
        var source = scale(scene, gain, gain, gain)
        if r != nil, let k = boostKernel, let b = k.apply(extent: full, arguments: [scene, 1.5, 0.3]) { source = scale(b, gain, gain, gain) }
        var bounced = scale(blur(source, Fit.halationUM), 4.0 / 7, 4.0 / 7, 4.0 / 7)
        if r != nil && !preview {
            for (k, w) in [(2.0, 2.0 / 7), (3.0, 1.0 / 7)] {
                bounced = addLight(bounced, scale(blur(source, Fit.halationUM * CGFloat(k.squareRoot())), w, w, w))
            }
        } else {
            bounced = blur(source, Fit.halationUM)
        }
        // Black-and-white film has an anti-halation backing and no red layer: a faint grey glow.
        let halo = stock.mono ? scale(bounced, Fit.halationR * h * 0.4, Fit.halationR * h * 0.4, Fit.halationR * h * 0.4)
                              : scale(bounced, Fit.halationR * h, Fit.halationG * h, 0)
        if !flat, h > 0, let k = addLightKernel, let lit = k.apply(extent: full, arguments: [img, halo]) { img = lit }
        trace?("halation", img)
        // Into the tables' code space: sRGB-encoded, 0…1.
        img = img.applyingFilter("CILinearToSRGBToneCurve")
        img = img.applyingFilter("CIColorClamp", parameters: ["inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1),
                                                             "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)])
        trace?("code in", img)
        img = cube(img, t.film, t.size, full)
        trace?("negative", img)
        // On the negative: inhibitor couplers (local contrast), push development, dye clouds, grain.
        let gamma = Float(1 + 0.12 * Double(push))
        if let k = densityKernel,
           let d = k.apply(extent: full, arguments: [img, flat ? img : blur(img, Fit.couplerUM), flat ? img : blur(img, Fit.couplerTailUM),
                                                      Fit.couplerK, Fit.couplerTailK, gamma,
                                                      t.pushOffset[push] ?? CIVector(x: 0, y: 0, z: 0), t.dmin, t.dmax,
                                                      timing(shot?.recipe), Float(max(0, shot?.recipe.preflash ?? 0) * 0.02),
                                                      shot == nil ? CIVector(x: 0, y: 0, z: 0) : CIVector(x: stock.toe.x * CGFloat(shot!.under), y: stock.toe.y * CGFloat(shot!.under), z: stock.toe.z * CGFloat(shot!.under)),
                                                      Float(shot == nil || stock.mono ? 0 : (shot?.recipe.scan == .lab ? 0.09 : 0.05) * (shot?.under ?? 0)), Float(t.greyCode)]) {
            img = d
        }
        trace?("developed", img)
        if !flat { img = blur(img, Fit.dyeBlurUM) }
        if !flat, let g = grainKernel, let rnd = CIFilter.randomGenerator().outputImage {
            // Clumps as a scanner sees them (the dye clouds merge into grains of about 14 µm), and
            // the strength a pixel of that size shows: a smaller pixel averages over fewer grains.
            let clump = max(0.6, 2 * Fit.grainClumpUM / um / 2.355)
            let aperture = 1.8 * min(1.6, max(0.4, 12 / um))
            let shift = CGFloat(seed % 9973) * 37
            func noise(_ dx: CGFloat, _ dy: CGFloat, _ sigma: CGFloat) -> CIImage {
                rnd.transformed(by: CGAffineTransform(translationX: dx, y: dy)).cropped(to: full)
                    .clampedToExtent().applyingGaussianBlur(sigma: Double(sigma)).cropped(to: full)
            }
            let a = noise(shift, shift * 0.7, clump)
            let b = noise(-shift * 1.3 - 5000, shift + 3000, clump * 2)
            let c = noise(shift * 0.6 + 9000, -shift - 7000, clump * 4)
            // Uniform noise has a spread of 0.289; a blur of `clump` pixels averages it down.
            func norm(_ s: CGFloat) -> CGFloat { max(1, 2 * s * sqrt(.pi)) / 0.2887 }
            let rms = Float(stock.grain * aperture * (r?.grain ?? 1) * max(0.5, 1 + 0.3 * Double(push)))
            let norms = CIVector(x: norm(clump), y: norm(clump * 2), z: norm(clump * 4))
            if stock.mono {
                // one silver layer: no colour in the grain (red and green share one noise; the
                // print is then made neutral). The noise is used raw: a colour matrix would
                // un-premultiply the generator's random alpha and bias the grain.
                if let out = g.apply(extent: full, arguments: [img, a, b, c, rms, Float(0), Fit.grainTop, norms, t.dmin, t.dmax]) {
                    img = out
                }
            } else if let out = g.apply(extent: full, arguments: [img, a, b, c, rms, Fit.grainChroma, Fit.grainTop, norms, t.dmin, t.dmax]) {
                img = out
            }
        }
        img = img.applyingFilter("CIColorClamp", parameters: ["inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1),
                                                             "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)])
        trace?("grained", img)
        img = cube(img, t.print, t.size, full)
        // The scanner: levels and colour set from the frame, as a minilab operator's scanner does.
        if !flat, !preview, let r = shot?.recipe, r.labAuto > 0 {
            img = LabAuto.applyScan(img, LabAuto.scan(img, strength: r.labAuto, mono: stock.mono, preview: false, encoded: true), linear: false)
        }
        if stock.mono {
            // a neutral silver print
            img = img.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.3, y: 0.59, z: 0.11, w: 0), "inputGVector": CIVector(x: 0.3, y: 0.59, z: 0.11, w: 0),
                "inputBVector": CIVector(x: 0.3, y: 0.59, z: 0.11, w: 0)]).cropped(to: full)
        }
        trace?("print", img)
        img = img.applyingFilter("CISRGBToneCurveToLinear")
        // Flare on the print: a little of its light lifts its deepest blacks.
        let printGlare = CGFloat(0.012 * (r?.glare ?? 0))
        if printGlare > 0 {
            img = addLight(scale(img, 1 - printGlare, 1 - printGlare, 1 - printGlare), scale(veil(img, full), printGlare, printGlare, printGlare))
        }
        // The lab scanner's sharpening.
        if !flat && (!preview || um < 40) {
            let us = CIFilter.unsharpMask()
            us.inputImage = img.clampedToExtent(); us.radius = Float(Fit.sharpenUM / um); us.intensity = Fit.sharpen
            img = (us.outputImage ?? img).cropped(to: full)
        }
        return Sanitize.apply(img, floor: 0).transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY))
    }

    /// The light of the whole frame, spread wide: what a veiling glare adds.
    static func veil(_ i: CIImage, _ full: CGRect) -> CIImage {
        let k: CGFloat = 64 / max(full.width, full.height, 1)
        let small = i.transformed(by: CGAffineTransform(scaleX: k, y: k))
        let b = small.clampedToExtent().applyingGaussianBlur(sigma: 9).cropped(to: small.extent)
        return b.clampedToExtent().samplingLinear().transformed(by: CGAffineTransform(scaleX: 1 / k, y: 1 / k)).cropped(to: full)
    }

    /// Print filter density per printing light. Warmer: less density on the blue printing light
    /// (more yellow dye on the print). Magenta: more on the green.
    static func timing(_ r: FilmRecipe?) -> CIVector {
        guard let r else { return CIVector(x: 0, y: 0, z: 0) }
        let w = CGFloat(r.warmth) * 0.12, m = CGFloat(r.tint) * 0.1
        return CIVector(x: w * 0.25, y: -m, z: -w)
    }

    static func cube(_ i: CIImage, _ data: Data, _ n: Int, _ full: CGRect) -> CIImage {
        let f = CIFilter.colorCube()
        f.inputImage = i
        f.cubeDimension = Float(n)
        f.cubeData = data
        return (f.outputImage ?? i).cropped(to: full)
    }
}
