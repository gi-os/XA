import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// The viewfinder's film, fast enough for 30 frames a second on little power.
///
/// Everything FilmLab does to a single pixel (exposure, the negative, push development, the
/// lab's timing, the print) is baked once into one colour cube, rebuilt only when the stock,
/// push or print settings change. Each frame is then: the camera's light falloff, the lab's
/// correction, a glow from a small blurred copy, the cube, and grain from a texture made once and
/// slid about. The photo you take still goes through the full FilmLab.develop.
enum FilmPreview {
    private static let lock = NSLock()
    private static var cubes: [String: Data] = [:]
    private static var order: [String] = []
    private static let n = 25
    private static let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull(), .cacheIntermediates: false])

    static func develop(_ input: CIImage, stock: FilmStock, push: Int, seed: Int, shot: FilmShot?) -> CIImage? {
        let e = input.extent
        guard e.width > 1, e.height > 1, e.width.isFinite, let cube = cube(stock, push: push, recipe: shot?.recipe) else { return nil }
        let full = CGRect(origin: .zero, size: e.size)
        var img = input.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
        let r = shot?.recipe
        let um: CGFloat = (r?.format.longMM ?? 36) * 1000 / max(e.width, e.height)
        // The camera: only the lens's falloff (its soft corners are a blur; the finder skips it).
        if let r, r.lens > 0 { img = vignette(img, amount: min(1, r.lens), full) }
        // The lab's correction for this frame (exposure and balance as light gains).
        if let c = shot?.lab { img = scale(img, c.x, c.y, c.z, full) }
        // Halation from a quarter-size copy: cheap, and a glow is soft anyway.
        let h = CGFloat(stock.halation * (r?.halation ?? 1))
        if h > 0.01, let t = FilmLab.tables(stock.id) {
            _ = t
            let q: CGFloat = 0.25
            let small = img.transformed(by: CGAffineTransform(scaleX: q, y: q))
            let glow = small.clampedToExtent().applyingGaussianBlur(sigma: Double(FilmLab.Fit.halationUM * 1.4 / um * q))
                .cropped(to: small.extent).samplingLinear()
                .transformed(by: CGAffineTransform(scaleX: 1 / q, y: 1 / q)).cropped(to: full)
            // the full lab adds it after its exposure gain; before the gain it is the same share
            let k = FilmLab.Fit.halationR * h
            let halo = stock.mono ? scale(glow, k * 0.4, k * 0.4, k * 0.4, full)
                                  : scale(glow, k, FilmLab.Fit.halationG * h, 0, full)
            img = FilmLab.addLight(img, halo)
        }
        // The film, in one table: light in (as code), print out (linear).
        img = img.applyingFilter("CILinearToSRGBToneCurve")
            .applyingFilter("CIColorClamp", parameters: ["inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1),
                                                         "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)])
        let f = CIFilter.colorCube()
        f.inputImage = img
        f.cubeDimension = Float(n)
        f.cubeData = cube
        img = (f.outputImage ?? img).cropped(to: full)
        // The scanner's levels and colour (see LabAuto.scan), read off the print a few times a second.
        if let r, r.labAuto > 0 {
            img = LabAuto.applyScan(img, LabAuto.scan(img, strength: r.labAuto, mono: stock.mono, preview: true), linear: true)
        }
        // Grain: density noise is a multiplication of the light. The texture is made once.
        let gr = stock.grain * (r?.grain ?? 1) * max(0.5, 1 + 0.3 * Double(push))
        if gr > 0, let tex = grainTexture(), let k = grainKernel {
            var g = SeededRandom(seed)
            let dx = CGFloat(g.next() * 512), dy = CGFloat(g.next() * 512)
            // the grain clumps are ~7 µm on the negative: as big as the texture's when a pixel is ~4 µm
            let s = max(1, min(4, 4 / um * 7))
            let noise = tex.applyingFilter("CIAffineTile", parameters: [kCIInputTransformKey: CGAffineTransform(scaleX: s, y: s)])
                .transformed(by: CGAffineTransform(translationX: -dx * s, y: -dy * s)).cropped(to: full)
            let amp = Float(gr * 2.3 * 3.2 * min(1.6, max(0.6, 12 / um)))
            if let out = k.apply(extent: full, arguments: [img, noise, amp, Float(stock.mono ? 0 : 0.25)]) { img = out }
        }
        return Sanitize.apply(img, floor: 0).transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY))
    }

    // MARK: the cube

    /// The per-pixel film for this stock, push and print, as a cube: sRGB code in, linear print out.
    static func cube(_ stock: FilmStock, push: Int, recipe: FilmRecipe?) -> Data? {
        let r = recipe
        let key = "\(stock.id)|\(push)|\(r?.warmth ?? 0)|\(r?.tint ?? 0)|\(r?.preflash ?? 0)|\(r?.scan.rawValue ?? "-")|\(r?.glare ?? 0)"
        lock.lock()
        if let c = cubes[key] { lock.unlock(); return c }
        lock.unlock()
        guard let made = build(stock, push: push, recipe: recipe) else { return nil }
        lock.lock()
        cubes[key] = made; order.append(key)
        if order.count > 12 { cubes[order.removeFirst()] = nil }
        lock.unlock()
        return made
    }

    private static func build(_ stock: FilmStock, push: Int, recipe: FilmRecipe?) -> Data? {
        // A lattice of every cube entry as an image (n wide, n·n tall), in linear light.
        var px = [Float](repeating: 1, count: n * n * n * 4)
        func dec(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : powf((v + 0.055) / 1.055, 2.4) }
        for b in 0..<n { for g in 0..<n { for r in 0..<n {
            let i = ((b * n + g) * n + r) * 4
            px[i] = dec(Float(r) / Float(n - 1)); px[i + 1] = dec(Float(g) / Float(n - 1)); px[i + 2] = dec(Float(b) / Float(n - 1))
        } } }
        let data = px.withUnsafeBufferPointer { Data(buffer: $0) }
        let lattice = CIImage(bitmapData: data, bytesPerRow: n * 16, size: CGSize(width: n, height: n * n), format: .RGBAf, colorSpace: nil)
        var shot = FilmShot(recipe: recipe ?? FilmRecipe(), flashFired: false, seed: 1)
        // per pixel only: no camera, no glow, no grain (the frame adds those itself)
        shot.recipe.lens = 0; shot.recipe.flash = 0; shot.recipe.leak = 0; shot.recipe.mist = 0
        shot.recipe.halation = 0; shot.recipe.grain = 0; shot.recipe.glare = 0
        let out = FilmLab.develop(lattice, stock: stock, push: push, preview: true, seed: 1, shot: recipe == nil ? nil : shot, flat: true)
        var res = [Float](repeating: 0, count: n * n * n * 4)
        res.withUnsafeMutableBytes { raw in
            context.render(out, toBitmap: raw.baseAddress!, rowBytes: n * 16, bounds: CGRect(x: 0, y: 0, width: n, height: n * n), format: .RGBAf, colorSpace: nil)
        }
        // Bitmap in and bitmap out keep the same row order, so the entries come back where they went.
        var cube = res.map { $0.isFinite ? $0 : 0 }
        for i in stride(from: 3, to: cube.count, by: 4) { cube[i] = 1 }
        return cube.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    // MARK: grain

    private static var texture: CIImage?
    /// 512² of soft noise, centred on 0.5, alpha 1, made once.
    private static func grainTexture() -> CIImage? {
        lock.lock(); if let t = texture { lock.unlock(); return t }; lock.unlock()
        guard let rnd = CIFilter.randomGenerator().outputImage, let opaque = opaqueKernel else { return nil }
        let box = CGRect(x: 0, y: 0, width: 512, height: 512)
        guard let flat = opaque.apply(extent: box, arguments: [rnd.cropped(to: box)]) else { return nil }
        let soft = flat.clampedToExtent().applyingGaussianBlur(sigma: 0.9).cropped(to: box)
        // the blur narrows the spread; stretch it back to a unit-ish spread around 0.5
        let stretched = soft.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 3.2, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 3.2, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 3.2, w: 0), "inputBiasVector": CIVector(x: -1.1, y: -1.1, z: -1.1, w: 0)])
        guard let cg = context.createCGImage(stretched, from: box, format: .RGBA8, colorSpace: nil) else { return nil }
        let t = CIImage(cgImage: cg)
        lock.lock(); texture = t; lock.unlock()
        return t
    }

    private static let opaqueKernel = CIColorKernel(source: "kernel vec4 xaOpaque(__sample s) { return vec4(s.r, s.g, s.b, 1.0); }")
    /// Light × 10^(noise × amp): grain is density. Shared across the channels, with a little colour.
    private static let grainKernel = CIColorKernel(source: """
    kernel vec4 xaFastGrain(__sample c, __sample n, float amp, float chroma) {
        float l = max(max(c.r, max(c.g, c.b)), 1e-4);
        float mid = sqrt(clamp(1.0 - l, 0.04, 1.0));
        vec3 d = vec3(n.r - 0.5) + chroma * (n.gbr - vec3(0.5));
        return vec4(c.rgb * pow(vec3(10.0), d * amp * mid * 0.25), 1.0);
    }
    """)

    // MARK: helpers

    private static func scale(_ i: CIImage, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ full: CGRect) -> CIImage {
        i.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: r, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: g, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: b, w: 0)]).cropped(to: full)
    }

    private static func vignette(_ img: CIImage, amount a: Double, _ full: CGRect) -> CIImage {
        let diag = hypot(full.width, full.height) / 2
        let g = CIFilter.radialGradient()
        g.center = CGPoint(x: full.midX, y: full.midY)
        g.radius0 = Float(diag * 0.35); g.radius1 = Float(diag)
        let edge = CGFloat(1 - 0.55 * a)
        g.color0 = CIColor(red: 1, green: 1, blue: 1); g.color1 = CIColor(red: edge, green: edge, blue: edge)
        guard let gain = g.outputImage?.cropped(to: full) else { return img }
        let m = CIFilter.multiplyCompositing()
        m.inputImage = img; m.backgroundImage = gain
        return (m.outputImage ?? img).cropped(to: full)
    }
}
