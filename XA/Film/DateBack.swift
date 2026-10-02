import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// An 8-bit colour, so the palette can be checked off-device the way Roll's was.
struct RGBA8: Codable, Equatable, Hashable {
    var r: Int, g: Int, b: Int, a: Int
    init(_ r: Int, _ g: Int, _ b: Int, _ a: Int = 255) { self.r = r; self.g = g; self.b = b; self.a = a }
    var ui: UIColor { UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255) }
    var cg: CGColor { ui.cgColor }
}

enum DateStyle: String, CaseIterable, Codable, Identifiable {
    case quartz, dots, camcorder, lcd, stamp, marker, edge
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var note: String {
        switch self {
        case .quartz: return "From Roll · 7-segment"
        case .dots: return "From Roll · 5×7 lamps"
        case .camcorder: return "From Roll · keylined"
        case .lcd: return "Early digicam overlay"
        case .stamp: return "Red ink, crooked"
        case .marker: return "Marker on white tape"
        case .edge: return "Film edge print"
        }
    }
}

enum DatePlacement: String, CaseIterable, Codable { case off, corner, follow }
enum DateFormat: String, CaseIterable, Codable { case own, dmy, long }

struct DateConfig: Codable, Equatable, Hashable {
    var style: DateStyle = .quartz
    var placement: DatePlacement = .follow
    var format: DateFormat = .own
    var time: Bool = false
    /// Nil keeps the style's own ink.
    var color: RGBA8? = nil
}

/// Arc-length walk along a polyline, for setting type along a frame's edge.
struct PathWalker {
    let points: [CGPoint]
    let cumulative: [CGFloat]
    init(points: [CGPoint]) {
        self.points = points
        var c: [CGFloat] = [0]
        if points.count > 1 {
            for i in 1..<points.count {
                let dx: CGFloat = points[i].x - points[i - 1].x
                let dy: CGFloat = points[i].y - points[i - 1].y
                c.append(c[i - 1] + hypot(dx, dy))
            }
        }
        cumulative = c
    }
    var length: CGFloat { cumulative.last ?? 0 }

    func point(at s0: CGFloat) -> (position: CGPoint, angle: CGFloat) {
        guard points.count > 1 else { return (points.first ?? .zero, 0) }
        let s = min(max(s0, 0), length)
        var i = 1
        while i < cumulative.count - 1 && cumulative[i] < s { i += 1 }
        let a = points[i - 1], b = points[i]
        let segLen: CGFloat = max(0.000001, cumulative[i] - cumulative[i - 1])
        let t: CGFloat = (s - cumulative[i - 1]) / segLen
        let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        return (p, atan2(b.y - a.y, b.x - a.x))
    }
}

/// The date back, burned into the photograph. Dots, Quartz and Camcorder are Roll's
/// DateStamp.kt drawn the same way on iOS: a dot matrix of round lamps that leans as a
/// staircase, seven mitred segments under one shear, and a keylined condensed face.
enum DateBack {
    /// Roll's SCALE: fifteen percent off the size the three were first drawn at.
    static let scale: CGFloat = 0.85
    static let slant: CGFloat = 0.26
    static let dot: CGFloat = 0.42

    struct Ink: Equatable { var lamp: RGBA8; var halo: RGBA8 }

    static func inkFor(_ style: DateStyle, mono: Bool) -> Ink {
        if mono {
            switch style {
            case .camcorder: return Ink(lamp: RGBA8(245, 245, 245, 255), halo: RGBA8(0, 0, 0, 245))
            case .marker: return Ink(lamp: RGBA8(26, 26, 26, 235), halo: RGBA8(240, 240, 240, 240))
            default: return Ink(lamp: RGBA8(245, 245, 245, 235), halo: RGBA8(0, 0, 0, 120))
            }
        }
        switch style {
        case .dots: return Ink(lamp: RGBA8(205, 222, 74, 230), halo: RGBA8(214, 232, 96, 58))
        case .quartz: return Ink(lamp: RGBA8(240, 86, 30, 240), halo: RGBA8(255, 132, 60, 50))
        case .camcorder: return Ink(lamp: RGBA8(247, 160, 42, 255), halo: RGBA8(0, 0, 0, 245))
        case .lcd: return Ink(lamp: RGBA8(255, 255, 255, 255), halo: RGBA8(0, 0, 0, 90))
        case .stamp: return Ink(lamp: RGBA8(216, 65, 47, 215), halo: RGBA8(216, 65, 47, 0))
        case .marker: return Ink(lamp: RGBA8(26, 26, 26, 235), halo: RGBA8(247, 243, 232, 240))
        case .edge: return Ink(lamp: RGBA8(255, 138, 43, 230), halo: RGBA8(255, 110, 20, 60))
        }
    }

    // MARK: text

    private static let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    static func format(_ date: Date, style: DateStyle = .dots, format: DateFormat = .own, time: Bool = false,
                       calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let y = c.year ?? 2000, m = c.month ?? 1, d = c.day ?? 1
        let yy = y % 100
        var s: String
        switch format {
        case .dmy: s = String(format: "%02d.%02d.%02d", d, m, yy)
        case .long: s = "\(months[max(0, min(11, m - 1))]) \(d) \(y)"
        case .own:
            switch style {
            case .dots: s = String(format: "%2d %2d '%02d", m, d, yy)
            case .quartz: s = String(format: "'%02d %02d %02d", yy, m, d)
            case .camcorder: s = String(format: "%02d/%02d/%d", m, d, y)
            case .lcd: s = String(format: "%d/%02d/%02d", y, m, d)
            case .stamp: s = "\(d) \(months[max(0, min(11, m - 1))]) \(y)"
            case .marker: s = "\(months[max(0, min(11, m - 1))].lowercased()) \(d) '" + String(format: "%02d", yy)
            case .edge: s = String(format: "%02d·%02d·%02d", yy, m, d)
            }
        }
        if time {
            let h = c.hour ?? 0, mi = c.minute ?? 0
            if style == .camcorder && format == .own {
                let h12 = h % 12 == 0 ? 12 : h % 12
                s += String(format: " %d:%02d %@", h12, mi, h < 12 ? "AM" : "PM")
            } else {
                s += String(format: " %02d:%02d", h, mi)
            }
        }
        return s
    }

    // MARK: glyph ROMs

    /// Roll's 5×7 masks, plus the punctuation the other formats need.
    static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["01110", "10001", "00001", "00110", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        "'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
        ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
        ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
        "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
    ]

    /// Which of the seven segments each digit lights: `a` top, clockwise `b c d e f`, `g` middle.
    static let segments: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg",
        "5": "acdfg", "6": "acdefg", "7": "abc", "8": "abcdefg", "9": "abcdfg",
    ]

    // MARK: runs of glyphs

    /// How a style draws one character, with the baseline at y = 0 and the glyph rising to −height.
    private struct Face {
        let style: DateStyle
        let height: CGFloat
        let ink: Ink

        var advance: CGFloat {
            switch style {
            case .dots: return height / 7 * 6
            case .quartz: return height * 0.55 * 1.34
            default: return 0
            }
        }

        func font() -> UIFont {
            switch style {
            case .camcorder: return XA.uiFont("SairaExtraCondensed-SemiBold", height * 1.45)
            case .lcd: return XA.uiFont("Silkscreen-Regular", height * 0.95)
            case .stamp: return XA.uiFont("BebasNeue-Regular", height * 1.3)
            case .marker: return XA.uiFont("Caveat-Bold", height * 1.35)
            case .edge: return XA.uiFont("ShareTechMono-Regular", height * 1.1)
            default: return XA.uiFont("ShareTechMono-Regular", height * 1.3)
            }
        }

        func width(of ch: Character) -> CGFloat {
            if style == .dots && DateBack.glyphs[ch] != nil { return advance }
            if style == .quartz && (DateBack.segments[ch] != nil || ch == "'" || ch == " " || ch == "." || ch == ":") { return advance }
            if style == .dots && ch == " " { return advance }
            let s = String(ch) as NSString
            return s.size(withAttributes: [.font: font()]).width
        }

        func width(of text: String) -> CGFloat {
            var w: CGFloat = 0
            for ch in text { w += width(of: ch) }
            return w
        }

        func draw(_ ch: Character, in ctx: CGContext) {
            if style == .dots, let rows = DateBack.glyphs[ch] { drawDots(rows, ctx); return }
            if style == .quartz, ch == " " { return }
            if style == .dots, ch == " " { return }
            if style == .quartz, DateBack.segments[ch] != nil || ch == "'" || ch == "." || ch == ":" { drawQuartz(ch, ctx); return }
            drawType(ch, ctx)
        }

        private func drawDots(_ rows: [String], _ ctx: CGContext) {
            let cell: CGFloat = height / 7
            let top: CGFloat = -7 * cell
            for (fill, spill) in [(ink.halo, cell * 0.22), (ink.lamp, CGFloat(0))] {
                ctx.setFillColor(fill.cg)
                for (r, bits) in rows.enumerated() {
                    let lean: CGFloat = CGFloat(rows.count - 1 - r) * cell * DateBack.slant
                    for (c, b) in bits.enumerated() where b == "1" {
                        let cx: CGFloat = CGFloat(c) * cell + lean + cell / 2
                        let cy: CGFloat = top + CGFloat(r) * cell + cell / 2
                        let rad: CGFloat = cell * DateBack.dot + spill
                        ctx.fillEllipse(in: CGRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2))
                    }
                }
            }
        }

        private func drawQuartz(_ ch: Character, _ ctx: CGContext) {
            let h = height
            let w: CGFloat = h * 0.55
            let t: CGFloat = w * 0.19
            let unit: CGFloat = h / 13
            let p = CGMutablePath()
            if ch == "'" {
                vbar(p, w * 0.42, -h, t, h * 0.24)
            } else if ch == "." {
                p.addRect(CGRect(x: w * 0.4, y: -t, width: t, height: t))
            } else if ch == ":" {
                p.addRect(CGRect(x: w * 0.4, y: -h * 0.3 - t / 2, width: t, height: t))
                p.addRect(CGRect(x: w * 0.4, y: -h * 0.7 - t / 2, width: t, height: t))
            } else if let on = DateBack.segments[ch] {
                let half: CGFloat = h / 2
                let nick: CGFloat = t * 0.5
                let across: CGFloat = w - t
                let run: CGFloat = half - t - nick
                if on.contains("a") { hbar(p, 0, -h, across, t) }
                if on.contains("g") { hbar(p, 0, -half - t / 2, across, t) }
                if on.contains("d") { hbar(p, 0, -t, across, t) }
                if on.contains("f") { vbar(p, 0, -h + t + nick, t, run) }
                if on.contains("b") { vbar(p, across, -h + t + nick, t, run) }
                if on.contains("e") { vbar(p, 0, -half + t * 0.5 + nick, t, run) }
                if on.contains("c") { vbar(p, across, -half + t * 0.5 + nick, t, run) }
            }
            ctx.saveGState()
            // One shear for the whole digit, about the baseline, so its feet stay put.
            ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: -0.11, d: 1, tx: 0, ty: 0))
            ctx.addPath(p)
            ctx.setFillColor(ink.halo.cg)
            ctx.setStrokeColor(ink.halo.cg)
            ctx.setLineWidth(unit * 0.9)
            ctx.drawPath(using: .fillStroke)
            ctx.addPath(p)
            ctx.setFillColor(ink.lamp.cg)
            ctx.fillPath()
            ctx.restoreGState()
        }

        private func hbar(_ p: CGMutablePath, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ t: CGFloat) {
            let m: CGFloat = t / 2
            p.move(to: CGPoint(x: x + m, y: y))
            p.addLine(to: CGPoint(x: x + w - m, y: y))
            p.addLine(to: CGPoint(x: x + w, y: y + m))
            p.addLine(to: CGPoint(x: x + w - m, y: y + t))
            p.addLine(to: CGPoint(x: x + m, y: y + t))
            p.addLine(to: CGPoint(x: x, y: y + m))
            p.closeSubpath()
        }

        private func vbar(_ p: CGMutablePath, _ x: CGFloat, _ y: CGFloat, _ t: CGFloat, _ h: CGFloat) {
            let m: CGFloat = t / 2
            p.move(to: CGPoint(x: x, y: y + m))
            p.addLine(to: CGPoint(x: x + m, y: y))
            p.addLine(to: CGPoint(x: x + t, y: y + m))
            p.addLine(to: CGPoint(x: x + t, y: y + h - m))
            p.addLine(to: CGPoint(x: x + m, y: y + h))
            p.addLine(to: CGPoint(x: x, y: y + h - m))
            p.closeSubpath()
        }

        private func drawType(_ ch: Character, _ ctx: CGContext) {
            let f = font()
            let s = String(ch) as NSString
            let origin = CGPoint(x: 0, y: -f.ascender)
            UIGraphicsPushContext(ctx)
            if style == .camcorder || style == .lcd {
                // Keyline pass under the fill, as a character generator drew it.
                let stroke: [NSAttributedString.Key: Any] = [.font: f, .strokeColor: ink.halo.ui, .strokeWidth: 22]
                s.draw(at: origin, withAttributes: stroke)
            }
            s.draw(at: origin, withAttributes: [.font: f, .foregroundColor: ink.lamp.ui])
            UIGraphicsPopContext()
        }
    }

    /// Straight run, baseline-left at `origin`.
    private static func drawRun(_ text: String, face: Face, origin: CGPoint, ctx: CGContext) {
        var x = origin.x
        for ch in text {
            ctx.saveGState()
            ctx.translateBy(x: x, y: origin.y)
            face.draw(ch, in: ctx)
            ctx.restoreGState()
            x += face.width(of: ch)
        }
    }

    /// Glyph by glyph along a path, centred on `fraction` of its length. Tops point left of travel.
    private static func drawAlong(_ text: String, face: Face, walker: PathWalker, fraction: CGFloat, ctx: CGContext) {
        let total = face.width(of: text)
        var s: CGFloat = walker.length * fraction - total / 2
        for ch in text {
            let w = face.width(of: ch)
            let p = walker.point(at: s + w / 2)
            ctx.saveGState()
            ctx.translateBy(x: p.position.x, y: p.position.y)
            ctx.rotate(by: p.angle)
            ctx.translateBy(x: -w / 2, y: 0)
            face.draw(ch, in: ctx)
            ctx.restoreGState()
            s += w
        }
    }

    // MARK: geometry

    /// Points on a circle from `a0` to `a1` degrees, y down, so 90° is the bottom.
    static func circleArc(center c: CGPoint, radius r: CGFloat, from a0: CGFloat, to a1: CGFloat, steps: Int = 180) -> [CGPoint] {
        (0...steps).map { i in
            let t: CGFloat = CGFloat(i) / CGFloat(steps)
            let a: CGFloat = (a0 + (a1 - a0) * t) * .pi / 180
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        }
    }

    static func cubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, steps: Int = 120) -> [CGPoint] {
        (0...steps).map { i in
            let t: CGFloat = CGFloat(i) / CGFloat(steps)
            let u: CGFloat = 1 - t
            let a: CGFloat = u * u * u, b: CGFloat = 3 * u * u * t, c: CGFloat = 3 * u * t * t, d: CGFloat = t * t * t
            let x: CGFloat = a * p0.x + b * p1.x + c * p2.x + d * p3.x
            let y: CGFloat = a * p0.y + b * p1.y + c * p2.y + d * p3.y
            return CGPoint(x: x, y: y)
        }
    }

    /// Glyph height each style uses on a frame this size, Roll's proportions.
    private static func height(_ style: DateStyle, _ size: CGSize) -> CGFloat {
        let short = min(size.width, size.height), long = max(size.width, size.height)
        switch style {
        case .dots: return max(1.5, short / 175 * scale) * 7
        case .quartz: return max(0.7, long / 720 * scale) * 13
        default: return long / 34 * scale * 0.72
        }
    }

    // MARK: drawing

    static func draw(in ctx: CGContext, size: CGSize, date: Date, config: DateConfig, shape: FrameShape, mono: Bool, instant: InstantKind = .none) {
        if instant != .none {
            drawInstant(ctx, size: size, date: date, config: config, kind: instant)
            return
        }
        guard config.placement != .off else { return }
        var ink = inkFor(config.style, mono: mono)
        if let c = config.color { ink.lamp = c }
        let text = format(date, style: config.style, format: config.format, time: config.time)
        let h = height(config.style, size)
        let face = Face(style: config.style, height: h, ink: ink)
        let frame = CGRect(origin: .zero, size: size)

        if shape != .none {
            // Inside a shape, the date has to stay on the picture.
            if config.placement == .follow, shape == .porthole {
                let d: CGFloat = min(size.width, size.height) * 0.92
                let r: CGFloat = d / 2 - h * 0.35 - d * 0.03
                let pts = circleArc(center: CGPoint(x: frame.midX, y: frame.midY), radius: r, from: 112, to: 18)
                decorate(face, ctx) { drawAlong(text, face: face, walker: PathWalker(points: pts), fraction: 0.5, ctx: ctx) }
                return
            }
            if config.placement == .follow, shape == .crush {
                // Up the right-hand curve, from the point toward the lobe, just inside the edge.
                let inset: CGFloat = 0.92 * 0.86
                func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { Shapes.heartPoint(x, y, in: frame, fill: inset) }
                let pts = cubic(P(50, 88), P(78, 66), P(98, 48), P(98, 28))
                decorate(face, ctx) { drawAlong(text, face: face, walker: PathWalker(points: pts), fraction: 0.42, ctx: ctx) }
                return
            }
            let box = shape.path(in: frame)?.boundingBox ?? frame
            let w = face.width(of: text)
            let origin = CGPoint(x: box.midX - w / 2, y: box.maxY - box.height * 0.08)
            decorate(face, ctx) { drawRun(text, face: face, origin: origin, ctx: ctx) }
            return
        }

        // The corner, with Roll's insets.
        let w = face.width(of: text)
        var origin: CGPoint
        switch config.style {
        case .dots:
            let cell = h / 7
            let over: CGFloat = 6 * cell * slant
            origin = CGPoint(x: size.width - cell * 8 - w - over, y: size.height - cell * 8)
        case .quartz:
            let unit = h / 13
            origin = CGPoint(x: size.width - unit * 16 - w - h * 0.11, y: size.height - unit * 16)
        case .edge:
            drawEdge(text, face: face, size: size, ctx: ctx)
            return
        default:
            let pad: CGFloat = h * 0.9
            origin = CGPoint(x: size.width - pad - w, y: size.height - pad)
        }
        decorate(face, ctx) { drawRun(text, face: face, origin: origin, ctx: ctx) }
    }

    /// Stamp and marker are objects on the picture: a boxed, crooked rubber stamp and a strip of tape.
    private static func decorate(_ face: Face, _ ctx: CGContext, _ body: () -> Void) {
        switch face.style {
        case .stamp, .marker:
            // Drawn inside a transparency layer so the box and the tape tilt with the text.
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            body()
            ctx.endTransparencyLayer()
        default:
            body()
        }
    }

    private static func drawEdge(_ text: String, face: Face, size: CGSize, ctx: CGContext) {
        let full = "▸ 24  XA  " + text + "  ▸ 24A"
        let w = face.width(of: full)
        ctx.saveGState()
        ctx.translateBy(x: face.height * 1.3, y: size.height / 2 + w / 2)
        ctx.rotate(by: -.pi / 2)
        drawRun(full, face: face, origin: .zero, ctx: ctx)
        ctx.restoreGState()
    }

    /// Instant prints get the date written by hand on the frame, and nothing else.
    private static func drawInstant(_ ctx: CGContext, size: CGSize, date: Date, config: DateConfig, kind: InstantKind) {
        guard config.placement != .off else { return }
        let border = Shapes.instantBorder(paper: size, kind: kind)
        let m: CGFloat = border.height * 0.28
        let f = XA.uiFont("Caveat-Bold", border.height * 0.34)
        let text = format(date, style: .marker, format: config.format == .own ? .own : config.format, time: false) as NSString
        let w = text.size(withAttributes: [.font: f]).width
        ctx.saveGState()
        ctx.translateBy(x: border.maxX - m * 1.3 - w, y: border.midY - f.lineHeight / 2)
        ctx.rotate(by: -0.05)
        UIGraphicsPushContext(ctx)
        text.draw(at: .zero, withAttributes: [.font: f, .foregroundColor: UIColor(white: 0.1, alpha: 0.9)])
        UIGraphicsPopContext()
        ctx.restoreGState()
    }

    // MARK: images

    /// The date on a clear image the size of the frame, or nil when there is nothing to draw.
    static func overlay(size: CGSize, date: Date, config: DateConfig, shape: FrameShape, mono: Bool, instant: InstantKind = .none) -> CGImage? {
        guard config.placement != .off, size.width >= 8, size.height >= 8 else { return nil }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { r in
            let ctx = r.cgContext
            if config.style == .marker && instant == .none { drawTape(ctx, size: size, date: date, config: config, shape: shape, mono: mono) }
            if config.style == .stamp && instant == .none { drawStamp(ctx, size: size, date: date, config: config, shape: shape) }
            else if config.style != .marker || instant != .none {
                draw(in: ctx, size: size, date: date, config: config, shape: shape, mono: mono, instant: instant)
            }
        }
        return img.cgImage
    }

    private static let cacheLock = NSLock()
    private static var cacheKey = ""
    private static var cached: CIImage?

    /// CIImage version, cached: the viewfinder asks for the same overlay thirty times a second.
    static func overlayImage(size: CGSize, date: Date, config: DateConfig, shape: FrameShape, mono: Bool, instant: InstantKind) -> CIImage? {
        guard config.placement != .off || instant != .none else { return nil }
        let text = format(date, style: config.style, format: config.format, time: config.time)
        let key = "\(Int(size.width))x\(Int(size.height))|\(text)|\(config.style)|\(config.placement)|\(config.color?.r ?? -1)\(config.color?.g ?? -1)\(config.color?.b ?? -1)|\(shape.rawValue)|\(mono)|\(instant)"
        cacheLock.lock()
        if key == cacheKey, let c = cached { cacheLock.unlock(); return c }
        cacheLock.unlock()
        var cfg = config
        if instant != .none && cfg.placement == .off { cfg.placement = .corner }
        guard let cg = overlay(size: size, date: date, config: cfg, shape: shape, mono: mono, instant: instant) else { return nil }
        var img = CIImage(cgImage: cg)
        if cfg.style == .camcorder { img = videoResolution(img) }
        cacheLock.lock(); cacheKey = key; cached = img; cacheLock.unlock()
        return img
    }

    /// A camcorder's character generator drew at about broadcast resolution: the date goes down
    /// to roughly 720 lines and back up, just soft enough to lose the crisp vector edge.
    static func videoResolution(_ img: CIImage) -> CIImage {
        let e = img.extent
        let short = min(e.width, e.height)
        guard short > 800 else { return img }
        let k: CGFloat = 720 / short
        let down = CIFilter.lanczosScaleTransform()
        down.inputImage = img
        down.scale = Float(k)
        down.aspectRatio = 0.9
        guard let small = down.outputImage else { return img }
        let smear = CIFilter.boxBlur()
        smear.inputImage = small.clampedToExtent()
        smear.radius = 0.6
        let soft = (smear.outputImage ?? small).cropped(to: small.extent)
        let sx = e.width / small.extent.width, sy = e.height / small.extent.height
        return soft.samplingLinear()
            .transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .cropped(to: e)
    }

    // MARK: stamp and tape

    private static func anchor(_ size: CGSize, _ shape: FrameShape, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        let frame = CGRect(origin: .zero, size: size)
        if shape != .none, let box = shape.path(in: frame)?.boundingBox {
            return CGPoint(x: box.midX, y: box.maxY - box.height * 0.12)
        }
        return CGPoint(x: size.width - w / 2 - h * 1.2, y: size.height - h * 1.6)
    }

    private static func drawStamp(_ ctx: CGContext, size: CGSize, date: Date, config: DateConfig, shape: FrameShape) {
        let h = height(.stamp, size)
        var ink = inkFor(.stamp, mono: false)
        if let c = config.color { ink.lamp = c }
        let f = XA.uiFont("BebasNeue-Regular", h * 1.3)
        let text = format(date, style: .stamp, format: config.format, time: config.time) as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: ink.lamp.ui, .kern: h * 0.12]
        let ts = text.size(withAttributes: attrs)
        let pad: CGFloat = h * 0.3
        let box = CGSize(width: ts.width + pad * 2, height: ts.height)
        let c = anchor(size, shape, box.width, h)
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: -7 * .pi / 180)
        ctx.setStrokeColor(ink.lamp.cg)
        ctx.setLineWidth(max(1.5, h * 0.12))
        ctx.stroke(CGRect(x: -box.width / 2, y: -box.height / 2, width: box.width, height: box.height))
        UIGraphicsPushContext(ctx)
        text.draw(at: CGPoint(x: -ts.width / 2, y: -ts.height / 2), withAttributes: attrs)
        UIGraphicsPopContext()
        ctx.restoreGState()
    }

    private static func drawTape(_ ctx: CGContext, size: CGSize, date: Date, config: DateConfig, shape: FrameShape, mono: Bool) {
        let h = height(.marker, size)
        let ink = inkFor(.marker, mono: mono)
        let f = XA.uiFont("Caveat-Bold", h * 1.35)
        let text = format(date, style: .marker, format: config.format, time: config.time) as NSString
        let ts = text.size(withAttributes: [.font: f])
        let tape = CGSize(width: ts.width + h * 1.4, height: ts.height + h * 0.3)
        let c = anchor(size, shape, tape.width, h)
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: -4 * .pi / 180)
        // Torn ends: a zigzag down each short side.
        let p = CGMutablePath()
        let x0: CGFloat = -tape.width / 2, x1: CGFloat = tape.width / 2
        let y0: CGFloat = -tape.height / 2, y1: CGFloat = tape.height / 2
        let teeth = 6
        p.move(to: CGPoint(x: x0, y: y0))
        p.addLine(to: CGPoint(x: x1, y: y0))
        for i in 0...teeth {
            let y: CGFloat = y0 + tape.height * CGFloat(i) / CGFloat(teeth)
            let dx: CGFloat = i % 2 == 0 ? 0 : -h * 0.18
            p.addLine(to: CGPoint(x: x1 + dx, y: y))
        }
        p.addLine(to: CGPoint(x: x0, y: y1))
        for i in stride(from: teeth, through: 0, by: -1) {
            let y: CGFloat = y0 + tape.height * CGFloat(i) / CGFloat(teeth)
            let dx: CGFloat = i % 2 == 0 ? 0 : h * 0.18
            p.addLine(to: CGPoint(x: x0 + dx, y: y))
        }
        p.closeSubpath()
        ctx.setShadow(offset: CGSize(width: 0, height: h * 0.05), blur: h * 0.15, color: UIColor(white: 0, alpha: 0.25).cgColor)
        ctx.addPath(p)
        ctx.setFillColor(ink.halo.cg)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        UIGraphicsPushContext(ctx)
        let color = config.color?.ui ?? ink.lamp.ui
        text.draw(at: CGPoint(x: -ts.width / 2, y: -ts.height / 2), withAttributes: [.font: f, .foregroundColor: color])
        UIGraphicsPopContext()
        ctx.restoreGState()
    }
}
