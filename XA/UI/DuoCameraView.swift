import SwiftUI

/// iPhone Duo, open and held tall: the inner display is the back of a camera, the F5 back from the
/// XA Refresh boards. The top half has the mode dial, the film slot, the screen with MODE, SELECT
/// and SET, the flash slider and the shutter in its zoom ring; the bottom half has the viewfinder,
/// the data strip under it, and the keys you need less often beside it. Nothing sits on the fold.
/// Each half is drawn 400 × 270 (the boards' units) and scaled to the half it gets.
struct DuoCameraView: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    var onRoll: () -> Void
    var onCustomize: () -> Void
    var onFilm: () -> Void
    var modes: [CaptureMode]
    var lockScreen: Bool
    var onLink: ((URL) -> Void)?
    /// Held sideways, the whole back is turned this far (clockwise) against the window, to
    /// stand as it does held tall (see CameraView). The safe areas are the window's, so they're
    /// left out then.
    var turnedBack: CGFloat = 0
    /// PRO: the field the command wheel changes.
    @State private var proField: ProField = .shutter
    /// The film shelf over the top half (tap the film box).
    @State private var shelf = false
    /// PRO's backlight (the LAMP key).
    @State private var lamp = true

    var body: some View {
        GeometryReader { g in
            let ins = turnedBack == 0 ? g.safeAreaInsets : EdgeInsets()
            let mid = g.size.height / 2
            let w = max(0, g.size.width - ins.leading - ins.trailing)
            let topH = max(0, mid - Duo.foldGap - ins.top)
            let bottomH = max(0, g.size.height - ins.bottom - mid - Duo.foldGap)
            ZStack(alignment: .topLeading) {
                F5.body
                DuoBack(camera: camera, settings: settings, proField: $proField, shelf: $shelf, lamp: $lamp,
                        onFilm: onFilm, modes: Self.unfoldedModes(modes))
                    .frame(width: w, height: topH)
                    .position(x: ins.leading + w / 2, y: ins.top + topH / 2)
                DuoDeck(camera: camera, settings: settings, proField: $proField, lamp: lamp,
                        onRoll: onRoll, onCustomize: onCustomize, onLink: onLink, turnedBack: turnedBack)
                    .frame(width: w, height: bottomH)
                    .position(x: ins.leading + w / 2, y: mid + Duo.foldGap + bottomH / 2)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            camera.setDuoInner(true)
            backCameraOnly()
        }
        .onChange(of: camera.mode) { _, _ in backCameraOnly() }
        .onChange(of: camera.front) { _, _ in backCameraOnly() }
        .onDisappear { camera.setDuoInner(false) }
    }

    /// Open, the Duo is the back of a camera: no BOOTH and no selfie camera. BOOTH (from the
    /// outer display, or the Lock Screen camera's settings) comes back as DIGI.
    static func unfoldedModes(_ modes: [CaptureMode]) -> [CaptureMode] { modes.filter { $0 != .booth } }

    private func backCameraOnly() {
        if camera.mode == .booth { camera.mode = Self.unfoldedModes(modes).first ?? .digi }
        if camera.front { camera.setFront(false) }
    }
}

// MARK: drawing

/// The F5 back's materials.
enum F5 {
    static let body = Color(hex: "#0C0C0D")
    /// The printing on the body.
    static let ink = Color(hex: "#E9E9E6")
    static func print(_ size: CGFloat) -> Font { .custom("IBMPlexSansCond-Bold", fixedSize: size) }
}

extension View {
    /// Places a view on a half's drawing: left, top, width and height in the drawing's units,
    /// `k` points to the unit.
    func f5(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ k: CGFloat) -> some View {
        frame(width: w * k, height: h * k).position(x: (x + w / 2) * k, y: (y + h / 2) * k)
    }
}

// MARK: the top half

/// The back of the camera.
struct DuoBack: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @Binding var proField: ProField
    @Binding var shelf: Bool
    @Binding var lamp: Bool
    var onFilm: () -> Void
    var modes: [CaptureMode]
    /// The screen's line: which setting MODE points at, and the value SELECT picked that SET
    /// hasn't kept yet.
    @State private var item = 0
    @State private var pending: Int?
    /// The dial while a finger turns it: degrees clockwise from straight up.
    @State private var turning: Double?

    var body: some View {
        GeometryReader { g in
            let k = min(g.size.width / 400, g.size.height / 270)
            ZStack(alignment: .topLeading) {
                Grip(k: k).f5(311, 0, 89, 270, k)
                if camera.mode == .pro {
                    DuoProPanel(camera: camera, settings: settings, field: $proField, lit: lamp, k: k)
                        .f5(10, 28, 142, 148, k)
                    proKeys(k)
                } else {
                    slot(k)
                    screen(k)
                }
                dialNames(k)
                dial(k)
                shutter(k)
                zoomKey("W", by: -1, k).f5(198, 164, 24, 28, k)
                zoomKey("T", by: 1, k).f5(316, 164, 24, 28, k)
                if camera.mode != .video { flash(k) }
                keys(k)
                if camera.mode == .pro { proWheel(k); proSideKeys(k) }
                if camera.mode == .video { tapeWheel(k); tally(k) }
                if shelf && (camera.mode.usesFilm || camera.mode == .video) {
                    shelfView(k).transition(.opacity)
                }
            }
            .frame(width: 400 * k, height: 270 * k, alignment: .topLeading)
            .position(x: g.size.width / 2, y: g.size.height / 2)
            .animation(.snappy(duration: 0.3), value: camera.mode)
            .animation(.snappy(duration: 0.25), value: shelf)
        }
        .onChange(of: camera.mode) { _, _ in item = 0; pending = nil; shelf = false }
    }

    // MARK: film slot

    /// What's loaded, in the slot: the film box (swipe for the next, tap for the shelf), the
    /// tape, or BOOTH's sticker sheet (tap or swipe for the next).
    @ViewBuilder private func slot(_ k: CGFloat) -> some View {
        switch camera.mode {
        case .digi, .film:
            Button { shelf = true } label: { filmBox(k) }
                .buttonStyle(.plain)
                .modifier(SwipeToStep(step: { camera.stepSim($0) }, vertical: camera.mode == .film ? { camera.stepPush($0) } : nil))
                .shadow(color: .black.opacity(0.9), radius: 1, y: 1)
                .f5(16, 16, 132, 87, k)
                .accessibilityLabel("Film: \(camera.stack.filmTitle). Show the film shelf")
        case .video:
            Button { shelf = true } label: { FilmBox(item: .video(camera.videoLook), width: 132 * k) }
                .buttonStyle(.plain)
                .modifier(SwipeToStep { camera.stepTape($0) })
                .shadow(color: .black.opacity(0.9), radius: 1, y: 1)
                .f5(16, 16, 132, 87, k)
                .accessibilityLabel("Tape: \(camera.videoLook.title). Show the tapes")
        case .booth:
            Button { stepSheet(1) } label: { BigSheet(layout: settings.boothLayout, k: k) }
                .buttonStyle(.plain)
                .modifier(SwipeToStep { stepSheet($0) })
                .shadow(color: .black.opacity(0.9), radius: 1, y: 1)
                .f5(16, 16, 132, 87, k)
                .accessibilityLabel("Sticker sheet \(settings.boothLayout.letter). Next sheet")
        case .pro:
            EmptyView()
        }
    }

    @ViewBuilder private func filmBox(_ k: CGFloat) -> some View {
        if let sim = camera.stack.shownSim {
            FilmBox(item: .sim(sim), width: 132 * k)
        } else {
            Rectangle().fill(XA.fill)
                .overlay(Text("NO SIM").font(XA.display(12 * k)).foregroundStyle(XA.faint))
                .frame(width: 132 * k, height: 87 * k)
        }
    }

    private func stepSheet(_ by: Int) {
        withAnimation(.snappy) { settings.boothLayout = settings.boothLayout.step(by) }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// The film shelf: the phone's film rows (SIM, LOOK, SHAPE, or the tapes) over the top half.
    /// Loading a box shows it in the viewfinder below; untouched, it folds away.
    private func shelfView(_ k: CGFloat) -> some View {
        ZStack {
            F5.body
                .contentShape(Rectangle())
                .onTapGesture { shelf = false }
            Group {
                if camera.mode == .video {
                    VideoRows(camera: camera, open: $shelf, onFilm: onFilm)
                } else {
                    FilmControls(camera: camera, open: $shelf, onFilm: onFilm)
                }
            }
            .padding(.horizontal, 12 * k)
        }
        .f5(0, 0, 311, 270, k)
    }

    // MARK: screen and keys

    @ViewBuilder private func screen(_ k: CGFloat) -> some View {
        let list = DuoMenu.items(camera, settings)
        if !list.isEmpty {
            let i = item % list.count
            let line = list[i]
            let v = pending ?? line.current
            DuoScreen(camera: camera, name: line.name, index: "\(i + 1)/\(list.count)",
                      value: line.values.indices.contains(v) ? line.values[v] : "-", blinking: pending != nil, k: k)
                .f5(12, 110, 140, 62, k)
        }
    }

    /// MODE, SELECT and SET, the data back's three keys.
    private func keys(_ k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(["MODE", "SELECT", "SET"].enumerated()), id: \.offset) { i, name in
                let y = 180 + CGFloat(i) * 24
                Text(name).font(F5.print(9 * k)).tracking(0.6 * k).foregroundStyle(F5.ink)
                    .frame(width: 44 * k, alignment: .trailing)
                    .position(x: (116 + 22) * k, y: (y + 8) * k)
                RoundKey(size: 16 * k, name: name) { press(i) }
                    .position(x: (166 + 8) * k, y: (y + 8) * k)
            }
        }
    }

    private func press(_ i: Int) {
        if camera.mode == .pro {
            switch i {
            case 0: cycleProgram()
            case 1:
                let all = ProField.allCases
                proField = all[((all.firstIndex(of: proField) ?? 0) + 1) % all.count]
            default: proField.reset(camera, settings)
            }
            return
        }
        let list = DuoMenu.items(camera, settings)
        guard !list.isEmpty else { return }
        let line = list[item % list.count]
        switch i {
        case 0:
            item = (item % list.count + 1) % list.count
            pending = nil
        case 1:
            pending = ((pending ?? line.current) + 1) % max(line.values.count, 1)
        default:
            if let p = pending { line.apply(p) }
            pending = nil
        }
    }

    /// PRO's MODE: P → S → M → P. S holds the shutter where the meter had it; M holds both.
    private func cycleProgram() {
        let s = Exposure.nearestShutterIndex(Int64(camera.meterShutter * Double(Exposure.nanosPerSecond)))
        let i = Exposure.nearestIsoIndex(Int(camera.meterISO))
        if camera.shutterIndex == nil && camera.isoIndex == nil { camera.shutterIndex = s; proField = .shutter }
        else if camera.isoIndex == nil { camera.isoIndex = i; proField = .iso }
        else { camera.shutterIndex = nil; camera.isoIndex = nil; proField = .ev }
    }

    // MARK: mode dial

    private static let dialOrder: [CaptureMode] = [.digi, .film, .pro, .video, .booth]

    /// Where the dial's notch points for each mode: degrees clockwise from straight up.
    private static func notch(_ m: CaptureMode) -> Double {
        switch m {
        case .digi: return -15
        case .film: return 30
        case .pro: return 72
        case .video: return 112
        case .booth: return 160
        }
    }

    /// Each mode's name around the dial: the top-left corner of its box.
    private static func nameAt(_ m: CaptureMode) -> CGPoint {
        switch m {
        case .digi: return CGPoint(x: 179, y: 4)
        case .film: return CGPoint(x: 217, y: 9)
        case .pro: return CGPoint(x: 240, y: 37)
        case .video: return CGPoint(x: 238, y: 71)
        case .booth: return CGPoint(x: 209, y: 99)
        }
    }

    private var dialModes: [CaptureMode] { Self.dialOrder.filter { modes.contains($0) } }

    /// The names round the dial: tap one to go straight there.
    private func dialNames(_ k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(dialModes, id: \.self) { m in
                let p = Self.nameAt(m)
                Button { ModeRibbon.set(m, camera) } label: {
                    Text(m.title).font(XA.display(10 * k))
                        .foregroundStyle(m == camera.mode ? m.lamp : Color.white.opacity(camera.recording ? 0.3 : 0.7))
                        .frame(width: 44 * k, height: 24 * k)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: (p.x + 22) * k, y: (p.y + 12) * k)
                .accessibilityLabel("\(m.title) mode")
                .accessibilityAddTraits(m == camera.mode ? .isSelected : [])
            }
        }
    }

    /// The knurled dial: drag it round and let go near a mode, or tap it for the next one.
    private func dial(_ k: CGFloat) -> some View {
        let lamp = camera.mode.lamp
        return ZStack {
            DialKnurl()
            Circle().strokeBorder(Color(hex: "#3A3A3C"), lineWidth: 2 * k)
            Rectangle().fill(lamp)
                .frame(width: 4 * k, height: 12 * k)
                .shadow(color: lamp, radius: 3 * k)
                .offset(y: -26 * k)
        }
        .rotationEffect(.degrees(turning ?? Self.notch(camera.mode)))
        .frame(width: 68 * k, height: 68 * k)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard !camera.recording else { return }
                let dx = v.location.x - 34 * k, dy = v.location.y - 34 * k
                guard hypot(dx, dy) > 6 * k, hypot(v.translation.width, v.translation.height) > 4 * k else { return }
                turning = Double(atan2(dx, -dy)) * 180 / .pi
            }
            .onEnded { _ in
                let t = turning
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { turning = nil }
                guard !camera.recording else { return }
                if let t { ModeRibbon.set(nearest(t), camera) } else { stepDial(1) }
            })
        .position(x: 214 * k, y: 64 * k)
        .accessibilityElement()
        .accessibilityLabel("Mode dial")
        .accessibilityValue(camera.mode.title)
        .accessibilityAdjustableAction { d in stepDial(d == .increment ? 1 : -1) }
    }

    private func nearest(_ t: Double) -> CaptureMode {
        func gap(_ a: Double, _ b: Double) -> Double {
            let d = abs((a - b).truncatingRemainder(dividingBy: 360))
            return min(d, 360 - d)
        }
        return dialModes.min { gap(Self.notch($0), t) < gap(Self.notch($1), t) } ?? camera.mode
    }

    private func stepDial(_ by: Int) {
        let list = dialModes
        guard !list.isEmpty else { return }
        let i = list.firstIndex(of: camera.mode) ?? 0
        ModeRibbon.set(list[((i + by) % list.count + list.count) % list.count], camera)
    }

    // MARK: shutter, zoom, flash

    /// The white shutter in its ring, W and T either side. It fires the instant a finger lands,
    /// like the phone's. VIDEO rings it red.
    private func shutter(_ k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ShutterRing().f5(222, 132, 92, 92, k)
            if camera.mode == .video {
                Circle().strokeBorder(Color(hex: "#E0302A"), lineWidth: 3 * k).f5(234, 144, 68, 68, k)
            }
            ShutterKey(camera: camera) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.white, Color(hex: "#D9D9D6"), Color(hex: "#BDBDB9")],
                                             center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 34 * k))
                        .shadow(color: .black.opacity(0.9), radius: 1.5 * k, y: 2 * k)
                    if camera.mode == .video {
                        if camera.recording {
                            RoundedRectangle(cornerRadius: 3 * k).fill(Color(hex: "#E0302A")).frame(width: 22 * k, height: 22 * k)
                        } else {
                            Circle().fill(Color(hex: "#E0302A")).frame(width: 18 * k, height: 18 * k)
                        }
                    }
                }
                .overlay(Circle().strokeBorder(camera.focusLocked ? XA.orange : .clear, lineWidth: 2.5 * k).padding(-5 * k))
                .frame(width: 56 * k, height: 56 * k)
            }
            .accessibilityLabel(camera.mode == .video ? (camera.recording ? "Stop recording" : "Record") : "Take picture")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { camera.fullPress() }
            .position(x: 268 * k, y: 178 * k)
        }
    }

    private func zoomKey(_ t: String, by: Int, _ k: CGFloat) -> some View {
        Button {
            camera.setZoom(camera.zoom * (by > 0 ? 1.4 : 1 / 1.4), ramp: true)
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(t).font(F5.print(11 * k)).foregroundStyle(F5.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(DuoPress())
        .accessibilityLabel(by > 0 ? "Zoom in" : "Zoom out")
    }

    /// Flash on, auto, off: three stops of a slider, as on the F5.
    private func flash(_ k: CGFloat) -> some View {
        let order: [FlashSetting] = [.on, .auto, .off]
        let at = CGFloat(order.firstIndex(of: settings.flash) ?? 2)
        return ZStack(alignment: .topLeading) {
            Image(systemName: "bolt.fill").font(.system(size: 10 * k, weight: .bold)).foregroundStyle(F5.ink)
                .position(x: 31 * k, y: 191 * k)
            HStack(spacing: 1 * k) {
                Text("┐").font(F5.print(9 * k))
                Text("A").font(F5.print(12 * k))
                Text("┌").font(F5.print(9 * k))
            }
            .foregroundStyle(F5.ink)
            .position(x: 61 * k, y: 191 * k)
            Image(systemName: "bolt.slash.fill").font(.system(size: 10 * k, weight: .bold)).foregroundStyle(F5.ink)
                .position(x: 91 * k, y: 191 * k)
            Rectangle().fill(Color(hex: "#070708"))
                .overlay(Rectangle().strokeBorder(Color(hex: "#232325"), lineWidth: 1.5 * k))
                .f5(16, 203, 90, 24, k)
            RoundedRectangle(cornerRadius: 3 * k)
                .fill(LinearGradient(colors: [Color(hex: "#4A4A4D"), Color(hex: "#262628")], startPoint: .top, endPoint: .bottom))
                .overlay(Rectangle().fill(Color(hex: "#F2F2EE")).frame(width: 2 * k, height: 12 * k))
                .shadow(color: .black.opacity(0.9), radius: 1, y: 1)
                .f5(16 + at * 30, 205, 30, 20, k)
                .animation(.snappy(duration: 0.18), value: settings.flash)
            ForEach(0..<3, id: \.self) { i in
                Button {
                    settings.flash = order[i]
                    camera.flashChanged()
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .f5(16 + CGFloat(i) * 30, 197, 30, 34, k)
                .accessibilityLabel(order[i].label)
                .accessibilityAddTraits(settings.flash == order[i] ? .isSelected : [])
            }
            Text("FLASH").font(F5.print(8 * k)).foregroundStyle(F5.ink.opacity(0.55))
                .frame(width: 60 * k, alignment: .leading)
                .position(x: (16 + 30) * k, y: (236 + 5) * k)
        }
    }

    // MARK: PRO

    /// The four keys over PRO's panel: each jumps to a field, and again to its second one. LAMP
    /// turns the backlight off and on.
    private func proKeys(_ k: CGFloat) -> some View {
        let keys: [(String, ProField?, ProField?)] = [("SHTR·ISO", .shutter, .iso), ("EV·WB", .ev, .wb), ("AF·FOCUS", .af, .focus), ("LAMP", nil, nil)]
        return ZStack(alignment: .topLeading) {
            ForEach(keys.indices, id: \.self) { i in
                let key = keys[i]
                let x = 8 + CGFloat(i) * 35
                RoundKey(size: 13 * k, name: key.0.replacingOccurrences(of: "·", with: " and ")) {
                    if let a = key.1, let b = key.2 { proField = proField == a ? b : a } else { lamp.toggle() }
                }
                .position(x: (x + 20) * k, y: 9.5 * k)
                Text(key.0).font(F5.print(6 * k)).foregroundStyle(F5.ink)
                    .frame(width: 40 * k)
                    .position(x: (x + 20) * k, y: 22 * k)
            }
        }
    }

    /// The command wheel under the shutter: rolls the field the panel has selected.
    private func proWheel(_ k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            CommandWheel { by in proField.step(by, camera, settings) }
                .f5(206, 234, 124, 22, k)
                .accessibilityLabel("Command wheel, \(proField.name)")
                .accessibilityValue(proField.value(camera, settings))
                .accessibilityAdjustableAction { d in proField.step(d == .increment ? 1 : -1, camera, settings) }
            Text("◀  COMMAND  ▶").font(F5.print(6 * k)).foregroundStyle(F5.ink.opacity(0.5))
                .frame(width: 124 * k)
                .position(x: (206 + 62) * k, y: 263 * k)
        }
    }

    /// AE-L AF-L holds focus and exposure (press again to let go); AF-ON focuses.
    private func proSideKeys(_ k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Text("AE-L\nAF-L").font(F5.print(6 * k)).multilineTextAlignment(.center).foregroundStyle(F5.ink)
                .frame(width: 30 * k)
                .position(x: 267 * k, y: 115 * k)
            RoundKey(size: 15 * k, name: "AE-L AF-L") {
                if camera.halfPressed { camera.releaseHalfPress() } else { camera.halfPress() }
            }
            .position(x: 293.5 * k, y: 115.5 * k)
            RoundKey(size: 15 * k, name: "AF-ON") { camera.focus(at: camera.focusPoint ?? CGPoint(x: 0.5, y: 0.5)) }
                .position(x: 313.5 * k, y: 115.5 * k)
            Text("AF-ON").font(F5.print(6 * k)).foregroundStyle(F5.ink)
                .fixedSize()
                .position(x: 334 * k, y: 115 * k)
        }
    }

    // MARK: VIDEO

    /// VIDEO's wheel changes the tape, mid-take too: each tape is a segment of the take.
    private func tapeWheel(_ k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            CommandWheel { by in camera.stepTape(by) }
                .f5(206, 234, 124, 22, k)
                .accessibilityLabel("Tape wheel")
                .accessibilityValue(camera.videoLook.title)
                .accessibilityAdjustableAction { d in camera.stepTape(d == .increment ? 1 : -1) }
            Text("◀  TAPE  ▶").font(F5.print(6 * k)).foregroundStyle(F5.ink.opacity(0.5))
                .frame(width: 124 * k)
                .position(x: (206 + 62) * k, y: 263 * k)
        }
    }

    /// The tally light: red while recording.
    private func tally(_ k: CGFloat) -> some View {
        Circle().fill(camera.recording ? Color(hex: "#FF3B30") : Color(hex: "#3A1514"))
            .shadow(color: camera.recording ? Color(hex: "#FF3B30") : .clear, radius: 4 * k)
            .f5(224, 126, 8, 8, k)
    }
}

// MARK: the bottom half

/// The viewfinder, the data strip under it, and GRID, AF AREA, MENU and ROLL beside it, down by
/// the thumb.
struct DuoDeck: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @Binding var proField: ProField
    let lamp: Bool
    var onRoll: () -> Void
    var onCustomize: () -> Void
    var onLink: ((URL) -> Void)?
    var turnedBack: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            let k = min(g.size.width / 400, g.size.height / 270)
            ZStack(alignment: .topLeading) {
                // the viewfinder as big as the half allows: the keys beside it are a slim column
                DuoFinder(camera: camera, settings: settings, onLink: onLink, turnedBack: turnedBack).f5(3, 7, 337, 226, k)
                strip.f5(5, 238, 333, 26, k)
                RareKey(title: "GRID", value: settings.grid ? "ON" : "OFF", lit: settings.grid, k: k) { settings.grid.toggle() }
                    .f5(346, 110, 50, 32, k)
                RareKey(title: "AF AREA", value: settings.afArea.label.uppercased(), k: k) {
                    let all = AFArea.allCases
                    settings.afArea = all[((all.firstIndex(of: settings.afArea) ?? 0) + 1) % all.count]
                }
                .f5(346, 150, 50, 32, k)
                RareKey(title: "MENU", k: k, action: onCustomize)
                    .f5(346, 190, 50, 32, k)
                RareKey(title: "ROLL", value: camera.kept > 0 ? "\(camera.kept) KEPT" : nil, lit: camera.kept > 0, k: k, action: onRoll)
                    .f5(346, 230, 50, 32, k)
            }
            .frame(width: 400 * k, height: 270 * k, alignment: .topLeading)
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
    }

    /// The phone's screen strip, one row in every mode; PRO's panel is on the top half, so its
    /// strip here is the slim one.
    @ViewBuilder private var strip: some View {
        if camera.mode == .pro {
            DuoProStrip(camera: camera, settings: settings, lit: lamp)
        } else {
            LCDStrip(camera: camera, settings: settings, proField: $proField)
        }
    }
}

/// The viewfinder on the inner display. Its frames come upright for the phone's own portrait;
/// held open and tall, that portrait lies on its side, so the picture turns by what the camera's
/// rotation coordinator says for this screen (see Hold.finderTurn). What's drawn on the picture
/// (focus, frame lines, the grid) turns with it; what you read (DIGI's screen junk, a QR code)
/// stays upright.
struct DuoFinder: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    var onLink: ((URL) -> Void)?
    /// The back turned against the window (see DuoCameraView): the rotation coordinator's angle
    /// is for the window, so the picture turns that much less.
    var turnedBack: CGFloat = 0
    /// Pinch anchor: the zoom when the pinch started.
    @State private var pinchFrom: CGFloat?

    var body: some View {
        let turn = Hold.norm(Hold.finderTurn(preview: camera.front ? camera.previewFrontAngle : camera.previewBackAngle, front: camera.front) - turnedBack)
        let sideways = Int(turn.rounded()) % 180 != 0
        GeometryReader { g in
            // the picture's own box: as the frames come, before the turn
            let w = sideways ? g.size.height : g.size.width
            let h = sideways ? g.size.width : g.size.height
            ZStack {
                // FILM's eyepiece falls off into the body, not into a black box around it
                camera.mode == .film && settings.filmRecipe.xaFinder ? F5.body : Color.black
                if camera.authorized == false {
                    CameraDeniedNote(firstOpen: camera.needsFirstOpen)
                } else {
                    picture(w, h)
                        .frame(width: w, height: h)
                        .rotationEffect(.degrees(Double(turn)))
                        .frame(width: g.size.width, height: g.size.height)
                    if camera.mode == .digi {
                        if settings.digiOSD {
                            DigicamOSD(camera: camera, settings: settings).allowsHitTesting(false).transition(.opacity)
                        } else {
                            VStack { DigiOSD(camera: camera); Spacer() }.allowsHitTesting(false).transition(.opacity)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if CameraModel.readsCodes(camera.mode), let code = camera.qrCode {
                    QRChip(code: code, open: onLink).id(code)
                        .padding(.bottom, camera.mode == .digi && settings.digiOSD ? 54 : 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: camera.qrCode)
        }
        .background(PreviewAnchor(camera: camera))
        .clipped()
        .simultaneousGesture(MagnifyGesture()
            .onChanged { v in
                if pinchFrom == nil { pinchFrom = camera.zoom }
                camera.setZoom((pinchFrom ?? 1) * v.magnification)
            }
            .onEnded { _ in pinchFrom = nil })
    }

    /// The picture and what's drawn on it, in the frames' own orientation.
    private func picture(_ w: CGFloat, _ h: CGFloat) -> some View {
        let film = camera.mode == .film && settings.filmRecipe.xaFinder
        return Viewfinder(camera: camera)
            .overlay { if settings.grid && !film { GridLines() } }
            .overlay {
                if film {
                    XAFinderView(camera: camera, format: settings.filmRecipe.format, surround: F5.body, fadesTop: false)
                } else if camera.leavingFilm {
                    XAFinderView(camera: camera, format: settings.filmRecipe.format, leaving: true, surround: F5.body, fadesTop: false)
                } else {
                    FocusBracket(camera: camera)
                }
            }
            .overlay { FocusTapLayer(camera: camera, filmOpen: .constant(false)) }
            .overlay { ShutterBlinkView(camera: camera, settings: settings) }
    }
}

/// Reports which way the window stands and how big it is, whenever it is laid out (a turn, or
/// moving between iPhone Duo's displays, lays it out again), or its screen changes.
struct SceneOrientationReader: UIViewRepresentable {
    let changed: (UIInterfaceOrientation, CGSize) -> Void

    final class Reader: UIView {
        var changed: ((UIInterfaceOrientation, CGSize) -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); report() }
        override func layoutSubviews() { super.layoutSubviews(); report() }
        override func traitCollectionDidChange(_ previous: UITraitCollection?) {
            super.traitCollectionDidChange(previous); report()
        }
        private func report() {
            guard let w = window, let o = w.windowScene?.interfaceOrientation else { return }
            let size = w.bounds.size
            // not in the middle of a layout pass
            DispatchQueue.main.async { [changed] in changed?(o, size) }
        }
    }

    func makeUIView(context: Context) -> Reader {
        let v = Reader()
        v.isUserInteractionEnabled = false
        v.changed = changed
        return v
    }

    func updateUIView(_ uiView: Reader, context: Context) { uiView.changed = changed }
}

/// An empty view whose layer tells the camera which screen the viewfinder is on (see
/// CameraModel.previewJoined). It sits behind the viewfinder, never turned with it.
struct PreviewAnchor: UIViewRepresentable {
    let camera: CameraModel

    final class Anchor: UIView {
        var joined: ((CALayer) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { joined?(layer) }
        }
    }

    func makeUIView(context: Context) -> Anchor {
        let v = Anchor()
        v.isUserInteractionEnabled = false
        v.joined = { [weak camera] layer in camera?.previewJoined(layer) }
        return v
    }

    func updateUIView(_ uiView: Anchor, context: Context) {}
}

// MARK: parts

/// A key that goes down a point when pressed.
struct DuoPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 1 : 0)
            .brightness(configuration.isPressed ? -0.08 : 0)
    }
}

/// A small round rubber key, with room round it for a finger.
struct RoundKey: View {
    let size: CGFloat
    let name: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#A2A2A6"), Color(hex: "#5E5E62"), Color(hex: "#2E2E31")],
                                     center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: size * 0.62))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.9), radius: 1, y: 2)
                .frame(width: max(size, 34), height: max(size, 34))
                .contentShape(Circle())
        }
        .buttonStyle(DuoPress())
        .accessibilityLabel(name)
    }
}

/// One of the keys beside the viewfinder: a name, and what it is set to.
struct RareKey: View {
    let title: String
    var value: String? = nil
    var lit = false
    let k: CGFloat
    let action: () -> Void

    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 2 * k) {
                Text(title).font(F5.print(8 * k)).tracking(0.6 * k)
                    .foregroundStyle(lit ? XA.orange : F5.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let value {
                    Text(value).font(F5.print(6 * k)).foregroundStyle(F5.ink.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 5 * k)
                .fill(LinearGradient(colors: [Color(hex: "#3B3B3E"), Color(hex: "#222224")], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 5 * k).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
            .shadow(color: .black.opacity(0.9), radius: 1, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(DuoPress())
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "")
    }
}

/// BOOTH's sticker sheet, big enough to fill the film slot.
struct BigSheet: View {
    let layout: BoothLayout
    let k: CGFloat
    private let pink = Color(uiColor: BoothInk.pink), lilac = Color(uiColor: BoothInk.lilac), mint = Color(uiColor: BoothInk.mint)

    var body: some View {
        VStack(spacing: 0) {
            tiles.padding([.top, .horizontal], 4 * k)
            HStack {
                Text("♥ XA BOOTH").foregroundStyle(Color(uiColor: BoothInk.hot))
                Spacer(minLength: 2 * k)
                Text(layout.title).foregroundStyle(Color(uiColor: BoothInk.violet))
            }
            .font(.custom(BoothInk.font, fixedSize: 7 * k))
            .padding(.horizontal, 6 * k)
            .frame(height: 13 * k)
        }
        .frame(width: 132 * k, height: 87 * k)
        .background(Color.white)
        .id(layout)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    @ViewBuilder private var tiles: some View {
        switch layout {
        case .sheet:
            HStack(spacing: 2 * k) {
                tile(pink).frame(width: 82 * k)
                VStack(spacing: 2 * k) { tile(lilac); tile(mint) }
            }
        case .grid:
            VStack(spacing: 2 * k) {
                HStack(spacing: 2 * k) { tile(pink); tile(lilac) }
                HStack(spacing: 2 * k) { tile(mint); tile(pink) }
            }
        case .strip:
            HStack(spacing: 2 * k) { tile(pink); tile(lilac); tile(mint); tile(pink) }
        }
    }

    private func tile(_ c: Color) -> some View { Rectangle().fill(c) }
}

/// The grip: a cross-hatched panel down the right edge, curving away from the dial.
struct Grip: View {
    let k: CGFloat

    var body: some View {
        // One outline and one hatch: as two pieces, the rounded pad and the strip under it had a
        // seam where they met, and the pad's curve ran into the strip with a step.
        hatch
            .frame(width: 89 * k, height: 270 * k)
            .clipShape(GripShape())
            .allowsHitTesting(false)
    }

    private var hatch: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#151516")))
            let step = max(2, 4 * k)
            var p = Path()
            var x = -size.height
            while x < size.width + size.height {
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                p.move(to: CGPoint(x: x + size.height, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            ctx.stroke(p, with: .color(Color.white.opacity(0.035)), lineWidth: max(0.5, 0.8 * k))
        }
    }
}

/// The grip: the thumb pad at the top, curving down into the strip along the edge. In the
/// grip's 89 × 270 units, scaled to the frame it is given.
struct GripShape: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 89, sy = r.height / 270
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        var path = Path()
        path.move(to: p(0, 0))
        path.addLine(to: p(89, 0))
        path.addLine(to: p(89, 270))
        path.addLine(to: p(53, 270))
        path.addLine(to: p(53, 118))
        // down the strip's edge and out round the pad, with no corner where they meet
        path.addCurve(to: p(0, 34), control1: p(53, 72), control2: p(0, 82))
        path.closeSubpath()
        return path
    }
}

/// The dial's knurling: sixty ribs, alternately lit and shaded.
struct DialKnurl: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2), r = min(size.width, size.height) / 2
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(hex: "#1A1A1C")))
            for i in stride(from: 0, to: 60, by: 2) {
                let a0 = CGFloat(i) * 6 * .pi / 180, a1 = CGFloat(i + 1) * 6 * .pi / 180
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
                p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
                p.closeSubpath()
                ctx.fill(p, with: .color(Color(hex: "#2C2C2E")))
            }
        }
        .clipShape(Circle())
    }
}

/// The ring round the shutter: a dark band with fine ribs inside it.
struct ShutterRing: View {
    var body: some View {
        GeometryReader { g in
            let w = min(g.size.width, g.size.height)
            ZStack {
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2), r = min(size.width, size.height) / 2
                    for i in stride(from: 0, to: 90, by: 2) {
                        let a0 = CGFloat(i) * 4 * .pi / 180, a1 = CGFloat(i + 1) * 4 * .pi / 180
                        var p = Path()
                        p.move(to: c)
                        p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
                        p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
                        p.closeSubpath()
                        ctx.fill(p, with: .color(Color.white.opacity(0.04)))
                    }
                }
                .clipShape(Circle())
                Circle().strokeBorder(Color(hex: "#1C1C1E"), lineWidth: w * 11 / 92)
            }
            .frame(width: w, height: w)
        }
        .allowsHitTesting(false)
    }
}
