import SwiftUI

/// DIGI's screen, the way a 2005 pocket digicam filled its LCD: white rounded type with a black
/// edge, cyan button hints, and a lot of junk, every piece of it live.
struct DigicamOSD: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @AppStorage("digiFileNo") private var fileNo = 1
    @State private var battery: Float = -1
    @State private var free: Int64 = 0
    @State private var blink = false
    private let cyan = Color(red: 0.37, green: 0.84, blue: 1)

    var body: some View {
        GeometryReader { g in
            let k = g.size.width / 390          // laid out on a 390-wide screen
            ZStack {
                // top row: battery, record mode + size + quality, folder + shots left + card
                HStack(alignment: .center, spacing: 0) {
                    HStack(spacing: 5 * k) {
                        BatteryIcon(level: battery).frame(width: 24 * k, height: 13 * k)
                            .opacity(battery >= 0 && battery < 0.15 && blink ? 0.2 : 1)
                        osd(minutes, 17 * k) + Text("min").font(font(11 * k))
                    }
                    Spacer()
                    HStack(spacing: 6 * k) {
                        Image(systemName: "camera").font(.system(size: 13 * k, weight: .bold))
                        osd("\(settings.digiMegapixels)M", 15 * k)
                        osd(settings.crunch >= 0.7 ? "FINE" : "STD", 12 * k)
                    }
                    Spacer()
                    HStack(spacing: 6 * k) {
                        osd("101", 12 * k).padding(.horizontal, 3 * k)
                            .overlay(RoundedRectangle(cornerRadius: 2 * k).stroke(Color.white, lineWidth: 1.5 * k).shadow(color: .black, radius: 0, x: 1, y: 1))
                        osd("\(shotsLeft)", 16 * k)
                        CardIcon(saving: camera.developing > 0 && blink).frame(width: 13 * k, height: 18 * k)
                    }
                }
                .padding(.horizontal, 12 * k)
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, 10 * k)

                // left column: flash, white balance, ISO, exposure
                VStack(alignment: .leading, spacing: 7 * k) {
                    HStack(spacing: 3 * k) {
                        Image(systemName: settings.flash == .off ? "bolt.slash.fill" : "bolt.fill").font(.system(size: 13 * k, weight: .bold))
                        if settings.flash == .auto { osd("AUTO", 10 * k) }
                    }
                    osd("AWB", 11 * k)
                    osd("ISO \(isoLabel)", 11 * k)
                    osd(camera.ev == 0 ? "±0.0EV" : String(format: "%+.1fEV", camera.ev), 11 * k)
                    if camera.zoom < 0.95 { Image(systemName: "camera.macro").font(.system(size: 13 * k, weight: .bold)) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 12 * k).padding(.top, 40 * k)

                // right column: histogram and the W–T zoom bar
                VStack(alignment: .trailing, spacing: 8 * k) {
                    Histo(bins: camera.histogram).frame(width: 56 * k, height: 22 * k)
                    VStack(spacing: 3 * k) {
                        osd("W", 10 * k)
                        ZoomBar(fraction: zoomFraction, optical: opticalFraction).frame(width: 6 * k, height: 70 * k)
                        osd("T", 10 * k)
                    }
                    osd(String(format: "%.1f×", camera.zoom * camera.zoomMultiplier), 11 * k)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 12 * k).padding(.top, 40 * k)

                // middle: AF corners and the spot; green and locked on a half-press
                ZStack {
                    if camera.halfPressed {
                        Rectangle().stroke(Color(red: 0.22, green: 0.88, blue: 0.35), lineWidth: 2.5 * k)
                            .shadow(color: .black, radius: 0, x: 1, y: 1)
                    } else if camera.focusPoint == nil {
                        AFCorners().stroke(Color.white, lineWidth: 2 * k).shadow(color: .black, radius: 0, x: 1, y: 1)
                    }
                    Cross().stroke(Color.white, lineWidth: 1.5 * k).frame(width: 10 * k, height: 10 * k).shadow(color: .black, radius: 0, x: 1, y: 1)
                }
                .frame(width: 46 * k, height: 38 * k)

                // camera shake: a hand that flashes when the shutter is slower than about 1/30
                if camera.meterShutter > 1.0 / 30 {
                    Image(systemName: "hand.raised.fill").font(.system(size: 17 * k, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0.81, blue: 0.18))
                        .shadow(color: .black, radius: 0, x: 1, y: 1)
                        .opacity(blink ? 1 : 0.25)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.leading, 12 * k)
                }

                // the half-press read-out
                if camera.halfPressed {
                    osd("F\(String(format: "%.1f", camera.aperture))  \(DigiOSD.shutter(camera.meterShutter))", 17 * k)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, 70 * k).padding(.bottom, 52 * k)
                }

                // the button guide, then the next file and the clock
                VStack(spacing: 5 * k) {
                    HStack(spacing: 18 * k) {
                        Text("◀▶ SIM").font(font(10 * k)).foregroundStyle(cyan)
                        Text("▲ ROLL").font(font(10 * k)).foregroundStyle(cyan)
                    }
                    .shadow(color: Color(red: 0, green: 0.23, blue: 0.33), radius: 0, x: 1, y: 1)
                    TimelineView(.everyMinute) { t in
                        HStack(spacing: 12 * k) {
                            osd("101-" + String(format: "%04d", fileNo % 10000), 13 * k)
                            osd(Self.day(t.date), 13 * k)
                            osd(Self.clock(t.date), 13 * k)
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 12 * k).padding(.bottom, 9 * k)
            }
            .foregroundStyle(.white)
            .compositingGroup()
            .keyline()
        }
        .modifier(Wake(axis: .vertical))
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            refresh()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in blink.toggle() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in refresh() }
        .onChange(of: camera.lastShot) { _, _ in fileNo += 1; refresh() }
    }

    // MARK: live values

    /// The phone's battery as a 2005 InfoLithium would report it: minutes, in fives.
    private var minutes: String {
        guard battery >= 0 else { return "—" }
        return "\(Int((battery * 120 / 5).rounded()) * 5)"
    }
    /// Shots that still fit, from the phone's free space and DIGI's photo size.
    private var shotsLeft: Int {
        let per = Int64(max(1, settings.digiMegapixels)) * 420_000
        return free > 0 ? Int(min(9999, free / per)) : 0
    }
    private var isoLabel: String {
        let iso = camera.meterISO
        let steps: [Float] = [100, 200, 400, 800, 1600, 3200]
        return "\(Int(steps.min { abs(log2($0 / max(iso, 1))) < abs(log2($1 / max(iso, 1))) } ?? 100))"
    }
    private var zoomFraction: CGFloat {
        let z = camera.zoom * camera.zoomMultiplier
        return CGFloat(min(1, max(0, log(Double(z) / 0.5) / log(20))))
    }
    private var opticalFraction: CGFloat {
        let top = camera.lenses.map { $0.factor }.max() ?? 1
        return CGFloat(min(1, max(0, log(Double(top) / 0.5) / log(20))))
    }

    private func refresh() {
        let b = UIDevice.current.batteryLevel
        battery = b
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
        return String(format: "%d:%02d%@", h % 12 == 0 ? 12 : h % 12, c.minute ?? 0, h < 12 ? "AM" : "PM")
    }

    // MARK: type

    private func font(_ size: CGFloat) -> Font { .custom("Nunito-Black", fixedSize: size) }
    /// White rounded type with the black keyline the LCD drew round every character.
    private func osd(_ s: String, _ size: CGFloat) -> Text {
        Text(s).font(font(size))
    }
}

// The keyline: four hard shadows round the type and icons.
private struct Keyline: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black, radius: 0, x: 1.2, y: 1.2)
            .shadow(color: .black, radius: 0, x: -1, y: -1)
    }
}
extension View { fileprivate func keyline() -> some View { modifier(Keyline()) } }

private struct BatteryIcon: View {
    let level: Float
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: h * 0.2).stroke(Color.white, lineWidth: h * 0.16).frame(width: w * 0.88)
                Rectangle().fill(Color.white).frame(width: w * 0.08, height: h * 0.42).offset(x: w * 0.9)
                Rectangle().fill(level >= 0 && level < 0.15 ? Color(red: 1, green: 0.3, blue: 0.25) : Color.white)
                    .frame(width: max(0, w * 0.7 * CGFloat(level < 0 ? 1 : level)), height: h * 0.5).offset(x: w * 0.09)
            }
            .frame(height: h)
        }
        .keyline()
    }
}

private struct CardIcon: View {
    let saving: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            Path { p in
                p.move(to: CGPoint(x: 1, y: 1)); p.addLine(to: CGPoint(x: w * 0.68, y: 1)); p.addLine(to: CGPoint(x: w - 1, y: h * 0.28))
                p.addLine(to: CGPoint(x: w - 1, y: h - 1)); p.addLine(to: CGPoint(x: 1, y: h - 1)); p.closeSubpath()
            }
            .stroke(saving ? Color(red: 1, green: 0.3, blue: 0.25) : Color.white, lineWidth: 1.8)
        }
        .keyline()
    }
}

private struct Histo: View {
    let bins: [Float]
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(Color.black.opacity(0.35))
                Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1)
                if !bins.isEmpty {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(bins.indices, id: \.self) { i in
                            Rectangle().fill(Color.white.opacity(0.9)).frame(height: max(0.5, CGFloat(bins[i]) * (g.size.height - 3)))
                        }
                    }
                    .padding(1.5)
                }
            }
        }
    }
}

private struct ZoomBar: View {
    let fraction: CGFloat
    let optical: CGFloat
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                Rectangle().stroke(Color.white, lineWidth: 1.5)
                // the digital part of the range, shaded
                Rectangle().fill(Color.white.opacity(0.25)).frame(height: g.size.height * (1 - optical)).frame(maxHeight: .infinity, alignment: .top)
                Rectangle().fill(Color.white).frame(height: max(2, g.size.height * fraction))
            }
        }
        .keyline()
    }
}

private struct AFCorners: Shape {
    func path(in r: CGRect) -> Path {
        let l = min(r.width, r.height) * 0.3
        var p = Path()
        for (c, dx, dy) in [(CGPoint(x: r.minX, y: r.minY), 1.0, 1.0), (CGPoint(x: r.maxX, y: r.minY), -1.0, 1.0),
                            (CGPoint(x: r.minX, y: r.maxY), 1.0, -1.0), (CGPoint(x: r.maxX, y: r.maxY), -1.0, -1.0)] {
            p.move(to: CGPoint(x: c.x + l * CGFloat(dx), y: c.y)); p.addLine(to: c); p.addLine(to: CGPoint(x: c.x, y: c.y + l * CGFloat(dy)))
        }
        return p
    }
}

private struct Cross: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}
