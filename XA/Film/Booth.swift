import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// BOOTH's skin settings, the way a purikura machine offers them before you shoot.
enum BoothSkin: String, CaseIterable, Codable {
    case natural, glow, doll
    var title: String {
        switch self {
        case .natural: return "NATURAL"
        case .glow: return "GLOW"
        case .doll: return "DOLL"
        }
    }
}

/// How the four shots are laid out on the sticker sheet.
enum BoothLayout: String, CaseIterable, Codable {
    /// One big sticker, three medium, eight small.
    case sheet
    /// Four in a two-by-two grid.
    case grid
    /// The classic strip: four, one above the other.
    case strip
    var letter: String {
        switch self {
        case .sheet: return "A"
        case .grid: return "B"
        case .strip: return "C"
        }
    }
    var title: String { "SHEET \(letter)" }
    func step(_ by: Int) -> BoothLayout {
        let all = Self.allCases, n = all.count
        let i = all.firstIndex(of: self) ?? 0
        return all[((i + by) % n + n) % n]
    }
}

/// The booth's colors, shared by the display, the corner card and the sheet.
enum BoothInk {
    static let hot = UIColor(red: 1, green: 0.31, blue: 0.63, alpha: 1)       // #FF4FA0
    static let pink = UIColor(red: 1, green: 0.70, blue: 0.82, alpha: 1)      // #FFB3D1
    static let lilac = UIColor(red: 0.80, green: 0.72, blue: 1, alpha: 1)     // #CDB8FF
    static let mint = UIColor(red: 0.72, green: 0.94, blue: 0.86, alpha: 1)   // #B8F0DC
    static let violet = UIColor(red: 0.48, green: 0.35, blue: 0.85, alpha: 1) // #7A5AD9
    static let font = "MochiyPopOne-Regular"
}

/// The machine's beauty filter: smoother skin, brighter, a little pink; DOLL also makes the eyes bigger.
enum Booth {
    static let shots = 4

    /// Eye centers in the image's own coordinates (Core Image, origin bottom left).
    struct Eyes { var points: [CGPoint]; var span: CGFloat }

    static func skin(_ src: CIImage, _ skin: BoothSkin, eyes: Eyes?) -> CIImage {
        let img = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
        let e = img.extent
        let w = min(e.width, e.height)
        let smooth: CGFloat = skin == .natural ? 0.35 : (skin == .glow ? 0.55 : 0.6)
        let lift: Float = skin == .natural ? 0.12 : (skin == .glow ? 0.32 : 0.38)
        let sat: Float = skin == .natural ? 1.0 : (skin == .glow ? 1.06 : 1.08)
        let pinkness: CGFloat = skin == .natural ? 0.01 : (skin == .glow ? 0.03 : 0.035)
        let bloom: Float = skin == .natural ? 0 : (skin == .glow ? 0.45 : 0.5)
        // Soft skin: a blurred copy laid over the picture where it is smooth, so edges (eyes,
        // hair, the outline of a face) keep their detail and cheeks go soft.
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = img.clampedToExtent()
        blur.radius = Float(w * 0.006)
        let soft = (blur.outputImage ?? img).cropped(to: e)
        let edges = CIFilter.edges()
        edges.inputImage = img
        edges.intensity = 6
        let mono = CIFilter.colorControls()
        mono.inputImage = edges.outputImage ?? img
        mono.saturation = 0
        let mb = CIFilter.gaussianBlur()
        mb.inputImage = (mono.outputImage ?? img).clampedToExtent()
        mb.radius = Float(w * 0.004)
        // Mask: white where it is smooth (gets the soft copy), black on edges.
        let two: CGFloat = -smooth * 2
        let inv = CIFilter.colorMatrix()
        inv.inputImage = (mb.outputImage ?? img).cropped(to: e)
        inv.rVector = CIVector(x: two, y: 0, z: 0, w: 0)
        inv.gVector = CIVector(x: 0, y: two, z: 0, w: 0)
        inv.bVector = CIVector(x: 0, y: 0, z: two, w: 0)
        inv.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        inv.biasVector = CIVector(x: smooth, y: smooth, z: smooth, w: 1)
        let mask = CIFilter.colorClamp()
        mask.inputImage = inv.outputImage
        mask.minComponents = CIVector(x: 0, y: 0, z: 0, w: 1)
        mask.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = soft
        blend.backgroundImage = img
        blend.maskImage = mask.outputImage
        var out = (blend.outputImage ?? img).cropped(to: e)

        // Brighter and a touch pink: the booth's ring of lights.
        let ex = CIFilter.exposureAdjust()
        ex.inputImage = out
        ex.ev = lift
        out = ex.outputImage ?? out
        let cc = CIFilter.colorControls()
        cc.inputImage = out
        cc.saturation = sat
        cc.contrast = 0.96
        out = cc.outputImage ?? out
        let tint = CIFilter.colorMatrix()
        tint.inputImage = out
        tint.biasVector = CIVector(x: pinkness, y: 0, z: pinkness * 0.6, w: 0)
        out = (tint.outputImage ?? out).cropped(to: e)
        if bloom > 0 {
            let b = CIFilter.bloom()
            b.inputImage = out.clampedToExtent()
            b.radius = Float(w * 0.02)
            b.intensity = bloom
            out = (b.outputImage ?? out).cropped(to: e)
        }
        if skin == .doll, let eyes {
            for p in eyes.points {
                let bump = CIFilter.bumpDistortion()
                bump.inputImage = out.clampedToExtent()
                bump.center = p
                bump.radius = Float(eyes.span * 0.42)
                bump.scale = 0.38
                out = (bump.outputImage ?? out).cropped(to: e)
            }
        }
        return out
    }

    /// Finds the eyes of every face in the picture, for DOLL. Points come back in the
    /// coordinates of `img` translated to the origin, the way `skin` works.
    static func eyes(in src: CIImage) -> Eyes? {
        let img = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
        let e = img.extent
        let req = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(ciImage: img, options: [:])
        guard (try? handler.perform([req])) != nil, let faces = req.results, !faces.isEmpty else { return nil }
        var pts: [CGPoint] = []
        var span: CGFloat = 0
        for f in faces {
            let box = f.boundingBox
            func center(_ r: VNFaceLandmarkRegion2D?) -> CGPoint? {
                guard let r, r.pointCount > 0 else { return nil }
                let ps = r.normalizedPoints
                let x = ps.map { CGFloat($0.x) }.reduce(0, +) / CGFloat(ps.count)
                let y = ps.map { CGFloat($0.y) }.reduce(0, +) / CGFloat(ps.count)
                return CGPoint(x: (box.minX + x * box.width) * e.width, y: (box.minY + y * box.height) * e.height)
            }
            guard let l = center(f.landmarks?.leftEye), let r = center(f.landmarks?.rightEye) else { continue }
            pts += [l, r]
            span = max(span, hypot(l.x - r.x, l.y - r.y))
        }
        return pts.isEmpty ? nil : Eyes(points: pts, span: span)
    }

    /// The same eyes on a copy of the picture `k` times the size.
    static func scaled(_ eyes: Eyes?, _ k: CGFloat) -> Eyes? {
        guard let eyes else { return nil }
        return Eyes(points: eyes.points.map { CGPoint(x: $0.x * k, y: $0.y * k) }, span: eyes.span * k)
    }

    // MARK: the sheet

    static func sheetSize(_ layout: BoothLayout) -> CGSize {
        switch layout {
        case .sheet: return CGSize(width: 1610, height: 2800)
        case .grid: return CGSize(width: 1800, height: 2560)
        case .strip: return CGSize(width: 1000, height: 3000)
        }
    }

    /// The sticker sheet for four shots. Shots are upright; the sheet is portrait.
    static func sheet(_ shots: [UIImage], layout: BoothLayout, date: Date, number: Int) -> UIImage? {
        guard !shots.isEmpty else { return nil }
        let size = sheetSize(layout)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let cg = ctx.cgContext
            // Paper: white fading to blush.
            let colors = [UIColor.white.cgColor, UIColor(red: 0.984, green: 0.914, blue: 0.945, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width * 0.4, y: size.height), options: [])
            }
            let pad = size.width * 0.056
            let df = DateFormatter(); df.dateFormat = "yyyy.MM.dd"
            let head = size.width * (layout == .strip ? 0.075 : 0.05)
            text("XA BOOTH", at: CGPoint(x: pad, y: pad), size: head, color: BoothInk.hot)
            let meta = "\(df.string(from: date)) · NO.\(String(format: "%04d", number % 10000))"
            if layout == .strip {
                text(meta, at: CGPoint(x: pad, y: pad + head * 1.4), size: head * 0.45, color: BoothInk.violet.withAlphaComponent(0.7))
            } else {
                text(meta, right: size.width - pad, baseline: pad + head * 0.95, size: head * 0.6, color: UIColor(red: 0.63, green: 0.44, blue: 0.54, alpha: 1))
            }
            let top = pad + head * (layout == .strip ? 2.3 : 1.6)
            let s = { (i: Int) in shots[i % shots.count] }
            let inner = size.width - pad * 2
            switch layout {
            case .sheet:
                let gap = inner * 0.035
                let bigH = inner * 200 / 286
                sticker(s(0), CGRect(x: pad, y: top, width: inner, height: bigH), caption: "BEST DAY ♥")
                let mw = (inner - gap * 2) / 3, mh = mw * 66 / 88
                for i in 0..<3 { sticker(s(i + 1), CGRect(x: pad + CGFloat(i) * (mw + gap), y: top + bigH + gap, width: mw, height: mh)) }
                let sg = inner * 0.028
                let sw = (inner - sg * 3) / 4, sh = sw * 48 / 64
                for r in 0..<2 {
                    for c in 0..<4 {
                        let y = top + bigH + gap + mh + gap + CGFloat(r) * (sh + sg)
                        sticker(s(r * 4 + c), CGRect(x: pad + CGFloat(c) * (sw + sg), y: y, width: sw, height: sh))
                    }
                }
            case .grid:
                let gap = inner * 0.04
                let tw = (inner - gap) / 2, th = tw * 4 / 3
                for i in 0..<4 {
                    let r = CGRect(x: pad + CGFloat(i % 2) * (tw + gap), y: top + CGFloat(i / 2) * (th + gap), width: tw, height: th)
                    sticker(s(i), r, caption: i == 3 ? "♥" : nil)
                }
            case .strip:
                let gap = inner * 0.06
                let th = (size.height - top - pad - gap * 3) / 4
                for i in 0..<4 { sticker(s(i), CGRect(x: pad, y: top + CGFloat(i) * (th + gap), width: inner, height: th)) }
            }
        }
    }

    /// One die-cut sticker: the photo cropped to fill, rounded, with a white border.
    private static func sticker(_ img: UIImage, _ r: CGRect, caption: String? = nil) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let radius = min(r.width, r.height) * 0.07
        let border = max(4, min(r.width, r.height) * 0.025)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: border * 0.4), blur: border * 1.5, color: UIColor(white: 0, alpha: 0.12).cgColor)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: r.insetBy(dx: -border, dy: -border), cornerRadius: radius + border).fill()
        cg.restoreGState()
        cg.saveGState()
        UIBezierPath(roundedRect: r, cornerRadius: radius).addClip()
        // Fill, keeping the upper part (faces) when it has to crop top and bottom.
        let k = max(r.width / img.size.width, r.height / img.size.height)
        let w = img.size.width * k, h = img.size.height * k
        let y = r.minY - (h - r.height) * 0.3
        img.draw(in: CGRect(x: r.midX - w / 2, y: y, width: w, height: h))
        cg.restoreGState()
        if let caption {
            let size = r.height * 0.1
            let attrs = attributes(size: size, color: .white)
            let tw = (caption as NSString).size(withAttributes: attrs).width
            let p = CGPoint(x: r.midX - tw / 2, y: r.maxY - size * 1.7)
            var stroke = attrs
            stroke[.strokeColor] = BoothInk.hot
            stroke[.strokeWidth] = 22
            (caption as NSString).draw(at: p, withAttributes: stroke)
            (caption as NSString).draw(at: p, withAttributes: attrs)
        }
    }

    private static func attributes(size: CGFloat, color: UIColor) -> [NSAttributedString.Key: Any] {
        [.font: UIFont(name: BoothInk.font, size: size) ?? UIFont.systemFont(ofSize: size, weight: .heavy), .foregroundColor: color]
    }

    private static func text(_ s: String, at p: CGPoint, size: CGFloat, color: UIColor) {
        (s as NSString).draw(at: p, withAttributes: attributes(size: size, color: color))
    }

    private static func text(_ s: String, right: CGFloat, baseline: CGFloat, size: CGFloat, color: UIColor) {
        let a = attributes(size: size, color: color)
        let sz = (s as NSString).size(withAttributes: a)
        (s as NSString).draw(at: CGPoint(x: right - sz.width, y: baseline - sz.height * 0.8), withAttributes: a)
    }
}
