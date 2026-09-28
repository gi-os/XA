import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Two cameras in one body.
/// DIGI is a 2003 point-and-shoot: a small file, cheap processing, sims, looks, shapes, a date back.
/// PRO is the iPhone at its best: full resolution, full processing, saved untouched.
enum CaptureMode: String, CaseIterable, Identifiable, Codable {
    case digi, pro, video

    var id: String { rawValue }
    var title: String {
        switch self {
        case .digi: return "DIGI"
        case .pro: return "PRO"
        case .video: return "VIDEO"
        }
    }

    /// Whether the viewfinder runs through the darkroom (everything but PRO).
    var developed: Bool { self != .pro }

    /// Largest photo asked of the sensor. DIGI reads out 12MP fast and shrinks it after.
    var maxSensorPixels: Int { self == .pro ? Int.max : 12_600_000 }

    var prioritization: AVCapturePhotoOutput.QualityPrioritization { self == .pro ? .quality : .speed }

    static func megapixels(_ s: CGSize) -> Int {
        let px: CGFloat = s.width * s.height
        return max(1, Int((px / 1_000_000).rounded()))
    }
}

/// The cheap look of an early CCD compact: small file, hard tone curve that clips the
/// highlights, a little too much color, a sharpening halo, blotchy color noise and a
/// JPEG squeezed too hard.
enum Digicam {
    /// Long edge for each resolution setting: 1MP 1152, 2MP 1600, 3MP 2048, 5MP 2592,
    /// 8MP 3264, 12MP the sensor's own 4032.
    static func longEdge(megapixels: Int) -> CGFloat {
        switch megapixels {
        case ...1: return 1152
        case 2: return 1600
        case 3: return 2048
        case 4...5: return 2592
        case 6...8: return 3264
        default: return 4032
        }
    }

    static func size(for s: CGSize, megapixels: Int = 2) -> CGSize {
        let edge = longEdge(megapixels: megapixels)
        let long = max(s.width, s.height)
        guard long > edge else { return s }
        let k: CGFloat = edge / long
        let w: CGFloat = (s.width * k).rounded()
        let h: CGFloat = (s.height * k).rounded()
        return CGSize(width: w, height: h)
    }

    /// Tone and color only: cheap enough for the live viewfinder. Skipped when a sim is loaded,
    /// because the sim is the color science then.
    static func tone(_ i: CIImage) -> CIImage {
        let c = CIFilter.colorControls()
        c.inputImage = i
        c.saturation = 1.18
        c.contrast = 1.06
        let t = CIFilter.toneCurve()
        t.inputImage = c.outputImage ?? i
        t.point0 = CGPoint(x: 0, y: 0.03)
        t.point1 = CGPoint(x: 0.25, y: 0.21)
        t.point2 = CGPoint(x: 0.5, y: 0.53)
        t.point3 = CGPoint(x: 0.75, y: 0.86)
        t.point4 = CGPoint(x: 0.9, y: 1)
        return (t.outputImage ?? i).cropped(to: i.extent)
    }

    /// Shrink with a plain bilinear scale, not Lanczos: the camera had no time for a good one.
    static func shrink(_ src: CIImage, megapixels: Int) -> CIImage {
        let input = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
        let target = size(for: input.extent.size, megapixels: megapixels)
        let k: CGFloat = target.width / input.extent.width
        let extent = CGRect(origin: .zero, size: target)
        return input.transformed(by: CGAffineTransform(scaleX: k, y: k)).cropped(to: extent)
    }

    /// The sensor and the cheap ISP: sharpening halo and blotchy color noise.
    static func crunch(_ img: CIImage, noise amount: CGFloat) -> CIImage {
        let extent = img.extent
        let sharp = CIFilter.unsharpMask()
        sharp.inputImage = img
        sharp.radius = 2.2
        sharp.intensity = 0.7
        var out = (sharp.outputImage ?? img).cropped(to: extent)
        if amount > 0 { out = colorNoise(out, amount: amount) }
        return out
    }

    /// A CCD's colour noise is blotchy chroma, a few pixels across, not single hot pixels.
    static func colorNoise(_ i: CIImage, amount: CGFloat) -> CIImage {
        guard let rnd0 = CIFilter.randomGenerator().outputImage else { return i }
        let cell: CGFloat = max(2, min(i.extent.width, i.extent.height) / 420)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = rnd0.transformed(by: CGAffineTransform(scaleX: cell, y: cell))
        blur.radius = Float(cell * 0.8)
        guard let rnd = blur.outputImage else { return i }
        let two: CGFloat = amount * 2 * 2.4
        let m = CIFilter.colorMatrix()
        m.inputImage = rnd
        m.rVector = CIVector(x: two, y: 0, z: 0, w: 0)
        m.gVector = CIVector(x: 0, y: two, z: 0, w: 0)
        m.bVector = CIVector(x: 0, y: 0, z: two, w: 0)
        m.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        m.biasVector = CIVector(x: -two / 2, y: -two / 2, z: -two / 2, w: 0)
        guard let n = m.outputImage?.cropped(to: i.extent) else { return i }
        let add = CIFilter.additionCompositing()
        add.inputImage = n
        add.backgroundImage = i
        return (add.outputImage ?? i).cropped(to: i.extent)
    }
}

/// A lens button: a zoom factor on the (virtual) device and how the Camera app would label it.
struct Lens: Equatable, Identifiable {
    let factor: CGFloat
    let label: String
    var id: CGFloat { factor }
}

enum Lenses {
    /// One stop per physical lens, plus a 2× crop off the main camera.
    /// `switchOvers` are the device's virtualDeviceSwitchOverVideoZoomFactors and
    /// `multiplier` its displayVideoZoomFactorMultiplier (0.5 when there's an ultra wide).
    static func stops(switchOvers: [CGFloat], maxZoom: CGFloat, multiplier: CGFloat) -> [Lens] {
        var factors: [CGFloat] = [1]
        factors.append(contentsOf: switchOvers)
        let main: CGFloat = self.main(switchOvers: switchOvers, multiplier: multiplier)
        let crop: CGFloat = main * 2
        let taken = factors.contains { abs($0 - crop) / crop < 0.1 }
        if !taken && crop <= maxZoom { factors.append(crop) }
        let kept = factors.filter { $0 <= maxZoom }.sorted()
        return kept.map { f in
            let shown: CGFloat = f * multiplier
            return Lens(factor: f, label: label(shown))
        }
    }

    /// Main camera's zoom factor: where XA starts.
    static func main(switchOvers: [CGFloat], multiplier: CGFloat) -> CGFloat {
        multiplier < 1 ? (switchOvers.first ?? 1) : 1
    }

    static func label(_ shown: CGFloat) -> String {
        let r: CGFloat = (shown * 10).rounded() / 10
        if r == r.rounded() { return "\(Int(r))" }
        let s = String(format: "%.1f", Double(r))
        return s.hasPrefix("0") ? String(s.dropFirst()) : s
    }
}
