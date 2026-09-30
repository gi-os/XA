import SwiftUI

extension CaptureMode {
    /// Each mode's lamp: the collar's tab and its name when it is the one selected.
    var lamp: Color {
        switch self {
        case .digi: return Color(hex: "#FF8A2B")
        case .pro: return Color(hex: "#5BD3F0")
        case .video: return Color(hex: "#FF3B30")
        }
    }
}

/// A ribbed collar round the shutter button. Flick it left or right, or tap a name, to change
/// mode; the names run along its edge and a colored tab marks where it sits. Locked while
/// recording.
struct ModeCollar<Center: View>: View {
    @ObservedObject var camera: CameraModel
    var modes: [CaptureMode]
    /// The mode the shutter is being pushed toward, lit before it is let go.
    var aimed: CaptureMode? = nil
    @ViewBuilder var center: () -> Center

    static var size: CGSize { CGSize(width: 164, height: 60) }
    private let textRadius: CGFloat = 42

    var body: some View {
        let s = Self.size
        ZStack {
            ring
                .contentShape(Capsule())
                .gesture(DragGesture(minimumDistance: 0).onEnded(release))
            ForEach(Array(modes.enumerated()), id: \.element) { i, m in
                let on = camera.mode == m
                let spot = Self.point(at: offset(i), r: textRadius)
                // The tab sits on the collar's own edge, under the name.
                let edge = CGPoint(x: spot.p.x - spot.n.x * 12, y: spot.p.y - spot.n.y * 12)
                if on {
                    RoundedRectangle(cornerRadius: 3).fill(m.lamp)
                        .frame(width: 10, height: 12)
                        .rotationEffect(.radians(spot.angle))
                        .position(edge)
                        .shadow(color: m.lamp.opacity(0.6), radius: 3)
                        .transition(.opacity)
                }
                CurvedLabel(text: m.title, at: offset(i), radius: textRadius, color: on || aimed == m ? m.lamp : Color(white: 0.91).opacity(camera.recording ? 0.25 : 0.5))
                    .scaleEffect(aimed == m ? 1.08 : 1)
                    .allowsHitTesting(false)
            }
            center()
        }
        .frame(width: s.width, height: s.height)
        .animation(.snappy(duration: 0.22), value: camera.mode)
        .animation(.snappy(duration: 0.15), value: aimed)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next mode") { step(1) }
        .accessibilityAction(named: "Previous mode") { step(-1) }
    }

    private var ring: some View {
        Capsule()
            .fill(Color(white: 0.1))
            .overlay(
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    while x < size.width { ctx.fill(Path(CGRect(x: x, y: 0, width: 3, height: size.height)), with: .color(Color(white: 0.175))); x += 6 }
                }
                .clipShape(Capsule())
            )
            .overlay(Capsule().strokeBorder(Color(white: 0.23), lineWidth: 2))
            .shadow(color: .black.opacity(0.8), radius: 2, y: 2)
    }

    /// Where each name sits along the edge, as a distance along the text path.
    private func offset(_ i: Int) -> CGFloat {
        let total = Self.pathLength(r: textRadius)
        let arc = total / 2 - 52
        // The ends of the row sit halfway round each curve; a middle mode sits on the top edge.
        let ends: (CGFloat, CGFloat) = (arc * 0.66, total - arc * 0.66)
        if modes.count == 1 { return total / 2 }
        let t = CGFloat(i) / CGFloat(modes.count - 1)
        return modes.count == 3 && i == 1 ? total / 2 : ends.0 + (ends.1 - ends.0) * t
    }

    private func release(_ v: DragGesture.Value) {
        guard !camera.recording else { return }
        let dx = v.translation.width
        if abs(dx) > 18 { step(dx > 0 ? 1 : -1); return }
        // A tap: the nearest name.
        let x = v.location.x
        let spots = modes.indices.map { Self.point(at: offset($0), r: textRadius).p.x }
        if let i = spots.indices.min(by: { abs(spots[$0] - x) < abs(spots[$1] - x) }) { set(modes[i]) }
    }

    private func step(_ by: Int) {
        guard !camera.recording, let i = modes.firstIndex(of: camera.mode) else { return }
        let j = min(max(i + by, 0), modes.count - 1)
        set(modes[j])
    }

    private func set(_ m: CaptureMode) {
        guard m != camera.mode else { return }
        withAnimation(.snappy) { camera.mode = m }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: the path round the collar

    /// Up the left curve, along the top, down the right curve, at distance `r` from the ends'
    /// centers. Collar-local points.
    static func pathLength(r: CGFloat) -> CGFloat { 2 * r * 0.75 * .pi + 104 }

    /// A point on the path, its outward normal, and the angle a letter there is turned.
    static func point(at s: CGFloat, r: CGFloat) -> (p: CGPoint, n: CGPoint, angle: Double) {
        let arc = r * 0.75 * .pi
        let cl = CGPoint(x: 30, y: 30), cr = CGPoint(x: 134, y: 30)
        func onArc(_ c: CGPoint, _ theta: CGFloat) -> (CGPoint, CGPoint, Double) {
            let n = CGPoint(x: cos(theta), y: sin(theta))
            // Tangent (increasing theta) is (-sin, cos); a letter's baseline follows it.
            return (CGPoint(x: c.x + r * n.x, y: c.y + r * n.y), n, Double(atan2(cos(theta), -sin(theta))))
        }
        if s <= arc { return onArc(cl, 0.75 * .pi + s / r) }
        if s <= arc + 104 { return (CGPoint(x: 30 + (s - arc), y: 30 - r), CGPoint(x: 0, y: -1), 0) }
        return onArc(cr, 1.5 * .pi + (s - arc - 104) / r)
    }
}

/// Letters set one by one along the collar's edge.
private struct CurvedLabel: View {
    let text: String
    let at: CGFloat
    let radius: CGFloat
    let color: Color
    private let advance: CGFloat = 7.4
    var body: some View {
        let chars = Array(text)
        ZStack {
            ForEach(chars.indices, id: \.self) { i in
                let s = at + (CGFloat(i) - CGFloat(chars.count - 1) / 2) * advance
                let spot = ModeCollar<EmptyView>.point(at: s, r: radius)
                Text(String(chars[i])).font(XA.display(9)).foregroundStyle(color)
                    .rotationEffect(.radians(spot.angle))
                    .position(spot.p)
            }
        }
    }
}

/// The row between the film rows and the shutter: settings and flash on the left, the zoom
/// toggle in the middle, the loaded film (or tape) as an angled box in the corner.
struct ToolRow<Corner: View>: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    var onCustomize: () -> Void
    @ViewBuilder var corner: () -> Corner

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                RoundButton(size: 38, action: onCustomize) { Image(systemName: "slider.horizontal.3").font(.system(size: 16)) }
                    .accessibilityLabel("Customize")
                if camera.mode != .video {
                    // Flash: off, auto, on. A shot the flash lit gets DIGI's party-flash look.
                    RoundButton(size: 38, action: { settings.flash = settings.flash.next; camera.flashChanged() }) {
                        Image(systemName: settings.flash.icon).font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(settings.flash == .on ? XA.orange : .white)
                    }
                    .accessibilityLabel(settings.flash.label)
                    .transition(.opacity)
                }
            }
            .frame(width: 80, alignment: .leading)
            Spacer(minLength: 4)
            ZoomToggle(camera: camera)
            Spacer(minLength: 4)
            corner().frame(width: 80, alignment: .trailing)
        }
        .frame(height: 52)
    }
}

/// The lenses as the system camera shows them: .5, 1×, 2, 5.
struct ZoomToggle: View {
    @ObservedObject var camera: CameraModel
    var body: some View {
        HStack(spacing: 2) {
            ForEach(camera.lenses) { l in
                let on = abs(camera.zoom - l.factor) / l.factor < 0.08
                Button { camera.setZoom(l.factor, ramp: true); UISelectionFeedbackGenerator().selectionChanged() } label: {
                    Text(on ? LCDStrip.zoomText(camera.zoom * camera.zoomMultiplier).replacingOccurrences(of: ".0×", with: "×") : l.label)
                        .font(XA.display(12))
                        .foregroundStyle(on ? XA.orange : Color.white.opacity(0.82))
                        .frame(width: 36, height: 30)
                        .background(on ? Color(white: 0.17) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zoom \(l.label)")
            }
        }
        .padding(3)
        .background(XA.fill, in: Capsule())
    }
}
