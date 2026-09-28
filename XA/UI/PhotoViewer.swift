import SwiftUI
import Photos
import UniformTypeIdentifiers

/// The photo viewer: swipe between photos, a thumbnail row to slide along, pinch to zoom,
/// info, edit, send and delete.
struct PhotoViewer: View {
    @ObservedObject var library: Library
    @State var current: String
    @Environment(\.dismiss) private var dismiss
    @State private var zoomed = false
    @State private var chrome = true
    @State private var info = false
    @State private var editing: PHAsset?
    @State private var file: URL?

    private var assets: [PHAsset] { library.assets }
    private var asset: PHAsset? { assets.first { $0.localIdentifier == current } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $current) {
                ForEach(assets, id: \.localIdentifier) { a in
                    PhotoPage(asset: a, library: library, zoomed: $zoomed)
                        .tag(a.localIdentifier)
                        .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { chrome.toggle() } }
            if chrome && !zoomed {
                VStack(spacing: 0) {
                    top
                    Spacer()
                    ThumbRow(library: library, current: $current)
                    actions
                }
                .transition(.opacity)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { v in
            if !zoomed && v.translation.height > 140 && abs(v.translation.height) > abs(v.translation.width) * 1.5 { dismiss() }
        })
        .sheet(isPresented: $info) { if let asset { PhotoInfo(asset: asset, library: library) } }
        .sheet(item: Binding(get: { editing.map { EditTarget(asset: $0) } }, set: { editing = $0?.asset })) { t in
            PhotoEditor(asset: t.asset, library: library)
        }
        .onChange(of: current) { _, _ in prepareFile() }
        .onAppear(perform: prepareFile)
        .onChange(of: library.assets.count) { _, _ in
            if asset == nil { if let first = library.assets.first { current = first.localIdentifier } else { dismiss() } }
        }
    }

    private var top: some View {
        HStack {
            RoundButton(action: { dismiss() }) { Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)) }
                .accessibilityLabel("Close")
            Spacer()
            VStack(spacing: 2) {
                Text(dayTitle).font(XA.display(15))
                Text(timeTitle).font(.system(size: 12)).foregroundStyle(XA.dim)
            }
            Spacer()
            Text(position).font(XA.mono(12)).frame(width: 44)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private var actions: some View {
        HStack {
            if let file {
                ShareLink(item: file) { icon("square.and.arrow.up", "Send") }
            } else { icon("square.and.arrow.up", "Send").opacity(0.4) }
            Spacer()
            Button { editing = asset } label: { icon("slider.horizontal.3", "Edit") }
            Spacer()
            Button { info = true } label: { icon("info.circle", "Info") }
            Spacer()
            Button { if let asset { library.delete(asset) } } label: { icon("trash", "Delete") }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28).padding(.top, 10).padding(.bottom, 12)
        .background(Color.black.opacity(0.6))
    }

    private func icon(_ name: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: name).font(.system(size: 20))
            Text(label.uppercased()).font(XA.display(10))
        }
        .frame(minWidth: 52, minHeight: 44)
        .accessibilityLabel(label)
    }

    private var position: String {
        guard let i = assets.firstIndex(where: { $0.localIdentifier == current }) else { return "" }
        return "\(i + 1)/\(assets.count)"
    }

    private var dayTitle: String {
        guard let d = asset?.creationDate else { return "" }
        if Calendar.current.isDateInToday(d) { return "TODAY" }
        if Calendar.current.isDateInYesterday(d) { return "YESTERDAY" }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM yyyy"
        return f.string(from: d).uppercased()
    }

    private var timeTitle: String {
        guard let d = asset?.creationDate else { return "" }
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: d)
    }

    private func prepareFile() {
        file = nil
        guard let a = asset else { return }
        let id = a.localIdentifier
        library.data(a) { d, uti in
            guard let d, id == current else { return }
            let ext = (uti.flatMap { UTType($0)?.preferredFilenameExtension }) ?? "jpg"
            let safe = id.replacingOccurrences(of: "/", with: "-").prefix(12)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("XA-\(safe).\(ext)")
            try? d.write(to: url)
            DispatchQueue.main.async { if id == current { file = url } }
        }
    }
}

private struct EditTarget: Identifiable { let asset: PHAsset; var id: String { asset.localIdentifier } }

private struct PhotoPage: View {
    let asset: PHAsset
    let library: Library
    @Binding var zoomed: Bool
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            if let img { ZoomableImage(image: img, zoomed: $zoomed) } else { ProgressView().tint(.white) }
        }
        .onAppear { if img == nil { library.full(asset) { img = $0 } } }
        .onChange(of: asset.modificationDate) { _, _ in library.full(asset) { img = $0 } }
    }
}

/// Thumbnails along the bottom. The current one is lit and kept centred; tap to jump.
private struct ThumbRow: View {
    @ObservedObject var library: Library
    @Binding var current: String
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 3) {
                    ForEach(library.assets, id: \.localIdentifier) { a in
                        let on = a.localIdentifier == current
                        SmallThumb(asset: a, library: library)
                            .frame(width: on ? 44 : 32, height: 48)
                            .clipped()
                            .overlay(Rectangle().strokeBorder(on ? XA.orange : .clear, lineWidth: 2))
                            .id(a.localIdentifier)
                            .onTapGesture { withAnimation(.snappy) { current = a.localIdentifier } }
                    }
                }
                .padding(.horizontal, 180)
            }
            .frame(height: 52)
            .onAppear { proxy.scrollTo(current, anchor: .center) }
            .onChange(of: current) { _, c in withAnimation(.snappy) { proxy.scrollTo(c, anchor: .center) } }
        }
        .background(Color.black.opacity(0.6))
    }
}

private struct SmallThumb: View {
    let asset: PHAsset
    let library: Library
    @State private var img: UIImage?
    var body: some View {
        Color.black
            .overlay { if let img { Image(uiImage: img).resizable().scaledToFill() } }
            .onAppear { library.thumbnail(asset, side: 100) { img = $0 } }
    }
}

/// The file's own story: film, size, exposure, lens, format.
private struct PhotoInfo: View {
    let asset: PHAsset
    let library: Library
    @State private var rows: [(String, String)] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INFO").font(XA.display(20)).padding(.bottom, 12)
            ForEach(rows.indices, id: \.self) { i in
                HStack(alignment: .top) {
                    Text(rows[i].0).font(.system(size: 14)).foregroundStyle(XA.dim).frame(width: 110, alignment: .leading)
                    Text(rows[i].1).font(.system(size: 14, weight: rows[i].0 == "Film" ? .semibold : .regular))
                        .foregroundStyle(rows[i].0 == "Film" ? XA.orange : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 9)
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
            }
            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(red: 0.07, green: 0.07, blue: 0.075))
        .preferredColorScheme(.dark)
        .onAppear { library.metadata(asset) { rows = $0 } }
    }
}
