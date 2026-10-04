import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// FILM's finder, after the Olympus XA's: a bright frame with the speed scale down one side and
/// the rangefinder patch in the middle. It is part of the body, so with the phone upright it
/// lies turned a quarter, as the XA's does when you hold the camera on its side.
///
/// Geometry is worked out in the finder's own landscape space (4 wide, 3 high, the scale on the
/// left), then turned a quarter clockwise into the portrait viewfinder (3 wide, 4 high).
enum XAFinder {
    /// The finder's landscape space.
    static let LW: CGFloat = 4, LH: CGFloat = 3
    static let scaleColumn: CGFloat = 0.48, rightMargin: CGFloat = 0.2, topMargin: CGFloat = 0.27

    /// The bright frame in landscape finder space, for a format.
    static func landscapeFrame(_ f: FilmFormat) -> CGRect {
        let aw = LW - scaleColumn - rightMargin, ah = LH - 2 * topMargin
        let a = 1 / f.aspect                       // long over short
        var fw = min(aw, ah * a)
        var fh = fw / a
        if fh > ah { fh = ah; fw = fh * a }
        return CGRect(x: scaleColumn + (aw - fw) / 2, y: topMargin + (ah - fh) / 2, width: fw, height: fh)
    }

    /// Landscape finder space → the portrait viewfinder, normalised 0…1 with the origin top left.
    static func toPortrait(_ r: CGRect) -> CGRect {
        CGRect(x: (LH - r.maxY) / LH, y: r.minY / LW, width: r.height / LH, height: r.width / LW)
    }

    /// Where the photo lands in the viewfinder, normalised, origin top left.
    static func frame(_ f: FilmFormat) -> CGRect { toPortrait(landscapeFrame(f)) }

    /// The viewfinder picture: the main camera, cropped to the format, sitting exactly in the
    /// bright frame; around it the same scene carried on, softly blurred (until the ultra-wide
    /// feeds it), and feathered so the hand-over is hard to see. `img` is the frame as the screen
    /// shows it (portrait); the result has the same extent.
    /// The rangefinder patch in landscape finder space: centred in the frame.
    static func landscapePatch(_ f: FilmFormat) -> CGRect {
        let fr = landscapeFrame(f)
        let w: CGFloat = 0.39, h: CGFloat = 0.315
        return CGRect(x: fr.midX - w / 2, y: fr.midY - h / 2, width: w, height: h)
    }
    static func patch(_ f: FilmFormat) -> CGRect { toPortrait(landscapePatch(f)) }

    /// `shift` (0…1) is how far the rangefinder's second image sits off the first: it jumps when
    /// the camera moves or focus is hunting, and settles back to 0 as focus lands.
    static func compose(_ img: CIImage, format: FilmFormat, shift: CGFloat = 0) -> CIImage {
        let e = img.extent
        guard e.width > 8, e.height > 8 else { return img }
        let crop = format.frame(in: e)
        let n = frame(format)
        // Core Image's origin is bottom left.
        let t = CGRect(x: e.minX + n.minX * e.width, y: e.minY + (1 - n.maxY) * e.height,
                       width: n.width * e.width, height: n.height * e.height)
        let k = t.width / max(crop.width, 1)
        let mapped = img
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            .transformed(by: CGAffineTransform(scaleX: k, y: k))
            .transformed(by: CGAffineTransform(translationX: t.minX, y: t.minY))
        let short = min(e.width, e.height)
        let around = mapped.clampedToExtent()
            .applyingGaussianBlur(sigma: Double(short * 0.006))
            .applyingFilter("CIExposureAdjust", parameters: ["inputEV": -0.15])
            .cropped(to: e)
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

        // The rangefinder patch: a brighter, warmer window in the middle with the second image
        // laid over the first, offset along the finder's long side (the screen's up and down
        // while the finder lies turned) until focus brings the two together.
        let pn = patch(format)
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
