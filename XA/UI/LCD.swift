import SwiftUI

/// The small screen under the viewfinder. It is the one part of the camera that changes with
/// the mode: a green dot-matrix LCD in DIGI, a blue backlit segment panel in PRO, an amber
/// camcorder panel in VIDEO. Switching modes slides the old one out and powers the new one on.
struct LCDStrip: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        ZStack {
            switch camera.mode {
            case .digi: DigiLCD(camera: camera, settings: settings).transition(Self.swap)
            case .pro: ProLCD(camera: camera).transition(Self.swap)
            case .video: VideoLCD(camera: camera).transition(Self.swap)
            }
        }
        .frame(height: 36)
        .padding(3)
        .background(Color(white: 0.025))
        .clipped()
        .animation(.easeInOut(duration: 0.26), value: camera.mode)
        .accessibilityElement(children: .combine)
    }

    static let swap: AnyTransition = .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.12).delay(0.22)),
                                                 removal: .move(edge: .leading).combined(with: .opacity))
}

// MARK: panels

/// Old green reflective LCD: no backlight, faint pixel grid, glare.
private struct GreenPanel: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: "#AAB697"), Color(hex: "#96A382")], startPoint: .top, endPoint: .bottom)
            .overlay(PixelGrid(alpha: 0.04))
            .overlay(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .center))
            .overlay(Rectangle().strokeBorder(Color.black.opacity(0.3), lineWidth: 1))
    }
}

/// Backlit panel: bright in the middle, falling off at the edges, glowing past its frame.
private struct LitPanel: View {
    let center: Color, mid: Color, edge: Color, glow: Color
    var body: some View {
        RadialGradient(colors: [center, mid, edge], center: UnitPoint(x: 0.46, y: 0.38), startRadius: 0, endRadius: 220)
            .overlay(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .center))
            .overlay(Rectangle().strokeBorder(Color.black.opacity(0.3), lineWidth: 1))
            .shadow(color: glow, radius: 8)
    }
}

private struct PixelGrid: View {
    let alpha: Double
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            var y: CGFloat = 0
            while y < size.height { p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += 3 }
            ctx.fill(p, with: .color(.black.opacity(alpha)))
        }
        .allowsHitTesting(false)
    }
}

// MARK: DIGI

private struct DigiLCD: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    private let ink = Color(hex: "#1B2216")

    var body: some View {
        let sim = FilmCatalog.sim(camera.stack.simID) ?? Sim.neutral
        let flash = settings.flash == .on ? "F ON" : (settings.flash == .auto ? "F A" : "F OFF")
        let look = camera.stack.look == .none ? "" : camera.stack.look.title
        let shape = camera.stack.effectiveShape?.title ?? ""
        let extra = [look, shape].filter { !$0.isEmpty }.joined(separator: " + ")
        GreenPanel()
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        dot(">" + sim.title, 9)
                        Spacer()
                        dot("\(settings.digiMegapixels)M", 9)
                    }
                    HStack {
                        dot(extra.isEmpty ? flash : flash + "  " + extra, 11)
                        Spacer()
                        if settings.date.placement != .off { dot(Self.dateText(), 11) }
                    }
                }
                .padding(.horizontal, 8)
                .modifier(ColdWake())
            }
    }

    private func dot(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(.custom("Silkscreen-Regular", fixedSize: size)).foregroundStyle(ink)
            .shadow(color: Color(red: 0.09, green: 0.13, blue: 0.05).opacity(0.25), radius: 0, x: 1.2, y: 1.2)
            .lineLimit(1).minimumScaleFactor(0.6)
    }

    static func dateText() -> String {
        let f = DateFormatter(); f.dateFormat = "''yy MM dd"
        return f.string(from: Date())
    }
}

// MARK: PRO

private struct ProLCD: View {
    @ObservedObject var camera: CameraModel
    private let ink = Color(hex: "#0A2430"), off = Color(red: 0.04, green: 0.14, blue: 0.19).opacity(0.08), shade = Color(red: 0, green: 0.24, blue: 0.31).opacity(0.22)

    var body: some View {
        let mode = camera.shutterIndex == nil ? "P" : (camera.isoIndex == nil ? "S" : "M")
        let d = camera.meterShutter
        let shutter = d >= 1 ? "\(Int(d.rounded()))\"" : "\(Int((1 / max(d, 0.0001)).rounded()))"
        let ev = camera.ev
        let evText = (ev < 0 ? "-" : "") + String(format: "%.1f", abs(ev))
        LitPanel(center: Color(hex: "#D4F8FF"), mid: Color(hex: "#9FE6F2"), edge: Color(hex: "#6FC9DC"), glow: Color(red: 0.47, green: 0.84, blue: 1).opacity(0.5))
            .overlay(alignment: .leading) {
                HStack(alignment: .center, spacing: 10) {
                    SevenSeg(text: mode, height: 20, on: ink, off: off, shade: shade)
                        .padding(2).overlay(Rectangle().strokeBorder(ink.opacity(0.45), lineWidth: 1))
                    SevenSeg(text: shutter, height: 22, on: ink, off: off, shade: shade)
                    label("F", 8)
                    SevenSeg(text: "1.8", height: 11, on: ink, off: off, shade: shade).offset(x: -8)
                    label("ISO", 8).offset(x: -6)
                    SevenSeg(text: "\(Int(camera.meterISO.rounded()))", height: 15, on: ink, off: off, shade: shade).offset(x: -12)
                    SevenSeg(text: evText, height: 12, on: ink, off: off, shade: shade).offset(x: -12)
                    Spacer(minLength: 0)
                    Histo(bins: camera.histogram, ink: ink).frame(width: 60, height: 22)
                }
                .padding(.horizontal, 8)
                .modifier(SlideWake())
            }
            .modifier(PowerOn())
    }

    private func label(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(.custom("IBMPlexSansCond-Bold", fixedSize: size)).foregroundStyle(ink)
            .shadow(color: shade, radius: 0, x: 1.1, y: 1.1)
    }
}

private struct Histo: View {
    let bins: [Float]
    let ink: Color
    var body: some View {
        Canvas { ctx, size in
            guard !bins.isEmpty else { return }
            let n = min(bins.count, 30)
            let step = bins.count / n
            let w = size.width / CGFloat(n)
            for i in 0..<n {
                let v = CGFloat(bins[min(bins.count - 1, i * step)])
                let h = max(1, v * size.height)
                ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: size.height - h, width: max(1, w - 1), height: h)), with: .color(ink))
            }
        }
    }
}

// MARK: VIDEO

private struct VideoLCD: View {
    @ObservedObject var camera: CameraModel
    private let ink = Color(hex: "#2A1406"), off = Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.08), shade = Color(red: 0.35, green: 0.16, blue: 0).opacity(0.25)

    var body: some View {
        let t = Int(camera.recordSeconds)
        let counter = "\(t / 3600):" + String(format: "%02d:%02d", (t / 60) % 60, t % 60)
        let fps = Int(camera.videoLook.heldFPS ?? 30)
        LitPanel(center: Color(hex: "#FFE9BD"), mid: Color(hex: "#FFC86F"), edge: Color(hex: "#E59A3E"), glow: Color(red: 1, green: 0.67, blue: 0.27).opacity(0.5))
            .overlay(alignment: .leading) {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle().fill(camera.recording ? ink : off).frame(width: 7, height: 7)
                        label(camera.recording ? "REC" : "STBY", 9)
                    }
                    .phaseAnimator(camera.recording ? [1.0, 0.25] : [1.0]) { v, a in v.opacity(a) } animation: { _ in .easeInOut(duration: 0.5) }
                    SevenSeg(text: counter, height: 18, on: ink, off: off, shade: shade)
                    VStack(alignment: .leading, spacing: 1) {
                        label(camera.videoLook.title, 9)
                        label("SP · \(fps)P", 8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .modifier(SlideWake())
            }
            .modifier(PowerOn())
    }

    private func label(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(.custom("IBMPlexSansCond-Bold", fixedSize: size)).foregroundStyle(ink)
            .shadow(color: shade, radius: 0, x: 1.1, y: 1.1).lineLimit(1)
    }
}

// MARK: waking up

/// A backlight coming on: a few uneven flickers, then steady.
private struct PowerOn: ViewModifier {
    @State private var go = false
    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 0.0, trigger: go) { view, b in
                view.brightness(b).saturation(1 + b)
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(-0.7)
                    LinearKeyframe(0.25, duration: 0.05)
                    LinearKeyframe(-0.6, duration: 0.05)
                    LinearKeyframe(0.12, duration: 0.07)
                    LinearKeyframe(-0.45, duration: 0.05)
                    LinearKeyframe(0.2, duration: 0.1)
                    LinearKeyframe(0, duration: 0.25)
                }
            }
            .onAppear { go.toggle() }
    }
}

/// The new readings slide in once the backlight is up.
private struct SlideWake: ViewModifier {
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .offset(x: shown ? 0 : 18).opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.easeOut(duration: 0.3).delay(0.32)) { shown = true } }
    }
}

/// A reflective LCD left unused for years: the crystals answer slowly and the text swims in.
private struct ColdWake: ViewModifier {
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0).blur(radius: shown ? 0 : 1.6)
            .onAppear { withAnimation(.easeInOut(duration: 2.0).delay(0.3)) { shown = true } }
    }
}

// MARK: seven segments

/// Seven-segment digits with the unlit segments faintly visible and a shadow under the lit
/// ones, the way an LCD's segments sit above its reflector.
struct SevenSeg: View {
    let text: String
    let height: CGFloat
    let on: Color, off: Color, shade: Color

    private static let map: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg", "6": "acdefg", "7": "abc", "8": "abcdefg", "9": "abcdfg",
        "-": "g", " ": "", "A": "abcefg", "C": "adef", "E": "adefg", "F": "aefg", "H": "bcefg", "L": "def", "M": "abcefm", "P": "abefg", "S": "acdfg", "U": "bcdef"
    ]
    private static let raw: [Character: [(CGFloat, CGFloat)]] = [
        "a": [(1.6, 0), (10.4, 0), (8.8, 1.9), (3.2, 1.9)],
        "b": [(12, 1.3), (12, 10.4), (10.9, 11), (10.1, 10.2), (10.1, 2.9)],
        "c": [(12, 11.6), (12, 20.7), (10.1, 19.1), (10.1, 11.8), (10.9, 11)],
        "d": [(3.2, 20.1), (8.8, 20.1), (10.4, 22), (1.6, 22)],
        "e": [(0, 11.6), (1.1, 11), (1.9, 11.8), (1.9, 19.1), (0, 20.7)],
        "f": [(0, 1.3), (1.9, 2.9), (1.9, 10.2), (1.1, 11), (0, 10.4)],
        "g": [(1.3, 11), (2.6, 10.05), (9.4, 10.05), (10.7, 11), (9.4, 11.95), (2.6, 11.95)],
        "m": [(5.05, 2.4), (6.95, 2.4), (6.95, 9.6), (6, 10.4), (5.05, 9.6)]
    ]
    private static let segs: [Character: [CGPoint]] = raw.mapValues { $0.map { CGPoint(x: $0.0, y: $0.1) } }

    var body: some View {
        HStack(alignment: .bottom, spacing: height * 0.08) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in glyph(ch) }
        }
    }

    @ViewBuilder private func glyph(_ ch: Character) -> some View {
        let k = height / 23
        if ch == "." || ch == ":" || ch == "\"" {
            Canvas { ctx, size in
                let s = 2.4 * k
                let dots: [CGRect]
                switch ch {
                case ".": dots = [CGRect(x: 0.8 * k, y: 19.6 * k, width: s, height: s)]
                case ":": dots = [CGRect(x: 0.8 * k, y: 6 * k, width: s, height: s), CGRect(x: 0.8 * k, y: 14.5 * k, width: s, height: s)]
                default: dots = [CGRect(x: 0.6 * k, y: 0, width: 1.4 * k, height: 5 * k), CGRect(x: 3 * k, y: 0, width: 1.4 * k, height: 5 * k)]
                }
                for r in dots { ctx.fill(Path(r), with: .color(on)) }
            }
            .frame(width: (ch == "\"" ? 5 : 4) * k, height: height)
        } else {
            let lit = Self.map[ch] ?? ""
            Canvas { ctx, size in
                func path(_ pts: [CGPoint], dx: CGFloat = 0) -> Path {
                    var p = Path()
                    for (i, q) in pts.enumerated() {
                        // A slight italic lean, like the panel's own glyphs.
                        let x = (q.x + 1.5 - q.y * 0.105 + 1.2) * k + dx, y = q.y * k + dx
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    p.closeSubpath(); return p
                }
                for (name, pts) in Self.segs {
                    let isOn = lit.contains(name)
                    if name == "m" && !isOn { continue }
                    if isOn { ctx.fill(path(pts, dx: 1.1 * k), with: .color(shade)) }
                    ctx.fill(path(pts), with: .color(isOn ? on : off))
                }
            }
            .frame(width: 14.5 * k, height: height)
        }
    }
}
