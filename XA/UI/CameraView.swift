import SwiftUI

/// The camera screen: a clean viewfinder on top, every control underneath it.
struct CameraView: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    var onRoll: () -> Void
    var onCustomize: () -> Void
    var onFilm: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            viewfinder
            if camera.mode == .digi { DigiRows(camera: camera, onFilm: onFilm) } else { ProRows(camera: camera) }
            ModeRow(camera: camera, onCustomize: onCustomize)
            ShutterRow(camera: camera, onRoll: onRoll)
        }
        .padding(.horizontal, 11)
        .padding(.bottom, 6)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
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
                    .overlay { if camera.flash { Color.white.opacity(0.7) } }
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct DigiRows: View {
    @ObservedObject var camera: CameraModel
    var onFilm: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            StackRow(stack: camera.stack, onTap: onFilm)
            HStack(spacing: 10) {
                Button(action: onFilm) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 53).background(XA.fill)
                }
                .buttonStyle(.plain).foregroundStyle(.white)
                .accessibilityLabel("See every film")
                FilmStrip(camera: camera)
            }
        }
    }
}

/// Every film as its box, in one strip: sims, looks, shapes. Tap to load; tap a loaded look
/// or shape again to take it off.
struct FilmStrip: View {
    @ObservedObject var camera: CameraModel
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilmCatalog.sims) { s in
                        tile(.sim(s), on: camera.stack.simID == s.id) { camera.stack.simID = camera.stack.simID == s.id ? nil : s.id }
                    }
                    divider
                    ForEach(Look.allCases.filter { $0 != .none }) { l in
                        tile(.look(l), on: camera.stack.look == l) { camera.stack.look = camera.stack.look == l ? .none : l }
                    }
                    divider
                    ForEach(FilmCatalog.shapes) { s in
                        tile(.shape(s), on: camera.stack.shape == s) { camera.stack.shape = camera.stack.shape == s ? .none : s }
                    }
                }
                .padding(.vertical, 3).padding(.horizontal, 2)
            }
            .onAppear { if let id = camera.stack.simID { proxy.scrollTo("sim-\(id)", anchor: .center) } }
        }
        .frame(height: 59)
    }
    private var divider: some View { Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 40) }
    private func tile(_ item: FilmItem, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            FilmBox(item: item, width: 80)
                .overlay(Rectangle().strokeBorder(on ? XA.orange : Color.clear, lineWidth: 2).padding(-3))
                .opacity(on ? 1 : 0.82)
        }
        .buttonStyle(.plain)
        .id(item.id)
        .accessibilityLabel(item.title)
    }
}

// MARK: PRO

private struct ProRows: View {
    @ObservedObject var camera: CameraModel
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Histogram(bins: camera.histogram).frame(width: 64, height: 26)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(camera.lenses) { l in
                        let on = abs(camera.zoom - l.factor) / l.factor < 0.08
                        Button { camera.setZoom(l.factor) } label: {
                            Text(on ? l.label + "×" : l.label).font(.system(size: 12, weight: .bold))
                                .frame(width: on ? 40 : 34, height: on ? 40 : 34)
                                .background(on ? Color.white : XA.fill, in: Circle())
                                .foregroundStyle(on ? Color.black : Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
                Color.clear.frame(width: 64, height: 26)
            }
            .frame(height: 40)
            ProStrip(camera: camera)
            Dial(camera: camera)
        }
    }
}

struct Histogram: View {
    let bins: [Float]
    var body: some View {
        GeometryReader { g in
            Path { p in
                guard bins.count > 1 else { return }
                let w = g.size.width / CGFloat(bins.count - 1)
                p.move(to: CGPoint(x: 0, y: g.size.height))
                for (i, b) in bins.enumerated() {
                    p.addLine(to: CGPoint(x: CGFloat(i) * w, y: g.size.height * (1 - CGFloat(b))))
                }
                p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                p.closeSubpath()
            }
            .fill(Color.white.opacity(0.55))
        }
    }
}

private struct ProStrip: View {
    @ObservedObject var camera: CameraModel
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ProControl.allCases) { c in
                let on = camera.proControl == c
                Button { camera.proControl = c } label: {
                    VStack(spacing: 2) {
                        Text(c.title).font(.system(size: 10, weight: .bold)).tracking(0.8)
                            .foregroundStyle(on ? XA.orange : XA.dim)
                        Text(camera.label(c)).font(XA.mono(14)).lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(on ? XA.orange : .white)
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(on ? XA.orange.opacity(0.14) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4).background(XA.strip)
    }
}

/// Tick dial for the selected PRO control. Drag sideways; each tick is one stop.
private struct Dial: View {
    @ObservedObject var camera: CameraModel
    @State private var start: Int?
    var body: some View {
        let d = camera.dial(camera.proControl)
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(-12...12, id: \.self) { i in
                let idx = d.index + i
                let valid = idx >= 0 && idx < d.count
                Rectangle()
                    .fill(i == 0 ? XA.orange : Color.white.opacity(valid ? (idx % 3 == 0 ? 0.7 : 0.3) : 0.08))
                    .frame(width: i == 0 ? 3 : 2, height: i == 0 ? 20 : (idx % 3 == 0 ? 16 : 8))
            }
        }
        .frame(maxWidth: .infinity).frame(height: 24)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { v in
                if start == nil { start = d.index }
                let steps = Int((-v.translation.width / 12).rounded())
                camera.setDial(camera.proControl, (start ?? 0) + steps)
            }
            .onEnded { _ in start = nil })
        .accessibilityLabel("\(camera.proControl.title) dial")
        .accessibilityValue(camera.label(camera.proControl))
        .accessibilityAdjustableAction { dir in
            let d = camera.dial(camera.proControl)
            camera.setDial(camera.proControl, d.index + (dir == .increment ? 1 : -1))
        }
    }
}

// MARK: shared rows

private struct ModeRow: View {
    @ObservedObject var camera: CameraModel
    var onCustomize: () -> Void
    var body: some View {
        HStack {
            RoundButton(action: onCustomize) { Image(systemName: "slider.horizontal.3").font(.system(size: 18)) }
                .accessibilityLabel("Customize")
            Spacer()
            HStack(spacing: 2) {
                ForEach(CaptureMode.allCases) { m in
                    let on = camera.mode == m
                    Button { withAnimation(.snappy) { camera.mode = m } } label: {
                        Text(m.title).font(XA.display(18)).tracking(0.6)
                            .padding(.horizontal, 18).padding(.vertical, 7)
                            .foregroundStyle(on ? (m == .digi ? Color(red: 0.16, green: 0.08, blue: 0) : .black) : Color.white.opacity(0.82))
                            .background(on ? (m == .digi ? XA.orange : Color.white) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3).background(XA.fill, in: Capsule())
            Spacer()
            Text(spec).font(XA.mono(12)).lineLimit(1)
                .padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44).background(XA.fill, in: Capsule())
        }
    }
    private var spec: String {
        if camera.mode == .digi {
            let s = Digicam.size(for: camera.photoSize == .zero ? CGSize(width: 4032, height: 3024) : camera.photoSize, megapixels: camera.settings.digiMegapixels)
            return "\(CaptureMode.megapixels(s))MP"
        }
        return "\(CaptureMode.megapixels(camera.photoSize))MP"
    }
}

private struct ShutterRow: View {
    @ObservedObject var camera: CameraModel
    var onRoll: () -> Void
    var body: some View {
        HStack(spacing: 28) {
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
            Button { camera.shoot() } label: {
                Capsule().fill(Color.white).frame(width: 118, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Take picture")
            RoundButton(size: 50, action: { camera.flip() }) { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 20, weight: .medium)) }
                .accessibilityLabel("Switch camera")
        }
        .frame(height: 76)
    }
}
