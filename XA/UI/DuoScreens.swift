import SwiftUI

// MARK: the screen's menu

/// One line of the top screen's menu: a setting's name, the values SELECT steps through, the one
/// it has now, and what SET does to keep another.
struct DuoItem {
    let name: String
    let values: [String]
    let current: Int
    let apply: (Int) -> Void
}

/// What MODE, SELECT and SET reach in each mode. Every line is a real setting, the same one the
/// phone layout changes somewhere else (PRO has its own panel).
enum DuoMenu {
    static func items(_ c: CameraModel, _ s: AppSettings) -> [DuoItem] {
        switch c.mode {
        case .digi:
            let sizes = AppSettings.digiOptions
            return [
                DuoItem(name: "SIZE", values: sizes.map { "\($0)MP" }, current: sizes.firstIndex(of: s.digiMegapixels) ?? 0) { i in
                    s.digiMegapixels = sizes[i]
                    c.applyResolution()
                },
                date(s.date) { s.date = $0 },
                toggle("SCREEN", s.digiOSD) { s.digiOSD = $0 },
                toggle("SOUND", s.sounds) { s.sounds = $0 },
            ]
        case .film:
            let pushes = Array(FilmStock.pushRange)
            let formats = FilmFormat.allCases
            return [
                DuoItem(name: "PUSH", values: pushes.map { $0 > 0 ? "+\($0)" : "\($0)" }, current: pushes.firstIndex(of: c.stack.push) ?? 0) { i in
                    var st = c.stack
                    st.push = pushes[i]
                    c.stack = st
                },
                DuoItem(name: "FORMAT", values: formats.map { $0.title }, current: formats.firstIndex(of: s.filmRecipe.format) ?? 0) { i in
                    var r = s.filmRecipe
                    r.format = formats[i]
                    s.filmRecipe = r
                },
                DuoItem(name: "FINDER", values: ["XA", "PLAIN"], current: s.filmRecipe.xaFinder ? 0 : 1) { i in
                    var r = s.filmRecipe
                    r.xaFinder = i == 0
                    s.filmRecipe = r
                },
                date(s.filmDate) { s.filmDate = $0 },
            ]
        case .video:
            let tapes = VideoLook.shelf
            let sims = FilmCatalog.sims(for: .video)
            let loaded = c.stack.simID ?? Sim.neutral.id
            return [
                DuoItem(name: "TAPE", values: tapes.map { $0.title }, current: tapes.firstIndex(of: c.videoLook) ?? 0) { i in
                    c.videoLook = tapes[i]
                },
                DuoItem(name: "SIM", values: sims.map { $0.title }, current: sims.firstIndex { $0.id == loaded } ?? 0) { i in
                    var st = c.stack
                    st.simID = sims[i].id
                    c.stack = st
                },
            ]
        case .booth:
            let skins = BoothSkin.allCases, frames = BoothDeco.allCases, sheets = BoothLayout.allCases
            return [
                DuoItem(name: "SKIN", values: skins.map { $0.title }, current: skins.firstIndex(of: s.boothSkin) ?? 0) { i in
                    s.boothSkin = skins[i]
                    c.syncFrameSettings()
                },
                DuoItem(name: "FRAME", values: frames.map { $0.title }, current: frames.firstIndex(of: s.boothDeco) ?? 0) { i in
                    s.boothDeco = frames[i]
                    c.syncFrameSettings()
                },
                DuoItem(name: "SHEET", values: sheets.map { $0.title }, current: sheets.firstIndex(of: s.boothLayout) ?? 0) { i in
                    s.boothLayout = sheets[i]
                },
            ]
        case .pro:
            return []
        }
    }

    private static func toggle(_ name: String, _ on: Bool, _ set: @escaping (Bool) -> Void) -> DuoItem {
        DuoItem(name: name, values: ["ON", "OFF"], current: on ? 0 : 1) { i in set(i == 0) }
    }

    /// The date back: along the frame, in the corner, or off.
    private static func date(_ d: DateConfig, _ set: @escaping (DateConfig) -> Void) -> DuoItem {
        let places: [DatePlacement] = [.follow, .corner, .off]
        return DuoItem(name: "DATE", values: ["FRAME", "CORNER", "OFF"], current: places.firstIndex(of: d.placement) ?? 0) { i in
            var n = d
            n.placement = places[i]
            set(n)
        }
    }
}

// MARK: the top screen

/// The top screen: the setting MODE points at, its place in the list, and its value, which
/// blinks while SELECT has changed it and SET hasn't kept it. Each mode has its own glass, as on
/// the phone: DIGI's VCR blue, FILM's green LCD, VIDEO's amber camcorder panel, BOOTH's candy.
struct DuoScreen: View {
    @ObservedObject var camera: CameraModel
    let name: String
    let index: String
    let value: String
    let blinking: Bool
    let k: CGFloat

    private static let vcrBlue = Color(hex: "#1D2FAE")
    private static let vcrWhite = Color(hex: "#ECEBE6")
    private static let lcdInk = Color(hex: "#1B2216")
    private static let amberInk = Color(hex: "#2A1406")
    private static let hot = Color(uiColor: BoothInk.hot)
    private static let violet = Color(uiColor: BoothInk.violet)

    var body: some View {
        ZStack {
            Rectangle().fill(Color(hex: "#070708"))
                .overlay(Rectangle().strokeBorder(Color(hex: "#2A2A2C"), lineWidth: 2 * k))
            ZStack {
                glass
                readings
            }
            .padding(4 * k)
            .clipped()
            .id(camera.mode)
            .transition(.opacity)
        }
    }

    @ViewBuilder private var glass: some View {
        switch camera.mode {
        case .digi:
            Self.vcrBlue.overlay(Rectangle().strokeBorder(Color(hex: "#4F8EE0"), lineWidth: 1))
        case .film:
            GreenPanel()
        case .video:
            LitPanel(center: Color(hex: "#FFE9BD"), mid: Color(hex: "#FFC86F"), edge: Color(hex: "#E59A3E"),
                     glow: Color(red: 1, green: 0.67, blue: 0.27).opacity(0.5))
        case .booth:
            LinearGradient(colors: [Color(hex: "#FFD1E6"), Color(hex: "#FFE9F3"), Color(hex: "#D9F6EA")], startPoint: .leading, endPoint: .trailing)
        case .pro:
            Color.clear
        }
    }

    @ViewBuilder private var readings: some View {
        switch camera.mode {
        case .digi: digi
        case .film: film
        case .video: video
        case .booth: booth
        case .pro: EmptyView()
        }
    }

    /// Off-white blocks with blocky blue capitals, a VCR's menu.
    private var digi: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 2 * k) {
                chip(">" + name, 9)
                Spacer(minLength: 0)
                Text(index).font(.custom("Silkscreen-Regular", fixedSize: 9 * k)).foregroundStyle(Self.vcrWhite)
                    .padding(.top, 2 * k)
            }
            Spacer(minLength: 0)
            chip(value, 15).blinks(blinking)
        }
        .padding(5 * k)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func chip(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(.custom("Silkscreen-Regular", fixedSize: size * k)).tracking(0.6 * k)
            .foregroundStyle(Self.vcrBlue)
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, 4 * k).padding(.vertical, 2 * k)
            .background(Self.vcrWhite)
    }

    /// Dot-matrix type on the reflective LCD, its unlit cells faintly there.
    private var film: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                dots(">" + name, 11)
                Spacer(minLength: 2 * k)
                dots(index, 11)
            }
            Spacer(minLength: 0)
            ZStack(alignment: .leading) {
                dots(String(repeating: "8", count: max(1, value.count)), 20).opacity(0.07)
                dots(value, 20).blinks(blinking)
            }
        }
        .padding(.horizontal, 7 * k).padding(.vertical, 5 * k)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func dots(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(.custom("Silkscreen-Regular", fixedSize: size * k)).foregroundStyle(Self.lcdInk)
            .shadow(color: Color(red: 0.09, green: 0.13, blue: 0.05).opacity(0.25), radius: 0, x: 1.2 * k, y: 1.2 * k)
            .lineLimit(1).minimumScaleFactor(0.5)
    }

    /// The camcorder panel: standing by or recording, the tape counter, and the menu line.
    private var video: some View {
        let t = Int(camera.recordSeconds)
        let counter = "\(t / 3600):" + String(format: "%02d:%02d", (t / 60) % 60, t % 60)
        let off = Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.08), shade = Color(red: 0.35, green: 0.16, blue: 0).opacity(0.25)
        return VStack(alignment: .leading, spacing: 2 * k) {
            HStack(spacing: 4 * k) {
                Circle().fill(camera.recording ? Self.amberInk : off).frame(width: 6 * k, height: 6 * k)
                amber(camera.recording ? "REC" : "STBY", 8)
                Spacer(minLength: 0)
                SevenSeg(text: counter, height: 12 * k, on: Self.amberInk, off: off, shade: shade)
            }
            Rectangle().fill(Self.amberInk.opacity(0.4)).frame(height: 1)
            HStack {
                amber(">" + name, 7)
                Spacer(minLength: 2 * k)
                amber(index, 7)
            }
            amber(value, 12).blinks(blinking)
        }
        .padding(.horizontal, 5 * k).padding(.vertical, 4 * k)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func amber(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(F5.print(size * k)).foregroundStyle(Self.amberInk)
            .shadow(color: Color(red: 0.35, green: 0.16, blue: 0).opacity(0.25), radius: 0, x: 1.1 * k, y: 1.1 * k)
            .lineLimit(1).minimumScaleFactor(0.5)
    }

    /// A purikura machine's bubbly type.
    private var booth: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                bubble(">" + name, 10, Self.hot)
                Spacer(minLength: 2 * k)
                bubble(index, 10, Self.violet)
            }
            Spacer(minLength: 0)
            bubble("♥ " + value, 17, Self.hot).blinks(blinking)
        }
        .padding(.horizontal, 7 * k).padding(.vertical, 5 * k)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func bubble(_ s: String, _ size: CGFloat, _ c: Color) -> some View {
        Text(s).font(.custom(BoothInk.font, fixedSize: size * k)).foregroundStyle(c)
            .lineLimit(1).minimumScaleFactor(0.5)
    }
}

private extension View {
    /// A value SELECT changed and SET hasn't kept: it blinks, on and off, like an LCD's.
    @ViewBuilder func blinks(_ on: Bool) -> some View {
        if on {
            phaseAnimator([1.0, 0.0]) { v, a in v.opacity(a) } animation: { _ in .linear(duration: 0.05).delay(0.35) }
        } else {
            self
        }
    }
}

// MARK: PRO

/// PRO's backlit panel, square to fit over the film slot: program and shutter, the AF and white
/// balance, the exposure scale, ISO and flash, and the line the command wheel edits. Tap a
/// reading to edit it, as on the phone's panel.
struct DuoProPanel: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    @Binding var field: ProField
    let lit: Bool
    let k: CGFloat
    private let ink = Color(hex: "#0A2430"), off = Color(red: 0.04, green: 0.14, blue: 0.19).opacity(0.08), shade = Color(red: 0, green: 0.24, blue: 0.31).opacity(0.22)

    var body: some View {
        ZStack {
            Rectangle().fill(Color(hex: "#060607"))
                .overlay(Rectangle().strokeBorder(Color(hex: "#2A2A2C"), lineWidth: 2 * k))
            ZStack {
                glass
                readings
            }
            .padding(4 * k)
            .clipped()
        }
    }

    @ViewBuilder private var glass: some View {
        if lit {
            LitPanel(center: Color(hex: "#D4F8FF"), mid: Color(hex: "#9FE6F2"), edge: Color(hex: "#6FC9DC"),
                     glow: Color(red: 0.47, green: 0.84, blue: 1).opacity(0.5))
        } else {
            LinearGradient(colors: [Color(hex: "#86A9B1"), Color(hex: "#5F848D")], startPoint: .top, endPoint: .bottom)
                .overlay(Rectangle().strokeBorder(Color.black.opacity(0.3), lineWidth: 1))
        }
    }

    private var readings: some View {
        let program = camera.shutterIndex == nil ? (camera.isoIndex == nil ? "P" : "A") : (camera.isoIndex == nil ? "S" : "M")
        let all = ProField.allCases
        return VStack(spacing: 0) {
            // program, shutter, aperture
            HStack(alignment: .center, spacing: 5 * k) {
                SevenSeg(text: program, height: 18 * k, on: ink, off: off, shade: shade)
                    .padding(2 * k)
                    .overlay(Rectangle().strokeBorder(ink.opacity(0.45), lineWidth: 1))
                tap(.shutter) { SevenSeg(text: shutterText, height: 21 * k, on: ink, off: off, shade: shade) }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1 * k) {
                    label("F", 7)
                    SevenSeg(text: String(format: "%.1f", camera.aperture), height: 10 * k, on: ink, off: off, shade: shade)
                }
            }
            .frame(height: 28 * k)
            rule
            // AF, white balance, focus
            HStack(spacing: 6 * k) {
                tap(.af) { label(ProField.af.value(camera, settings), 8) }
                tap(.wb) { label("WB " + (camera.wbIndex == 0 ? "A" : camera.label(.wb)), 8) }
                Spacer(minLength: 0)
                tap(.focus) { label(ProField.focus.value(camera, settings), 8) }
            }
            .frame(height: 19 * k)
            rule
            // exposure compensation
            tap(.ev) { EVScale(ev: camera.ev, ink: ink).frame(height: 18 * k) }
                .frame(maxWidth: .infinity)
                .frame(height: 28 * k)
            rule
            // ISO and flash
            HStack(alignment: .center, spacing: 4 * k) {
                tap(.iso) {
                    HStack(alignment: .bottom, spacing: 3 * k) {
                        VStack(alignment: .leading, spacing: 0) {
                            label("ISO", 7)
                            label(camera.isoIndex == nil ? "AUTO" : "", 5)
                        }
                        SevenSeg(text: isoText, height: 16 * k, on: ink, off: off, shade: shade)
                    }
                }
                Spacer(minLength: 0)
                tap(.flash) {
                    HStack(spacing: 1 * k) {
                        Image(systemName: "bolt.fill").font(.system(size: 8 * k, weight: .heavy)).foregroundStyle(ink)
                            .shadow(color: shade, radius: 0, x: 1.1, y: 1.1)
                        label(settings.flash == .off ? "OFF" : (settings.flash == .auto ? "A" : "ON"), 8)
                    }
                }
            }
            .frame(height: 25 * k)
            rule
            // the line the wheel edits
            HStack(alignment: .center, spacing: 2 * k) {
                VStack(alignment: .leading, spacing: 1 * k) {
                    label(">" + field.name, 8)
                    label("\((all.firstIndex(of: field) ?? 0) + 1)/\(all.count)", 6).opacity(0.8)
                }
                Spacer(minLength: 0)
                label(field.value(camera, settings), 13)
                    .phaseAnimator([1.0, 0.15]) { v, a in v.opacity(a) } animation: { _ in .easeInOut(duration: 0.45) }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 4 * k)
    }

    private var shutterText: String {
        if let i = camera.shutterIndex {
            let d = Exposure.shutterStops[min(max(i, 0), Exposure.shutterStops.count - 1)]
            return d == 1 ? "1\"" : "\(d)"
        }
        let d = camera.meterShutter
        return d >= 1 ? "\(Int(d.rounded()))\"" : "\(Int((1 / max(d, 0.0001)).rounded()))"
    }

    private var isoText: String {
        "\(camera.isoIndex.map { Exposure.isoAt($0) } ?? Int(camera.meterISO.rounded()))"
    }

    private var rule: some View { Rectangle().fill(ink.opacity(0.4)).frame(height: 1) }

    private func label(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(F5.print(size * k)).foregroundStyle(ink)
            .shadow(color: shade, radius: 0, x: 1.1, y: 1.1)
            .lineLimit(1).minimumScaleFactor(0.6)
    }

    /// A reading: tap it to edit it; the one selected gets a thin box.
    private func tap<C: View>(_ f: ProField, @ViewBuilder _ c: () -> C) -> some View {
        c()
            .padding(.horizontal, 3 * k).padding(.vertical, 1 * k)
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

/// PRO's strip under the viewfinder: the live histogram, the shots the phone has room for, the
/// card light (on while a picture is being written), the battery and the file format.
struct DuoProStrip: View {
    @ObservedObject var camera: CameraModel
    @ObservedObject var settings: AppSettings
    let lit: Bool
    @State private var left = 0
    @State private var battery: Float = -1
    private let ink = Color(hex: "#0A2430"), off = Color(red: 0.04, green: 0.14, blue: 0.19).opacity(0.08), shade = Color(red: 0, green: 0.24, blue: 0.31).opacity(0.22)

    var body: some View {
        ZStack {
            if lit {
                LitPanel(center: Color(hex: "#D4F8FF"), mid: Color(hex: "#9FE6F2"), edge: Color(hex: "#6FC9DC"),
                         glow: Color(red: 0.47, green: 0.84, blue: 1).opacity(0.5))
            } else {
                LinearGradient(colors: [Color(hex: "#86A9B1"), Color(hex: "#5F848D")], startPoint: .top, endPoint: .bottom)
            }
            HStack(spacing: 8) {
                LivePanelHisto(meters: camera.meters, ink: ink).frame(width: 96, height: 20)
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    label("[", 13)
                    SevenSeg(text: String(min(left, 9999)), height: 17, on: ink, off: off, shade: shade)
                    label("]", 13)
                }
                Image(systemName: "sdcard.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(ink)
                    .opacity(camera.developing > 0 ? 1 : 0.25)
                batteryIcon
                label(settings.proFormat == .heif ? "HEIF" : "JPEG", 10)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .padding(3)
        .background(Color(white: 0.025))
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            refresh()
        }
        .onChange(of: camera.developing) { _, _ in refresh() }
        .onChange(of: settings.proFormat) { _, _ in refresh() }
    }

    private var batteryIcon: some View {
        let level: CGFloat = battery < 0 ? 1 : CGFloat(battery)
        return HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5).strokeBorder(ink, lineWidth: 1.4)
                Rectangle().fill(ink).frame(width: max(1, 15 * level), height: 6).padding(.leading, 2.5)
            }
            .frame(width: 21, height: 11)
            Rectangle().fill(ink).frame(width: 2, height: 4)
        }
        .accessibilityLabel("Battery")
    }

    private func label(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(F5.print(size)).foregroundStyle(ink)
            .shadow(color: shade, radius: 0, x: 1.1, y: 1.1).lineLimit(1)
    }

    /// Room on the phone, as PRO pictures: about 5 MB a HEIF, 10 MB a JPEG.
    private func refresh() {
        battery = UIDevice.current.batteryLevel
        let free: Int64 = (try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
        let each: Int64 = settings.proFormat == .heif ? 5_000_000 : 10_000_000
        left = Int(max(0, free) / each)
    }
}
