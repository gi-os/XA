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
        FilmStock(id: "bowery400", name: "Bowery", rated: 400, suffix: "", grain: 0.010, halation: 1),
        FilmStock(id: "bowery800", name: "Bowery", rated: 800, suffix: "", grain: 0.013, halation: 1),
        FilmStock(id: "coney200", name: "Coney", rated: 200, suffix: "", grain: 0.010, halation: 1),
        FilmStock(id: "chelsea100", name: "Chelsea", rated: 100, suffix: "", grain: 0.006, halation: 0.9),
        FilmStock(id: "prospect200", name: "Prospect", rated: 200, suffix: "", grain: 0.010, halation: 1),
        FilmStock(id: "canal500t", name: "Canal", rated: 500, suffix: "T", grain: 0.012, halation: 1.5),
        FilmStock(id: "orchard400", name: "Orchard", rated: 400, suffix: "", grain: 0.011, halation: 1),
        // Natura 1600 (Superia 1600 in Japan's box), read from Fujifilm's datasheet: tools/filmsim/natura.
        FilmStock(id: "ludlow1600", name: "Ludlow", rated: 1600, suffix: "", grain: 0.017, halation: 1.1),
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
                       ev: (m["ev"] as? Double) ?? Fit.exposureEV, pushOffset: offsets)
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
    kernel vec4 xaDensity(__sample c, __sample bc, __sample bt, float kc, float kt, float gam, vec3 off, vec3 dmin, vec3 dmax) {
        vec3 code = c.rgb + kc * (c.rgb - bc.rgb) + kt * (c.rgb - bt.rgb);
        vec3 D = code * (dmax - dmin) + dmin;
        D = max(D, vec3(0.0)) * gam + min(D, vec3(0.0)) + off;
        return vec4((D - dmin) / (dmax - dmin), 1.0);
    }
    """)

    private static let grainKernel = CIColorKernel(source: """
    kernel vec4 xaGrain(__sample c, __sample n1, __sample n2, float rms, float chroma, float top, float norm, vec3 dmin, vec3 dmax) {
        vec3 D = c.rgb * (dmax - dmin) + dmin;
        vec3 n = (sqrt(1.0 - chroma) * (n1.r - 0.5) + sqrt(chroma) * (n2.rgb - vec3(0.5))) * norm;
        vec3 d = max(D - dmin, vec3(0.02));
        vec3 q = d / top;
        vec3 amp = rms * sqrt(d) / (vec3(1.0) + q * q);
        D = D + n * amp;
        return vec4((D - dmin) / (dmax - dmin), 1.0);
    }
    """)

    /// Develop a frame (linear, Core Image's working space) on `stock`, shot `push` stops over
    /// or under box speed. `seed` fixes the grain of a photo; the viewfinder passes a fresh one.
    static func develop(_ input: CIImage, stock: FilmStock, push: Int, preview: Bool, seed: Int) -> CIImage {
        guard let t = tables(stock.id) else { return input }
        let e = input.extent
        guard e.width > 1, e.height > 1, e.width.isFinite, e.height.isFinite else { return input }
        var img = input.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
        let full = CGRect(origin: .zero, size: e.size)
        let um: CGFloat = 36000 / max(e.width, e.height)
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
        img = scale(img, gain, gain, gain)
        // Light spreading in the emulsion, then the red halo from the film base.
        let mix = CIFilter.dissolveTransition()
        mix.inputImage = img; mix.targetImage = blur(img, Fit.scatterUM); mix.time = Fit.scatterWeight
        img = (mix.outputImage ?? img).cropped(to: full)
        let h = CGFloat(stock.halation)
        let halo = scale(blur(img, Fit.halationUM), Fit.halationR * h, Fit.halationG * h, 0)
        img = halo.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: full)
        // Into the tables' code space: sRGB-encoded, 0…1.
        img = img.applyingFilter("CILinearToSRGBToneCurve")
        img = img.applyingFilter("CIColorClamp", parameters: ["inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1),
                                                             "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)])
        img = cube(img, t.film, t.size, full)
        // On the negative: inhibitor couplers (local contrast), push development, dye clouds, grain.
        let gamma = Float(1 + 0.12 * Double(push))
        if let k = densityKernel,
           let d = k.apply(extent: full, arguments: [img, blur(img, Fit.couplerUM), blur(img, Fit.couplerTailUM),
                                                      Fit.couplerK, Fit.couplerTailK, gamma,
                                                      t.pushOffset[push] ?? CIVector(x: 0, y: 0, z: 0), t.dmin, t.dmax]) {
            img = d
        }
        img = blur(img, Fit.dyeBlurUM)
        if let g = grainKernel, let rnd = CIFilter.randomGenerator().outputImage {
            let clump = max(0.35, Fit.grainClumpUM / um / 2.355)
            let shift = CGFloat(seed % 9973) * 37
            let n1 = rnd.transformed(by: CGAffineTransform(translationX: shift, y: shift * 0.7)).cropped(to: full)
                .clampedToExtent().applyingGaussianBlur(sigma: Double(clump)).cropped(to: full)
            let n2 = rnd.transformed(by: CGAffineTransform(translationX: -shift * 1.3 - 5000, y: shift + 3000)).cropped(to: full)
                .clampedToExtent().applyingGaussianBlur(sigma: Double(clump)).cropped(to: full)
            // Uniform noise has a spread of 0.289; a blur of `clump` pixels averages it down.
            let norm = Float(max(1, 2 * clump * sqrt(.pi)) / 0.2887)
            let rms = Float(stock.grain * max(0.5, 1 + 0.3 * Double(push)))
            if let out = g.apply(extent: full, arguments: [img, n1, n2, rms, Fit.grainChroma, Fit.grainTop, norm, t.dmin, t.dmax]) {
                img = out
            }
        }
        img = img.applyingFilter("CIColorClamp", parameters: ["inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1),
                                                             "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)])
        img = cube(img, t.print, t.size, full)
        img = img.applyingFilter("CISRGBToneCurveToLinear")
        // The lab scanner's sharpening.
        if !preview || um < 40 {
            let us = CIFilter.unsharpMask()
            us.inputImage = img.clampedToExtent(); us.radius = Float(Fit.sharpenUM / um); us.intensity = Fit.sharpen
            img = (us.outputImage ?? img).cropped(to: full)
        }
        return Sanitize.apply(img, floor: 0).transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY))
    }

    private static func cube(_ i: CIImage, _ data: Data, _ n: Int, _ full: CGRect) -> CIImage {
        let f = CIFilter.colorCube()
        f.inputImage = i
        f.cubeDimension = Float(n)
        f.cubeData = data
        return (f.outputImage ?? i).cropped(to: full)
    }
}
