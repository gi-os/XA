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
                    group("DIGI") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resolution").font(.system(size: 15))
                            Segmented(items: AppSettings.digiOptions.map { ($0, "\($0)MP") }, selection: $settings.digiMegapixels)
                            NavigationLink { RecipeEditor(settings: settings, camera: camera) } label: {
                                row("Your recipe", "\(settings.recipe.onCount) on", accent: true)
                            }
                            Toggle("Instant review", isOn: $settings.instantReview).tint(XA.orange).font(.system(size: 15))
                            FlatSlider(label: "Save quality", value: $settings.crunch, range: 0.3...0.95, format: { "\(Int(($0 * 100).rounded()))" })
                            FlatSlider(label: "Sensor noise", value: $settings.noise, format: { "\(Int(($0 * 100).rounded()))" })
                            NavigationLink { DateScreen(settings: settings, camera: camera) } label: {
                                row("Date back", "\(settings.date.style.title.capitalized) · \(placement)", accent: true)
                            }
                        }
                    }
                    group("PRO") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resolution").font(.system(size: 15))
                            Segmented(items: [(0, "MAX")] + camera.proOptions.map { ($0, "\($0)MP") }, selection: $settings.proMegapixels)
                            Text("Format").font(.system(size: 15))
                            Segmented(items: [(ProFormat.heif, "HEIF"), (.jpeg, "JPEG")], selection: $settings.proFormat)
                            Toggle("Grid", isOn: $settings.grid).tint(XA.orange).font(.system(size: 15))
                        }
                    }
                    group("FOCUS") {
                        VStack(alignment: .leading, spacing: 8) {
                            Segmented(items: [(AFMode.single, "AF-S · lock on half-press"), (.continuous, "AF-C · keep tracking")], selection: $settings.afMode)
                            Segmented(items: [(AFArea.auto, "Auto"), (.point, "Point"), (.eye, "Eye")], selection: $settings.afArea)
                            Text("Tap the shutter to shoot; push it left or right and let go to change mode. Camera Control: light press locks focus, full press shoots. Tap the frame to aim; long-press to hand focus back to the camera. Eye finds the nearer eye and follows it.")
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
                        Segmented(items: [(OpenIn.last, "Last mode"), (.digi, "DIGI"), (.pro, "PRO")], selection: $settings.openIn)
                    }
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

    private var placement: String {
        switch settings.date.placement {
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
