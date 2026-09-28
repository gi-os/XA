import SwiftUI
import CoreImage

/// Every dial of a sim, with a before/after preview of the last viewfinder frame.
struct SimEditor: View {
    @ObservedObject var camera: CameraModel
    @State var sim: Sim
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var split: CGFloat = 0.4
    @State private var before: UIImage?
    @State private var after: UIImage?
    @State private var source: CIImage?

    var body: some View {
        VStack(spacing: 12) {
            header
            preview
            Segmented(items: [(0, "COLOR"), (1, "TONE"), (2, "GRAIN"), (3, "BOX")], selection: $tab)
                .font(XA.display(15))
            ScrollView {
                VStack(spacing: 4) {
                    switch tab {
                    case 0: colorTab
                    case 1: toneTab
                    case 2: grainTab
                    default: boxTab
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear { source = camera.latestFrame ?? SimEditor.sample; render() }
        .onChange(of: sim) { _, _ in render() }
    }

    static let sample: CIImage = {
        let r = CGRect(x: 0, y: 0, width: 480, height: 360)
        let g = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 480, y: 360),
            "inputColor0": CIColor(red: 0.95, green: 0.65, blue: 0.35), "inputColor1": CIColor(red: 0.2, green: 0.35, blue: 0.6),
        ])?.outputImage ?? CIImage(color: .gray)
        return g.cropped(to: r)
    }()

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }.font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 11).background(XA.fill, in: Capsule())
            Spacer()
            Text(sim.title).font(XA.display(18)).lineLimit(1)
            Spacer()
            Button("Save") { save() }.font(.system(size: 15, weight: .bold))
                .padding(.horizontal, 18).padding(.vertical, 11).background(XA.orange, in: Capsule()).foregroundStyle(.black)
        }
        .buttonStyle(.plain)
    }

    private var preview: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                if let after { Image(uiImage: after).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped() }
                if let before {
                    Image(uiImage: before).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                        .mask(alignment: .leading) { Rectangle().frame(width: g.size.width * split) }
                }
                Rectangle().fill(Color.white).frame(width: 2).offset(x: g.size.width * split - 1)
                Text("BEFORE").font(.system(size: 11, weight: .bold)).padding(8).frame(maxHeight: .infinity, alignment: .bottom)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in split = min(1, max(0, v.location.x / g.size.width)) })
        }
        .frame(height: 230)
        .background(XA.fill)
    }

    private func render() {
        guard let src = source else { return }
        let s = sim
        DispatchQueue.global(qos: .userInitiated).async {
            let a = SimEngine.apply(s, to: src, preview: true)
            let ca = Looks.context.createCGImage(a, from: a.extent)
            let cb = Looks.context.createCGImage(src, from: src.extent)
            DispatchQueue.main.async {
                if let ca { after = UIImage(cgImage: ca) }
                if before == nil, let cb { before = UIImage(cgImage: cb) }
            }
        }
    }

    private func pct(_ v: Double) -> String { String(format: "%+d", Int((v * 100).rounded())) }

    @ViewBuilder private var colorTab: some View {
        FlatSlider(label: "Warmth", value: $sim.warmth, range: -1...1, format: pct)
        FlatSlider(label: "Tint", value: $sim.tint, range: -1...1, format: pct)
        FlatSlider(label: "Saturation", value: $sim.saturation, range: -1...1, format: pct)
        Toggle("Black and white", isOn: $sim.mono).tint(XA.orange).font(.system(size: 14))
        SectionLabel(text: "COLOR SHIFTS").padding(.top, 8)
        FlatSlider(label: "Reds · hue", value: $sim.redHue, range: -1...1, format: pct)
        FlatSlider(label: "Reds · saturation", value: $sim.redSat, range: -1...1, format: pct)
        FlatSlider(label: "Greens · hue", value: $sim.greenHue, range: -1...1, format: pct)
        FlatSlider(label: "Greens · saturation", value: $sim.greenSat, range: -1...1, format: pct)
        FlatSlider(label: "Blues · hue", value: $sim.blueHue, range: -1...1, format: pct)
        FlatSlider(label: "Blues · saturation", value: $sim.blueSat, range: -1...1, format: pct)
        SectionLabel(text: "SPLIT TONE").padding(.top, 8)
        ToneRow(label: "Shadows", tone: $sim.shadowTone, amount: $sim.shadowAmount)
        ToneRow(label: "Highlights", tone: $sim.highlightTone, amount: $sim.highlightAmount)
    }

    @ViewBuilder private var toneTab: some View {
        FlatSlider(label: "Contrast", value: $sim.contrast, range: -1...1, format: pct)
        CurveEditor(curve: $sim.curve).frame(height: 150).padding(.vertical, 6)
        FlatSlider(label: "Fade", value: $sim.fade, format: pct)
        FlatSlider(label: "Highlight rolloff", value: $sim.rolloff, format: pct)
    }

    @ViewBuilder private var grainTab: some View {
        FlatSlider(label: "Grain", value: $sim.grain, format: pct)
        FlatSlider(label: "Grain size", value: $sim.grainSize, format: pct)
        FlatSlider(label: "Bloom · white glow", value: $sim.bloom, format: pct)
        FlatSlider(label: "Halation · red ring", value: $sim.halation, format: pct)
        FlatSlider(label: "Vignette", value: $sim.vignette, format: pct)
        SectionLabel(text: "PRINT").padding(.top, 8)
        Segmented(items: [(SimFrame.none, "None"), (.instant, "Instant"), (.round, "Round")], selection: $sim.frame)
    }

    @ViewBuilder private var boxTab: some View {
        HStack { Spacer(); FilmBox(item: .sim(previewSim), width: 240); Spacer() }.padding(.vertical, 8)
        HStack(spacing: 8) {
            field("Name", $sim.name)
            field("ISO", $sim.iso).frame(width: 80)
            Stepper("\(sim.exposures) exp", value: $sim.exposures, in: 8...36, step: 4).font(.system(size: 13)).frame(width: 130)
        }
        SectionLabel(text: "COLORS").padding(.top, 6)
        HStack(spacing: 14) {
            swatch("Box", \.bg); swatch("Type", \.fg); swatch("Number", \.accent); swatch("Pattern", \.second)
        }
        SectionLabel(text: "TYPEFACE").padding(.top, 6)
        FlowChips(items: BoxFont.allCases.map { ($0, $0.label) }, selection: $sim.box.font)
        SectionLabel(text: "PATTERN").padding(.top, 6)
        FlowChips(items: BoxPattern.allCases.map { ($0, $0.label) }, selection: $sim.box.pattern)
    }

    /// Presets keep their bespoke box until saved as a copy.
    private var previewSim: Sim {
        var s = sim
        if s.isPreset { s.id = "preview" }
        return s
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(XA.faint)
            TextField(label, text: text).font(.system(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(XA.fill)
    }

    private func swatch(_ label: String, _ key: WritableKeyPath<BoxDesign, String>) -> some View {
        VStack(spacing: 4) {
            ColorPicker(label, selection: Binding(get: { Color(hex: sim.box[keyPath: key]) }, set: { sim.box[keyPath: key] = $0.hex }), supportsOpacity: false)
                .labelsHidden()
            Text(label).font(.system(size: 11)).foregroundStyle(XA.dim)
        }
    }

    private func save() {
        var s = sim
        var list = FilmCatalog.custom
        if s.isPreset {
            // A preset is never overwritten: edits become a film of your own.
            s.id = "custom-\(Int(Date().timeIntervalSince1970))"
            s.name = s.name + " II"
            list.append(s)
        } else if let i = list.firstIndex(where: { $0.id == s.id }) {
            list[i] = s
        } else {
            list.append(s)
        }
        FilmCatalog.setCustom(list)
        camera.stack.simID = s.id
        dismiss()
    }
}

private struct ToneRow: View {
    let label: String
    @Binding var tone: Tone
    @Binding var amount: Double
    var body: some View {
        HStack(spacing: 12) {
            ColorPicker(label, selection: Binding(get: { Color(red: tone.r, green: tone.g, blue: tone.b) }, set: { c in
                let ui = UIColor(c); var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                ui.getRed(&r, green: &g, blue: &b, alpha: &a)
                tone = Tone(Double(r), Double(g), Double(b))
            }), supportsOpacity: false).labelsHidden()
            FlatSlider(label: label, value: $amount, format: { String(format: "%d", Int(($0 * 100).rounded())) })
        }
    }
}

/// Five points on the tone curve, dragged up and down.
private struct CurveEditor: View {
    @Binding var curve: [Double]
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Rectangle().fill(XA.fill)
                Path { p in
                    for i in 1...3 {
                        let x = w * CGFloat(i) / 4, y = h * CGFloat(i) / 4
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h))
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                    }
                }.stroke(Color.white.opacity(0.12), lineWidth: 1)
                Path { p in
                    for (i, v) in curve.enumerated() {
                        let pt = CGPoint(x: w * CGFloat(i) / CGFloat(curve.count - 1), y: h * (1 - CGFloat(v)))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }.stroke(XA.orange, lineWidth: 2.5)
                ForEach(curve.indices, id: \.self) { i in
                    Circle().fill(Color.white).frame(width: 16, height: 16)
                        .position(x: w * CGFloat(i) / CGFloat(curve.count - 1), y: h * (1 - CGFloat(curve[i])))
                        .gesture(DragGesture().onChanged { v in curve[i] = Double(min(1, max(0, 1 - v.location.y / h))) })
                }
            }
        }
    }
}

/// Wrapping chips for a small enum.
struct FlowChips<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T
    var body: some View {
        let rows = stride(from: 0, to: items.count, by: 4).map { Array(items[$0..<min($0 + 4, items.count)]) }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(rows[r].indices, id: \.self) { i in
                        let it = rows[r][i]
                        let on = it.0 == selection
                        Button { selection = it.0 } label: {
                            Text(it.1).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(on ? Color.white : XA.fill)
                                .foregroundStyle(on ? Color.black : Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
