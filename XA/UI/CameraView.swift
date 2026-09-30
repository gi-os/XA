import SwiftUI

/// The camera screen: a clean viewfinder on top, every control underneath it.
struct CameraView: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    var onRoll: () -> Void
    var onCustomize: () -> Void
    var onFilm: () -> Void
    var modes: [CaptureMode] = CaptureMode.allCases
    /// The film rows are open; folded, the loaded film sits in the mode row as a little box.
    @State private var filmOpen = true
    /// Pinch anchor: the zoom when the pinch started, so the gesture scales from there
    /// instead of compounding on the live value.
    @State private var pinchFrom: CGFloat?
    /// PRO: the panel field the command wheel changes.
    @State private var proField: ProField = .shutter

    var body: some View {
        VStack(spacing: 8) {
            // The tap layer is part of the view the gestures sit on: laid over it afterwards, it
            // swallowed every touch and the pinch and swipes never arrived.
            viewfinder
                .overlay { FocusTapLayer(camera: camera, filmOpen: $filmOpen) }
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded(swipe))
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { v in
                            if pinchFrom == nil { pinchFrom = camera.zoom }
                            camera.setZoom((pinchFrom ?? 1) * v.magnification)
                        }
                        .onEnded { _ in pinchFrom = nil }
                )
            LCDStrip(camera: camera, settings: settings, proField: $proField)
            ZStack {
                switch camera.mode {
                case .digi:
                    if filmOpen { FilmControls(camera: camera, open: $filmOpen, onFilm: onFilm).transition(Self.rows) }
                case .video:
                    if filmOpen || camera.recording { VideoRows(camera: camera, open: $filmOpen, onFilm: onFilm).transition(Self.rows) }
                case .pro:
                    ProKeys(camera: camera, settings: settings, field: $proField, onCustomize: onCustomize).transition(Self.rows)
                }
            }
            .animation(.snappy(duration: 0.32), value: camera.mode)
            VStack(spacing: 8) {
                // PRO keeps settings and flash by the command wheel; the others have this row.
                if camera.mode != .pro {
                    ToolRow(camera: camera, settings: settings, onCustomize: onCustomize) { corner }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                ShutterRow(camera: camera, settings: settings, modes: modes, onRoll: onRoll)
                    .padding(.top, 14)
            }
            .animation(.snappy(duration: 0.3), value: camera.mode)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 24).onEnded { v in
                if v.translation.height < -60 && abs(v.translation.height) > abs(v.translation.width) { onRoll() }
            })
        }
        .padding(.horizontal, 11)
        // The shutter sits where the system camera's does, so thumbs find it without looking.
        .padding(.bottom, 44)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    /// The corner of the tool row: the loaded film folded into an angled box (swipe it for the
    /// next one, tap to open the rows), or the resolution while the rows are open.
    @ViewBuilder private var corner: some View {
        if camera.mode == .video && !filmOpen && !camera.recording {
            FannedTape(look: camera.videoLook) { withAnimation(.snappy) { filmOpen = true } }
                .modifier(SwipeToStep { camera.stepTape($0) })
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else if camera.mode == .digi && !filmOpen {
            FannedFilm(stack: camera.stack) { withAnimation(.snappy) { filmOpen = true } }
                .modifier(SwipeToStep { camera.stepSim($0) })
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else if camera.mode == .digi {
            MPMenu(camera: camera, settings: settings)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    /// Mode rows: the old one drops away, the new one rises in after it.
    static let rows: AnyTransition = .asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity).animation(.snappy(duration: 0.32).delay(0.12)),
        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)).animation(.easeIn(duration: 0.16)))

    /// On the frame: left and right change the sim, up and down the look. In PRO, up opens the roll.
    private func swipe(_ v: DragGesture.Value) {
        guard pinchFrom == nil else { return }
        let dx = v.translation.width, dy = v.translation.height
        let horizontal = abs(dx) > abs(dy)
        guard max(abs(dx), abs(dy)) > 50 else { return }
        if camera.mode == .pro {
            if !horizontal && dy < 0 { onRoll() }
            return
        }
        withAnimation(.snappy) {
            if horizontal { camera.stepSim(dx < 0 ? 1 : -1) }
            else if camera.mode == .video {
                let all = VideoLook.allCases, n = all.count
                let i = all.firstIndex(of: camera.videoLook) ?? 0
                camera.videoLook = all[((i + (dy < 0 ? 1 : -1)) % n + n) % n]
                UISelectionFeedbackGenerator().selectionChanged()
            } else { camera.stepLook(dy < 0 ? 1 : -1) }
        }
    }

    @ViewBuilder private var viewfinder: some View {
        ZStack {
            Color.black
            if camera.authorized == false {
                VStack(spacing: 12) {
                    Text("XA needs the camera.").font(XA.display(18))
                    Text("Settings › XA › Camera").font(.system(size: 14)).foregroundStyle(XA.dim)
                }
                .foregroundStyle(.white)
            } else {
                Viewfinder(camera: camera)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay { if settings.grid && camera.mode == .pro { GridLines() } }
                    .overlay { FocusBracket(camera: camera) }
                    .overlay { if camera.reviewing { ReviewOverlay(camera: camera, settings: settings).transition(.opacity) } }
                    .overlay { if camera.flash { Color.white.opacity(0.7) } }
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct GridLines: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                for i in 1...2 {
                    let x = g.size.width * CGFloat(i) / 3, y = g.size.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: g.size.height))
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: g.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: DIGI

/// Three rows, SIM, LOOK and SHAPE: swipe up and down to change row, sideways to pick. After a
/// few seconds untouched they fold into one button showing what is loaded.
private struct FilmControls: View {
    @ObservedObject var camera: CameraModel
    @Binding var open: Bool
    var onFilm: () -> Void
    @State private var row = 0
    @State private var touched = Date()

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                StackRow(stack: camera.stack, onTap: { poke() }, onSlot: { i in withAnimation(.snappy) { row = i }; poke() })
                Button { withAnimation(.snappy) { open = false } } label: {
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 28).background(XA.fill)
                }
                .buttonStyle(.plain).foregroundStyle(XA.dim)
                .accessibilityLabel("Fold the film rows")
            }
            HStack(spacing: 8) {
                Button(action: onFilm) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 53).background(XA.fill)
                }
                .buttonStyle(.plain).foregroundStyle(.white)
                .accessibilityLabel("See every film")
                RowPicker(row: $row)
                FilmStrip(camera: camera, row: row, onPick: poke)
                    .id(row)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
            .contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance: 16).onEnded { v in
                guard abs(v.translation.height) > abs(v.translation.width), abs(v.translation.height) > 24 else { return }
                withAnimation(.snappy) { row = min(2, max(0, row + (v.translation.height < 0 ? 1 : -1))) }
                poke()
            })
        }
        .frame(height: 94)
        .onChange(of: camera.stack) { _, _ in poke() }
        .task(id: touched) {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled && Date().timeIntervalSince(touched) >= 3.9 { withAnimation(.easeInOut(duration: 0.3)) { open = false } }
        }
    }

    private func poke() { touched = Date() }
}

/// The folded film: the sim's box with the shape (or look) box tucked on it. Tap to open the rows.
struct FannedFilm: View {
    let stack: Stack
    var action: () -> Void
    var body: some View {
        let sim = FilmCatalog.sim(stack.simID)
        let second: FilmItem? = stack.effectiveShape.map { FilmItem.shape($0) } ?? (stack.look != .none ? FilmItem.look(stack.look) : nil)
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let sim { FilmBox(item: .sim(sim), width: 62) } else {
                        Rectangle().fill(XA.fill).frame(width: 62, height: 41).overlay(Text("NO SIM").font(XA.display(9)).foregroundStyle(XA.faint))
                    }
                }
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
                if let second {
                    FilmBox(item: second, width: 34).rotationEffect(.degrees(7)).offset(x: 42, y: 14)
                }
            }
            .frame(width: 80, height: 48, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Film: \(sim?.title ?? "no sim"). Show the film rows")
    }
}

/// SIM · LOOK · SHAPE, stacked; the lit one is the row showing.
private struct RowPicker: View {
    @Binding var row: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(["SIM", "LOOK", "SHAPE"].enumerated()), id: \.offset) { i, t in
                Button { withAnimation(.snappy) { row = i } } label: {
                    Text(t).font(XA.display(10)).tracking(0.8)
                        .foregroundStyle(row == i ? XA.orange : XA.faint)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 40, alignment: .leading)
    }
}

/// One row of boxes. Tap to load; tap a loaded look or shape again to take it off.
struct FilmStrip: View {
    @ObservedObject var camera: CameraModel
    var row: Int
    var onPick: () -> Void = {}
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    switch row {
                    case 0:
                        ForEach(FilmCatalog.sims) { s in
                            tile(.sim(s), on: FilmCatalog.sim(camera.stack.simID)?.id == s.id) { camera.stack.simID = s.id }
                        }
                    case 1:
                        ForEach(Look.allCases.filter { $0 != .none }) { l in
                            tile(.look(l), on: camera.stack.look == l) { camera.stack.look = camera.stack.look == l ? .none : l }
                        }
                    default:
                        ForEach(FilmCatalog.shapes) { s in
                            tile(.shape(s), on: camera.stack.shape == s) { camera.stack.shape = camera.stack.shape == s ? .none : s }
                        }
                    }
                }
                .padding(.vertical, 3).padding(.horizontal, 2)
            }
            .onAppear { scroll(proxy) }
            .onChange(of: camera.stack) { _, _ in withAnimation { scroll(proxy) } }
        }
        .frame(height: 59)
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        switch row {
        case 0: if let id = camera.stack.simID { proxy.scrollTo("sim-\(id)", anchor: .center) }
        case 1: if camera.stack.look != .none { proxy.scrollTo("look-\(camera.stack.look.rawValue)", anchor: .center) }
        default: if camera.stack.shape != .none { proxy.scrollTo("shape-\(camera.stack.shape.rawValue)", anchor: .center) }
        }
    }

    private func tile(_ item: FilmItem, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { action(); onPick() } label: {
            FilmBox(item: item, width: 80)
                .overlay(Rectangle().strokeBorder(on ? XA.orange : Color.clear, lineWidth: 2).padding(-3))
                .opacity(on ? 1 : 0.82)
        }
        .buttonStyle(.plain)
        .id(item.id)
        .accessibilityLabel(item.title)
    }
}

// MARK: VIDEO

/// Video looks as tapes and cartridges, and the sim they are shot through.
private struct VideoRows: View {
    @ObservedObject var camera: CameraModel
    @Binding var open: Bool
    var onFilm: () -> Void
    @State private var touched = Date()
    var body: some View {
        VStack(spacing: 6) {
            if camera.recording {
                TakeBar(segments: camera.segments, duration: camera.recordSeconds)
            } else {
            HStack(spacing: 6) {
                Text("SIM").font(XA.display(10)).foregroundStyle(XA.faint)
                Button(action: onFilm) {
                    Text(FilmCatalog.sim(camera.stack.simID)?.title ?? Sim.neutral.title).font(XA.display(12)).foregroundStyle(XA.orange)
                        .padding(.horizontal, 10).padding(.vertical, 5).background(XA.fill)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(VideoLook.allCases) { l in
                            let on = camera.videoLook == l
                            Button { camera.videoLook = l } label: {
                                FilmBox(item: .video(l), width: 80)
                                    .overlay(Rectangle().strokeBorder(on ? XA.orange : .clear, lineWidth: 2).padding(-3))
                                    .opacity(on ? 1 : 0.82)
                            }
                            .buttonStyle(.plain)
                            .id(l)
                            .accessibilityLabel(l.title)
                        }
                    }
                    .padding(.vertical, 3).padding(.horizontal, 2)
                }
                .onChange(of: camera.videoLook) { _, l in withAnimation { proxy.scrollTo(l, anchor: .center) } }
            }
            .frame(height: 59)
        }
        .frame(height: 94)
        // Like the film rows: untouched for a few seconds, the tapes fold into the box in the mode row.
        .onChange(of: camera.videoLook) { _, _ in touched = Date() }
        .simultaneousGesture(TapGesture().onEnded { touched = Date() })
        .task(id: touched) {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled && !camera.recording && Date().timeIntervalSince(touched) >= 3.9 { withAnimation(.easeInOut(duration: 0.3)) { open = false } }
        }
    }
}

/// The take as coloured segments, one per tape, growing as it records.
struct TakeBar: View {
    let segments: [TakeSegment]
    let duration: Double
    var body: some View {
        let spans = TakeSegment.spans(segments, duration: max(duration, 0.01))
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(spans.indices, id: \.self) { i in
                        Rectangle().fill(Color(hex: spans[i].0.color)).frame(width: max(2, (g.size.width - CGFloat(spans.count) * 2) * CGFloat(spans[i].1)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 8)
            HStack {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Spacer()
                Text(spans.map { $0.0.title }.joined(separator: " → ")).font(XA.display(10)).foregroundStyle(XA.dim).lineLimit(1)
            }
        }
        .frame(height: 26)
    }
}

// MARK: shared rows

/// DIGI's resolution, in the tool row's corner while the film rows are open.
private struct MPMenu: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    var body: some View { mpMenu }

    private var mpMenu: some View {
            Menu {
                ForEach(AppSettings.digiOptions, id: \.self) { mp in
                    Button { settings.digiMegapixels = mp; camera.applyResolution() } label: {
                        if mp == settings.digiMegapixels { Label("\(mp)MP", systemImage: "checkmark") } else { Text("\(mp)MP") }
                    }
                }
            } label: {
                Text(spec).font(XA.mono(12)).lineLimit(1).foregroundStyle(.white)
                    .padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44).background(XA.fill, in: Capsule())
            }
            .accessibilityLabel("Resolution \(spec)")
    }
    private var spec: String { "\(settings.digiMegapixels)MP" }
}

private struct ShutterRow: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    var modes: [CaptureMode]
    var onRoll: () -> Void
    var body: some View {
        HStack(spacing: 22) {
            if settings.showRollButton { rollButton } else { Color.clear.frame(width: 50, height: 50) }
            ModeCollar(camera: camera, modes: modes) { shutter }
            if settings.showFlipButton {
                RoundButton(size: 50, action: { camera.flip() }) { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 20, weight: .medium)) }
                    .accessibilityLabel("Switch camera")
            } else { Color.clear.frame(width: 50, height: 50) }
        }
        .frame(height: 76)
    }

    private var shutter: some View {
            ShutterKey(camera: camera) {
                if camera.mode == .video {
                    ZStack {
                        Capsule().fill(camera.recording ? Color.red : Color.white)
                        if camera.recording {
                            Text(Library.clock(camera.recordSeconds)).font(XA.mono(16)).foregroundStyle(.white)
                        } else {
                            Circle().fill(Color.red).frame(width: 22, height: 22)
                        }
                    }
                    .frame(width: 118, height: 40)
                } else {
                    Capsule().fill(Color.white).frame(width: camera.halfPressed ? 112 : 118, height: camera.halfPressed ? 36 : 40)
                        .overlay(Capsule().strokeBorder(camera.focusLocked ? XA.orange : .clear, lineWidth: 3).padding(-6))
                        .frame(width: 118, height: 40)
                }
            }
            .accessibilityLabel(camera.mode == .video ? (camera.recording ? "Stop recording" : "Record") : "Take picture")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { camera.fullPress() }
    }

    private var rollButton: some View {
            Button(action: onRoll) {
                ZStack {
                    Rectangle().fill(XA.fill)
                    if let img = camera.lastShot { Image(uiImage: img).resizable().scaledToFill() }
                    if camera.developing > 0 { ProgressView().tint(.white) }
                }
                .frame(width: 50, height: 50).clipped()
                .overlay(Rectangle().strokeBorder(Color.white, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open the roll")
    }
}

/// The on-screen shutter fires the instant a finger lands. Modes change on the collar round it,
/// never on the button, so nothing has to wait to find out what the finger meant.
private struct ShutterKey<Label: View>: View {
    @ObservedObject var camera: CameraModel
    @ViewBuilder var label: () -> Label
    @State private var down = false
    var body: some View {
        label().contentShape(Rectangle())
            .scaleEffect(down ? 0.95 : 1)
            .animation(.snappy(duration: 0.1), value: down)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !down { down = true; camera.fullPress() } }
                .onEnded { _ in down = false })
    }
}

/// Tap to aim focus; the first tap folds the film rows if they are open. Double-tap flips.
private struct FocusTapLayer: View {
    @ObservedObject var camera: CameraModel
    @Binding var filmOpen: Bool
    var body: some View {
        GeometryReader { g in
            Color.clear.contentShape(Rectangle())
                .onTapGesture(count: 2) { camera.flip(); UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                .simultaneousGesture(SpatialTapGesture().onEnded { v in
                    if filmOpen { withAnimation(.snappy) { filmOpen = false }; return }
                    let p = CGPoint(x: v.location.x / max(g.size.width, 1), y: v.location.y / max(g.size.height, 1))
                    camera.focus(at: p)
                })
                .onLongPressGesture(minimumDuration: 0.6) { camera.resetFocus() }
        }
    }
}

/// Four thin corners where focus is aimed: orange while it hunts, white once locked. Fades when idle.
private struct FocusBracket: View {
    @ObservedObject var camera: CameraModel
    @State private var visible = false
    var body: some View {
        GeometryReader { g in
            if let p = camera.focusPoint, visible || camera.halfPressed {
                let s: CGFloat = 54
                Corners().stroke(camera.focusLocked ? Color.white : XA.orange, lineWidth: 1.5)
                    .frame(width: s, height: s)
                    .position(x: p.x * g.size.width, y: p.y * g.size.height)
                    .animation(.snappy, value: p)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: camera.focusPoint) { _, _ in flash() }
        .onChange(of: camera.focusLocked) { _, _ in flash() }
    }
    private func flash() {
        visible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { if !camera.halfPressed { withAnimation(.easeOut(duration: 0.3)) { visible = false } } }
    }
}

private struct Corners: Shape {
    func path(in r: CGRect) -> Path {
        let l: CGFloat = r.width * 0.28
        var p = Path()
        for (c, dx, dy) in [(CGPoint(x: r.minX, y: r.minY), 1.0, 1.0), (CGPoint(x: r.maxX, y: r.minY), -1.0, 1.0),
                            (CGPoint(x: r.minX, y: r.maxY), 1.0, -1.0), (CGPoint(x: r.maxX, y: r.maxY), -1.0, -1.0)] {
            p.move(to: CGPoint(x: c.x + l * CGFloat(dx), y: c.y)); p.addLine(to: c); p.addLine(to: CGPoint(x: c.x, y: c.y + l * CGFloat(dy)))
        }
        return p
    }
}


/// Swipe a film (or tape) box sideways to load the next or previous one; a tap still does
/// whatever the box does. The box follows the finger a little, then springs back.
struct SwipeToStep: ViewModifier {
    var step: (Int) -> Void
    @State private var drag: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: drag * 0.35)
            .rotationEffect(.degrees(Double(drag) * 0.04))
            .highPriorityGesture(DragGesture(minimumDistance: 12)
                .onChanged { v in if abs(v.translation.width) > abs(v.translation.height) { drag = v.translation.width } }
                .onEnded { v in
                    let dx = v.translation.width
                    if abs(dx) > 28 && abs(dx) > abs(v.translation.height) { step(dx < 0 ? 1 : -1) }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drag = 0 }
                })
            .accessibilityAction(named: "Next") { step(1) }
            .accessibilityAction(named: "Previous") { step(-1) }
    }
}

/// The loaded tape, folded into the mode row the way the film box is in DIGI.
struct FannedTape: View {
    let look: VideoLook
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            FilmBox(item: .video(look), width: 62)
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
                .frame(width: 80, height: 48, alignment: .topLeading)
                .id(look)
                .transition(.push(from: .trailing))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.25), value: look)
        .accessibilityLabel("Tape: \(look.title)")
    }
}

/// DIGI's instant review: the shot held on the LCD for a moment, soft and scanned, with its
/// file number, while an orange bar drains. Half-press (or shoot again) to skip it.
private struct ReviewOverlay: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @State private var left: CGFloat = 1
    var body: some View {
        ZStack(alignment: .bottom) {
            Canvas { ctx, size in
                var y: CGFloat = 0
                var p = Path()
                while y < size.height { p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += 3 }
                ctx.fill(p, with: .color(.black.opacity(0.22)))
            }
            VStack(spacing: 4) {
                Rectangle().fill(XA.orange).frame(height: 3)
                    .scaleEffect(x: left, anchor: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("▶ " + camera.reviewFile).foregroundStyle(XA.orange)
                    Spacer()
                    Text("\(settings.digiMegapixels)MP · FINE · \((FilmCatalog.sim(camera.stack.simID) ?? Sim.neutral).title.uppercased())")
                        .foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                }
                .font(XA.mono(10))
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.linear(duration: CameraModel.reviewSeconds)) { left = 0 } }
    }
}
