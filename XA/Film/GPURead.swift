import CoreImage
import CoreVideo
import Foundation

/// Reads from the GPU without waiting for it where the read is asked for. The render is queued
/// on the caller's queue; the pixels arrive on `queue` once the GPU is done. (The viewfinder's
/// reads used to wait on the frame queue: every one held up the next camera frame, and the
/// viewfinder skipped a beat a few times a second.)
enum GPURead {
    /// One queue, in order: a read's handler can keep state without a lock of its own.
    static let queue = DispatchQueue(label: "xa.reads", qos: .userInitiated)

    /// `img`'s pixels in `bounds` as RGBA floats in the context's working space (no output colour
    /// management, as `render(_:toBitmap:...colorSpace: nil)` gives), handed to `done` on `queue`.
    /// False (and `done` never called) when the render couldn't be started.
    @discardableResult
    static func floats(_ img: CIImage, bounds: CGRect, context: CIContext, done: @escaping ([Float]) -> Void) -> Bool {
        let w = Int(bounds.width), h = Int(bounds.height)
        guard w > 0, h > 0 else { return false }
        let rowBytes = w * 16
        let buf = UnsafeMutableRawPointer.allocate(byteCount: rowBytes * h, alignment: 16)
        let dest = CIRenderDestination(bitmapData: buf, width: w, height: h, bytesPerRow: rowBytes, format: .RGBAf)
        dest.colorSpace = nil
        guard let task = try? context.startTask(toRender: img, from: bounds, to: dest, at: .zero) else {
            buf.deallocate()
            return false
        }
        queue.async {
            _ = try? task.waitUntilCompleted()
            let px = Array(UnsafeBufferPointer(start: buf.assumingMemoryBound(to: Float.self), count: w * h * 4))
            buf.deallocate()
            done(px)
        }
        return true
    }

    /// `img` (its extent at the origin, the buffer's size) drawn into `pb`; `done` gets the copy on
    /// `queue` once it is there. The camera's own buffer goes back to it as soon as the GPU has read it.
    @discardableResult
    static func copy(_ img: CIImage, into pb: CVPixelBuffer, context: CIContext, done: @escaping (CIImage) -> Void) -> Bool {
        let dest = CIRenderDestination(pixelBuffer: pb)
        dest.colorSpace = sRGB
        guard let task = try? context.startTask(toRender: img, to: dest) else { return false }
        queue.async {
            _ = try? task.waitUntilCompleted()
            done(CIImage(cvPixelBuffer: pb, options: [.colorSpace: sRGB]))
        }
        return true
    }

    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
}

/// Small BGRA frames of the app's own, for copies taken off the camera's frames. Use from one queue.
final class FramePool {
    private var pool: CVPixelBufferPool?
    private var width = 0, height = 0

    func buffer(width w: Int, height h: Int) -> CVPixelBuffer? {
        guard w > 0, h > 0 else { return nil }
        if pool == nil || w != width || h != height {
            let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                        kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
                                        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                                        kCVPixelBufferMetalCompatibilityKey as String: true]
            var p: CVPixelBufferPool?
            CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &p)
            pool = p; width = w; height = h
        }
        guard let pool else { return nil }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
        return pb
    }
}
