import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// What a purikura machine does after the flash: cuts you out, drops you on a loud backdrop and
/// scribbles on the picture with a neon pen. Each of the four shots gets the next one.
enum BoothDeco: String, CaseIterable, Codable {
    /// Lavender sky of outlined stars, a white glow round the edge, sparkles.
    case stars
    /// Soft white, a big airbrushed heart drawn round the faces.
    case heart
    /// Hot pink wall of roses, blush and LOVE in marker.
    case roses
    /// Red and pink hearts all over, XOXO.
    case hearts
    /// Candy yellow with dots, cat ears and whiskers on everyone.
    case kitty

    var title: String { rawValue.uppercased() }

    func step(_ by: Int) -> BoothDeco {
        let all = Self.allCases, n = all.count
        let i = all.firstIndex(of: self) ?? 0
        return all[((i + by) % n + n) % n]
    }

    /// The pen color for this frame's doodles.
    var ink: UIColor {
        switch self {
        case .stars: return UIColor(red: 0.36, green: 0.40, blue: 0.95, alpha: 1)
        case .heart: return UIColor(red: 1, green: 0.36, blue: 0.62, alpha: 1)
        case .roses: return UIColor(red: 0.85, green: 0.05, blue: 0.40, alpha: 1)
        case .hearts: return UIColor(red: 0.90, green: 0.06, blue: 0.25, alpha: 1)
        case .kitty: return UIColor(red: 1, green: 0.38, blue: 0.68, alpha: 1)
        }
    }

    var word: String {
        switch self {
        case .stars: return "BFF"
        case .heart: return "CUTE!"
        case .roses: return "LOVE"
        case .hearts: return "XOXO"
        case .kitty: return "MEOW"
        }
    }
}

extension Booth {
    /// The whole booth: face, skin, then the frame's backdrop and doodles.
    static func develop(_ src: CIImage, _ skin: BoothSkin, deco: BoothDeco?, faces: Eyes?, preview: Bool) -> CIImage {
        var person = Booth.skin(src, skin, eyes: faces)
        guard let deco else { return person }
        let e = person.extent
        if let back = Deco.backdrop(deco, size: e.size), let mask = personMask(person, preview: preview) {
            let b = CIFilter.blendWithMask()
            b.inputImage = person
            b.backgroundImage = back
            b.maskImage = mask
            person = (b.outputImage ?? person).cropped(to: e)
        }
        if let over = Deco.overlay(deco, size: e.size, faces: faces, date: Date()) {
            person = over.composited(over: person).cropped(to: e)
        }
        return person
    }

    /// Who is a person and who is the wall, from the iPhone's person segmentation.
    static func personMask(_ img: CIImage, preview: Bool) -> CIImage? {
        let req = VNGeneratePersonSegmentationRequest()
        req.qualityLevel = preview ? .balanced : .accurate
        req.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(ciImage: img, options: [:])
        guard (try? handler.perform([req])) != nil, let pb = req.results?.first?.pixelBuffer else { return nil }
        let m = CIImage(cvPixelBuffer: pb)
        let e = img.extent
        let sx = e.width / max(m.extent.width, 1), sy = e.height / max(m.extent.height, 1)
        let scaled = m.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        let short = min(e.width, e.height)
        // Generous: anything the model half thinks is you (hair, shoulders, a hand) counts as you,
        // and the cut is grown a little past your edge, so the backdrop never bites into you.
        let boost = CIFilter.colorMatrix()
        boost.inputImage = scaled
        boost.rVector = CIVector(x: 2.2, y: 0, z: 0, w: 0)
        boost.gVector = CIVector(x: 0, y: 2.2, z: 0, w: 0)
        boost.bVector = CIVector(x: 0, y: 0, z: 2.2, w: 0)
        let grow = CIFilter.morphologyMaximum()
        grow.inputImage = (boost.outputImage ?? scaled).clampedToExtent()
        grow.radius = Float(short * 0.012)
        // A soft edge, like the machine's.
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = (grow.outputImage ?? scaled).clampedToExtent()
        blur.radius = Float(short * 0.006)
        let clamp = CIFilter.colorClamp()
        clamp.inputImage = (blur.outputImage ?? scaled).cropped(to: e)
        return clamp.outputImage?.cropped(to: e)
    }
}

/// Drawing the backdrops and the doodles with Core Graphics (origin top left).
enum Deco {
    private static let lock = NSLock()
    private static var backdrops: [String: CIImage] = [:]
    private static var lastOverlay: (key: String, image: CIImage)?

    static func backdrop(_ d: BoothDeco, size: CGSize) -> CIImage? {
        let key = "\(d.rawValue)-\(Int(size.width))x\(Int(size.height))"
        lock.lock(); let hit = backdrops[key]; lock.unlock()
        if let hit { return hit }
        guard let cg = render(size, { ctx in drawBackdrop(d, ctx, size) }) else { return nil }
        let img = CIImage(cgImage: cg)
        // Only the viewfinder's size is worth keeping; a photo's backdrop is drawn once.
        if size.width * size.height <= 2_500_000 {
            lock.lock()
            if backdrops.count > 6 { backdrops.removeAll() }
            backdrops[key] = img
            lock.unlock()
        }
        return img
    }

    static func overlay(_ d: BoothDeco, size: CGSize, faces: Booth.Eyes?, date: Date) -> CIImage? {
        // Faces in drawing coordinates, top left origin.
        let fs: [Booth.Face] = (faces ?? []).map { f in
            func m(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: size.height - p.y) }
            return Booth.Face(eyes: f.eyes.map(m), span: f.span, nose: m(f.nose), jaw: m(f.jaw), width: f.width)
        }
        let q: CGFloat = max(4, min(size.width, size.height) / 120)
        let key = "\(d.rawValue)-\(Int(size.width))x\(Int(size.height))-" + fs.map { f in f.eyes.map { "\(Int($0.x / q)),\(Int($0.y / q))" }.joined(separator: ";") }.joined(separator: "|")
        lock.lock(); let hit = lastOverlay; lock.unlock()
        if let hit, hit.key == key { return hit.image }
        guard let cg = render(size, { ctx in drawOverlay(d, ctx, size, fs, date) }, opaque: false) else { return nil }
        let img = CIImage(cgImage: cg)
        lock.lock(); lastOverlay = (key, img); lock.unlock()
        return img
    }

    private static func render(_ size: CGSize, _ draw: (CGContext) -> Void, opaque: Bool = true) -> CGImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: f).image { draw($0.cgContext) }.cgImage
    }

    // MARK: backdrops

    private static func drawBackdrop(_ d: BoothDeco, _ c: CGContext, _ size: CGSize) {
        let s = min(size.width, size.height)
        var rng = Seeded((BoothDeco.allCases.firstIndex(of: d) ?? 0) * 97 + 11)
        switch d {
        case .stars:
            gradient(c, size, [hex(0xD9D4F7), hex(0x8F88DA)])
            for _ in 0..<38 {
                let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                let r = s * (0.03 + rng.next() * 0.06)
                let path = star(p, r, rotation: rng.next() * 1.2)
                c.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
                c.addPath(path); c.fillPath()
                c.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
                c.setLineWidth(s * 0.005)
                c.addPath(path); c.strokePath()
            }
        case .heart:
            gradient(c, size, [hex(0xFFFAFC), hex(0xF5DCE6)])
        case .roses:
            c.setFillColor(hex(0xF2468F).cgColor); c.fill(CGRect(origin: .zero, size: size))
            let r = s * 0.075
            var y: CGFloat = -r
            var row = 0
            while y < size.height + r {
                var x: CGFloat = row % 2 == 0 ? -r : 0
                while x < size.width + r {
                    rose(c, CGPoint(x: x + rng.next() * r * 0.3, y: y), r * (0.8 + rng.next() * 0.4))
                    x += r * 2.1
                }
                y += r * 1.8; row += 1
            }
        case .hearts:
            c.setFillColor(hex(0xFF5C8D).cgColor); c.fill(CGRect(origin: .zero, size: size))
            let step = s * 0.12
            var row = 0
            var y: CGFloat = 0
            while y < size.height + step {
                var x: CGFloat = row % 2 == 0 ? 0 : step / 2
                var k = row
                while x < size.width + step {
                    let col = k % 2 == 0 ? hex(0xFFD3E1) : hex(0xE3123F)
                    c.setFillColor(col.cgColor)
                    c.addPath(heart(CGPoint(x: x, y: y), step * 0.36)); c.fillPath()
                    x += step; k += 1
                }
                y += step * 0.9; row += 1
            }
        case .kitty:
            c.setFillColor(hex(0xFFE04A).cgColor); c.fill(CGRect(origin: .zero, size: size))
            c.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            let step = s * 0.09
            var y: CGFloat = 0, row = 0
            while y < size.height + step {
                var x: CGFloat = row % 2 == 0 ? 0 : step / 2
                while x < size.width + step {
                    c.fillEllipse(in: CGRect(x: x - step * 0.14, y: y - step * 0.14, width: step * 0.28, height: step * 0.28))
                    x += step
                }
                y += step * 0.87; row += 1
            }
        }
    }

    // MARK: doodles

    private static func drawOverlay(_ d: BoothDeco, _ c: CGContext, _ size: CGSize, _ faces: [Booth.Face], _ date: Date) {
        let s = min(size.width, size.height)
        let pen = s * 0.012
        var rng = Seeded((BoothDeco.allCases.firstIndex(of: d) ?? 0) * 89 + 5)
        switch d {
        case .stars:
            // The machine's white halo round the edge.
            let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
            let cols = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.85).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0.55, 1]) {
                c.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: hypot(size.width, size.height) * 0.55, options: [.drawsAfterEndLocation])
            }
            for f in faces {
                sparkle(c, CGPoint(x: f.eyes[0].x - f.span * 1.3, y: f.eyes[0].y - f.span * 1.1), f.span * 0.35, .white)
                sparkle(c, CGPoint(x: f.eyes[1].x + f.span * 1.2, y: f.eyes[1].y + f.span * 1.6), f.span * 0.25, .white)
            }
        case .heart:
            // One big airbrushed heart round everyone.
            let box = group(faces, size)
            let r = max(box.width, box.height) * 0.62
            let path = heart(CGPoint(x: box.midX, y: box.midY - r * 0.15), r)
            c.saveGState()
            c.setShadow(offset: .zero, blur: s * 0.05, color: hex(0xFF5C9A).withAlphaComponent(0.9).cgColor)
            c.setStrokeColor(hex(0xFF7AAE).withAlphaComponent(0.75).cgColor)
            c.setLineWidth(s * 0.045)
            c.setLineCap(.round)
            c.addPath(path); c.strokePath()
            c.restoreGState()
            for _ in 0..<8 {
                sparkle(c, CGPoint(x: rng.next() * size.width, y: rng.next() * size.height), s * (0.015 + rng.next() * 0.025), .white)
            }
        case .roses, .hearts:
            for f in faces { blush(c, f) }
            for _ in 0..<5 {
                let p = CGPoint(x: rng.next() * size.width, y: size.height * (0.55 + rng.next() * 0.4))
                neon(c, heart(p, s * (0.03 + rng.next() * 0.03)), d.ink, pen)
            }
        case .kitty:
            for f in faces {
                kitty(c, f, d.ink, pen)
                blush(c, f)
            }
            // A paw print in the corner.
            paw(c, CGPoint(x: size.width * 0.82, y: size.height * 0.88), s * 0.06, d.ink)
        }
        // The scribbled word and the date, in marker, tilted.
        scribble(c, d.word, at: CGPoint(x: size.width * 0.06, y: size.height * 0.05), size: s * 0.09, color: d.ink, tilt: -0.14)
        let df = DateFormatter(); df.dateFormat = "MM.dd"
        scribble(c, df.string(from: date), at: CGPoint(x: size.width * 0.62, y: size.height * 0.9), size: s * 0.06, color: d.ink, tilt: -0.08)
    }

    /// The bounding box of everyone's faces, or the middle of the picture.
    private static func group(_ faces: [Booth.Face], _ size: CGSize) -> CGRect {
        guard !faces.isEmpty else { return CGRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: size.height * 0.45) }
        var r = CGRect.null
        for f in faces {
            let mid = CGPoint(x: (f.eyes[0].x + f.eyes[1].x) / 2, y: (f.eyes[0].y + f.eyes[1].y) / 2)
            r = r.union(CGRect(x: mid.x - f.width * 0.6, y: mid.y - f.span * 1.6, width: f.width * 1.2, height: f.span * 3.6))
        }
        return r
    }

    private static func kitty(_ c: CGContext, _ f: Booth.Face, _ ink: UIColor, _ pen: CGFloat) {
        let mid = CGPoint(x: (f.eyes[0].x + f.eyes[1].x) / 2, y: (f.eyes[0].y + f.eyes[1].y) / 2)
        let d = f.span
        for side: CGFloat in [-1, 1] {
            let base = CGPoint(x: mid.x + side * d * 1.05, y: mid.y - d * 1.75)
            let ear = CGMutablePath()
            ear.move(to: CGPoint(x: base.x - d * 0.42, y: base.y + d * 0.1))
            ear.addLine(to: CGPoint(x: base.x + side * d * 0.15, y: base.y - d * 0.75))
            ear.addLine(to: CGPoint(x: base.x + d * 0.42, y: base.y + d * 0.1))
            c.setFillColor(hex(0xFFC2DA).withAlphaComponent(0.9).cgColor)
            c.addPath(ear); c.fillPath()
            neon(c, ear, ink, pen)
            // Whiskers.
            let cheek = CGPoint(x: mid.x + side * d * 0.75, y: mid.y + d * 0.85)
            for k in -1...1 {
                let w = CGMutablePath()
                w.move(to: cheek)
                w.addLine(to: CGPoint(x: cheek.x + side * d * 0.7, y: cheek.y + CGFloat(k) * d * 0.18))
                neon(c, w, ink, pen * 0.7)
            }
        }
    }

    /// Pink cheeks with the machine's little diagonal hatching.
    private static func blush(_ c: CGContext, _ f: Booth.Face) {
        let d = f.span
        for (i, eye) in f.eyes.enumerated() {
            let side: CGFloat = i == 0 ? (eye.x < f.eyes[1].x ? -1 : 1) : (eye.x < f.eyes[0].x ? -1 : 1)
            let p = CGPoint(x: eye.x + side * d * 0.2, y: eye.y + d * 0.65)
            c.saveGState()
            c.setShadow(offset: .zero, blur: d * 0.15, color: hex(0xFF6F9F).withAlphaComponent(0.6).cgColor)
            c.setFillColor(hex(0xFF8DB3).withAlphaComponent(0.45).cgColor)
            c.fillEllipse(in: CGRect(x: p.x - d * 0.28, y: p.y - d * 0.14, width: d * 0.56, height: d * 0.28))
            c.restoreGState()
            c.setStrokeColor(hex(0xFF3D7F).withAlphaComponent(0.8).cgColor)
            c.setLineWidth(max(1.5, d * 0.03))
            c.setLineCap(.round)
            for k in 0..<3 {
                let x = p.x - d * 0.12 + CGFloat(k) * d * 0.12
                c.move(to: CGPoint(x: x, y: p.y + d * 0.07))
                c.addLine(to: CGPoint(x: x + d * 0.08, y: p.y - d * 0.07))
            }
            c.strokePath()
        }
    }

    private static func paw(_ c: CGContext, _ p: CGPoint, _ r: CGFloat, _ ink: UIColor) {
        c.setFillColor(ink.withAlphaComponent(0.9).cgColor)
        c.fillEllipse(in: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.2, width: r * 1.1, height: r * 0.9))
        for (dx, dy) in [(-0.6, -0.55), (-0.2, -0.85), (0.2, -0.85), (0.6, -0.55)] as [(CGFloat, CGFloat)] {
            c.fillEllipse(in: CGRect(x: p.x + dx * r - r * 0.18, y: p.y + dy * r - r * 0.2, width: r * 0.36, height: r * 0.4))
        }
    }

    /// The purikura pen: a white outline with a colored line on top.
    private static func neon(_ c: CGContext, _ path: CGPath, _ ink: UIColor, _ w: CGFloat) {
        c.setLineCap(.round); c.setLineJoin(.round)
        c.setStrokeColor(UIColor.white.cgColor); c.setLineWidth(w * 2.2)
        c.addPath(path); c.strokePath()
        c.setStrokeColor(ink.cgColor); c.setLineWidth(w)
        c.addPath(path); c.strokePath()
    }

    private static func scribble(_ c: CGContext, _ s: String, at p: CGPoint, size: CGFloat, color: UIColor, tilt: CGFloat) {
        let font = UIFont(name: "PermanentMarker-Regular", size: size) ?? UIFont.systemFont(ofSize: size, weight: .black)
        c.saveGState()
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: tilt)
        let outline: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .strokeColor: UIColor.white, .strokeWidth: -28]
        (s as NSString).draw(at: .zero, withAttributes: outline)
        (s as NSString).draw(at: .zero, withAttributes: [.font: font, .foregroundColor: color])
        c.restoreGState()
    }

    private static func sparkle(_ c: CGContext, _ p: CGPoint, _ r: CGFloat, _ col: UIColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: p.x, y: p.y - r))
        path.addQuadCurve(to: CGPoint(x: p.x + r, y: p.y), control: p)
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r), control: p)
        path.addQuadCurve(to: CGPoint(x: p.x - r, y: p.y), control: p)
        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r), control: p)
        c.saveGState()
        c.setShadow(offset: .zero, blur: r * 0.6, color: col.cgColor)
        c.setFillColor(col.cgColor)
        c.addPath(path); c.fillPath()
        c.restoreGState()
    }

    private static func rose(_ c: CGContext, _ p: CGPoint, _ r: CGFloat) {
        c.setFillColor(hex(0xFF8FBF).cgColor)
        c.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        c.setStrokeColor(hex(0xD8155F).cgColor)
        c.setLineWidth(r * 0.09)
        c.setLineCap(.round)
        // A spiral of petals.
        let path = CGMutablePath()
        var a: CGFloat = 0
        path.move(to: p)
        while a < .pi * 5 {
            let rr = r * 0.9 * a / (.pi * 5)
            path.addLine(to: CGPoint(x: p.x + cos(a) * rr, y: p.y + sin(a) * rr))
            a += 0.25
        }
        c.addPath(path); c.strokePath()
    }

    static func star(_ p: CGPoint, _ r: CGFloat, rotation: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<10 {
            let a = rotation - .pi / 2 + CGFloat(i) * .pi / 5
            let rr = i % 2 == 0 ? r : r * 0.45
            let q = CGPoint(x: p.x + cos(a) * rr, y: p.y + sin(a) * rr)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        path.closeSubpath()
        return path
    }

    /// A heart of half-width `r` centered on `p`, point down.
    static func heart(_ p: CGPoint, _ r: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let top = CGPoint(x: p.x, y: p.y - r * 0.45)
        let bottom = CGPoint(x: p.x, y: p.y + r)
        path.move(to: bottom)
        path.addCurve(to: top, control1: CGPoint(x: p.x - r * 1.5, y: p.y + r * 0.1), control2: CGPoint(x: p.x - r * 0.9, y: p.y - r * 1.25))
        path.addCurve(to: bottom, control1: CGPoint(x: p.x + r * 0.9, y: p.y - r * 1.25), control2: CGPoint(x: p.x + r * 1.5, y: p.y + r * 0.1))
        path.closeSubpath()
        return path
    }

    private static func gradient(_ c: CGContext, _ size: CGSize, _ cols: [UIColor]) {
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols.map(\.cgColor) as CFArray, locations: nil) else { return }
        c.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width * 0.3, y: size.height), options: [])
    }

    private static func hex(_ v: Int) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }

    /// Same scatter every time for the same frame, so the viewfinder doesn't flicker.
    private struct Seeded {
        var s: UInt64
        init(_ seed: Int) { s = UInt64(truncatingIfNeeded: seed) &* 6364136223846793005 &+ 1 }
        mutating func next() -> CGFloat {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((s >> 33) % 10_000) / 10_000
        }
    }
}
