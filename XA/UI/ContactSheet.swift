import SwiftUI
import Photos

/// Every picture XA has taken, newest first, as a contact sheet.
struct ContactSheet: View {
    @ObservedObject var library: Library
    var onClose: (() -> Void)?
    @State private var open: PHAsset?

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 3), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Roll").font(.system(size: 30, weight: .heavy))
                Spacer()
                Text("\(library.assets.count)").font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
                if let onClose {
                    Button(action: onClose) { Image(systemName: "camera.fill").padding(10) }
                        .buttonStyle(.plain).background(.ultraThinMaterial, in: Circle())
                        .accessibilityLabel("Back to the camera")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            if !library.authorized {
                Spacer()
                Button("Show my XA pictures") { library.requestAccess() }.buttonStyle(.borderedProminent).tint(.orange)
                Spacer()
            } else if library.assets.isEmpty {
                Spacer()
                Text("Nothing on the roll yet.").foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 3) {
                        ForEach(library.assets, id: \.localIdentifier) { a in
                            Thumb(asset: a, library: library)
                                .onTapGesture { open = a }
                        }
                    }
                    .padding(3)
                }
            }
        }
        .background(Color(white: 0.06))
        .foregroundStyle(.white)
        .sheet(item: Binding(get: { open.map(Opened.init) }, set: { open = $0?.asset })) { o in
            FullPhoto(asset: o.asset, library: library)
        }
    }
}

private struct Opened: Identifiable { let asset: PHAsset; var id: String { asset.localIdentifier } }

private struct Thumb: View {
    let asset: PHAsset
    let library: Library
    @State private var img: UIImage?

    var body: some View {
        Color(white: 0.12)
            .aspectRatio(1, contentMode: .fit)
            .overlay { if let img { Image(uiImage: img).resizable().scaledToFill() } }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .onAppear { library.thumbnail(asset, side: 240) { img = $0 } }
    }
}

private struct FullPhoto: View {
    let asset: PHAsset
    let library: Library
    @State private var img: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img {
                Image(uiImage: img).resizable().scaledToFit()
                VStack {
                    Spacer()
                    ShareLink(item: Image(uiImage: img), preview: SharePreview("XA picture", image: Image(uiImage: img))) {
                        Label("Send", systemImage: "square.and.arrow.up").padding(.horizontal, 18).padding(.vertical, 10)
                    }
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                }
            } else { ProgressView() }
        }
        .onAppear { library.full(asset) { img = $0 } }
    }
}
