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
                    group("OPENS IN") {
                        Segmented(items: [(OpenIn.last, "Last"), (.digi, "DIGI"), (.film, "FILM"), (.pro, "PRO")], selection: $settings.openIn)
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
            Text("FILM").font(XA.display(11)).foregroundStyle(XA.faint).padding(.top, 4)
            FlatSlider(label: "Halation", value: $settings.filmRecipe.halation, range: 0...2, format: { "\(Int(($0 * 100).rounded()))" })
            FlatSlider(label: "Grain", value: $settings.filmRecipe.grain, range: 0...2, format: { "\(Int(($0 * 100).rounded()))" })
            FlatSlider(label: "Glare", value: $settings.filmRecipe.glare, range: 0...2, format: { "\(Int(($0 * 100).rounded()))" })
            Text("100 is the film as measured. Halation bounces three times off the film base and gets the highlights the phone clipped back; grain comes in three layers, blue the coarsest, with coarse fast grains in the shadows; glare is stray light in the camera and on the print.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            Text("CAMERA").font(XA.display(11)).foregroundStyle(XA.faint).padding(.top, 4)
            FlatSlider(label: "Cheap lens", value: $settings.filmRecipe.lens, format: { "\(Int(($0 * 100).rounded()))" })
            FlatSlider(label: "Flash falloff", value: $settings.filmRecipe.flash, format: { "\(Int(($0 * 100).rounded()))" })
            FlatSlider(label: "Light leaks", value: $settings.filmRecipe.leak, format: { "\(Int(($0 * 100).rounded()))" })
            FlatSlider(label: "Mist filter", value: $settings.filmRecipe.mist, format: { "\(Int(($0 * 100).rounded()))" })
            Text("FORMAT").font(XA.display(11)).foregroundStyle(XA.faint).padding(.top, 4)
            Segmented(items: FilmFormat.allCases.map { ($0, $0.title) }, selection: $settings.filmRecipe.format)
            Text("The size of the negative: smaller formats show bigger grain and glow. 35mm is cut 2:3, 120 square.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            Text("LAB").font(XA.display(11)).foregroundStyle(XA.faint).padding(.top, 4)
            Segmented(items: [(FilmScan.lab, "Lab scan"), (.full, "Full size")], selection: $settings.filmRecipe.scan)
            FlatSlider(label: "Print warmth", value: $settings.filmRecipe.warmth, range: -1...1, format: { String(format: "%+d", Int(($0 * 100).rounded())) })
            FlatSlider(label: "Print tint", value: $settings.filmRecipe.tint, range: -1...1, format: { String(format: "%+d", Int(($0 * 100).rounded())) })
            FlatSlider(label: "Preflash", value: $settings.filmRecipe.preflash, format: { "\(Int(($0 * 100).rounded()))" })
            Text("Leaks show up on the print, not in the finder, on some frames. The lab scans at a minilab's size (3088 px), where grain sits the way it does on real scans.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            Toggle("Develop from RAW", isOn: $settings.digiZero).tint(XA.orange).font(.system(size: 15))
                .onChange(of: settings.digiZero) { _, _ in camera.zeroChanged() }
            Text("FILM saves full size with none of DIGI's digicam processing. From RAW it also skips the iPhone's own (Smart HDR, tone mapping, sharpening), so the stock is the only look. Slower to save.")
                .font(.system(size: 12)).foregroundStyle(XA.faint)
            Text("The film stocks (Bowery, Coney, Chelsea, Prospect, Canal, Orchard, Ludlow) are developed through tables baked with spektrafilm, Andrea Volpato's spectral simulation of film from published datasheets, with grain, halation and coupler effects fitted to it. Film modeling powered by spektrafilm (github.com/andreavolpato/spektrafilm); tables CC BY-SA 4.0. Swipe a stock's box up to push it a stop, down to pull.")
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
