import SwiftUI
import Photos
import UniformTypeIdentifiers

/// The roll: every XA picture, by day, newest first. Pulls down from the camera; flick up to go back.
struct ContactSheet: View {
    @ObservedObject var library: Library
    var onClose: (() -> Void)?
    /// Live drag distance while pulling the roll down, so the layer follows the finger.
    var onDrag: ((CGFloat) -> Void)?
    @State private var open: Opened?

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 8)
            HStack(alignment: .firstTextBaseline) {
                Text("ROLL").font(XA.display(40))
                Text("\(library.assets.count)").font(XA.mono(13)).foregroundStyle(XA.dim)
                Spacer()
                if let onClose {
                    RoundButton(action: onClose) { Image(systemName: "camera.fill").font(.system(size: 16)) }
                        .accessibilityLabel("Back to the camera")
                }
            }
            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 6)
            .contentShape(Rectangle())
            // The header is a handle: drag it down and the roll follows the finger.
            .gesture(DragGesture(minimumDistance: 6).onChanged { v in
                onDrag?(max(0, v.translation.height))
            }.onEnded { v in
                if v.translation.height > 110 || v.predictedEndTranslation.height > 260 { onClose?() } else { onDrag?(0) }
            })
            if library.denied {
                // Photos access was turned down: the pictures are in Photos, the roll can't see them.
                Spacer()
                VStack(spacing: 14) {
                    Text("Your pictures are in the Photos app.").font(XA.display(16))
                    Text("To see them here too, let XA see your photos.").font(.system(size: 14)).foregroundStyle(XA.dim)
                    Button("Open Settings") {
                        if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                    }
                    .font(XA.display(16)).padding(.horizontal, 18).padding(.vertical, 12)
                    .background(XA.orange).foregroundStyle(.black)
                }
                .multilineTextAlignment(.center).padding(.horizontal, 24)
                Spacer()
            } else if !library.authorized {
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
                RollTable(library: library, onOpen: { open = Opened(asset: $0) }, onPullClose: onClose)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .xaBackToCamera)) { _ in open = nil }
        .fullScreenCover(item: $open) { o in
            PhotoViewer(library: library, current: o.asset.localIdentifier)
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
        Color.black
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay { if let img { Image(uiImage: img).resizable().scaledToFit() } }
            .overlay(alignment: .bottomTrailing) {
                if asset.mediaType == .video {
                    Text(Library.clock(asset.duration)).font(XA.mono(10)).padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.black.opacity(0.6)).padding(4)
                }
            }
            .clipped()
            .onAppear { library.thumbnail(asset, side: 320) { img = $0 } }
    }
}

/// Pinch to zoom, double-tap to zoom in and out, pan when zoomed.
struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    @Binding var zoomed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIScrollView {
        let sv = FittingScrollView()
        sv.delegate = context.coordinator
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 8
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.backgroundColor = .clear
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        iv.backgroundColor = .clear
        sv.addSubview(iv)
        context.coordinator.imageView = iv
        sv.imageView = iv
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        sv.addGestureRecognizer(tap)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        DispatchQueue.main.async {
            if sv.zoomScale == 1 { context.coordinator.imageView?.frame = sv.bounds }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableImage
        weak var imageView: UIImageView?
        init(_ p: ZoomableImage) { parent = p }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ sv: UIScrollView) {
            let z = sv.zoomScale > 1.01
            if z != parent.zoomed { DispatchQueue.main.async { self.parent.zoomed = z } }
        }

        @objc func doubleTap(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? UIScrollView else { return }
            if sv.zoomScale > 1.01 {
                sv.setZoomScale(1, animated: true)
            } else {
                let p = g.location(in: imageView)
                let w = sv.bounds.width / 3, h = sv.bounds.height / 3
                sv.zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
            }
        }
    }
}


/// Keeps the photo fitted to the screen whenever the scroll view is laid out. Fitting it once,
/// right after it was made, sometimes ran while the view was still zero by zero: the photo got
/// a zero frame and the page stayed black.
final class FittingScrollView: UIScrollView {
    weak var imageView: UIImageView?
    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == 1, let iv = imageView, iv.frame.size != bounds.size { iv.frame = bounds }
    }
}
