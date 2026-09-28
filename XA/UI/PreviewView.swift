import MetalKit
import CoreImage
import SwiftUI
import AVKit

/// The viewfinder: filtered Core Image frames drawn straight into a Metal view, aspect-filled.
final class PreviewView: MTKView {
    private let ci: CIContext
    private let queue: MTLCommandQueue?
    private var image: CIImage?
    private var pixelated = false

    init() {
        let dev = MTLCreateSystemDefaultDevice()
        ci = dev.map { CIContext(mtlDevice: $0, options: [.cacheIntermediates: false]) } ?? CIContext()
        queue = dev?.makeCommandQueue()
        super.init(frame: .zero, device: dev)
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = true
        colorPixelFormat = .bgra8Unorm
        backgroundColor = .black
        contentMode = .scaleAspectFill
    }

    required init(coder: NSCoder) { fatalError("not used") }

    func show(_ img: CIImage, pixelated: Bool) {
        image = img
        self.pixelated = pixelated
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let img = image, let drawable = currentDrawable, let cb = queue?.makeCommandBuffer() else { return }
        let ds = drawableSize
        let e = img.extent
        guard e.width > 0, e.height > 0 else { return }
        let s = max(ds.width / e.width, ds.height / e.height)
        var src = pixelated ? img.samplingNearest() : img
        src = src.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
            .transformed(by: CGAffineTransform(scaleX: s, y: s))
            .transformed(by: CGAffineTransform(translationX: (ds.width - e.width * s) / 2, y: (ds.height - e.height * s) / 2))
        let bg = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: ds))
        ci.render(src.composited(over: bg), to: drawable.texture, commandBuffer: cb, bounds: CGRect(origin: .zero, size: ds), colorSpace: CGColorSpaceCreateDeviceRGB())
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
        let shutter = AVCaptureEventInteraction { event in
            if event.phase == .began { camera.shoot() }
        }
        v.addInteraction(shutter)
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
