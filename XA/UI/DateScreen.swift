import SwiftUI

/// Date back: style, placement, format, ink, time.
struct DateScreen: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var camera: CameraModel
    @State private var preview: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    Checker(size: 10)
                    if let preview { Image(uiImage: preview).resizable().scaledToFit() }
                }
                .frame(height: 250).clipped()
                SectionLabel(text: "STYLE")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(DateStyle.allCases) { s in
                            let on = settings.date.style == s
                            Button { settings.date.style = s } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    DateChip(style: s).frame(width: 104, height: 56)
                                        .overlay(Rectangle().strokeBorder(on ? XA.orange : .clear, lineWidth: 2))
                                    Text(s.title).font(XA.display(12))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                }
                HStack(spacing: 8) {
                    Rectangle().fill(XA.orange).frame(width: 6, height: 6)
                    Text("Sunday 600 and Sunday Round write it by hand on the print instead.").font(.system(size: 13)).foregroundStyle(XA.dim)
                }
                SectionLabel(text: "PLACEMENT")
                Segmented(items: [(DatePlacement.off, "Off"), (.corner, "Corner"), (.follow, "Follow frame")], selection: $settings.date.placement)
                SectionLabel(text: "FORMAT")
                Segmented(items: [(DateFormat.own, "Style's own"), (.dmy, "28.09.26"), (.long, "SEP 28 2026")], selection: $settings.date.format)
                SectionLabel(text: "INK")
                HStack(spacing: 12) {
                    inkButton(nil)
                    ForEach([RGBA8(255, 138, 43), RGBA8(200, 245, 106), RGBA8(216, 65, 47), RGBA8(255, 255, 255), RGBA8(255, 210, 63)], id: \.self) { inkButton($0) }
                    Spacer()
                    Toggle("Time", isOn: $settings.date.time).tint(XA.orange).fixedSize()
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("DATE BACK")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: render)
        .onChange(of: settings.date) { _, _ in render(); camera.syncFrameSettings() }
    }

    private func inkButton(_ c: RGBA8?) -> some View {
        let on = settings.date.color == c
        return Button { settings.date.color = c } label: {
            ZStack {
                if let c { Circle().fill(Color(uiColor: c.ui)) } else { Circle().fill(XA.fill); Text("A").font(XA.display(13)) }
            }
            .frame(width: 32, height: 32)
            .overlay(Circle().strokeBorder(on ? Color.white : .clear, lineWidth: 2).padding(-4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(c == nil ? "Style's own ink" : "Ink")
    }

    private func render() {
        let stack = camera.stack
        var d = DevelopSettings()
        d.stack = stack
        d.date = settings.date
        let src = camera.latestFrame ?? SimEditor.sample
        DispatchQueue.global(qos: .userInitiated).async {
            let (img, _) = Darkroom.develop(src, d, date: Date(), preview: true)
            let cg = Looks.context.createCGImage(img, from: img.extent)
            DispatchQueue.main.async { if let cg { preview = UIImage(cgImage: cg) } }
        }
    }
}

/// A style's own sample, drawn by the real renderer.
private struct DateChip: View {
    let style: DateStyle
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            Rectangle().fill(style == .marker ? Color(red: 0.55, green: 0.4, blue: 0.3) : XA.fill2)
            if let img { Image(uiImage: img).resizable().scaledToFit() }
        }
        .clipped()
        .onAppear {
            let cfg = DateConfig(style: style, placement: .corner, format: .own, time: false)
            if let cg = DateBack.overlay(size: CGSize(width: 520, height: 280), date: Date(), config: cfg, shape: .none, mono: false) {
                img = UIImage(cgImage: cg)
            }
        }
    }
}
