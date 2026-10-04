import SwiftUI

/// Everything is a setting.
struct CustomizeView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var camera: CameraModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    modeGroups(first: true)
                    group("FOCUS") {
                        VStack(alignment: .leading, spacing: 8) {
                            Segmented(items: [(AFMode.single, "AF-S · lock on half-press"), (.continuous, "AF-C · keep tracking")], selection: $settings.afMode)
                            Segmented(items: [(AFArea.auto, "Auto"), (.point, "Point"), (.eye, "Eye")], selection: $settings.afArea)
                            Text("The shutter fires the moment you touch it; swipe sideways below the viewfinder to change mode. Camera Control: light press locks focus, full press shoots. Tap the frame to aim; long-press to hand focus back to the camera. Eye finds the nearer eye and follows it.")
                                .font(.system(size: 12)).foregroundStyle(XA.faint)
                        }
                    }
                    group("SOUND") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("XA camera sounds", isOn: $settings.sounds).tint(XA.orange).font(.system(size: 15))
                            Text("An AF motor when you aim focus, a fast metal shutter when you shoot. Off uses the iPhone's click. The silent switch mutes both.")
                                .font(.system(size: 12)).foregroundStyle(XA.faint)
                        }
                    }
                    group("CAMERA CONTROL") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Slide in DIGI").font(.system(size: 15))
                            Segmented(items: [(DigiSlide.sim, "Sims first"), (.look, "Looks first")], selection: $settings.digiSlide)
                            Text("Slide in PRO").font(.system(size: 15))
                            Segmented(items: [(ProSlide.exposure, "Exposure"), (.zoom, "Zoom")], selection: $settings.proSlide)
                        }
                    }
                    group("CAMERA SCREEN") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Roll button", isOn: $settings.showRollButton).tint(XA.orange).font(.system(size: 15))
                            Toggle("Flip button", isOn: $settings.showFlipButton).tint(XA.orange).font(.system(size: 15))
                            Text("Without them: swipe up for the roll, double-tap the viewfinder to flip.")
                                .font(.system(size: 12)).foregroundStyle(XA.faint)
                        }
                    }
                    group("APP ICON") { IconPicker() }
                    group("OPENS IN") {
                        Segmented(items: [(OpenIn.last, "Last"), (.digi, "DIGI"), (.film, "FILM"), (.pro, "PRO")], selection: $settings.openIn)
                    }
                    group("SHUTTER BLINK") {
                        Segmented(items: [(ShutterBlink.off, "Off"), (.white, "White"), (.black, "Black (SLR)")], selection: $settings.blink)
                    }
                    modeGroups(first: false)
                    group("CAMERA BUTTON") {
                        Text("Make XA the camera: Settings › Camera › Camera Control › Launch Camera › XA. Add the XA control to Control Center or the Lock Screen to open it while locked.")
                            .font(.system(size: 13)).foregroundStyle(XA.dim)
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .principal) { Text("CUSTOMIZE").font(XA.display(17)) }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { camera.applyResolution(); camera.rebuildControls() }
    }

    /// The settings for the mode you were shooting in come first; the other modes' after the rest.
    @ViewBuilder private func modeGroups(first: Bool) -> some View {
        let current: CaptureMode? = [.digi, .film, .pro].contains(camera.mode) ? camera.mode : nil
        if first {
            if let current { modeGroup(current) }
        } else {
            ForEach([CaptureMode.digi, .pro, .film].filter { $0 != current }, id: \.self) { m in modeGroup(m) }
        }
    }

    @ViewBuilder private func modeGroup(_ m: CaptureMode) -> some View {
        switch m {
        case .digi: digiGroup
        case .pro: proGroup
        case .film: filmGroup
        default: EmptyView()
        }
    }

    private var digiGroup: some View {
        group("DIGI") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution").font(.system(size: 15))
                Segmented(items: AppSettings.digiOptions.map { ($0, "\($0)MP") }, selection: $settings.digiMegapixels)
                NavigationLink { RecipeEditor(settings: settings, camera: camera) } label: {
                    row("Your recipe", "\(settings.recipe.onCount) on", accent: true)
                }
                Toggle("Instant review", isOn: $settings.instantReview).tint(XA.orange).font(.system(size: 15))
                Toggle("Screen info", isOn: $settings.digiOSD).tint(XA.orange).font(.system(size: 15))
                Text("The 2005 digicam's screen: battery, photo size, shots left, flash, histogram, zoom bar, the next file number and the clock, all live. Off: just the exposure. Default on.")
                    .font(.system(size: 12)).foregroundStyle(XA.faint)
                if !camera.lastTiming.isEmpty {
                    Text("Last shot: \(camera.lastTiming)").font(.system(size: 12, design: .monospaced)).foregroundStyle(XA.faint)
                }
                FlatSlider(label: "Save quality", value: $settings.crunch, range: 0.3...0.95, format: { "\(Int(($0 * 100).rounded()))" })
                FlatSlider(label: "Sensor noise", value: $settings.noise, format: { "\(Int(($0 * 100).rounded()))" })
                NavigationLink { DateScreen(settings: settings, camera: camera) } label: {
                    row("Date back", "\(settings.date.style.title.capitalized) · \(Self.placement(settings.date))", accent: true)
                }
            }
        }
    }

    private var proGroup: some View {
        group("PRO") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution").font(.system(size: 15))
                Segmented(items: [(0, "MAX")] + camera.proOptions.map { ($0, "\($0)MP") }, selection: $settings.proMegapixels)
                Text("Format").font(.system(size: 15))
                Segmented(items: [(ProFormat.heif, "HEIF"), (.jpeg, "JPEG")], selection: $settings.proFormat)
                Toggle("Grid", isOn: $settings.grid).tint(XA.orange).font(.system(size: 15))
            }
        }
    }

    private var filmGroup: some View {
        group("FILM") {
            VStack(alignment: .leading, spacing: 8) {
            NavigationLink { DateScreen(settings: settings, camera: camera, film: true) } label: {
                row("Date back", "\(settings.filmDate.style.title.capitalized) · \(Self.placement(settings.filmDate))", accent: true)
            }
            Toggle("XA viewfinder", isOn: $settings.filmRecipe.xaFinder).tint(XA.orange).font(.system(size: 15))
            Text("Look through an Olympus XA's finder: the photo in a bright frame, the speed scale with its meter needle, the rangefinder patch. Off: the plain viewfinder. Default on.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            Toggle("Ultra-wide around the frame", isOn: $settings.filmRecipe.ultraWide).tint(XA.orange).font(.system(size: 15))
                .disabled(!settings.filmRecipe.xaFinder)
            Text("Experimental: runs the ultra-wide camera too, to fill the finder around the frame. Uses more battery. Off while developing from RAW. Default off.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            Text("FILM").font(XA.display(11)).foregroundStyle(XA.faint).padding(.top, 4)
            Text("How the film itself behaves. 100 is the stock as measured.").font(.system(size: 12)).foregroundStyle(XA.faint)
            FlatSlider(label: "Halation", value: $settings.filmRecipe.halation, range: 0...2, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "The red glow around bright lights and windows. Light passes through the film, bounces off its back and comes back wider. Black-and-white film has a backing that stops most of it, so it glows faint grey.", standard: 1)
            FlatSlider(label: "Grain", value: $settings.filmRecipe.grain, range: 0...2, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "The texture of the film. Fast stocks and pushed rolls are grainier, and shadows show the coarsest grain.", standard: 1)
            FlatSlider(label: "Glare", value: $settings.filmRecipe.glare, range: 0...2, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "Stray light inside the camera and on the print. It softens the deepest blacks a little, most in bright scenes.", standard: 1)
            Text("CAMERA").font(XA.display(11)).foregroundStyle(XA.faint).padding(.top, 4)
            Text("The point-and-shoot in front of the film.").font(.system(size: 12)).foregroundStyle(XA.faint)
            FlatSlider(label: "Cheap lens", value: $settings.filmRecipe.lens, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "A plastic lens: the corners go about a stop darker and a little soft.", standard: 0.5)
            FlatSlider(label: "Flash falloff", value: $settings.filmRecipe.flash, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "With the flash on, the middle of the frame gets the light and the room behind drops into the dark, like a small built-in flash.", standard: 0.5)
            FlatSlider(label: "Light leaks", value: $settings.filmRecipe.leak, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "Light getting past the camera's back, burning an orange and red streak in from one edge. It only shows on the print, on some frames: more often the higher you set it.", standard: 0.3)
            FlatSlider(label: "Mist filter", value: $settings.filmRecipe.mist, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "A diffusion filter over the lens: highlights bloom into a soft haze. Off unless you want the dreamy look.", standard: 0)
            Text("FORMAT").font(XA.display(11)).foregroundStyle(XA.faint).padding(.top, 4)
            Segmented(items: FilmFormat.allCases.map { ($0, $0.title) }, selection: $settings.filmRecipe.format)
            Text("The size of the negative. Smaller formats show bigger grain and glow: 110 is tiny and gritty, 120 is big, smooth and square. 35mm is cut 2:3. Default 35MM.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            Text("LAB").font(XA.display(11)).foregroundStyle(XA.faint).padding(.top, 4)
            Segmented(items: [(FilmScan.lab, "Lab scan"), (.full, "Full size")], selection: $settings.filmRecipe.scan)
            Text("Lab scan saves at a minilab scanner's size (3088 px on the long side), where grain looks the way it does on real scans. Full size keeps every pixel. Default Lab scan.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            FlatSlider(label: "Lab auto-correct", value: $settings.filmRecipe.labAuto, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "What the lab's machine does to every frame: prints a dim or grey day brighter, sets the black and white points so a flat scene still has punch, adds color to a pale frame and warms a cold one. Night stays night. 0 prints the negative as it is.", standard: 0.7)
            FlatSlider(label: "Print warmth", value: $settings.filmRecipe.warmth, range: -1...1, format: { String(format: "%+d", Int(($0 * 100).rounded())) },
                       note: "The lab's color timing: plus prints warmer and more yellow, minus cooler and bluer.", standard: 0)
            FlatSlider(label: "Print tint", value: $settings.filmRecipe.tint, range: -1...1, format: { String(format: "%+d", Int(($0 * 100).rounded())) },
                       note: "Plus prints more magenta, minus more green.", standard: 0)
            FlatSlider(label: "Preflash", value: $settings.filmRecipe.preflash, format: { "\(Int(($0 * 100).rounded()))" },
                       note: "A little even light on the paper before printing. It softens the brightest parts and lifts the look toward faded.", standard: 0)
            Text("Double-tap a setting's name to put it back to its default.").font(.system(size: 12)).foregroundStyle(XA.faint)
            Toggle("Develop from RAW", isOn: $settings.digiZero).tint(XA.orange).font(.system(size: 15))
                .onChange(of: settings.digiZero) { _, _ in camera.zeroChanged() }
            Text("FILM saves full size with none of DIGI's digicam processing. From RAW it also skips the iPhone's own (Smart HDR, tone mapping, sharpening), so the stock is the only look. Slower to save. Default off.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            Text("The film stocks (Bowery, Coney, Chelsea, Prospect, Canal, Orchard, Ludlow) are developed through tables baked with spektrafilm, Andrea Volpato's spectral simulation of film from published datasheets, with grain, halation and coupler effects fitted to it. The black-and-white stocks (Bleecker, Delancey, Essex) use XA's own tables, shaped like the published curves. Film modeling powered by spektrafilm (github.com/andreavolpato/spektrafilm); tables CC BY-SA 4.0. Swipe a stock's box up to push it a stop, down to pull.")
                .font(.system(size: 12)).foregroundStyle(XA.dim)
            }
        }
    }

    static func placement(_ d: DateConfig) -> String {
        switch d.placement {
        case .off: return "off"
        case .corner: return "corner"
        case .follow: return "follows frame"
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            c().padding(12).frame(maxWidth: .infinity, alignment: .leading).background(XA.fill)
        }
        .padding(.top, 6)
    }

    private func row(_ label: String, _ value: String, accent: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(.white)
            Spacer()
            Text(value).font(.system(size: 15)).foregroundStyle(accent ? XA.orange : XA.dim)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(XA.faint)
        }
        .padding(.vertical, 6)
    }
}

/// The app's icon: the original or one of the alternates.
private struct IconPicker: View {
    private static let icons: [(name: String?, preview: String, title: String)] = [
        (nil, "IconPreview-Original", "Original"),
        ("AppIcon-Lens", "IconPreview-Lens", "Lens"),
        ("AppIcon-LensCrop", "IconPreview-LensCrop", "Lens, close"),
        ("AppIcon-LensCover", "IconPreview-LensCover", "Lens cover"),
        ("AppIcon-Navy", "IconPreview-Navy", "Professional"),
        ("AppIcon-Bowery", "IconPreview-Bowery", "Bowery 800"),
        ("AppIcon-Coney", "IconPreview-Coney", "Coney 200"),
        ("AppIcon-Ludlow", "IconPreview-Ludlow", "Ludlow 1600"),
    ]
    @State private var current = UIApplication.shared.alternateIconName

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Self.icons, id: \.preview) { icon in
                    let on = current == icon.name
                    Button {
                        guard UIApplication.shared.supportsAlternateIcons, !on else { return }
                        UIApplication.shared.setAlternateIconName(icon.name) { error in
                            if error == nil { DispatchQueue.main.async { current = icon.name } }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(icon.preview).resizable().frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? XA.orange : .clear, lineWidth: 2.5).padding(-4))
                            Text(icon.title).font(.system(size: 11)).foregroundStyle(on ? .white : XA.dim).lineLimit(1)
                        }
                        .frame(width: 72)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(icon.title) icon")
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 4)
        }
    }
}
