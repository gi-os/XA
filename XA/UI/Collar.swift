import SwiftUI

extension CaptureMode {
    /// Each mode's lamp: its name on the ribbon when it is the one selected.
    var lamp: Color {
        switch self {
        case .digi: return Color(hex: "#FF8A2B")
        case .film: return Color(hex: "#F2B33D")
        case .pro: return Color(hex: "#5BD3F0")
        case .video: return Color(hex: "#FF3B30")
        case .booth: return Color(hex: "#FF4FA0")
        }
    }
}

/// The modes as a ribbon of names above the shutter, the way the iPhone camera shows them: the
/// current one sits in the middle over a dot. Swipe the deck sideways to slide it, or tap a name.
struct ModeRibbon: View {
    @ObservedObject var camera: CameraModel
    var modes: [CaptureMode]
    /// How far a finger has dragged the deck sideways right now: the ribbon follows it, and the
    /// name under the dot is where you land when you let go.
    @Binding var drag: CGFloat
    static let pitch: CGFloat = 74
    private var pitch: CGFloat { Self.pitch }

    var body: some View {
        let i = CGFloat(modes.firstIndex(of: camera.mode) ?? 0) - drag / pitch
        let target = Self.target(camera.mode, drag: drag, modes)
        ZStack {
            ForEach(Array(modes.enumerated()), id: \.element) { k, m in
                let on = target == m
                Text(m.title).font(XA.display(13)).tracking(0.6)
                    .foregroundStyle(on ? m.lamp : Color.white.opacity(camera.recording ? 0.25 : 0.55))
                    .frame(width: 70, height: 22)
                    .contentShape(Rectangle())
                    .onTapGesture { ModeRibbon.set(m, camera) }
                    .accessibilityAddTraits(.isButton)
                    .offset(x: (CGFloat(k) - i) * pitch)
            }
            Circle().fill(target.lamp).frame(width: 5, height: 5).offset(y: 14)
        }
        .onChange(of: target) { _, _ in UISelectionFeedbackGenerator().selectionChanged() }
        .frame(maxWidth: .infinity).frame(height: 44)
        .clipped()
        .contentShape(Rectangle())
        // Slide along the names, as in the iPhone camera: the ribbon follows the finger and you
        // land on the name under the dot.
        .highPriorityGesture(DragGesture(minimumDistance: 3)
            .onChanged { v in if !camera.recording { drag = v.translation.width } }
            .onEnded { v in
                if !camera.recording { ModeRibbon.land(drag: v.translation.width, modes, camera) }
                withAnimation(.snappy(duration: 0.28)) { drag = 0 }
            })
        .animation(.snappy(duration: 0.28), value: camera.mode)
        .accessibilityElement(children: .contain)
    }

    static func set(_ m: CaptureMode, _ camera: CameraModel) {
        guard m != camera.mode, !camera.recording else { return }
        withAnimation(.snappy) { camera.mode = m }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// The mode a drag of `drag` points would land on.
    static func target(_ from: CaptureMode, drag: CGFloat, _ modes: [CaptureMode]) -> CaptureMode {
        guard let i = modes.firstIndex(of: from), !modes.isEmpty else { return from }
        let j = Int((CGFloat(i) - drag / pitch).rounded())
        return modes[min(modes.count - 1, max(0, j))]
    }

    /// Let go after a drag: land on the mode under the dot; a short flick still moves one.
    static func land(drag: CGFloat, _ modes: [CaptureMode], _ camera: CameraModel) {
        let t = target(camera.mode, drag: drag, modes)
        if t != camera.mode { set(t, camera) } else if abs(drag) > 30 { step(drag < 0 ? 1 : -1, modes, camera) }
    }

    /// Swipe left for the mode to the right, as on the iPhone.
    static func step(_ by: Int, _ modes: [CaptureMode], _ camera: CameraModel) {
        guard let i = modes.firstIndex(of: camera.mode) else { return }
        let j = i + by
        if modes.indices.contains(j) { set(modes[j], camera) }
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
