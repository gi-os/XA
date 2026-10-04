import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// FILM's finder, after the Olympus XA's: a bright frame with the speed scale down one side and
/// the rangefinder patch in the middle. It is part of the body, so with the phone upright it
/// lies turned a quarter, as the XA's does when you hold the camera on its side.
///
/// Geometry is worked out in the finder's own landscape space (`long` wide, 3 high, the scale on
/// the left), then turned a quarter clockwise into the portrait viewfinder (3 wide, `long` high).
/// `long` follows the viewfinder's shape: 4 for 3:4, more when the finder runs up to the top of
/// the screen. The frame is centred, so the rangefinder patch sits in the middle of the finder.
enum XAFinder {
    static let LH: CGFloat = 3
    /// Room for the speed scale on one side, just enough for the bars elsewhere: the frame is as big as the screen allows.
    static let scaleMargin: CGFloat = 0.40, farMargin: CGFloat = 0.16, topMargin: CGFloat = 0.14

    /// The landscape length for a viewfinder of this shape (height over width).
    static func long(_ hOverW: CGFloat) -> CGFloat { max(3.2, LH * hOverW) }

    /// The bright frame in landscape finder space, for a format.
    static func landscapeFrame(_ f: FilmFormat, long LW: CGFloat = 4) -> CGRect {
        let aw = LW - scaleMargin - farMargin, ah = LH - 2 * topMargin
        let a = 1 / f.aspect                       // long over short
        var fw = min(aw, ah * a)
        var fh = fw / a
        if fh > ah { fh = ah; fw = fh * a }
        return CGRect(x: scaleMargin + (aw - fw) / 2, y: (LH - fh) / 2, width: fw, height: fh)
    }

    /// Landscape finder space → the portrait viewfinder, normalised 0…1 with the origin top left.
    static func toPortrait(_ r: CGRect, long LW: CGFloat = 4) -> CGRect {
        CGRect(x: (LH - r.maxY) / LH, y: r.minY / LW, width: r.height / LH, height: r.width / LW)
    }

    /// Where the photo lands in the viewfinder, normalised, origin top left.
    static func frame(_ f: FilmFormat, long: CGFloat = 4) -> CGRect { toPortrait(landscapeFrame(f, long: long), long: long) }

    /// The viewfinder picture: the main camera, cropped to the format, sitting exactly in the
    /// bright frame; around it the same scene carried on, softly blurred (until the ultra-wide
    /// feeds it), and feathered so the hand-over is hard to see. `img` is the frame as the screen
    /// shows it (portrait); the result has the same extent.
    /// The rangefinder patch in landscape finder space: centred in the frame.
    static func landscapePatch(_ f: FilmFormat, long: CGFloat = 4) -> CGRect {
        let fr = landscapeFrame(f, long: long)
        let w: CGFloat = 0.39, h: CGFloat = 0.315
        return CGRect(x: fr.midX - w / 2, y: fr.midY - h / 2, width: w, height: h)
    }
    static func patch(_ f: FilmFormat, long: CGFloat = 4) -> CGRect { toPortrait(landscapePatch(f, long: long), long: long) }

    /// `shift` (0…1) is how far the rangefinder's second image sits off the first: it jumps when
    /// the camera moves or focus is hunting, and settles back to 0 as focus lands.
    /// `wide` is the ultra-wide frame (portrait, any size), `ratio` how much wider it sees than the
    /// main camera, `gain` its colour matched to the main camera. Without it the surround is the
    /// main picture carried on.
    /// The result has the viewfinder's own shape: as wide as `img`, `long`/3 times as tall.
    static func compose(_ img: CIImage, format: FilmFormat, shift: CGFloat = 0, long: CGFloat = 4,
                        wide: CIImage? = nil, ratio: CGFloat = 2, gain: CIVector = CIVector(x: 1, y: 1, z: 1),
                        intro: CGFloat = 1) -> CIImage {
        let src = img.extent
        guard src.width > 8, src.height > 8 else { return img }
        let crop = format.frame(in: src)
        // the canvas: the viewfinder's shape, centred on the picture
        let ch = src.width * long / LH
        let e = CGRect(x: src.minX, y: src.midY - ch / 2, width: src.width, height: ch)
        let n = frame(format, long: long)
        // Core Image's origin is bottom left.
        let final = CGRect(x: e.minX + n.minX * e.width, y: e.minY + (1 - n.maxY) * e.height,
                           width: n.width * e.width, height: n.height * e.height)
        // Arriving (intro < 1): the picture starts where the plain viewfinder had it, full size,
        // and steps back into the frame as the finder zooms out to fit.
        let p = max(0, min(1, intro))
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * p }
        let t = p >= 1 ? final : CGRect(x: lerp(crop.minX, final.minX), y: lerp(crop.minY, final.minY),
                                        width: lerp(crop.width, final.width), height: lerp(crop.height, final.height))
        let k = t.width / max(crop.width, 1)
        let mapped = img
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            .transformed(by: CGAffineTransform(scaleX: k, y: k))
            .transformed(by: CGAffineTransform(translationX: t.minX, y: t.minY))
        let short = min(e.width, e.height)
        let around: CIImage
        if let wide, wide.extent.width > 8 {
            // The ultra-wide, lined up: its middle (1/ratio of it) is what the main camera sees.
            let w = wide.extent
            let su = src.width / (w.width / ratio)
            let onScreen = wide
                .transformed(by: CGAffineTransform(translationX: -w.midX, y: -w.midY))
                .transformed(by: CGAffineTransform(scaleX: su, y: su))
                .transformed(by: CGAffineTransform(translationX: src.midX, y: src.midY))
            around = onScreen
                .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
                .transformed(by: CGAffineTransform(scaleX: k, y: k))
                .transformed(by: CGAffineTransform(translationX: t.minX, y: t.minY))
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: gain.x, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: gain.y, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: gain.z, w: 0)])
                .clampedToExtent()
                .applyingGaussianBlur(sigma: Double(short * 0.004))
                .applyingFilter("CIExposureAdjust", parameters: ["inputEV": -0.1])
                .cropped(to: e)
        } else {
            around = mapped.clampedToExtent()
                .applyingGaussianBlur(sigma: Double(short * 0.006))
                .applyingFilter("CIExposureAdjust", parameters: ["inputEV": -0.15])
                .cropped(to: e)
        }
        let feather = short * 0.025
        let mask = CIImage(color: .white).cropped(to: t.insetBy(dx: feather * 0.6, dy: feather * 0.6))
            .composited(over: CIImage(color: .black).cropped(to: e.insetBy(dx: -feather * 3, dy: -feather * 3)))
            .applyingGaussianBlur(sigma: Double(feather * 0.5))
            .cropped(to: e)
        let b = CIFilter.blendWithMask()
        b.inputImage = mapped.cropped(to: e)
        b.backgroundImage = around
        b.maskImage = mask
        var out = (b.outputImage ?? around).cropped(to: e)
        if p < 1 {
            // the surround fades in as the frame settles; the patch comes once it has
            let plain = mapped.cropped(to: e).composited(over: CIImage(color: .black).cropped(to: e))
            let mix = CIFilter.dissolveTransition()
            mix.inputImage = plain
            mix.targetImage = out
            mix.time = Float(min(1, p * 1.4))
            out = (mix.outputImage ?? out).cropped(to: e)
            if p < 0.6 { return out }
        }
        // Toward the speed scale (the top while the finder lies turned) the scene sinks a little
        // further into the dark, so the end of the surround never shows against a bright wall.
        let g = CIFilter.linearGradient()
        g.point0 = CGPoint(x: e.midX, y: e.maxY)
        g.point1 = CGPoint(x: e.midX, y: t.maxY + feather)
        g.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.55)
        g.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        if let shade = g.outputImage?.cropped(to: e) { out = shade.composited(over: out).cropped(to: e) }

        // The rangefinder patch: a brighter, warmer window in the middle with the second image
        // laid over the first, offset along the finder's long side (the screen's up and down
        // while the finder lies turned) until focus brings the two together.
        let pn = patch(format, long: long)
        let pr = CGRect(x: e.minX + pn.minX * e.width, y: e.minY + (1 - pn.maxY) * e.height,
                        width: pn.width * e.width, height: pn.height * e.height)
        let offset = shift * short * 0.05
        let ghost = mapped.transformed(by: CGAffineTransform(translationX: 0, y: offset))
        let inside = out.cropped(to: pr)
        let twin = ghost.cropped(to: pr)
        let mix = CIFilter.dissolveTransition()
        mix.inputImage = inside
        mix.targetImage = twin
        mix.time = 0.5
        let warm = (mix.outputImage ?? inside)
            .applyingFilter("CIExposureAdjust", parameters: ["inputEV": 0.45])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.02, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1.0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.9, w: 0)])
            .cropped(to: pr)
        let soft = short * 0.008
        let pmask = CIImage(color: .white).cropped(to: pr.insetBy(dx: soft, dy: soft))
            .composited(over: CIImage(color: .black).cropped(to: pr.insetBy(dx: -soft * 4, dy: -soft * 4)))
            .applyingGaussianBlur(sigma: Double(soft))
            .cropped(to: pr)
        let pb = CIFilter.blendWithMask()
        pb.inputImage = warm
        pb.backgroundImage = out.cropped(to: pr)
        pb.maskImage = pmask
        if let p = pb.outputImage { out = p.cropped(to: pr).composited(over: out).cropped(to: e) }
        return out
    }

    /// Per-channel gain that makes the ultra-wide's middle match the main camera's picture.
    static func matchGain(main: CIImage, wide: CIImage, ratio: CGFloat) -> CIVector? {
        let w = wide.extent
        let mid = CGRect(x: w.midX - w.width / ratio / 2, y: w.midY - w.height / ratio / 2, width: w.width / ratio, height: w.height / ratio)
        guard let a = average(main, main.extent), let b = average(wide, mid) else { return nil }
        func g(_ x: Float, _ y: Float) -> CGFloat { CGFloat(min(2, max(0.5, (x + 0.002) / (y + 0.002)))) }
        return CIVector(x: g(a[0], b[0]), y: g(a[1], b[1]), z: g(a[2], b[2]))
    }

    private static let meter = CIContext(options: [.workingColorSpace: NSNull()])
    private static func average(_ img: CIImage, _ r: CGRect) -> [Float]? {
        let f = CIFilter.areaAverage()
        f.inputImage = img
        f.extent = r
        guard let out = f.outputImage else { return nil }
        var px = [Float](repeating: 0, count: 4)
        meter.render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        return px.allSatisfy { $0.isFinite } ? px : nil
    }

    // MARK: the needle

    /// The XA's speed scale, top to bottom, and where each mark sits along the column (0 = top
    /// of the hatched over-exposure block, 1 = the foot of the under-exposure block).
    static let marks: [(label: String, seconds: Double, at: CGFloat)] = [
        ("500", 1.0 / 500, 0.20), ("250", 1.0 / 250, 0.25), ("125", 1.0 / 125, 0.30), ("60", 1.0 / 60, 0.37),
        ("30", 1.0 / 30, 0.45), ("15", 1.0 / 15, 0.53), ("8", 1.0 / 8, 0.61), ("4", 1.0 / 4, 0.67),
        ("2", 1.0 / 2, 0.72), ("1", 1, 0.77),
    ]

    /// Where the needle points for a shutter speed: between the marks in stops; into the hatch
    /// when it is faster than 1/500 (too much light), onto the block when slower than a second.
    static func needle(_ seconds: Double) -> CGFloat {
        guard seconds > 0, seconds.isFinite else { return 0.45 }
        let ev = log2(seconds)
        let first = marks[0], last = marks[marks.count - 1]
        if ev <= log2(first.seconds) {
            let over = log2(first.seconds) - ev
            return max(0.06, first.at - CGFloat(over) * 0.04)
        }
        if ev >= log2(last.seconds) {
            let under = ev - log2(last.seconds)
            return min(0.86, last.at + CGFloat(under) * 0.04)
        }
        for i in 0..<(marks.count - 1) {
            let a = marks[i], b = marks[i + 1]
            let ea = log2(a.seconds), eb = log2(b.seconds)
            if ev >= ea && ev <= eb {
                return a.at + (b.at - a.at) * CGFloat((ev - ea) / (eb - ea))
            }
        }
        return 0.45
    }
}
