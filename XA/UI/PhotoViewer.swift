import SwiftUI
import Photos
import UniformTypeIdentifiers
import AVKit

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
                .disabled(asset?.mediaType == .video).opacity(asset?.mediaType == .video ? 0.3 : 1)
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
        if a.mediaType == .video {
            library.exportVideo(a) { url in if id == current { file = url } }
            return
        }
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
    @State private var player: AVPlayer?
    var body: some View {
        ZStack {
            if asset.mediaType == .video {
                if let player {
                    VideoPlayer(player: player).onDisappear { player.pause() }
                    VStack { Spacer(); TakeScrubber(player: player, segments: TakeSegment.load(for: asset.localIdentifier), duration: asset.duration).padding(.horizontal, 16).padding(.bottom, 150) }
                } else { ProgressView().tint(.white) }
            } else if let img { ZoomableImage(image: img, zoomed: $zoomed) } else { ProgressView().tint(.white) }
        }
        .onAppear {
            if asset.mediaType == .video {
                if player == nil { library.playerItem(asset) { item in if let item { player = AVPlayer(playerItem: item) } } }
            } else if img == nil { library.full(asset) { img = $0 } }
        }
        .onChange(of: asset.modificationDate) { _, _ in library.full(asset) { img = $0 } }
    }
}

/// Thumbnails along the bottom, like Photos: drag the strip and the photo follows whichever
/// thumbnail sits in the middle; swipe the photo and the strip follows. Tap to jump.
private struct ThumbRow: View {
    @ObservedObject var library: Library
    @Binding var current: String
    @State private var centred: String?
    @State private var dragging = false
    private let cell: CGFloat = 34

    var body: some View {
        GeometryReader { g in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 2) {
                    ForEach(library.assets, id: \.localIdentifier) { a in
                        let on = a.localIdentifier == current
                        SmallThumb(asset: a, library: library)
                            .frame(width: cell, height: 48)
                            .clipped()
                            .overlay(Rectangle().strokeBorder(on ? XA.orange : .clear, lineWidth: 2))
                            .scaleEffect(y: on ? 1.08 : 1)
                            .id(a.localIdentifier)
                            .onTapGesture { withAnimation(.snappy) { centred = a.localIdentifier; current = a.localIdentifier } }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, g.size.width / 2 - cell / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centred, anchor: .center)
            .onScrollPhaseChange { _, phase in dragging = phase == .interacting || phase == .decelerating }
            .onChange(of: centred) { _, c in
                // Scrubbing: the photo follows the strip, without the page-turn animation.
                guard dragging, let c, c != current else { return }
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { current = c }
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .onChange(of: current) { _, c in if centred != c && !dragging { withAnimation(.snappy) { centred = c } } }
            .onAppear { centred = current }
        }
        .frame(height: 56)
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

/// The take's tapes as a scrub bar: drag to seek, the playhead follows playback.
private struct TakeScrubber: View {
    let player: AVPlayer
    let segments: [TakeSegment]
    let duration: Double
    @State private var t: Double = 0
    @State private var token: Any?
    var body: some View {
        let spans = TakeSegment.spans(segments.isEmpty ? [TakeSegment(look: .clean, start: 0)] : segments, duration: max(duration, 0.01))
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(spans.indices, id: \.self) { i in
                            Rectangle().fill(Color(hex: spans[i].0.color).opacity(0.85))
                                .frame(width: max(2, (g.size.width - CGFloat(spans.count) * 2) * CGFloat(spans[i].1)))
                        }
                    }
                    Rectangle().fill(Color.white).frame(width: 3, height: 34).offset(x: g.size.width * CGFloat(t / max(duration, 0.01)) - 1.5)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let f = min(1, max(0, v.location.x / g.size.width))
                    t = f * duration
                    player.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                })
            }
            .frame(height: 30)
            HStack {
                Text(spans.map { $0.0.title }.joined(separator: " → ")).font(XA.display(10)).foregroundStyle(XA.dim)
                Spacer()
                Text("\(Library.clock(t)) / \(Library.clock(duration))").font(XA.mono(10)).foregroundStyle(XA.dim)
            }
        }
        .onAppear {
            token = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { time in t = time.seconds }
        }
        .onDisappear { if let token { player.removeTimeObserver(token) } }
    }
}
