import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Looks for video, recorded into the file. Several only work in motion: Trails and Datamosh
/// remember the frames before, Super 8, Pocket and Stop Motion hold frames the way the real
/// things ran slow.
enum VideoLook: Int, CaseIterable, Codable, Identifiable {
    case clean, super8, vhs, pocket, trails, stopMotion, datamosh

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .clean: return "CLEAN"
        case .super8: return "SUPER 8"
        case .vhs: return "VHS"
        case .pocket: return "POCKET"
        case .trails: return "TRAILS"
        case .stopMotion: return "STOP MOTION"
        case .datamosh: return "DATAMOSH"
        }
    }

    /// Frames per second the look shows; the file still runs at the camera's rate and repeats frames.
    var heldFPS: Double? {
        switch self {
        case .super8: return 18
        case .pocket: return 12
        case .stopMotion: return 6
        default: return nil
        }
    }
}

/// Per-recording state: the last frames, the hold clock, the wobble.
final class VideoFX {
    private var held: CIImage?
    private var heldAt: Double = -1
    private var previousOut: CIImage?
    private var previousIn: CIImage?
    private var keyframeAt: Double = 0
    private var leakUntil: Double = 0
    private var noiseBandY: CGFloat = -1

    func reset() { held = nil; heldAt = -1; previousOut = nil; previousIn = nil; keyframeAt = 0 }

    /// `time` is seconds, monotonic. Returns the frame to show and record.
    func apply(_ look: VideoLook, to src: CIImage, time: Double, date: Date) -> CIImage {
        let e = src.extent
        if let fps = look.heldFPS {
            if let held, time - heldAt < 1 / fps, held.extent == e { return held }
        }
        var out: CIImage
        switch look {
        case .clean: out = src
        case .super8: out = super8(src, time: time)
        case .vhs: out = vhs(src, time: time, date: date)
        case .pocket: out = Looks.apply(.gameboy, to: src)
        case .trails: out = trails(src)
        case .stopMotion: out = jitter(src, amount: 0.004)
        case .datamosh: out = datamosh(src, time: time)
        }
        out = out.cropped(to: e)
        if look.heldFPS != nil { held = out; heldAt = time }
        return out
    }

    private func jitter(_ img: CIImage, amount: CGFloat) -> CIImage {
        let e = img.extent
        let dx = CGFloat.random(in: -1...1) * e.width * amount
        let dy = CGFloat.random(in: -1...1) * e.height * amount
        return img.clampedToExtent().transformed(by: CGAffineTransform(translationX: dx, y: dy)).cropped(to: e)
    }

    /// Warm, weaving in the gate, flickering, grainy, with the odd light leak.
    private func super8(_ src: CIImage, time: Double) -> CIImage {
        let e = src.extent
        var img = jitter(src, amount: 0.004)
        let warm = CIFilter.temperatureAndTint(); warm.inputImage = img
        warm.neutral = CIVector(x: 6500, y: 0); warm.targetNeutral = CIVector(x: 5200, y: 14)
        let cc = CIFilter.colorControls(); cc.inputImage = warm.outputImage
        cc.saturation = 0.9; cc.contrast = 1.12
        cc.brightness = Float.random(in: -0.025...0.025)
        img = (cc.outputImage ?? img).cropped(to: e)
        img = FilmGrain.apply(img, amount: 0.7, size: 0.7)
        let v = CIFilter.vignetteEffect(); v.inputImage = img
        v.center = CGPoint(x: e.midX, y: e.midY); v.radius = Float(hypot(e.width, e.height) * 0.46); v.intensity = 0.9; v.falloff = 0.5
        img = (v.outputImage ?? img).cropped(to: e)
        if time > leakUntil + 2.5 && Double.random(in: 0...1) < 0.01 { leakUntil = time + 0.8 }
        if time < leakUntil {
            let leak = CIFilter.radialGradient()
            leak.center = CGPoint(x: e.maxX, y: e.maxY * 0.7)
            leak.radius0 = 0; leak.radius1 = Float(e.width * 0.8)
            leak.color0 = CIColor(red: 1, green: 0.45, blue: 0.1, alpha: 0.55)
            leak.color1 = CIColor(red: 1, green: 0.2, blue: 0, alpha: 0)
            if let l = leak.outputImage?.cropped(to: e) {
                let add = CIFilter.screenBlendMode(); add.inputImage = l; add.backgroundImage = img
                img = (add.outputImage ?? img).cropped(to: e)
            }
        }
        return img
    }

    /// Soft, low-resolution, colour bleeding sideways, scanlines, the odd tracking band.
    private func vhs(_ src: CIImage, time: Double, date: Date) -> CIImage {
        let e = src.extent
        let k: CGFloat = 360 / max(e.width, 1)
        var img = src.transformed(by: CGAffineTransform(scaleX: k, y: k * 0.9))
            .transformed(by: CGAffineTransform(scaleX: 1 / k, y: 1 / (k * 0.9)))
            .cropped(to: e)
        let cc = CIFilter.colorControls(); cc.inputImage = img; cc.saturation = 1.3; cc.contrast = 1.05
        img = (cc.outputImage ?? img).cropped(to: e)
        // Chroma bleed: red a little right, blue a little left.
        let shift: CGFloat = max(2, e.width / 240)
        let red = channel(img, r: 1, g: 0, b: 0).transformed(by: CGAffineTransform(translationX: shift, y: 0))
        let blue = channel(img, r: 0, g: 0, b: 1).transformed(by: CGAffineTransform(translationX: -shift, y: 0))
        let green = channel(img, r: 0, g: 1, b: 0)
        let rg = CIFilter.additionCompositing(); rg.inputImage = red; rg.backgroundImage = green
        let rgb = CIFilter.additionCompositing(); rgb.inputImage = blue; rgb.backgroundImage = rg.outputImage
        img = (rgb.outputImage ?? img).cropped(to: e)
        // Scanlines.
        let stripes = CIFilter.stripesGenerator()
        stripes.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.22)
        stripes.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        stripes.width = Float(max(1, e.height / 480))
        stripes.sharpness = 1
        if let lines = stripes.outputImage?.transformed(by: CGAffineTransform(rotationAngle: .pi / 2)).cropped(to: e) {
            img = lines.composited(over: img).cropped(to: e)
        }
        // A tracking band now and then, rolling down the picture.
        if noiseBandY < 0 && Double.random(in: 0...1) < 0.006 { noiseBandY = e.maxY }
        if noiseBandY >= 0 {
            let band = CGRect(x: e.minX, y: noiseBandY - e.height * 0.04, width: e.width, height: e.height * 0.04)
            if let n = CIFilter.randomGenerator().outputImage {
                let g = CIFilter.colorControls(); g.inputImage = n.transformed(by: CGAffineTransform(scaleX: 6, y: 1)); g.saturation = 0
                if let noise = g.outputImage?.cropped(to: band) {
                    let sc = CIFilter.screenBlendMode(); sc.inputImage = noise; sc.backgroundImage = img
                    img = (sc.outputImage ?? img).cropped(to: e)
                }
            }
            noiseBandY -= e.height * 0.03
            if noiseBandY < e.minY { noiseBandY = -1 }
        }
        if let osd = VHSOverlay.image(size: e.size, date: date) {
            img = osd.transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY)).composited(over: img)
        }
        return img
    }

    private func channel(_ img: CIImage, r: CGFloat, g: CGFloat, b: CGFloat) -> CIImage {
        let m = CIFilter.colorMatrix(); m.inputImage = img
        m.rVector = CIVector(x: r, y: 0, z: 0, w: 0)
        m.gVector = CIVector(x: 0, y: g, z: 0, w: 0)
        m.bVector = CIVector(x: 0, y: 0, z: b, w: 0)
        m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return (m.outputImage ?? img).clampedToExtent()
    }

    /// Each frame laid over the last ones, so anything moving leaves a tail.
    private func trails(_ src: CIImage) -> CIImage {
        guard let prev = previousOut, prev.extent == src.extent else { previousOut = src; return src }
        let d = CIFilter.dissolveTransition(); d.inputImage = prev; d.targetImage = src; d.time = 0.28
        let out = (d.outputImage ?? src).cropped(to: src.extent)
        previousOut = out
        return out
    }

    /// Where the picture moves, the old pixels stay and smear, the way a broken P-frame looks.
    /// A clean keyframe every few seconds.
    private func datamosh(_ src: CIImage, time: Double) -> CIImage {
        let e = src.extent
        defer { previousIn = src }
        guard let prev = previousOut, let lastIn = previousIn, prev.extent == e else { previousOut = src; keyframeAt = time; return src }
        if time - keyframeAt > 3.2 { previousOut = src; keyframeAt = time; return src }
        let diff = CIFilter.differenceBlendMode(); diff.inputImage = src; diff.backgroundImage = lastIn
        let px = CIFilter.pixellate(); px.inputImage = diff.outputImage?.cropped(to: e); px.scale = Float(max(8, e.width / 60)); px.center = .zero
        let th = CIFilter.colorThreshold(); th.inputImage = px.outputImage?.cropped(to: e); th.threshold = 0.06
        guard let mask = th.outputImage?.cropped(to: e) else { previousOut = src; return src }
        let dx = e.width / 160, dy = -e.height / 220
        let smeared = prev.clampedToExtent().transformed(by: CGAffineTransform(translationX: dx, y: dy)).cropped(to: e)
        let b = CIFilter.blendWithMask(); b.inputImage = smeared; b.backgroundImage = src; b.maskImage = mask
        let out = (b.outputImage ?? src).cropped(to: e)
        previousOut = out
        return out
    }
}

/// The camcorder's on-screen display: PLAY at the top, the date at the bottom, in the
/// keylined condensed face Roll's camcorder date back uses.
enum VHSOverlay {
    private static let lock = NSLock()
    private static var key = ""
    private static var cached: CIImage?

    static func image(size: CGSize, date: Date) -> CIImage? {
        let f = DateFormatter(); f.dateFormat = "MMM.dd yyyy  h:mm a"
        let text = f.string(from: date).uppercased()
        let k = "\(Int(size.width))x\(Int(size.height))|\(text)"
        lock.lock(); if k == key, let c = cached { lock.unlock(); return c }; lock.unlock()
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let font = XA.uiFont("RobotoCondensed-Bold", size.height / 20)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let stroke: [NSAttributedString.Key: Any] = [.font: font, .strokeColor: UIColor.black, .strokeWidth: 22]
        let pad = size.height / 22
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            for (s, p) in [("PLAY ▶", CGPoint(x: pad, y: pad)), (text, CGPoint(x: pad, y: size.height - pad - font.lineHeight))] {
                (s as NSString).draw(at: p, withAttributes: stroke)
                (s as NSString).draw(at: p, withAttributes: attrs)
            }
        }
        guard let cg = img.cgImage else { return nil }
        let c = CIImage(cgImage: cg)
        lock.lock(); key = k; cached = c; lock.unlock()
        return c
    }
}
