import MetalKit
import CoreImage
import SwiftUI
import AVKit

/// The viewfinder: developed Core Image frames drawn straight into a Metal layer. Frames are
/// rendered on the camera's frame queue, not the main thread, so the viewfinder keeps moving
/// while SwiftUI is busy (a mode switch, the film rows opening).
final class PreviewView: MTKView {
    private let ci: CIContext
    private let queue: MTLCommandQueue?
    private let sizeLock = NSLock()
    private var _size: CGSize = .zero

    init() {
        let dev = MTLCreateSystemDefaultDevice()
        ci = dev.map { CIContext(mtlDevice: $0, options: [.cacheIntermediates: false, .priorityRequestLow: false]) } ?? CIContext()
        queue = dev?.makeCommandQueue()
        super.init(frame: .zero, device: dev)
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = false
        autoResizeDrawable = true
        colorPixelFormat = .bgra8Unorm
        backgroundColor = .black
        contentMode = .scaleAspectFill
    }

    required init(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let ds = drawableSize
        sizeLock.lock(); _size = ds; sizeLock.unlock()
    }

    /// Call from any queue.
    func show(_ img: CIImage, pixelated: Bool) {
        sizeLock.lock(); let known = _size; sizeLock.unlock()
        guard known.width > 0, known.height > 0, let layer = self.layer as? CAMetalLayer,
              let drawable = layer.nextDrawable(), let cb = queue?.makeCommandBuffer() else { return }
        // Size from the texture actually handed out, not the one remembered at the last layout.
        // The viewfinder changes height when PRO's dials come in; a stale size left strips of the
        // texture undrawn along the top and right, showing whatever was in them before.
        let ds = CGSize(width: drawable.texture.width, height: drawable.texture.height)
        // Whole pixels only. A downscaled frame ends mid-pixel on its far edges (top and right in
        // Core Image), and scaling that again for the screen blends the half-covered row with
        // transparency: a faint line along the top and right. PRO shows it because nothing else
        // crops the raw frame. Clamp, then crop to the whole pixels inside.
        let f = img.extent
        let e = CGRect(x: f.minX.rounded(.up), y: f.minY.rounded(.up),
                       width: f.maxX.rounded(.down) - f.minX.rounded(.up),
                       height: f.maxY.rounded(.down) - f.minY.rounded(.up))
        guard e.width > 0, e.height > 0 else { return }
        let img = img.clampedToExtent().cropped(to: e)
        // Fit, not fill: an instant print is square and must not be cropped.
        let s = min(ds.width / e.width, ds.height / e.height)
        var src = pixelated ? img.samplingNearest() : img
        src = src.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
            .transformed(by: CGAffineTransform(scaleX: s, y: s))
            .transformed(by: CGAffineTransform(translationX: (ds.width - e.width * s) / 2, y: (ds.height - e.height * s) / 2))
        let bounds = CGRect(origin: .zero, size: ds)
        let bg = CIImage(color: .black).cropped(to: bounds)
        ci.render(src.composited(over: bg), to: drawable.texture, commandBuffer: cb, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
        cb.present(drawable)
        cb.commit()
    }
}

/// Hosts the preview and turns the volume buttons and a Camera Control click into the shutter.
struct Viewfinder: UIViewRepresentable {
    let camera: CameraModel

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        camera.preview = v
        // Two-stage button: Camera Control's light press is the first stage (the system's own);
        // the full press fires the instant it goes down, not when the button comes back up.
        let shutter = AVCaptureEventInteraction { event in
            if event.phase == .began { camera.fullPress() }
        }
        v.addInteraction(shutter)
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
