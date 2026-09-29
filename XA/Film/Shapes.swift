import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Photo shapes. Everything outside the shape is saved as empty pixels.
enum FrameShape: Int, CaseIterable, Codable, Identifiable {
    case none, capsule, porthole, window, crush, nova, polaroid, polaRound, instax, instaxWide

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .none: return "NONE"
        case .capsule: return "CAPSULE"
        case .porthole: return "PORTHOLE"
        case .window: return "WINDOW"
        case .crush: return "CRUSH"
        case .nova: return "NOVA"
        case .polaroid: return "POLAROID"
        case .polaRound: return "POLA ROUND"
        case .instax: return "INSTAX"
        case .instaxWide: return "INSTAX WIDE"
        }
    }

    /// Instant film prints the photo on paper instead of cutting it out.
    var instant: InstantKind? {
        switch self {
        case .polaroid: return .square
        case .polaRound: return .round
        case .instax: return .mini
        case .instaxWide: return .wide
        default: return nil
        }
    }

    /// The outline in `r`, in top-left-origin coordinates.
    func path(in r: CGRect) -> CGPath? {
        let w = r.width, h = r.height
        switch self {
        case .none, .polaroid, .polaRound, .instax, .instaxWide:
            return nil
        case .capsule:
            // Upright in a portrait frame, lying down in a landscape one.
            let tall = h >= w
            let pw: CGFloat = tall ? w * 0.8 : min(w * 0.94, h * 0.8 * 2.2)
            let ph: CGFloat = tall ? min(h * 0.94, w * 0.8 * 2.2) : h * 0.8
            let rect = CGRect(x: r.midX - pw / 2, y: r.midY - ph / 2, width: pw, height: ph)
            let rad: CGFloat = min(pw, ph) / 2
            return CGPath(roundedRect: rect, cornerWidth: rad, cornerHeight: rad, transform: nil)
        case .porthole:
            let d: CGFloat = min(w, h) * 0.92
            return CGPath(ellipseIn: CGRect(x: r.midX - d / 2, y: r.midY - d / 2, width: d, height: d), transform: nil)
        case .window:
            let pw: CGFloat = min(w * 0.72, h * 0.86 / 1.3)
            let ph: CGFloat = min(h * 0.86, pw * 1.7)
            let left: CGFloat = r.midX - pw / 2
            let top: CGFloat = r.midY - ph / 2
            let p = CGMutablePath()
            p.move(to: CGPoint(x: left, y: top + ph))
            p.addLine(to: CGPoint(x: left, y: top + pw / 2))
            p.addArc(center: CGPoint(x: r.midX, y: top + pw / 2), radius: pw / 2, startAngle: .pi, endAngle: 0, clockwise: false)
            p.addLine(to: CGPoint(x: left + pw, y: top + ph))
            p.closeSubpath()
            return p
        case .crush:
            return Shapes.heart(in: r, fill: 0.92)
        case .nova:
            let outer: CGFloat = min(w, h) * 0.47
            let inner: CGFloat = outer * 0.46
            let p = CGMutablePath()
            for i in 0..<10 {
                let rad: CGFloat = i % 2 == 0 ? outer : inner
                let a: CGFloat = -.pi / 2 + CGFloat(i) * .pi / 5
                let pt = CGPoint(x: r.midX + rad * cos(a), y: r.midY + 0.04 * h + rad * sin(a))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        }
    }
}

enum Shapes {
    /// The heart, drawn in a 100 × 90 box: two round lobes, a soft cleft and a long point.
    /// M50,88 C22,66 2,48 2,28 C2,13 13,2 27,2 C37,2 45,8 50,16 C55,8 63,2 73,2 C87,2 98,13 98,28 C98,48 78,66 50,88 Z
    static func heartPoint(_ x: CGFloat, _ y: CGFloat, in r: CGRect, fill: CGFloat) -> CGPoint {
        let k: CGFloat = min(r.width * fill / 96, r.height * fill / 86)
        return CGPoint(x: r.midX + (x - 50) * k, y: r.midY + (y - 45) * k)
    }

    static func heart(in r: CGRect, fill: CGFloat = 1) -> CGPath {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { heartPoint(x, y, in: r, fill: fill) }
        let p = CGMutablePath()
        p.move(to: P(50, 88))
        p.addCurve(to: P(2, 28), control1: P(22, 66), control2: P(2, 48))
        p.addCurve(to: P(27, 2), control1: P(2, 13), control2: P(13, 2))
        p.addCurve(to: P(50, 16), control1: P(37, 2), control2: P(45, 8))
        p.addCurve(to: P(73, 2), control1: P(55, 8), control2: P(63, 2))
        p.addCurve(to: P(98, 28), control1: P(87, 2), control2: P(98, 13))
        p.addCurve(to: P(50, 88), control1: P(98, 48), control2: P(78, 66))
        p.closeSubpath()
        return p
    }

    private static let lock = NSLock()
    private static var masks: [String: CIImage] = [:]

    /// White inside the shape, clear outside, the size of `extent`.
    static func mask(_ shape: FrameShape, extent: CGRect) -> CIImage? {
        guard shape != .none else { return nil }
        let key = "\(shape.rawValue)-\(Int(extent.width))x\(Int(extent.height))"
        lock.lock()
        if let m = masks[key] { lock.unlock(); return m.transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY)) }
        lock.unlock()
        let size = extent.size
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            guard let p = shape.path(in: CGRect(origin: .zero, size: size)) else { return }
            ctx.cgContext.addPath(p)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillPath()
        }
        guard let cg = img.cgImage else { return nil }
        let m = CIImage(cgImage: cg)
        lock.lock()
        if masks.count > 16 { masks.removeAll() }
        masks[key] = m
        lock.unlock()
        return m.transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    /// Cut the photo to the shape. `background` shows through (clear when saving, a
    /// checkerboard in the viewfinder).
    static func apply(_ shape: FrameShape, to img: CIImage, background: CIImage? = nil) -> CIImage {
        let e = img.extent
        guard let m = mask(shape, extent: e) else { return img }
        let bg = background ?? CIImage(color: .clear).cropped(to: e)
        let f = CIFilter.blendWithAlphaMask()
        f.inputImage = img
        f.backgroundImage = bg
        f.maskImage = m
        return (f.outputImage ?? img).cropped(to: e)
    }

    /// The transparency checkerboard the viewfinder shows outside a shape.
    static func checker(extent e: CGRect) -> CIImage {
        let f = CIFilter.checkerboardGenerator()
        f.color0 = CIColor(red: 0.047, green: 0.047, blue: 0.051)
        f.color1 = CIColor(red: 0.082, green: 0.082, blue: 0.09)
        f.width = Float(max(8, e.width / 22))
        f.sharpness = 1
        f.center = CGPoint(x: e.minX, y: e.minY)
        return (f.outputImage ?? CIImage(color: .black)).cropped(to: e)
    }

    // MARK: instant prints

    static let paper = CIColor(red: 0.969, green: 0.961, blue: 0.941)

    /// Where things sit on an instant print made from a photo of the given size, top-left origin.
    struct InstantLayout {
        let paper: CGSize
        let window: CGRect
        let border: CGRect
    }

    /// Paper and window for each instant film, from the window's width.
    /// Polaroid: square window, thick chin. Instax Mini: 46 x 62 mm on 54 x 86. Instax Wide: 99 x 62 on 108 x 86.
    static func instantLayout(for size: CGSize, kind: InstantKind = .square) -> InstantLayout {
        let aspect = kind.aspect   // window width / height
        var ww: CGFloat = size.width, wh: CGFloat = size.width / aspect
        if wh > size.height { wh = size.height; ww = wh * aspect }
        let side = ww * kind.side, top = ww * kind.top, bottom = ww * kind.bottom
        let paper = CGSize(width: ww + 2 * side, height: wh + top + bottom)
        let window = CGRect(x: side, y: top, width: ww, height: wh)
        let border = CGRect(x: 0, y: top + wh, width: paper.width, height: bottom)
        return InstantLayout(paper: paper, window: window, border: border)
    }

    /// The chin of a print of `paper` size, in top-left coordinates, for the handwritten date.
    static func instantBorder(paper: CGSize, kind: InstantKind) -> CGRect {
        let ww = paper.width / (1 + 2 * kind.side)
        let bottom = ww * kind.bottom
        return CGRect(x: 0, y: paper.height - bottom, width: paper.width, height: bottom)
    }

    /// Print the photo on instant film: the window cropped from the middle of the frame, on paper.
    static func instant(_ img: CIImage, kind: InstantKind) -> CIImage {
        let e = img.extent
        let layout = instantLayout(for: e.size, kind: kind)
        let win = layout.window.size
        let crop = CGRect(x: e.midX - win.width / 2, y: e.midY - win.height / 2, width: win.width, height: win.height)
        var photo = img.cropped(to: crop).transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        let paperRect = CGRect(origin: .zero, size: layout.paper)
        let paperImg = CIImage(color: paper).cropped(to: paperRect)
        if kind == .round {
            let d: CGFloat = min(win.width, win.height) * 0.92
            let circle = CGRect(x: (win.width - d) / 2, y: (win.height - d) / 2, width: d, height: d)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
            let maskImg = UIGraphicsImageRenderer(size: win, format: fmt).image { ctx in
                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fillEllipse(in: circle)
            }
            if let cg = maskImg.cgImage {
                let f = CIFilter.blendWithAlphaMask()
                f.inputImage = photo
                f.backgroundImage = CIImage(color: paper).cropped(to: photo.extent)
                f.maskImage = CIImage(cgImage: cg)
                photo = (f.outputImage ?? photo).cropped(to: photo.extent)
            }
        }
        // CI is bottom-left origin: the window sits `bottom border` up from the foot of the paper.
        let fromBottom: CGFloat = layout.paper.height - layout.window.maxY
        let placed = photo.transformed(by: CGAffineTransform(translationX: layout.window.minX, y: fromBottom))
        return placed.composited(over: paperImg).cropped(to: paperRect)
    }

    /// Older sims that printed their own frame.
    static func instant(_ img: CIImage, round: Bool) -> CIImage { instant(img, kind: round ? .round : .square) }
}

/// Instant film formats.
enum InstantKind: String, Codable {
    case none, square, round, mini, wide
    /// Window width / height.
    var aspect: CGFloat {
        switch self {
        case .mini: return 46.0 / 62.0
        case .wide: return 99.0 / 62.0
        default: return 1
        }
    }
    /// Margins as fractions of the window width.
    var side: CGFloat { self == .mini ? 4.0 / 46.0 : (self == .wide ? 4.5 / 99.0 : 0.06) }
    var top: CGFloat { self == .mini ? 6.5 / 46.0 : (self == .wide ? 6.5 / 99.0 : 0.06) }
    var bottom: CGFloat { self == .mini ? 17.5 / 46.0 : (self == .wide ? 17.5 / 99.0 : 0.216) }
}
