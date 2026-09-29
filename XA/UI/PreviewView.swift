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
        sizeLock.lock(); let ds = _size; sizeLock.unlock()
        guard ds.width > 0, ds.height > 0, let layer = self.layer as? CAMetalLayer,
              let drawable = layer.nextDrawable(), let cb = queue?.makeCommandBuffer() else { return }
        let e = img.extent
        guard e.width > 0, e.height > 0 else { return }
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
        // Buttons act on the way down: the first press locks focus, the second fires.
        let shutter = AVCaptureEventInteraction { event in
            if event.phase == .began { camera.press() }
        }
        v.addInteraction(shutter)
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
