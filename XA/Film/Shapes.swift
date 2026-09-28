import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Photo shapes. Everything outside the shape is saved as empty pixels.
enum FrameShape: Int, CaseIterable, Codable, Identifiable {
    case none, capsule, porthole, window, crush, nova

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .none: return "NONE"
        case .capsule: return "CAPSULE"
        case .porthole: return "PORTHOLE"
        case .window: return "WINDOW"
        case .crush: return "CRUSH"
        case .nova: return "NOVA"
        }
    }

    /// The outline in `r`, in top-left-origin coordinates.
    func path(in r: CGRect) -> CGPath? {
        let w = r.width, h = r.height
        switch self {
        case .none:
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

    static func instantLayout(for size: CGSize) -> InstantLayout {
        let side: CGFloat = min(size.width, size.height)
        let m: CGFloat = side * 0.06
        let bottom: CGFloat = m * 3.6
        let paper = CGSize(width: side + 2 * m, height: side + m + bottom)
        let window = CGRect(x: m, y: m, width: side, height: side)
        let border = CGRect(x: 0, y: m + side, width: paper.width, height: bottom)
        return InstantLayout(paper: paper, window: window, border: border)
    }

    /// Print the photo on instant film: square window (or a round one) on a white frame.
    static func instant(_ img: CIImage, round: Bool) -> CIImage {
        let e = img.extent
        let layout = instantLayout(for: e.size)
        let side = layout.window.width
        let crop = CGRect(x: e.midX - side / 2, y: e.midY - side / 2, width: side, height: side)
        var photo = img.cropped(to: crop).transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        let paperRect = CGRect(origin: .zero, size: layout.paper)
        let paperImg = CIImage(color: paper).cropped(to: paperRect)
        if round {
            let d: CGFloat = side * 0.92
            let inset: CGFloat = (side - d) / 2
            let circle = CGRect(x: inset, y: inset, width: d, height: d)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
            let maskImg = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { ctx in
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
}
