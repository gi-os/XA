import CoreImage
import CoreImage.CIFilterBuiltins

/// Film grain that behaves like film: monochrome, clumped rather than per-pixel, sized to the
/// frame rather than to the pixels, and weighted to the midtones. Deep shadows and clean
/// highlights stay quieter, the way a negative does.
enum FilmGrain {
    /// `moving`: a fresh patch of noise each call, so video grain dances instead of sitting
    /// on the lens like dirt. Stills leave it off and stay repeatable.
    static func apply(_ img: CIImage, amount: Double, size: Double, moving: Bool = false, seed: Int = 0) -> CIImage {
        guard amount > 0, let rnd = CIFilter.randomGenerator().outputImage else { return img }
        let e = img.extent
        // A grain is a fraction of the frame, never a single pixel: at 2MP a fine grain is about
        // two pixels across and a coarse one five. Per-pixel noise reads as a bad sensor.
        let unit: CGFloat = max(1, min(e.width, e.height) / 640)
        let cell: CGFloat = unit * (1.1 + CGFloat(size) * 2.2)
        // One channel of noise, grey. The generator's raw values are used as they are: a colour
        // matrix would un-premultiply its random alpha and bias every grain bright.
        guard let grey = rawGrey?.apply(extent: .infinite, arguments: [rnd]) else { return img }
        // A still keeps its own grain (its seed); video takes a fresh patch every frame.
        let jump: CGAffineTransform
        if moving {
            jump = CGAffineTransform(translationX: CGFloat(Int.random(in: -4000...4000)), y: CGFloat(Int.random(in: -4000...4000)))
        } else {
            var g = SeededRandom(seed &* 31 &+ 7)
            jump = CGAffineTransform(translationX: CGFloat(Int(g.next() * 8000) - 4000), y: CGFloat(Int(g.next() * 8000) - 4000))
        }
        let scaled = grey.transformed(by: jump).transformed(by: CGAffineTransform(scaleX: cell, y: cell))
        // Clumps: a little blur, then the contrast the blur took away put back.
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = scaled
        blur.radius = Float(cell * 0.75)
        guard let soft = blur.outputImage?.cropped(to: e) else { return img }
        let amp: CGFloat = CGFloat(amount) * 0.09
        let boost: CGFloat = 2.6
        let signed = CIFilter.colorMatrix()
        signed.inputImage = soft
        signed.rVector = CIVector(x: 2 * amp * boost, y: 0, z: 0, w: 0)
        signed.gVector = CIVector(x: 0, y: 2 * amp * boost, z: 0, w: 0)
        signed.bVector = CIVector(x: 0, y: 0, z: 2 * amp * boost, w: 0)
        signed.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        signed.biasVector = CIVector(x: -amp * boost, y: -amp * boost, z: -amp * boost, w: 1)
        guard let noise = signed.outputImage?.cropped(to: e) else { return img }
        // Midtone weight from the picture's own luminance.
        let lum = CIFilter.colorControls()
        lum.inputImage = img
        lum.saturation = 0
        let bump = CIFilter.toneCurve()
        bump.inputImage = lum.outputImage
        bump.point0 = CGPoint(x: 0, y: 0.3)
        bump.point1 = CGPoint(x: 0.25, y: 0.85)
        bump.point2 = CGPoint(x: 0.5, y: 1)
        bump.point3 = CGPoint(x: 0.75, y: 0.8)
        bump.point4 = CGPoint(x: 1, y: 0.25)
        guard let mask = bump.outputImage?.cropped(to: e) else { return img }
        let weigh = CIFilter.multiplyCompositing()
        weigh.inputImage = noise
        weigh.backgroundImage = mask
        guard let weighted = weigh.outputImage else { return img }
        // Added as light, the picture's own alpha kept (a layer with alpha 0 would add nothing).
        return addKeep?.apply(extent: e, arguments: [img, weighted.cropped(to: e)])?.cropped(to: e) ?? img
    }

    /// The random generator's raw red as a grey, alpha 1 (no un-premultiplying of its random alpha).
    static let rawGrey = CIColorKernel(source: "kernel vec4 xaRawGrey(__sample s) { return vec4(s.r, s.r, s.r, 1.0); }")
    static let addKeep = CIColorKernel(source: "kernel vec4 xaAddKeep(__sample b, __sample l) { return vec4(b.rgb + l.rgb * b.a, b.a); }")
}
