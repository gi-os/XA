import SwiftUI
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

/// Adjustments for a photo on the roll.
struct Adjust: Equatable {
    var exposure: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
    var warmth: Double = 0
    var fade: Double = 0
    var grain: Double = 0
    var vignette: Double = 0
    var simID: String? = nil
    var look: Look = .none

    var isIdentity: Bool { self == Adjust() }

    func apply(to src: CIImage) -> CIImage {
        let e = src.extent
        var img = src
        if let id = simID, let sim = FilmCatalog.sim(id), !sim.isNeutral { img = SimEngine.apply(sim, to: img, preview: false) }
        if look != .none { img = Looks.apply(look, to: img, outputWidth: look.pixelWidth != nil ? e.width : nil) }
        if exposure != 0 {
            let f = CIFilter.exposureAdjust(); f.inputImage = img; f.ev = Float(exposure * 2)
            img = f.outputImage ?? img
        }
        if contrast != 0 || saturation != 0 {
            let f = CIFilter.colorControls(); f.inputImage = img
            f.contrast = Float(1 + contrast * 0.5); f.saturation = Float(1 + saturation)
            img = f.outputImage ?? img
        }
        if warmth != 0 {
            let f = CIFilter.temperatureAndTint(); f.inputImage = img
            f.neutral = CIVector(x: 6500, y: 0); f.targetNeutral = CIVector(x: 6500 - CGFloat(warmth) * 1800, y: 0)
            img = f.outputImage ?? img
        }
        if fade > 0 {
            let f = CIFilter.colorMatrix(); f.inputImage = img
            let k = CGFloat(1 - fade * 0.2), b = CGFloat(fade * 0.08)
            f.rVector = CIVector(x: k, y: 0, z: 0, w: 0); f.gVector = CIVector(x: 0, y: k, z: 0, w: 0); f.bVector = CIVector(x: 0, y: 0, z: k, w: 0)
            f.biasVector = CIVector(x: b, y: b, z: b, w: 0)
            img = f.outputImage ?? img
        }
        if grain > 0 { img = FilmGrain.apply(img.cropped(to: e), amount: grain, size: 0.4) }
        if vignette > 0 {
            let v = CIFilter.vignetteEffect(); v.inputImage = img
            v.center = CGPoint(x: e.midX, y: e.midY); v.radius = Float(hypot(e.width, e.height) * 0.55)
            v.intensity = Float(vignette * 0.9); v.falloff = 0.6
            img = v.outputImage ?? img
        }
        // Keep empty pixels empty.
        return img.cropped(to: e)
    }
}

/// Edit a photo: adjustments, or a different sim or look. Saves a copy; the original stays.
struct PhotoEditor: View {
    let asset: PHAsset
    let library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var adjust = Adjust()
    @State private var tab = 0
    @State private var source: CIImage?
    @State private var preview: UIImage?
    @State private var original: UIImage?
    @State private var holding = false
    @State private var saving = false
    @State private var hasAlpha = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel") { dismiss() }.font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 16).padding(.vertical, 11).background(XA.fill, in: Capsule())
                Spacer()
                Text("EDIT").font(XA.display(18))
                Spacer()
                Button(saving ? "Saving" : "Save copy") { save() }.font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 16).padding(.vertical, 11).background(XA.orange, in: Capsule()).foregroundStyle(.black)
                    .disabled(saving || source == nil)
            }
            .buttonStyle(.plain)
            ZStack {
                Color.black
                if let img = holding ? original : preview { Image(uiImage: img).resizable().scaledToFit() } else { ProgressView().tint(.white) }
            }
            .frame(maxHeight: 330)
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in holding = true }.onEnded { _ in holding = false })
            .overlay(alignment: .bottomLeading) {
                Text(holding ? "ORIGINAL" : "HOLD TO COMPARE").font(XA.display(10)).padding(8).foregroundStyle(XA.dim)
            }
            Segmented(items: [(0, "ADJUST"), (1, "FILM")], selection: $tab)
            ScrollView {
                VStack(spacing: 4) {
                    if tab == 0 {
                        FlatSlider(label: "Exposure", value: $adjust.exposure, range: -1...1, format: sgn)
                        FlatSlider(label: "Contrast", value: $adjust.contrast, range: -1...1, format: sgn)
                        FlatSlider(label: "Saturation", value: $adjust.saturation, range: -1...1, format: sgn)
                        FlatSlider(label: "Warmth", value: $adjust.warmth, range: -1...1, format: sgn)
                        FlatSlider(label: "Fade", value: $adjust.fade, format: sgn)
                        FlatSlider(label: "Grain", value: $adjust.grain, format: sgn)
                        FlatSlider(label: "Vignette", value: $adjust.vignette, format: sgn)
                        Button("Reset") { adjust = Adjust(simID: adjust.simID, look: adjust.look) }
                            .font(XA.display(13)).foregroundStyle(XA.orange).padding(.top, 6)
                    } else {
                        SectionLabel(text: "SIM")
                        filmRow(FilmCatalog.sims.map { FilmItem.sim($0) }) { item in
                            if case .sim(let s) = item { adjust.simID = adjust.simID == s.id || s.isNeutral ? nil : s.id }
                        } isOn: { item in if case .sim(let s) = item { return adjust.simID == s.id }; return false }
                        SectionLabel(text: "LOOK").padding(.top, 8)
                        filmRow(Look.allCases.filter { $0 != .none }.map { FilmItem.look($0) }) { item in
                            if case .look(let l) = item { adjust.look = adjust.look == l ? .none : l }
                        } isOn: { item in if case .look(let l) = item { return adjust.look == l }; return false }
                        Text("A sim on top of a photo that already has one stacks the two.")
                            .font(.system(size: 12)).foregroundStyle(XA.faint).padding(.top, 8)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
        .onChange(of: adjust) { _, _ in render() }
    }

    private func sgn(_ v: Double) -> String { String(format: "%+d", Int((v * 100).rounded())) }

    private func filmRow(_ items: [FilmItem], _ tap: @escaping (FilmItem) -> Void, isOn: @escaping (FilmItem) -> Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    Button { tap(item) } label: {
                        FilmBox(item: item, width: 80)
                            .overlay(Rectangle().strokeBorder(isOn(item) ? XA.orange : .clear, lineWidth: 2).padding(-3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
    }

    private func load() {
        library.data(asset) { d, uti in
            guard let d, let full = CIImage(data: d, options: [.applyOrientationProperty: true]) else { return }
            let alpha = uti == UTType.png.identifier
            let e = full.extent
            let k: CGFloat = min(1, 1080 / max(e.width, e.height))
            let small = full.transformed(by: CGAffineTransform(scaleX: k, y: k))
            let o = Looks.context.createCGImage(small, from: small.extent)
            DispatchQueue.main.async {
                hasAlpha = alpha
                source = small
                fullData = d
                if let o { original = UIImage(cgImage: o) }
                render()
            }
        }
    }

    @State private var fullData: Data?

    private func render() {
        guard let src = source else { return }
        let a = adjust
        DispatchQueue.global(qos: .userInitiated).async {
            let out = a.apply(to: src)
            let cg = Looks.context.createCGImage(out, from: out.extent)
            DispatchQueue.main.async { if a == adjust, let cg { preview = UIImage(cgImage: cg) } }
        }
    }

    private func save() {
        guard let d = fullData, let full = CIImage(data: d, options: [.applyOrientationProperty: true]) else { return }
        saving = true
        let a = adjust, alpha = hasAlpha
        DispatchQueue.global(qos: .userInitiated).async {
            var out = a.apply(to: full)
            var props = full.properties
            let simPart = a.simID.flatMap { FilmCatalog.sim($0) }.map { " · \($0.title)" } ?? ""
            let note = "XA EDIT" + simPart + (a.look != .none ? " + \(a.look.title)" : "")
            props = Recipe.properties(from: props, recipe: note)
            out = out.settingProperties(props)
            guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return }
            let data: Data?
            let type: UTType
            if alpha {
                data = Looks.context.pngRepresentation(of: out, format: .RGBA8, colorSpace: cs)
                type = .png
            } else {
                data = Looks.context.jpegRepresentation(of: out, colorSpace: cs, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92])
                type = .jpeg
            }
            DispatchQueue.main.async {
                guard let data else { saving = false; return }
                library.save(data: data, type: type) { _ in saving = false; dismiss() }
            }
        }
    }
}
