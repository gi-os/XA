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
    @State private var filmOpen = false
    /// Which way up the phone is held, so the film box can turn with it.
    @StateObject private var tilt = DeviceTilt()
    /// Pinch anchor: the zoom when the pinch started, so the gesture scales from there
    /// instead of compounding on the live value.
    @State private var pinchFrom: CGFloat?
    /// PRO: the panel field the command wheel changes.
    @State private var proField: ProField = .shutter
    /// The deck's sideways drag, for the ribbon to follow.
    @State private var ribbonDrag: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            // The tap layer is part of the view the gestures sit on: laid over it afterwards, it
            // swallowed every touch and the pinch and swipes never arrived.
            viewfinder
                .overlay { FocusTapLayer(camera: camera, filmOpen: $filmOpen) }
                .onReceive(NotificationCenter.default.publisher(for: .xaBackToCamera)) { _ in filmOpen = false }
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
                case .digi, .film:
                    if filmOpen { FilmControls(camera: camera, open: $filmOpen, onFilm: onFilm).transition(Self.rows) }
                case .video:
                    if filmOpen || camera.recording { VideoRows(camera: camera, open: $filmOpen, onFilm: onFilm).transition(Self.rows) }
                case .pro:
                    ProKeys(camera: camera, settings: settings, field: $proField, onCustomize: onCustomize).transition(Self.expand)
                case .booth:
                    EmptyView()
                }
            }
            .animation(.snappy(duration: 0.32), value: camera.mode)
            VStack(spacing: 8) {
                // PRO keeps settings and flash by the command wheel; the others have this row.
                if camera.mode != .pro {
                    ToolRow(camera: camera, settings: settings, onCustomize: onCustomize) { corner }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                ShutterRow(camera: camera, settings: settings, onRoll: onRoll)
                // Under the shutter, in the space the home bar leaves: the viewfinder keeps the room.
                ModeRibbon(camera: camera, modes: modes, drag: $ribbonDrag)
            }
            .animation(.snappy(duration: 0.3), value: camera.mode)
            .contentShape(Rectangle())
            // The deck: swipe sideways to change mode, like the iPhone camera; up opens the roll.
            // Drag sideways and the ribbon follows the finger: let go on the mode you want.
            .gesture(DragGesture(minimumDistance: 24)
                .onChanged { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if !camera.recording && abs(dx) > abs(dy) * 1.3 { ribbonDrag = dx }
                }
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if dy < -60 && abs(dy) > abs(dx) { onRoll() }
                    else if !camera.recording && abs(dx) > abs(dy) * 1.3 { ModeRibbon.land(drag: dx, modes, camera) }
                    withAnimation(.snappy(duration: 0.28)) { ribbonDrag = 0 }
                })
        }
        .padding(.horizontal, 11)
        // The shutter sits where the system camera's does, so thumbs find it without looking;
        // the mode ribbon fills the gap under it.
        .padding(.bottom, 6)
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
        } else if camera.mode.usesFilm && !filmOpen {
            FannedFilm(stack: camera.stack) { withAnimation(.snappy) { filmOpen = true } }
                // turned with the phone, it sits centred in the corner instead of leaning off it
                .frame(width: 80, height: 52, alignment: .center)
                .rotationEffect(.degrees(tilt.angle))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tilt.angle)
                .modifier(SwipeToStep(step: { camera.stack.push = 0; camera.stepSim($0) },
                                      vertical: camera.mode == .film ? { camera.stepPush($0) } : nil))
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else if camera.mode == .booth {
            // The sticker sheet's layout as a little card: tap or swipe it for the next one.
            SheetCard(layout: settings.boothLayout) { stepLayout(1) }
                .modifier(SwipeToStep { stepLayout($0) })
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else if camera.mode == .digi {
            MPMenu(camera: camera, settings: settings)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    /// PRO's keys open out of the screen as it grows, in the same motion, and fold back into it.
    static let expand: AnyTransition = .asymmetric(
        insertion: .modifier(active: Unfold(k: 0), identity: Unfold(k: 1)).animation(.spring(response: 0.42, dampingFraction: 0.86)),
        removal: .modifier(active: Unfold(k: 0), identity: Unfold(k: 1)).animation(.easeOut(duration: 0.2)))

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
        if camera.mode == .booth {
            // Sideways: the next skin setting. Up and down: the next frame.
            if horizontal { stepSkin(dx < 0 ? 1 : -1) }
            else {
                settings.boothDeco = settings.boothDeco.step(dy < 0 ? 1 : -1)
                camera.syncFrameSettings()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            return
        }
        withAnimation(.snappy) {
            if horizontal { camera.stepSim(dx < 0 ? 1 : -1) }
            else if camera.mode == .video {
                let all = VideoLook.allCases, n = all.count
                let i = all.firstIndex(of: camera.videoLook) ?? 0
                camera.videoLook = all[((i + (dy < 0 ? 1 : -1)) % n + n) % n]
                UISelectionFeedbackGenerator().selectionChanged()
            } else if camera.mode == .film { camera.stepPush(dy < 0 ? 1 : -1) }
            else { camera.stepLook(dy < 0 ? 1 : -1) }
        }
    }

    private func stepSkin(_ by: Int) {
        let all = BoothSkin.allCases, n = all.count
        let i = all.firstIndex(of: settings.boothSkin) ?? 0
        settings.boothSkin = all[((i + by) % n + n) % n]
        camera.syncFrameSettings()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func stepLayout(_ by: Int) {
        withAnimation(.snappy) { settings.boothLayout = settings.boothLayout.step(by) }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// The finder is the same 3:4 window in every mode; FILM shows its format with frame lines.
    private var finderAspect: CGFloat { 3 / 4 }

    /// FILM through the XA finder: the finder takes all the room above the screen strip.
    private var xaFinder: Bool { (camera.mode == .film || camera.leavingFilm) && settings.filmRecipe.xaFinder }

    @ViewBuilder private var viewfinder: some View {
        if xaFinder && camera.authorized != false {
            Viewfinder(camera: camera)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { XAFinderView(camera: camera, format: settings.filmRecipe.format, leaving: camera.leavingFilm) }
                .background(GeometryReader { g in
                    Color.black
                        .onAppear { camera.setFinderShape(g.size.height / max(g.size.width, 1)) }
                        .onChange(of: g.size) { _, s in camera.setFinderShape(s.height / max(s.width, 1)) }
                })
        } else {
            standardFinder
        }
    }

    @ViewBuilder private var standardFinder: some View {
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
                    .aspectRatio(finderAspect, contentMode: .fit)
                    .overlay { if settings.grid && camera.mode == .pro { GridLines() } }
                    .overlay {
                        // FILM looks through the XA's finder; the other modes keep the focus bracket
                        if camera.mode == .film && settings.filmRecipe.xaFinder {
                            XAFinderView(camera: camera, format: settings.filmRecipe.format)
                        } else {
                            FocusBracket(camera: camera)
                        }
                    }
                    // DIGI prints its settings across the top of the picture as plain text, like the
                    // camera did, clear of the date back in the bottom corner.
                    .overlay(alignment: .top) {
                        if camera.mode == .digi { DigiOSD(camera: camera).allowsHitTesting(false).transition(.opacity) }
                    }
                    .overlay { if camera.flash { Color.white.opacity(0.7) } }
            }
        }
        .aspectRatio(finderAspect, contentMode: .fit)
        .animation(.snappy(duration: 0.3), value: finderAspect)
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
                if camera.mode == .digi { RowPicker(row: $row) }
                FilmStrip(camera: camera, row: camera.mode == .film ? 0 : row, onPick: poke)
                    .id(row)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
            .contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance: 16).onEnded { v in
                guard abs(v.translation.height) > abs(v.translation.width), abs(v.translation.height) > 24 else { return }
                guard camera.mode == .digi else { return }
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
        let sim = stack.shownSim
        let second: FilmItem? = stack.effectiveShape.map { FilmItem.shape($0) } ?? (stack.look != .none ? FilmItem.look(stack.look) : nil)
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let sim { FilmBox(item: .sim(sim), width: 62) } else {
                        Rectangle().fill(XA.fill).frame(width: 62, height: 41).overlay(Text("NO SIM").font(XA.display(9)).foregroundStyle(XA.faint))
                    }
                }
                .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
                if let second {
                    FilmBox(item: second, width: 34).rotationEffect(.degrees(7)).offset(x: 42, y: 14)
                }
            }
            // the box sits square and in the middle, so turning with the phone pivots on its centre
            .frame(width: second == nil ? 62 : 80, height: 48, alignment: .topLeading)
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
                        ForEach(FilmCatalog.sims(for: camera.mode)) { s in
                            let on = FilmCatalog.sim(camera.stack.simID)?.id == s.id
                            tile(.sim(on ? (camera.stack.shownSim ?? s) : s), on: on) {
                                if !on { camera.stack.push = 0 }
                                camera.stack.simID = s.id
                            }
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
    var onRoll: () -> Void
    var body: some View {
        HStack(spacing: 28) {
            if settings.showRollButton { rollButton } else { Color.clear.frame(width: 50, height: 50) }
            shutter
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

/// The on-screen shutter fires the instant a finger lands. Modes change by swiping the deck
/// around it, never on the button, so nothing has to wait to find out what the finger meant.
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
    /// Up and down, when the box has a second axis (a film stock's push and pull): up is +1.
    var vertical: ((Int) -> Void)? = nil
    @State private var drag: CGFloat = 0
    @State private var lift: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: drag * 0.35, y: lift * 0.3)
            .rotationEffect(.degrees(Double(drag) * 0.04))
            .highPriorityGesture(DragGesture(minimumDistance: 12)
                .onChanged { v in
                    if abs(v.translation.width) > abs(v.translation.height) { drag = v.translation.width; lift = 0 }
                    else if vertical != nil { lift = v.translation.height; drag = 0 }
                }
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if abs(dx) > 28 && abs(dx) > abs(dy) { step(dx < 0 ? 1 : -1) }
                    else if let vertical, abs(dy) > 24 && abs(dy) > abs(dx) { vertical(dy < 0 ? 1 : -1) }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drag = 0; lift = 0 }
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


/// The way the phone is held, as the angle the screen's contents turn to stay upright. The app
/// itself stays in portrait; only the pieces that matter (the film box) turn.
final class DeviceTilt: ObservableObject {
    @Published private(set) var angle: Double = 0
    private var token: NSObjectProtocol?

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        token = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.update()
        }
        update()
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func update() {
        switch UIDevice.current.orientation {
        case .portrait: angle = 0
        case .landscapeLeft: angle = 90      // top of the phone to the left
        case .landscapeRight: angle = -90    // top of the phone to the right
        default: break                       // face up/down or upside down: keep the last
        }
    }
}


extension Notification.Name {
    /// The app went to the background: next time it opens, it opens on the camera.
    static let xaBackToCamera = Notification.Name("xaBackToCamera")
}


/// DIGI's settings printed on the finder: aperture, shutter and ISO as the camera reports them.
private struct DigiOSD: View {
    @ObservedObject var camera: CameraModel
    var body: some View {
        HStack {
            Text("F\(String(format: "%.1f", camera.aperture)) \(Self.shutter(camera.meterShutter))")
            Spacer()
            Text("ISO \(Int(camera.meterISO.rounded()))")
        }
        .font(.custom("Silkscreen-Regular", fixedSize: 18))
        .tracking(1)
        .foregroundStyle(Color(hex: "#F4F4F0"))
        .shadow(color: .black.opacity(0.55), radius: 0, x: 1.5, y: 1.5)
        .padding(.horizontal, 14).padding(.top, 12)
        // Drawn in from the top, line by line, like the menu on the screen below.
        .modifier(Wake(axis: .vertical))
    }
    static func shutter(_ s: Double) -> String {
        guard s > 0 else { return "" }
        return s >= 0.5 ? String(format: "%.1f\"", s) : "1/\(Int((1 / s).rounded()))"
    }
}

/// BOOTH's corner: the sticker sheet's layout drawn as a little white card.
struct SheetCard: View {
    let layout: BoothLayout
    var action: () -> Void
    private let pink = Color(uiColor: BoothInk.pink), lilac = Color(uiColor: BoothInk.lilac), mint = Color(uiColor: BoothInk.mint)

    var body: some View {
        Button(action: action) {
            tiles
                .padding(3)
                .frame(width: 62, height: 44)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.6), radius: 5, y: 4)
                .rotationEffect(.degrees(-4))
                .id(layout)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sticker sheet \(layout.letter)")
    }

    @ViewBuilder private var tiles: some View {
        switch layout {
        case .sheet:
            GeometryReader { g in
                HStack(spacing: 2) {
                    tile(pink).frame(width: (g.size.width - 2) * 2 / 3)
                    VStack(spacing: 2) { tile(lilac); tile(mint) }
                }
            }
        case .grid:
            VStack(spacing: 2) {
                HStack(spacing: 2) { tile(pink); tile(lilac) }
                HStack(spacing: 2) { tile(mint); tile(pink) }
            }
        case .strip:
            HStack(spacing: 2) { tile(pink); tile(lilac); tile(mint); tile(pink) }
        }
    }

    private func tile(_ c: Color) -> some View { RoundedRectangle(cornerRadius: 2).fill(c) }
}

/// Folds a view up into its top edge: 0 folded, 1 open.
private struct Unfold: ViewModifier {
    let k: CGFloat
    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: max(k, 0.001), anchor: .top)
            .opacity(Double(min(1, k * 3)))
    }
}
