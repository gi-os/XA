import SwiftUI

/// The small screen under the viewfinder. It is the one part of the camera that changes with
/// the mode: a VCR-blue menu screen in DIGI, a green dot-matrix LCD in FILM, a blue backlit
/// segment panel in PRO, an amber camcorder panel in VIDEO. Switching modes slides the old one out and powers the new one on.
struct LCDStrip: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    /// PRO's selected panel field.
    @Binding var proField: ProField
    @State private var slideFrom: CGFloat?
    @State private var showZoom = false

    var body: some View {
        ZStack {
            switch camera.mode {
            case .digi: VcrLCD(camera: camera, settings: settings).transition(Self.swap)
            case .film: FilmLCD(camera: camera, settings: settings).transition(Self.swap)
            case .pro: ProLCD(camera: camera, settings: settings, field: $proField).transition(Self.proSwap)
            case .video: VideoLCD(camera: camera).transition(Self.swap)
            case .booth: BoothLCD(camera: camera, settings: settings).transition(Self.swap)
            }
        }
        // PRO grows the strip into the full panel; DIGI and VIDEO keep one row.
        .frame(height: Self.height(camera.mode))
        .padding(3)
        .background(Color(white: 0.025))
        .clipped()
        .overlay(alignment: .center) {
            if showZoom {
                Text(Self.zoomText(camera.zoom * camera.zoomMultiplier))
                    .font(.custom("IBMPlexSansCond-Bold", fixedSize: 15)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.black.opacity(0.78), in: Capsule())
                    .transition(.opacity)
            }
        }
        // One screen in every mode: the bezel stays put and only what it shows changes. For
        // PRO it physically grows to the full panel, and shrinks back when you leave.
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: camera.mode)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        // Slide along the strip to zoom, the way the system camera's zoom dial works:
        // left is closer, right is wider, and it keeps going as long as the finger does.
        .gesture(camera.mode == .pro ? nil : DragGesture(minimumDistance: 6)
            .onChanged { v in
                if slideFrom == nil { slideFrom = camera.zoom; withAnimation(.easeOut(duration: 0.12)) { showZoom = true } }
                let f = (slideFrom ?? 1) * CGFloat(exp(Double(-v.translation.width) / 140))
                camera.setZoom(f)
            }
            .onEnded { _ in
                slideFrom = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { if slideFrom == nil { withAnimation(.easeIn(duration: 0.25)) { showZoom = false } } }
            })
        .accessibilityElement(children: camera.mode == .pro ? .contain : .combine)
        .accessibilityAdjustableAction { dir in
            camera.setZoom(camera.zoom * (dir == .increment ? 1.25 : 0.8), ramp: true)
        }
    }

    static func height(_ m: CaptureMode) -> CGFloat { m == .pro ? 112 : 36 }

    static func zoomText(_ z: CGFloat) -> String {
        z < 10 ? String(format: "%.1f×", z) : String(format: "%.0f×", z)
    }

    /// The old picture goes dark, the new one comes up in the same glass.
    static let swap: AnyTransition = .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.14).delay(0.16)),
                                                 removal: .opacity.animation(.easeIn(duration: 0.14)))
    /// PRO's panel stays lit while the screen shrinks around it, then goes out.
    static let proSwap: AnyTransition = .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.14).delay(0.08)),
                                                    removal: .opacity.animation(.easeIn(duration: 0.14).delay(0.2)))
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

private struct FilmLCD: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    private let ink = Color(hex: "#1B2216")

    var body: some View {
        GreenPanel()
            .overlay {
                HStack {
                    dot(">" + camera.stack.filmTitle, 14)
                    Spacer(minLength: 8)
                    if settings.date.placement != .off { dot(Self.dateText(), 14) }
                    if settings.digiZero { dot("RAW", 14) }
                }
                .padding(.horizontal, 10)
                // A reflective LCD left unused for years: the text swims in slowly.
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

// MARK: DIGI

/// A VCR's on-screen menu: flat royal blue, every item an off-white block with blocky blue
/// capitals. Only what is true right now: the sim (and look), the size, the flash when it is
/// on, the date when the date back is on.
private struct VcrLCD: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    static let blue = Color(hex: "#1D2FAE")

    var body: some View {
        let film = ([FilmCatalog.sim(camera.stack.simID)?.title ?? Sim.neutral.title] + [camera.stack.look == .none ? nil : camera.stack.look.title, camera.stack.effectiveShape?.title].compactMap { $0 }).joined(separator: "+")
        Self.blue
            .overlay(Rectangle().strokeBorder(Color(hex: "#4F8EE0"), lineWidth: 1))
            .overlay {
                HStack(spacing: 6) {
                    chip(film)
                    Spacer(minLength: 4)
                    if settings.flash != .off { chip(settings.flash == .on ? "FLASH" : "AUTO") }
                    if settings.date.placement != .off { chip(FilmLCD.dateText()) }
                    chip("\(settings.digiMegapixels)MP")
                }
                .padding(.horizontal, 7)
                // The menu draws in line by line from the top, like a CRT; the blue is already there.
                .modifier(Wake(axis: .vertical))
            }
    }

    private func chip(_ s: String) -> some View {
        Text(s).font(.custom("Silkscreen-Regular", fixedSize: 12)).tracking(1.6).foregroundStyle(Self.blue)
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color(hex: "#ECEBE6"))
    }
}

// MARK: BOOTH

/// A purikura machine's screen: candy gradient, bubbly type. The skin setting and the sheet
/// while it waits; the shot, a "SMILE!" and the countdown while it runs.
private struct BoothLCD: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    static let hot = Color(hex: "#FF4FA0")

    var body: some View {
        let running = camera.boothShot != nil
        LinearGradient(colors: [Color(hex: "#FFD1E6"), Color(hex: "#FFE9F3"), Color(hex: "#D9F6EA")], startPoint: .leading, endPoint: .trailing)
            .overlay {
                HStack(spacing: 8) {
                    bubble(camera.boothShot.map { "SHOT \($0) / \(Booth.shots)" } ?? "♥ " + settings.boothSkin.title + " · " + settings.boothDeco.title, 14, Self.hot)
                    Spacer(minLength: 4)
                    bubble(running ? "SMILE!" : settings.boothLayout.title, 12, Color(hex: "#7A5AD9"))
                    if let n = camera.boothCount {
                        Text("\(n)").font(.custom(BoothInk.font, fixedSize: 26)).foregroundStyle(.white)
                            .shadow(color: Self.hot, radius: 0, x: 1.5, y: 0).shadow(color: Self.hot, radius: 0, x: -1.5, y: 0)
                            .shadow(color: Self.hot, radius: 0, x: 0, y: 1.5).shadow(color: Self.hot, radius: 0, x: 0, y: -1.5)
                            .contentTransition(.numericText(countsDown: true))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 10)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: camera.boothCount)
                .modifier(Wake(axis: .horizontal))
            }
    }

    private func bubble(_ s: String, _ size: CGFloat, _ c: Color) -> some View {
        Text(s).font(.custom(BoothInk.font, fixedSize: size)).foregroundStyle(c)
            .lineLimit(1).minimumScaleFactor(0.6)
    }
}

/// A display powering on: a mask sweeps across it, top to bottom or left to right.
struct Wake: ViewModifier {
    enum Axis { case vertical, horizontal }
    let axis: Axis
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .mask(alignment: axis == .vertical ? .top : .leading) {
                GeometryReader { g in
                    Rectangle()
                        .frame(width: axis == .horizontal ? (on ? g.size.width : 0) : g.size.width,
                               height: axis == .vertical ? (on ? g.size.height : 0) : g.size.height)
                }
            }
            .onAppear { withAnimation(.linear(duration: axis == .vertical ? 0.22 : 0.3).delay(0.18)) { on = true } }
    }
}

// MARK: PRO

private struct ProLCD: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @Binding var field: ProField

    var body: some View {
        LitPanel(center: Color(hex: "#D4F8FF"), mid: Color(hex: "#9FE6F2"), edge: Color(hex: "#6FC9DC"), glow: Color(red: 0.47, green: 0.84, blue: 1).opacity(0.5))
            // The readings keep their full size while the glass grows (or shrinks) around them.
            .overlay(alignment: .top) {
                ProPanel(camera: camera, settings: settings, field: $field)
                    .frame(height: LCDStrip.height(.pro), alignment: .top)
                    .modifier(SlideWake())
            }
            .clipped()
            // The backlight strikes once the glass has grown: a few stuttering flashes, then on.
            .modifier(Flicker())
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
            // An old TV warming up: a bright line opens into the picture, then the tube glows up slowly.
            .modifier(TubeWarmup())
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

/// A fluorescent backlight striking: dark while the screen grows, then a stutter of flashes.
private struct Flicker: ViewModifier {
    @State private var go = false
    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: Lamp(), trigger: go) { view, l in
                view.opacity(l.on).brightness(l.flash)
            } keyframes: { _ in
                KeyframeTrack(\.on) {
                    MoveKeyframe(0.06)
                    LinearKeyframe(0.06, duration: 0.26)
                    LinearKeyframe(1, duration: 0.03)
                    LinearKeyframe(0.15, duration: 0.05)
                    LinearKeyframe(0.95, duration: 0.03)
                    LinearKeyframe(0.3, duration: 0.07)
                    LinearKeyframe(1, duration: 0.03)
                    LinearKeyframe(0.6, duration: 0.05)
                    LinearKeyframe(1, duration: 0.08)
                }
                KeyframeTrack(\.flash) {
                    MoveKeyframe(0)
                    LinearKeyframe(0, duration: 0.29)
                    LinearKeyframe(0.35, duration: 0.03)
                    LinearKeyframe(0, duration: 0.15)
                    LinearKeyframe(0.2, duration: 0.03)
                    LinearKeyframe(0, duration: 0.2)
                }
            }
            .onAppear { go.toggle() }
    }
    struct Lamp { var on: Double = 0.06; var flash: Double = 0 }
}

/// A CRT coming on: a thin bright line opens to the full picture, then the glow comes up slowly.
private struct TubeWarmup: ViewModifier {
    @State private var open = false
    @State private var warm = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: open ? 1 : 0.05, anchor: .center)
            .brightness(warm ? 0 : -0.55)
            .saturation(warm ? 1 : 0.35)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2).delay(0.16)) { open = true }
                withAnimation(.easeIn(duration: 1.6).delay(0.3)) { warm = true }
            }
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
