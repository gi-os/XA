import SwiftUI

/// What the PRO panel can have selected. Tap one on the panel (or step with SELECT), then roll
/// the command wheel to change it.
enum ProField: String, CaseIterable, Identifiable {
    case shutter, iso, ev, wb, af, flash, file, size, lens, grid, focus
    var id: String { rawValue }
    var name: String {
        switch self {
        case .shutter: return "SHUTTER"
        case .iso: return "ISO"
        case .ev: return "EXPOSURE"
        case .wb: return "WHITE BAL"
        case .af: return "AF MODE"
        case .flash: return "FLASH"
        case .file: return "FILE"
        case .size: return "SIZE"
        case .lens: return "LENS"
        case .grid: return "GRID"
        case .focus: return "FOCUS"
        }
    }
    /// The lower row of the panel, left to right.
    static let lower: [ProField] = [.file, .size, .lens, .grid, .focus]

    func value(_ c: CameraModel, _ s: AppSettings) -> String {
        switch self {
        case .shutter: return c.label(.shutter)
        case .iso: return c.label(.iso)
        case .ev: return c.label(.ev)
        case .wb: return c.label(.wb)
        case .af: return s.afMode == .single ? "AF-S" : "AF-C"
        case .flash: return s.flash == .off ? "OFF" : (s.flash == .auto ? "AUTO" : "ON")
        case .file: return s.proFormat == .heif ? "HEIF" : "JPEG"
        case .size: return s.proMegapixels == 0 ? "MAX" : "\(s.proMegapixels)MP"
        case .lens: return LCDStrip.zoomText(c.zoom * c.zoomMultiplier)
        case .grid: return s.grid ? "ON" : "OFF"
        case .focus: return c.label(.focus)
        }
    }

    /// One click of the command wheel.
    func step(_ by: Int, _ c: CameraModel, _ s: AppSettings) {
        switch self {
        case .shutter, .iso, .ev, .wb, .focus:
            let ctl: ProControl = self == .shutter ? .shutter : (self == .iso ? .iso : (self == .ev ? .ev : (self == .wb ? .wb : .focus)))
            // The wheel runs the way the numbers read: right is faster, higher, brighter.
            let dir = self == .shutter ? -by : by
            c.setDial(ctl, c.dial(ctl).index + dir)
        case .af: s.afMode = s.afMode == .single ? .continuous : .single
        case .flash:
            let all = FlashSetting.allCases
            let i = all.firstIndex(of: s.flash) ?? 0
            s.flash = all[((i + by) % all.count + all.count) % all.count]
            c.flashChanged()
        case .file: s.proFormat = s.proFormat == .heif ? .jpeg : .heif
        case .size:
            let opts = [0] + c.proOptions.sorted(by: >)
            let i = opts.firstIndex(of: s.proMegapixels) ?? 0
            s.proMegapixels = opts[min(max(i + by, 0), opts.count - 1)]
            c.applyResolution()
        case .lens:
            guard !c.lenses.isEmpty else { return }
            let i = c.lenses.enumerated().min(by: { abs($0.element.factor - c.zoom) < abs($1.element.factor - c.zoom) })?.offset ?? 0
            c.setZoom(c.lenses[min(max(i + by, 0), c.lenses.count - 1)].factor, ramp: true)
        case .grid: s.grid.toggle()
        }
    }

    /// SET: back to the camera's own choice.
    func reset(_ c: CameraModel, _ s: AppSettings) {
        switch self {
        case .shutter: c.setDial(.shutter, 0)
        case .iso: c.setDial(.iso, 0)
        case .ev: c.ev = 0
        case .wb: c.setDial(.wb, 0)
        case .focus: c.setDial(.focus, 0)
        case .af: s.afMode = .single
        case .flash: s.flash = .off; c.flashChanged()
        case .file: s.proFormat = .heif
        case .size: s.proMegapixels = 0; c.applyResolution()
        case .lens: if let l = c.lenses.first(where: { abs($0.factor * c.zoomMultiplier - 1) < 0.05 }) ?? c.lenses.first { c.setZoom(l.factor, ramp: true) }
        case .grid: s.grid = false
        }
    }
}

/// PRO's big panel: the LCD is the menu. Every reading on it is a field you can tap.
struct ProPanel: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @Binding var field: ProField
    private let ink = Color(hex: "#0A2430"), off = Color(red: 0.04, green: 0.14, blue: 0.19).opacity(0.08), shade = Color(red: 0, green: 0.24, blue: 0.31).opacity(0.22)

    var body: some View {
        let program = camera.shutterIndex == nil ? (camera.isoIndex == nil ? "P" : "A") : (camera.isoIndex == nil ? "S" : "M")
        VStack(spacing: 0) {
            // Exposure: program, shutter, aperture, ISO, histogram.
            HStack(alignment: .center, spacing: 8) {
                SevenSeg(text: program, height: 20, on: ink, off: off, shade: shade)
                    .padding(2).overlay(Rectangle().strokeBorder(ink.opacity(0.45), lineWidth: 1))
                tap(.shutter) { SevenSeg(text: shutterText, height: 24, on: ink, off: off, shade: shade) }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    label("F", 8)
                    SevenSeg(text: String(format: "%.1f", camera.aperture), height: 12, on: ink, off: off, shade: shade)
                }
                tap(.iso) {
                    HStack(alignment: .bottom, spacing: 3) {
                        VStack(alignment: .leading, spacing: 0) {
                            label("ISO", 8)
                            label(camera.isoIndex == nil ? "AUTO" : "", 6)
                        }
                        SevenSeg(text: "\(camera.isoIndex.map { Exposure.isoAt($0) } ?? Int(camera.meterISO.rounded()))", height: 16, on: ink, off: off, shade: shade)
                    }
                }
                Spacer(minLength: 0)
                PanelHisto(bins: camera.histogram, ink: ink).frame(width: 54, height: 22)
            }
            .frame(height: 34)
            rule
            // EV scale and the quick settings.
            HStack(spacing: 10) {
                tap(.ev) { EVScale(ev: camera.ev, ink: ink).frame(width: 128, height: 18) }
                Spacer(minLength: 0)
                tap(.af) { label(ProField.af.value(camera, settings), 9) }
                tap(.wb) { label("WB " + (camera.wbIndex == 0 ? "A" : camera.label(.wb)), 9) }
                tap(.flash) { label("⚡" + (settings.flash == .off ? "OFF" : (settings.flash == .auto ? "A" : "ON")), 9) }
            }
            .frame(height: 24)
            rule
            // The lower row: file, size, lens, grid, focus.
            HStack(spacing: 0) {
                ForEach(ProField.lower) { f in
                    tap(f) {
                        VStack(spacing: 1) {
                            label(f.value(camera, settings), 10)
                            label(f.name, 6).opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 28)
            rule
            HStack {
                label(">" + field.name, 9)
                Spacer()
                label(field.value(camera, settings), 10)
                    .phaseAnimator([1.0, 0.15]) { v, a in v.opacity(a) } animation: { _ in .easeInOut(duration: 0.45) }
            }
            .frame(height: 18)
        }
        .padding(.horizontal, 8)
    }

    private var shutterText: String {
        if let i = camera.shutterIndex {
            let d = Exposure.shutterStops[min(max(i, 0), Exposure.shutterStops.count - 1)]
            return d == 1 ? "1\"" : "\(d)"
        }
        let d = camera.meterShutter
        return d >= 1 ? "\(Int(d.rounded()))\"" : "\(Int((1 / max(d, 0.0001)).rounded()))"
    }

    private var rule: some View { Rectangle().fill(ink.opacity(0.4)).frame(height: 1) }

    private func label(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(.custom("IBMPlexSansCond-Bold", fixedSize: size)).foregroundStyle(ink)
            .shadow(color: shade, radius: 0, x: 1.1, y: 1.1).lineLimit(1)
    }

    /// A field: tap to select it; the selected one gets a thin box.
    private func tap<C: View>(_ f: ProField, @ViewBuilder _ c: () -> C) -> some View {
        c()
            .padding(.horizontal, 3).padding(.vertical, 1)
            .overlay(Rectangle().strokeBorder(ink.opacity(field == f ? 0.7 : 0), lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture {
                field = f
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(f.name)
            .accessibilityValue(f.value(camera, settings))
            .accessibilityAddTraits(.isButton)
    }
}

private struct EVScale: View {
    let ev: Float
    let ink: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            for i in 0...12 {
                let x = CGFloat(i) * w / 12
                let h: CGFloat = i % 3 == 0 ? 6 : 3
                ctx.fill(Path(CGRect(x: x - 0.7, y: 5, width: 1.4, height: h)), with: .color(ink))
            }
            let at = CGFloat((min(2, max(-2, ev)) + 2) / 4) * w
            var tri = Path()
            tri.move(to: CGPoint(x: at - 3, y: 0)); tri.addLine(to: CGPoint(x: at + 3, y: 0)); tri.addLine(to: CGPoint(x: at, y: 4)); tri.closeSubpath()
            ctx.fill(tri, with: .color(ink))
            for (t, x) in [("-2", 0.0), ("0", w / 2), ("+2", w)] {
                ctx.draw(Text(t).font(.custom("IBMPlexSansCond-Bold", fixedSize: 6)).foregroundColor(ink), at: CGPoint(x: min(max(x, 4), w - 4), y: 15))
            }
        }
    }
}

private struct PanelHisto: View {
    let bins: [Float]
    let ink: Color
    var body: some View {
        Canvas { ctx, size in
            guard !bins.isEmpty else { return }
            let n = min(bins.count, 28)
            let step = max(1, bins.count / n)
            let w = size.width / CGFloat(n)
            for i in 0..<n {
                let v = CGFloat(bins[min(bins.count - 1, i * step)])
                let h = max(1, v * size.height)
                ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: size.height - h, width: max(1, w - 1), height: h)), with: .color(ink))
            }
        }
    }
}

/// Under the panel: MODE, SELECT and SET, the command wheel, and settings and flash.
struct ProKeys: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @Binding var field: ProField
    var onCustomize: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            key("MODE") { cycleProgram() }
            key("SELECT") {
                let all = ProField.allCases
                field = all[((all.firstIndex(of: field) ?? 0) + 1) % all.count]
            }
            key("SET") { field.reset(camera, settings) }
            CommandWheel { by in field.step(by, camera, settings) }
                .accessibilityLabel("Command wheel, \(field.name)")
                .accessibilityValue(field.value(camera, settings))
                .accessibilityAdjustableAction { d in field.step(d == .increment ? 1 : -1, camera, settings) }
            RoundButton(size: 36, action: onCustomize) { Image(systemName: "slider.horizontal.3").font(.system(size: 14)) }
                .accessibilityLabel("Customize")
            RoundButton(size: 36, action: { settings.flash = settings.flash.next; camera.flashChanged() }) {
                Image(systemName: settings.flash.icon).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(settings.flash == .on ? Color(hex: "#5BD3F0") : .white)
            }
            .accessibilityLabel(settings.flash.label)
        }
        .frame(height: 44)
    }

    /// P → S → M → P. S holds the shutter where the meter had it; M holds both.
    private func cycleProgram() {
        let s = Exposure.nearestShutterIndex(Int64(camera.meterShutter * Double(Exposure.nanosPerSecond)))
        let i = Exposure.nearestIsoIndex(Int(camera.meterISO))
        if camera.shutterIndex == nil && camera.isoIndex == nil { camera.shutterIndex = s; field = .shutter }
        else if camera.isoIndex == nil { camera.isoIndex = i; field = .iso }
        else { camera.shutterIndex = nil; camera.isoIndex = nil; field = .ev }
    }

    private func key(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Text(t).font(.custom("IBMPlexSansCond-Bold", fixedSize: 8)).tracking(0.6).foregroundStyle(Color(white: 0.91))
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.64), Color(white: 0.37), Color(white: 0.18)], center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: 11))
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.9), radius: 1, y: 1.5)
            }
            .frame(minWidth: 34, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t)
    }
}

/// A ribbed wheel lying on its side. Roll it with the thumb: one click per rib.
struct CommandWheel: View {
    var onStep: (Int) -> Void
    @State private var from: CGFloat?
    @State private var clicks = 0
    @State private var roll: CGFloat = 0
    private let rib: CGFloat = 14

    var body: some View {
        Canvas { ctx, size in
            let shift = roll.truncatingRemainder(dividingBy: 5)
            var x = -5 + shift
            while x < size.width + 5 {
                // Ribs bunch up toward the ends, like a cylinder seen from above.
                let u = min(max(x / size.width, 0), 1)
                let bright = 0.16 + 0.14 * sin(Double(u) * .pi)
                ctx.fill(Path(CGRect(x: x, y: 0, width: 2, height: size.height)), with: .color(Color(white: bright)))
                x += 5
            }
        }
        .background(Color(white: 0.08))
        .overlay(LinearGradient(colors: [.black.opacity(0.85), .clear, .clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(white: 0.05), lineWidth: 1.5))
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { v in
                if from == nil { from = 0; clicks = 0 }
                roll = v.translation.width
                let n = Int((v.translation.width / rib).rounded(.towardZero))
                while n != clicks {
                    let d = n > clicks ? 1 : -1
                    onStep(d)
                    clicks += d
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .onEnded { _ in from = nil; clicks = 0 })
    }
}
