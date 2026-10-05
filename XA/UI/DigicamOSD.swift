import SwiftUI

/// DIGI's screen, the way a 2005 pocket digicam filled its LCD: thick white rounded type with
/// a hard black keyline all round, white line icons keylined the same way, cyan button hints,
/// and a lot of junk, every piece of it live. Laid out on a 390-point-wide finder and scaled.
struct DigicamOSD: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @AppStorage("digiFileNo") private var fileNo = 1
    @State private var battery: Float = -1
    @State private var free: Int64 = 0

    var body: some View {
        GeometryReader { g in
            let k = max(0.6, g.size.width / 390)
            ZStack {
                topRow(k)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 11 * k).padding(.top, 9 * k)
                leftColumn(k)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 11 * k).padding(.top, 44 * k)
                rightColumn(k)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 11 * k).padding(.top, 42 * k)
                AFMark(halfPressed: camera.halfPressed, show: camera.focusPoint == nil || camera.halfPressed, k: k)
                if camera.meterShutter > 1.0 / 30 {
                    Blinking(period: 0.5) { Icon.hand.view(k: k, size: 22, color: OSD.yellow) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.leading, 11 * k).padding(.top, 60 * k)
                }
                if camera.halfPressed {
                    OSDText("F\(String(format: "%.1f", camera.aperture))   \(DigiOSD.shutter(camera.meterShutter))", 17 * k)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, 64 * k).padding(.bottom, 58 * k)
                }
                bottom(k)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 11 * k).padding(.bottom, 8 * k)
                // the LCD's own lines, faint
                Scanlines().opacity(0.06)
            }
        }
        .modifier(Wake(axis: .vertical))
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            refresh()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in refresh() }
        .onChange(of: camera.lastShot) { _, _ in fileNo += 1; refresh() }
    }

    // MARK: rows

    private func topRow(_ k: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 5 * k) {
                if battery >= 0 && battery < 0.15 {
                    Blinking(period: 0.5) { BatteryIcon(level: battery, k: k) }
                } else {
                    BatteryIcon(level: battery, k: k)
                }
                HStack(alignment: .lastTextBaseline, spacing: 1 * k) {
                    OSDText(minutes, 16 * k)
                    OSDText("min", 11 * k)
                }
            }
            Spacer(minLength: 4 * k)
            HStack(alignment: .center, spacing: 6 * k) {
                Icon.camera.view(k: k, size: 19)
                OSDText("\(settings.digiMegapixels)M", 15 * k)
                OSDText(settings.crunch >= 0.7 ? "FINE" : "STD", 12 * k)
            }
            Spacer(minLength: 4 * k)
            HStack(alignment: .center, spacing: 6 * k) {
                OSDText("101", 12 * k)
                    .padding(.horizontal, 3 * k).padding(.vertical, 0.5 * k)
                    .background(OutlinedBox(k: k))
                OSDText("\(shotsLeft)", 16 * k)
                CardIcon(saving: camera.developing > 0, k: k)
            }
        }
    }

    private func leftColumn(_ k: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * k) {
            HStack(spacing: 3 * k) {
                (settings.flash == .off ? Icon.flashOff : Icon.flash).view(k: k, size: 15)
                if settings.flash == .auto { OSDText("AUTO", 10 * k) }
            }
            if camera.zoom * camera.zoomMultiplier < 0.95 { Icon.macro.view(k: k, size: 15) }
            Icon.sun.view(k: k, size: 16)
            OSDText(camera.meterISO > 0 ? "ISO \(isoLabel)" : "ISO AUTO", 10.5 * k)
            OSDText(camera.ev == 0 ? "±0.0EV" : String(format: "%+.1fEV", camera.ev), 10.5 * k)
        }
    }

    private func rightColumn(_ k: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 6 * k) {
            Histo(bins: camera.histogram).frame(width: 58 * k, height: 22 * k)
            VStack(spacing: 3 * k) {
                OSDText("W", 10 * k)
                ZoomBar(fraction: zoomFraction, optical: opticalFraction, k: k).frame(width: 7 * k, height: 74 * k)
                OSDText("T", 10 * k)
            }
            .padding(.trailing, 2 * k)
            OSDText(String(format: "%.1f×", camera.zoom * camera.zoomMultiplier), 11 * k)
        }
    }

    private func bottom(_ k: CGFloat) -> some View {
        VStack(spacing: 6 * k) {
            HStack(spacing: 20 * k) {
                OSDText("◀▶ SIM", 10.5 * k, color: OSD.cyan, edge: OSD.cyanEdge)
                OSDText("▲ ROLL", 10.5 * k, color: OSD.cyan, edge: OSD.cyanEdge)
            }
            TimelineView(.everyMinute) { t in
                HStack(alignment: .lastTextBaseline) {
                    OSDText("101-" + String(format: "%04d", fileNo % 10000), 14 * k)
                    Spacer()
                    OSDText(Self.day(t.date), 14 * k)
                    Spacer()
                    HStack(alignment: .lastTextBaseline, spacing: 1 * k) {
                        OSDText(Self.clock(t.date), 14 * k)
                        OSDText(Self.half(t.date), 10 * k)
                    }
                }
            }
        }
    }

    // MARK: live values

    /// The phone's battery as an InfoLithium would report it: minutes, in fives.
    private var minutes: String {
        guard battery >= 0 else { return "--" }
        return "\(Int((battery * 120 / 5).rounded()) * 5)"
    }
    /// Shots that still fit, from the phone's free space and DIGI's photo size.
    private var shotsLeft: Int {
        let per = Int64(max(1, settings.digiMegapixels)) * 420_000
        return free > 0 ? Int(min(9999, free / per)) : 0
    }
    private var isoLabel: String {
        let iso = max(camera.meterISO, 1)
        let steps: [Float] = [100, 200, 400, 800, 1600, 3200]
        return "\(Int(steps.min { abs(log2($0 / iso)) < abs(log2($1 / iso)) } ?? 100))"
    }
    private var zoomFraction: CGFloat {
        let z = Double(camera.zoom * camera.zoomMultiplier)
        return CGFloat(min(1, max(0, log(z / 0.5) / log(20))))
    }
    private var opticalFraction: CGFloat {
        let top = Double(camera.lenses.map { $0.factor }.max() ?? 1)
        return CGFloat(min(1, max(0, log(top / 0.5) / log(20))))
    }

    private func refresh() {
        battery = UIDevice.current.batteryLevel
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let c = v.volumeAvailableCapacityForImportantUsage { free = c }
    }

    static func day(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 2005)  \(c.month ?? 1)  \(c.day ?? 1)"
    }
    static func clock(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        let h = c.hour ?? 0
        return String(format: "%d:%02d", h % 12 == 0 ? 12 : h % 12, c.minute ?? 0)
    }
    static func half(_ d: Date) -> String { (Calendar.current.component(.hour, from: d) < 12) ? "AM" : "PM" }
}

// MARK: - the look

enum OSD {
    static let font = "MPLUSRounded1c-ExtraBold"
    static let white = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let cyan = Color(red: 0.37, green: 0.84, blue: 1)
    static let cyanEdge = Color(red: 0, green: 0.2, blue: 0.3)
    static let yellow = Color(red: 1, green: 0.81, blue: 0.18)
    static let green = Color(red: 0.22, green: 0.88, blue: 0.35)
    static let red = Color(red: 1, green: 0.3, blue: 0.25)
}

/// Type the way the LCD drew it: a hard keyline all the way round (eight copies of the text in
/// black under the white one), not a soft shadow.
struct OSDText: View {
    let text: String
    let size: CGFloat
    var color: Color = OSD.white
    var edge: Color = .black
    init(_ text: String, _ size: CGFloat, color: Color = OSD.white, edge: Color = .black) {
        self.text = text; self.size = size; self.color = color; self.edge = edge
    }
    var body: some View {
        let w = max(1, size * 0.09)
        let t = Text(text).font(.custom(OSD.font, fixedSize: size)).kerning(size * 0.02)
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * .pi / 4
                t.foregroundStyle(edge).offset(x: CGFloat(cos(a)) * w, y: CGFloat(sin(a)) * w + w * 0.35)
            }
            t.foregroundStyle(color)
        }
        .fixedSize()
    }
}

/// Line icons drawn as paths, keylined like the type.
enum Icon {
    case camera, flash, flashOff, macro, sun, hand

    func view(k: CGFloat, size: CGFloat, color: Color = OSD.white) -> some View {
        Keylined(color: color, line: 1.9 * k) { p(in: CGRect(x: 0, y: 0, width: size * k, height: size * k)) }
            .frame(width: size * k, height: size * k)
    }

    /// Paths in a square; filled parts are closed and filled.
    func p(in r: CGRect) -> (stroke: Path, fill: Path) {
        let w = r.width, h = r.height
        var s = Path(), f = Path()
        switch self {
        case .camera:
            s.addRoundedRect(in: CGRect(x: w * 0.06, y: h * 0.3, width: w * 0.88, height: h * 0.58), cornerSize: CGSize(width: w * 0.08, height: w * 0.08))
            f.addRect(CGRect(x: w * 0.32, y: h * 0.14, width: w * 0.32, height: h * 0.18))
            s.addEllipse(in: CGRect(x: w * 0.36, y: h * 0.42, width: w * 0.28, height: w * 0.28))
        case .flash, .flashOff:
            f.move(to: CGPoint(x: w * 0.58, y: 0)); f.addLine(to: CGPoint(x: w * 0.12, y: h * 0.58))
            f.addLine(to: CGPoint(x: w * 0.46, y: h * 0.58)); f.addLine(to: CGPoint(x: w * 0.36, y: h))
            f.addLine(to: CGPoint(x: w * 0.88, y: h * 0.36)); f.addLine(to: CGPoint(x: w * 0.54, y: h * 0.36)); f.closeSubpath()
            if self == .flashOff { s.move(to: CGPoint(x: w * 0.05, y: h * 0.05)); s.addLine(to: CGPoint(x: w * 0.95, y: h * 0.95)) }
        case .macro:
            s.move(to: CGPoint(x: w * 0.5, y: h)); s.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
            s.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.1), control: CGPoint(x: w * 0.1, y: h * 0.5))
            s.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.5), control: CGPoint(x: w * 0.45, y: h * 0.15))
            s.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.1), control: CGPoint(x: w * 0.55, y: h * 0.15))
            s.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.5), control: CGPoint(x: w * 0.9, y: h * 0.5))
        case .sun:
            f.addEllipse(in: CGRect(x: w * 0.3, y: h * 0.3, width: w * 0.4, height: h * 0.4))
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4
                s.move(to: CGPoint(x: w / 2 + cos(a) * w * 0.32, y: h / 2 + sin(a) * h * 0.32))
                s.addLine(to: CGPoint(x: w / 2 + cos(a) * w * 0.47, y: h / 2 + sin(a) * h * 0.47))
            }
        case .hand:
            // a raised hand with shake marks
            f.move(to: CGPoint(x: w * 0.3, y: h * 0.95))
            f.addLine(to: CGPoint(x: w * 0.3, y: h * 0.42))
            for (x, top) in [(0.3, 0.22), (0.44, 0.08), (0.58, 0.1), (0.72, 0.2)] as [(CGFloat, CGFloat)] {
                f.addLine(to: CGPoint(x: w * x, y: h * top)); f.addLine(to: CGPoint(x: w * (x + 0.1), y: h * top))
                f.addLine(to: CGPoint(x: w * (x + 0.1), y: h * 0.45))
            }
            f.addLine(to: CGPoint(x: w * 0.82, y: h * 0.62)); f.addLine(to: CGPoint(x: w * 0.98, y: h * 0.5))
            f.addLine(to: CGPoint(x: w * 0.86, y: h * 0.82)); f.addLine(to: CGPoint(x: w * 0.7, y: h * 0.95)); f.closeSubpath()
            for y in [0.3, 0.5, 0.7] as [CGFloat] {
                s.move(to: CGPoint(x: 0, y: h * y)); s.addLine(to: CGPoint(x: w * 0.16, y: h * (y + 0.04)))
            }
        }
        return (s, f)
    }
}

/// A path drawn white over a thicker black copy of itself: the keyline.
struct Keylined: View {
    let color: Color
    let line: CGFloat
    let paths: () -> (stroke: Path, fill: Path)
    init(color: Color, line: CGFloat, _ paths: @escaping () -> (stroke: Path, fill: Path)) {
        self.color = color; self.line = line; self.paths = paths
    }
    var body: some View {
        let (s, f) = paths()
        let style = StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
        let edge = StrokeStyle(lineWidth: line + 2.6, lineCap: .round, lineJoin: .round)
        ZStack {
            s.stroke(Color.black, style: edge)
            f.stroke(Color.black, style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
            f.fill(Color.black)
            s.stroke(color, style: style)
            f.fill(color)
        }
    }
}

/// Shows its content on and off, on its own clock (only it redraws).
struct Blinking<Content: View>: View {
    let period: Double
    @ViewBuilder var content: () -> Content
    var body: some View {
        TimelineView(.periodic(from: .now, by: period)) { t in
            content().opacity(Int(t.date.timeIntervalSinceReferenceDate / period) % 2 == 0 ? 1 : 0.15)
        }
    }
}

private struct OutlinedBox: View {
    let k: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5 * k).stroke(Color.black, lineWidth: 4 * k)
            RoundedRectangle(cornerRadius: 2.5 * k).stroke(OSD.white, lineWidth: 1.7 * k)
        }
    }
}

private struct BatteryIcon: View {
    let level: Float
    let k: CGFloat
    var body: some View {
        let w = 25 * k, h = 13 * k
        Keylined(color: level >= 0 && level < 0.15 ? OSD.red : OSD.white, line: 1.8 * k) {
            var s = Path(), f = Path()
            s.addRoundedRect(in: CGRect(x: 1, y: 1, width: w * 0.84, height: h - 2), cornerSize: CGSize(width: h * 0.22, height: h * 0.22))
            f.addRect(CGRect(x: w * 0.86, y: h * 0.32, width: w * 0.1, height: h * 0.36))
            let lv = CGFloat(level < 0 ? 1 : max(0.05, level))
            f.addRect(CGRect(x: w * 0.1, y: h * 0.27, width: w * 0.66 * lv, height: h * 0.46))
            return (s, f)
        }
        .frame(width: w, height: h)
    }
}

private struct CardIcon: View {
    let saving: Bool
    let k: CGFloat
    var body: some View {
        let w = 14 * k, h = 19 * k
        let icon = { (c: Color) in
            Keylined(color: c, line: 1.8 * k) {
                var s = Path(), f = Path()
                s.move(to: CGPoint(x: 1, y: 1)); s.addLine(to: CGPoint(x: w * 0.64, y: 1)); s.addLine(to: CGPoint(x: w - 1, y: h * 0.3))
                s.addLine(to: CGPoint(x: w - 1, y: h - 1)); s.addLine(to: CGPoint(x: 1, y: h - 1)); s.closeSubpath()
                f.addRect(CGRect(x: w * 0.24, y: h * 0.12, width: w * 0.1, height: h * 0.22))
                f.addRect(CGRect(x: w * 0.44, y: h * 0.12, width: w * 0.1, height: h * 0.22))
                return (s, f)
            }
            .frame(width: w, height: h)
        }
        if saving { Blinking(period: 0.25) { icon(OSD.red) } } else { icon(OSD.white) }
    }
}

private struct AFMark: View {
    let halfPressed: Bool
    let show: Bool
    let k: CGFloat
    var body: some View {
        let w = 46 * k, h = 38 * k
        ZStack {
            if halfPressed {
                Rectangle().stroke(Color.black, lineWidth: 5 * k).frame(width: w, height: h)
                Rectangle().stroke(OSD.green, lineWidth: 2.6 * k).frame(width: w, height: h)
            } else if show {
                Keylined(color: OSD.white, line: 2.2 * k) {
                    var s = Path()
                    let l = w * 0.24
                    for (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                        s.move(to: CGPoint(x: x + l * dx, y: y)); s.addLine(to: CGPoint(x: x, y: y)); s.addLine(to: CGPoint(x: x, y: y + l * dy))
                    }
                    return (s, Path())
                }
                .frame(width: w, height: h)
            }
            Keylined(color: OSD.white, line: 1.6 * k) {
                var s = Path()
                let c = 6 * k
                s.move(to: CGPoint(x: c, y: 0)); s.addLine(to: CGPoint(x: c, y: c * 2))
                s.move(to: CGPoint(x: 0, y: c)); s.addLine(to: CGPoint(x: c * 2, y: c))
                return (s, Path())
            }
            .frame(width: 12 * k, height: 12 * k)
        }
    }
}

private struct Histo: View {
    let bins: [Float]
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(Color.black.opacity(0.4))
                Rectangle().stroke(Color.white.opacity(0.75), lineWidth: 1)
                if !bins.isEmpty {
                    Path { p in
                        let n = bins.count, w = (g.size.width - 3) / CGFloat(n), hh = g.size.height - 3
                        for (i, b) in bins.enumerated() {
                            let bh = max(0.5, CGFloat(b) * hh)
                            p.addRect(CGRect(x: 1.5 + CGFloat(i) * w, y: g.size.height - 1.5 - bh, width: w * 0.85, height: bh))
                        }
                    }
                    .fill(Color.white.opacity(0.9))
                }
            }
        }
    }
}

private struct ZoomBar: View {
    let fraction: CGFloat
    let optical: CGFloat
    let k: CGFloat
    var body: some View {
        GeometryReader { g in
            let h = g.size.height, w = g.size.width
            ZStack(alignment: .bottom) {
                Rectangle().stroke(Color.black, lineWidth: 4 * k)
                Rectangle().stroke(OSD.white, lineWidth: 1.6 * k)
                // the digital part of the range, shaded
                Rectangle().fill(Color.white.opacity(0.28)).frame(width: w - 3 * k, height: h * (1 - optical))
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, 1.5 * k)
                Rectangle().fill(OSD.white).frame(width: w - 3 * k, height: max(2, (h - 3 * k) * fraction)).padding(.bottom, 1.5 * k)
            }
        }
    }
}

private struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            var p = Path()
            while y < size.height { p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += 3 }
            ctx.fill(p, with: .color(.black))
        }
        .allowsHitTesting(false)
    }
}
