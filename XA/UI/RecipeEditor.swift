import SwiftUI
import CoreImage

/// DIGI, your recipe: switch each of the digicam's faults on or off and set how much, on a
/// live preview of the last viewfinder frame. Hold the preview to see it without them.
struct RecipeEditor: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var camera: CameraModel
    enum Demo: Int, CaseIterable { case day, flash, night
        var title: String { ["DAY", "FLASH", "NIGHT"][rawValue] }
        var conditions: DigicamFX.Conditions {
            switch self {
            case .day: return DigicamFX.Conditions(iso: 100, exposure: 1.0 / 250)
            case .flash: return DigicamFX.Conditions(flashFired: true, iso: 200, exposure: 1.0 / 60)
            case .night: return DigicamFX.Conditions(iso: 3200, exposure: 1.0 / 8)
            }
        }
    }
    @State private var demo: Demo = .day
    @State private var after: UIImage?
    @State private var before: UIImage?
    @State private var peek = false
    @State private var source: CIImage?
    @State private var generation = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                preview
                HStack(spacing: 6) {
                    ForEach(Demo.allCases, id: \.self) { d in
                        Button { demo = d } label: {
                            Text(d.title).font(XA.display(12)).padding(.horizontal, 12).padding(.vertical, 8)
                                .foregroundStyle(demo == d ? Color(red: 0.16, green: 0.08, blue: 0) : .white)
                                .background(demo == d ? XA.orange : XA.fill)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Text("\(settings.recipe.onCount) ON").font(XA.mono(12)).foregroundStyle(XA.dim)
                }
                ForEach(DigiRecipe.Key.allCases) { k in row(k) }
                NavigationLink { DateScreen(settings: settings, camera: camera) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DATE BACK").font(XA.display(14))
                            Text("The date burned into the corner.").font(.system(size: 11)).foregroundStyle(XA.dim)
                        }
                        Spacer()
                        Text(settings.date.placement == .off ? "OFF" : settings.date.style.title.uppercased()).font(XA.display(12)).foregroundStyle(XA.orange)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(XA.faint)
                    }
                    .padding(12).background(XA.fill)
                }
                .buttonStyle(.plain)
                Button("Back to how XA shoots") { settings.recipe = DigiRecipe() }
                    .font(.system(size: 13)).foregroundStyle(XA.dim).padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .toolbar { ToolbarItem(placement: .principal) { Text("YOUR RECIPE").font(XA.display(17)) } }
        .onAppear { source = camera.latestFrame ?? SimEditor.sample; render() }
        .onChange(of: settings.recipe) { _, _ in render() }
        .onChange(of: demo) { _, _ in render() }
    }

    private var preview: some View {
        ZStack {
            Color.white.opacity(0.05)
            if let img = peek ? before : after { Image(uiImage: img).resizable().scaledToFit() }
        }
        .frame(maxWidth: .infinity).frame(height: 300)
        .overlay(alignment: .topLeading) {
            Text(peek ? "WITHOUT" : "HOLD TO SEE WITHOUT").font(XA.mono(10)).foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.black.opacity(0.5)).padding(8)
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in peek = true }.onEnded { _ in peek = false })
    }

    private func row(_ k: DigiRecipe.Key) -> some View {
        let part = settings.recipe[k]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(k.title).font(XA.display(14))
                    Text(k.detail).font(.system(size: 11)).foregroundStyle(XA.dim)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { settings.recipe[k].on }, set: { settings.recipe[k].on = $0 }))
                    .labelsHidden().tint(XA.orange)
            }
            if part.on {
                HStack(spacing: 10) {
                    Slider(value: Binding(get: { settings.recipe[k].amount }, set: { settings.recipe[k].amount = $0 }), in: 0...1).tint(XA.orange)
                    Text("\(Int((part.amount * 100).rounded()))").font(XA.mono(12)).foregroundStyle(XA.orange).frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(12).background(XA.fill)
        .animation(.snappy, value: part.on)
    }

    private func render() {
        guard let src = source else { return }
        generation += 1
        let gen = generation
        var d = DevelopSettings()
        d.stack = camera.stack
        d.megapixels = 12
        d.noise = settings.noise
        d.date = settings.date
        d.recipe = settings.recipe
        let conditions = demo.conditions
        let needBefore = before == nil
        DispatchQueue.global(qos: .userInitiated).async {
            let a = Darkroom.develop(src, d, date: Date(), preview: false, demo: conditions).0
            let ca = Encoder.render(a, reference: nil) ?? Looks.context.createCGImage(a, from: a.extent)
            let cb = needBefore ? Looks.context.createCGImage(src, from: src.extent) : nil
            DispatchQueue.main.async {
                guard gen == generation else { return }
                if let ca { after = UIImage(cgImage: ca) }
                if let cb { before = UIImage(cgImage: cb) }
            }
        }
    }
}
