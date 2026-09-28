import SwiftUI
import Photos
import UniformTypeIdentifiers

/// The roll: every XA picture, by day, newest first. Pulls down from the camera; flick up to go back.
struct ContactSheet: View {
    @ObservedObject var library: Library
    var onClose: (() -> Void)?
    @State private var open: Opened?
    @State private var drag: CGFloat = 0

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("ROLL").font(XA.display(40))
                Text("\(library.assets.count)").font(XA.mono(13)).foregroundStyle(XA.dim)
                Spacer()
                if let onClose {
                    RoundButton(action: onClose) { Image(systemName: "camera.fill").font(.system(size: 16)) }
                        .accessibilityLabel("Back to the camera")
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
            if !library.authorized {
                Spacer()
                Button("Show my XA pictures") { library.requestAccess() }
                    .font(XA.display(16)).padding(.horizontal, 18).padding(.vertical, 12)
                    .background(XA.orange).foregroundStyle(.black)
                Spacer()
            } else if library.assets.isEmpty {
                Spacer()
                Text("Nothing on the roll yet.").foregroundStyle(XA.dim)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(library.days, id: \.title) { day in
                            Text(day.title).font(.system(size: 12, weight: .semibold)).tracking(1)
                                .foregroundStyle(XA.faint).padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                            LazyVGrid(columns: cols, spacing: 3) {
                                ForEach(day.assets, id: \.localIdentifier) { a in
                                    Thumb(asset: a, library: library).onTapGesture { open = Opened(asset: a) }
                                }
                            }
                            .padding(.horizontal, 3)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .offset(y: min(0, drag))
        .gesture(DragGesture(minimumDistance: 30).onChanged { v in
            if v.translation.height < 0 && abs(v.translation.height) > abs(v.translation.width) { drag = v.translation.height }
        }.onEnded { v in
            if v.translation.height < -120 { onClose?() }
            withAnimation(.snappy) { drag = 0 }
        })
        .fullScreenCover(item: $open) { o in
            FullPhoto(asset: o.asset, library: library)
        }
    }
}

private struct Opened: Identifiable { let asset: PHAsset; var id: String { asset.localIdentifier } }

/// The transparency checkerboard, for shaped pictures.
struct Checker: View {
    var size: CGFloat = 9
    var body: some View {
        SwiftUI.Canvas { ctx, s in
            ctx.fill(Path(CGRect(origin: .zero, size: s)), with: .color(Color(red: 0.047, green: 0.047, blue: 0.051)))
            var y: CGFloat = 0, row = 0
            while y < s.height {
                var x: CGFloat = row % 2 == 0 ? 0 : size
                while x < s.width {
                    ctx.fill(Path(CGRect(x: x, y: y, width: size, height: size)), with: .color(Color(red: 0.082, green: 0.082, blue: 0.09)))
                    x += size * 2
                }
                y += size; row += 1
            }
        }
    }
}

private struct Thumb: View {
    let asset: PHAsset
    let library: Library
    @State private var img: UIImage?

    var body: some View {
        Checker(size: 6)
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay { if let img { Image(uiImage: img).resizable().scaledToFill() } }
            .clipped()
            .onAppear { library.thumbnail(asset, side: 320) { img = $0 } }
    }
}

private struct FullPhoto: View {
    let asset: PHAsset
    let library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var img: UIImage?
    @State private var file: URL?

    var body: some View {
        ZStack {
            Checker(size: 14).ignoresSafeArea()
            if let img { Image(uiImage: img).resizable().scaledToFit() } else { ProgressView() }
            VStack {
                HStack {
                    RoundButton(action: { dismiss() }) { Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)) }
                        .accessibilityLabel("Close")
                    Spacer()
                }
                Spacer()
                if let file {
                    ShareLink(item: file) {
                        Label("SEND", systemImage: "square.and.arrow.up").font(XA.display(15))
                            .padding(.horizontal, 20).padding(.vertical, 11).background(XA.orange).foregroundStyle(.black)
                    }
                }
            }
            .padding(16)
        }
        .foregroundStyle(.white)
        .gesture(DragGesture().onEnded { v in if v.translation.height > 120 { dismiss() } })
        .onAppear {
            library.full(asset) { img = $0 }
            library.data(asset) { d, uti in
                guard let d else { return }
                let ext = (uti.flatMap { UTType($0)?.preferredFilenameExtension }) ?? "jpg"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("XA-\(asset.localIdentifier.prefix(8)).\(ext)")
                try? d.write(to: url)
                file = url
            }
        }
    }
}
