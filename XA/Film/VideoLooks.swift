import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Looks for video, recorded into the file. Several only work in motion: Trails and Datamosh
/// remember the frames before, Super 8, Pocket and Stop Motion hold frames the way the real
/// things ran slow.
enum VideoLook: Int, CaseIterable, Codable, Identifiable {
    case clean, pocket, pocketColor, super8, vhs, trails, motion, stopMotion, cctv, slitScan, datamosh

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .clean: return "CLEAN"
        case .pocket: return "POCKET"
        case .pocketColor: return "POCKET COLOR"
        case .super8: return "SUPER 8"
        case .vhs: return "VHS"
        case .trails: return "TRAILS"
        case .motion: return "MOTION"
        case .stopMotion: return "STOP MOTION"
        case .cctv: return "CCTV"
        case .slitScan: return "SLIT-SCAN"
        case .datamosh: return "DATAMOSH"
        }
    }

    /// The tape's colour, for the take timeline.
    var color: String {
        switch self {
        case .clean: return "#4A4A4C"
        case .pocket: return "#8BAC0F"
        case .pocketColor: return "#5B3F9E"
        case .super8: return "#F2B51E"
        case .vhs: return "#F4F1EA"
        case .trails: return "#E24DA0"
        case .motion: return "#6FB6C9"
        case .stopMotion: return "#FFFFFF"
        case .cctv: return "#C8F56A"
        case .slitScan: return "#1B4FA0"
        case .datamosh: return "#00A6D6"
        }
    }

    /// Frames per second the look shows; the file still runs at the camera's rate and repeats frames.
    var heldFPS: Double? {
        switch self {
        case .super8: return 18
        case .pocket, .pocketColor: return 12
        case .stopMotion: return 8
        case .cctv: return 15
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
    /// Recent camera frames, newest last, for Motion and Slit-scan.
    private var history: [CIImage] = []

    func reset() { held = nil; heldAt = -1; previousOut = nil; previousIn = nil; keyframeAt = 0; history = [] }

    /// `time` is seconds, monotonic. Returns the frame to show and record.
    func apply(_ look: VideoLook, to src: CIImage, time: Double, date: Date) -> CIImage {
        let e = src.extent
        if let fps = look.heldFPS {
            if let held, time - heldAt < 1 / fps, held.extent == e { return held }
        }
        if look == .motion || look == .slitScan {
            if let last = history.last, last.extent != e { history = [] }
            // Kept small: a frame costs nothing until it is rendered.
            history.append(src)
            if history.count > 30 { history.removeFirst(history.count - 30) }
        }
        var out: CIImage
        switch look {
        case .clean: out = src
        case .pocket: out = Looks.apply(.gameboy, to: src)
        case .pocketColor: out = Looks.apply(.gbcolor, to: src)
        case .super8: out = super8(src, time: time)
        case .vhs: out = vhs(src, time: time, date: date)
        case .trails: out = trails(src)
        case .motion: out = motion(src)
        case .stopMotion: out = jitter(src, amount: 0.004)
        case .cctv: out = cctv(src, date: date)
        case .slitScan: out = slitScan(src)
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
        img = FilmGrain.apply(img, amount: 0.7, size: 0.7, moving: true)
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
        // Chromatic aberration: the three channels don't land in the same place. Red is
        // magnified a touch and pushed right, blue shrunk and pushed left, so fringes widen
        // toward the edges the way a cheap camcorder lens and a worn head smear them.
        let shift: CGFloat = max(3, e.width / 160)
        let spread: CGFloat = 0.012
        let c = CGPoint(x: e.midX, y: e.midY)
        func about(_ scale: CGFloat, dx: CGFloat) -> CGAffineTransform {
            CGAffineTransform(translationX: -c.x, y: -c.y)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: c.x + dx, y: c.y))
        }
        let red = channel(img.clampedToExtent(), r: 1, g: 0, b: 0).transformed(by: about(1 + spread, dx: shift)).cropped(to: e)
        let blue = channel(img.clampedToExtent(), r: 0, g: 0, b: 1).transformed(by: about(1 - spread, dx: -shift)).cropped(to: e)
        let green = channel(img, r: 0, g: 1, b: 0)
        let rg = CIFilter.additionCompositing(); rg.inputImage = red; rg.backgroundImage = green
        let rgb = CIFilter.additionCompositing(); rgb.inputImage = blue; rgb.backgroundImage = rg.outputImage
        img = (rgb.outputImage ?? img).cropped(to: e)
        // Tape noise, alive: coarse grain that moves every frame.
        img = FilmGrain.apply(img, amount: 0.8, size: 0.9, moving: true)
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

    /// Only what moves: the frame over an inverted copy of itself from a moment ago, so
    /// anything still cancels to grey.
    private func motion(_ src: CIImage) -> CIImage {
        let e = src.extent
        guard history.count > 6 else { return src }
        let old = history[history.count - 7]
        let inv = CIFilter.colorInvert(); inv.inputImage = old
        let mix = CIFilter.dissolveTransition(); mix.inputImage = src; mix.targetImage = inv.outputImage; mix.time = 0.5
        let cc = CIFilter.colorControls(); cc.inputImage = mix.outputImage; cc.contrast = 2.4; cc.saturation = 1.4
        return (cc.outputImage ?? src).cropped(to: e)
    }

    /// Each band of rows from a different moment: the top is now, the bottom a second ago.
    private func slitScan(_ src: CIImage) -> CIImage {
        let e = src.extent
        let n = history.count
        guard n > 1 else { return src }
        let bands = 30
        let bandH: CGFloat = e.height / CGFloat(bands)
        var out = src
        for i in 0..<bands {
            let age = min(n - 1, i * n / bands)
            let frame = history[n - 1 - age]
            // CI is bottom-up: band 0 (now) sits at the top.
            let y: CGFloat = e.maxY - CGFloat(i + 1) * bandH
            out = frame.cropped(to: CGRect(x: e.minX, y: y, width: e.width, height: bandH + 1)).composited(over: out)
        }
        return out.cropped(to: e)
    }

    /// A security camera: green-grey, soft, noisy, 15 frames a second, the clock burned in.
    private func cctv(_ src: CIImage, date: Date) -> CIImage {
        let e = src.extent
        let cc = CIFilter.colorControls(); cc.inputImage = src; cc.saturation = 0.15; cc.contrast = 1.25; cc.brightness = -0.03
        let tint = CIFilter.colorMatrix(); tint.inputImage = cc.outputImage
        tint.rVector = CIVector(x: 0.85, y: 0, z: 0, w: 0); tint.gVector = CIVector(x: 0, y: 1.0, z: 0, w: 0); tint.bVector = CIVector(x: 0, y: 0, z: 0.82, w: 0)
        let k: CGFloat = 480 / max(e.width, 1)
        var img = (tint.outputImage ?? src).cropped(to: e)
            .transformed(by: CGAffineTransform(scaleX: k, y: k)).transformed(by: CGAffineTransform(scaleX: 1 / k, y: 1 / k)).cropped(to: e)
        img = FilmGrain.apply(img, amount: 0.5, size: 0.2, moving: true)
        if let osd = CCTVOverlay.image(size: e.size, date: date) {
            img = osd.transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY)).composited(over: img)
        }
        return img.cropped(to: e)
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

/// CAM 01, a record dot, and the date and time to the second, in a small green mono face.
enum CCTVOverlay {
    private static let lock = NSLock()
    private static var key = ""
    private static var cached: CIImage?

    static func image(size: CGSize, date: Date) -> CIImage? {
        let f = DateFormatter(); f.dateFormat = "yy-MM-dd  HH:mm:ss"
        let text = f.string(from: date)
        let k = "\(Int(size.width))x\(Int(size.height))|\(text)"
        lock.lock(); if k == key, let c = cached { lock.unlock(); return c }; lock.unlock()
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let font = XA.uiFont("ShareTechMono-Regular", size.height / 26)
        let green = UIColor(red: 0.78, green: 0.96, blue: 0.42, alpha: 0.95)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: green]
        let pad = size.height / 26
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { r in
            ("CAM 01" as NSString).draw(at: CGPoint(x: size.width - pad - ("CAM 01" as NSString).size(withAttributes: attrs).width, y: pad), withAttributes: attrs)
            let dot = font.lineHeight * 0.4
            r.cgContext.setFillColor(UIColor(red: 0.85, green: 0.25, blue: 0.18, alpha: 1).cgColor)
            r.cgContext.fillEllipse(in: CGRect(x: pad, y: pad + font.lineHeight * 0.3, width: dot, height: dot))
            ("REC" as NSString).draw(at: CGPoint(x: pad + dot * 1.8, y: pad), withAttributes: attrs)
            (text as NSString).draw(at: CGPoint(x: pad, y: size.height - pad - font.lineHeight), withAttributes: attrs)
        }
        guard let cg = img.cgImage else { return nil }
        let c = CIImage(cgImage: cg)
        lock.lock(); key = k; cached = c; lock.unlock()
        return c
    }
}

/// One stretch of a take in one tape.
struct TakeSegment: Codable, Equatable {
    var look: VideoLook
    var start: Double

    static func store(_ segs: [TakeSegment], for assetID: String) {
        if let d = try? JSONEncoder().encode(segs) { UserDefaults.standard.set(d, forKey: "segments:" + assetID) }
    }
    static func load(for assetID: String) -> [TakeSegment] {
        guard let d = UserDefaults.standard.data(forKey: "segments:" + assetID) else { return [] }
        return (try? JSONDecoder().decode([TakeSegment].self, from: d)) ?? []
    }

    /// (look, fraction of the whole) for drawing a bar.
    static func spans(_ segs: [TakeSegment], duration: Double) -> [(VideoLook, Double)] {
        guard duration > 0, !segs.isEmpty else { return [] }
        return segs.enumerated().map { i, s in
            let end = i + 1 < segs.count ? segs[i + 1].start : duration
            return (s.look, max(0, min(duration, end) - s.start) / duration)
        }
    }
}
