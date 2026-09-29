import CoreImage
import CoreImage.CIFilterBuiltins

/// Film grain that behaves like film: monochrome, clumped rather than per-pixel, sized to the
/// frame rather than to the pixels, and weighted to the midtones. Deep shadows and clean
/// highlights stay quieter, the way a negative does.
enum FilmGrain {
    /// `moving`: a fresh patch of noise each call, so video grain dances instead of sitting
    /// on the lens like dirt. Stills leave it off and stay repeatable.
    static func apply(_ img: CIImage, amount: Double, size: Double, moving: Bool = false) -> CIImage {
        guard amount > 0, let rnd = CIFilter.randomGenerator().outputImage else { return img }
        let e = img.extent
        // A grain is a fraction of the frame, never a single pixel: at 2MP a fine grain is about
        // two pixels across and a coarse one five. Per-pixel noise reads as a bad sensor.
        let unit: CGFloat = max(1, min(e.width, e.height) / 640)
        let cell: CGFloat = unit * (1.1 + CGFloat(size) * 2.2)
        // One channel of noise, grey.
        let mono = CIFilter.colorMatrix()
        mono.inputImage = rnd
        mono.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        mono.gVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        mono.bVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        mono.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        mono.biasVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let grey = mono.outputImage else { return img }
        let jump = moving ? CGAffineTransform(translationX: CGFloat.random(in: -4000...4000), y: CGFloat.random(in: -4000...4000)) : .identity
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
        let clear = CIFilter.colorMatrix()
        clear.inputImage = weighted
        clear.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        guard let grain = clear.outputImage?.cropped(to: e) else { return img }
        let add = CIFilter.additionCompositing()
        add.inputImage = grain
        add.backgroundImage = img
        return (add.outputImage ?? img).cropped(to: e)
    }
}
