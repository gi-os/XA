import XCTest
import CoreImage
import Metal
@testable import XA

/// Not a check: times each step of the viewfinder's frame (develop, the XA finder, the draw and
/// the reads) on a camera-sized frame, to see where a frame's time goes. Skipped unless
/// XA_FINDER_TIMING is set (TEST_RUNNER_XA_FINDER_TIMING from the command line); XA_FILM_IN is the
/// picture to use (a grey frame without it).
final class FinderTimingTests: XCTestCase {
    func testFinderTiming() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["XA_FINDER_TIMING"] != nil else { throw XCTSkip("set XA_FINDER_TIMING to time the viewfinder") }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let ci = CIContext(mtlDevice: device, options: [.cacheIntermediates: false, .priorityRequestLow: false])
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1206, height: 1800, mipmapped: false)
        td.usage = [.shaderRead, .shaderWrite, .renderTarget]
        td.storageMode = .private
        let tex = try XCTUnwrap(device.makeTexture(descriptor: td))

        // a camera frame: landscape 4:3 in a pixel buffer, the way the camera hands it over
        let frame = try cameraFrame(env["XA_FILM_IN"], width: Int(env["XA_FINDER_W"] ?? "1440") ?? 1440, ci: ci)
        let uwBuffer = try cameraFrame(env["XA_FILM_IN"], width: 480, ci: ci)

        func draw(_ img: CIImage) {
            let e = img.extent
            let s = min(CGFloat(tex.width) / e.width, CGFloat(tex.height) / e.height)
            let src = img.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY)).transformed(by: CGAffineTransform(scaleX: s, y: s))
            let bounds = CGRect(x: 0, y: 0, width: tex.width, height: tex.height)
            let cb = queue.makeCommandBuffer()!
            ci.render(src.composited(over: CIImage(color: .black).cropped(to: bounds)), to: tex, commandBuffer: cb, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
            cb.commit()
            cb.waitUntilCompleted()
        }
        func small(_ width: CGFloat) -> CIImage {
            let raw = CameraModel.upright(Sanitize.apply(CIImage(cvPixelBuffer: frame), floor: 0), mirror: false)
            let k = min(1, width / raw.extent.width)
            return raw.transformed(by: CGAffineTransform(scaleX: k, y: k))
        }
        var film = DevelopSettings()
        film.film = true
        film.stack = Stack(simID: env["XA_FILM_STOCKS"] ?? "bowery400")
        film.filmRecipe.leak = 0
        var accurate = film
        accurate.accurate = true
        let wide = CIImage(cvPixelBuffer: uwBuffer)
        let long = XAFinder.long(1.45)

        var report: [String] = []
        func time(_ name: String, _ body: () -> Void) {
            for _ in 0..<4 { body() }
            let n = 30
            let t0 = CACurrentMediaTime()
            for _ in 0..<n { autoreleasepool { body() } }
            let ms = (CACurrentMediaTime() - t0) / Double(n) * 1000
            report.append(String(format: "%-44@ %6.2f ms", name as NSString, ms))
        }
        time("plain 1080 draw") { draw(small(1080)) }
        time("plain 810 draw") { draw(small(810)) }
        time("film finder (no ultra-wide)") { draw(XAFinder.compose(small(810), format: .mm35, long: long)) }
        time("film finder + ultra-wide") { draw(XAFinder.compose(small(810), format: .mm35, long: long, wide: wide, ratio: 2)) }
        time("film peek, quick cube") {
            draw(XAFinder.compose(Darkroom.develop(small(810), film, date: Date(), preview: true).0, format: .mm35, long: long, wide: wide, ratio: 2))
        }
        time("film peek, accurate") {
            draw(XAFinder.compose(Darkroom.develop(small(810), accurate, date: Date(), preview: true).0, format: .mm35, long: long, wide: wide, ratio: 2))
        }
        time("film peek, accurate 540") {
            draw(XAFinder.compose(Darkroom.develop(small(540), accurate, date: Date(), preview: true).0, format: .mm35, long: long, wide: wide, ratio: 2))
        }
        time("film peek as the camera runs it (640 lab, finder)") {
            let u = small(810)
            let e = u.extent
            let sm = CGRect(x: 0, y: 0, width: 640, height: (e.height * 640 / e.width).rounded(.down))
            let input = u.transformed(by: CGAffineTransform(scaleX: sm.width / e.width, y: sm.height / e.height)).cropped(to: sm)
            let dev = Darkroom.develop(input, accurate, date: Date(), preview: true).0.clampedToExtent()
                .transformed(by: CGAffineTransform(scaleX: e.width / sm.width, y: e.height / sm.height)).cropped(to: e)
            draw(XAFinder.compose(dev, format: .mm35, long: long, wide: wide, ratio: 2))
        }
        time("accurate develop only (draw)") { draw(Darkroom.develop(small(810), accurate, date: Date(), preview: true).0) }
        time("accurate develop, graph only (no draw)") { _ = Darkroom.develop(small(810), accurate, date: Date(), preview: true).0 }
        time("quick develop only (draw)") { draw(Darkroom.develop(small(810), film, date: Date(), preview: true).0) }
        time("quick develop, graph only (no draw)") { _ = Darkroom.develop(small(810), film, date: Date(), preview: true).0 }
        time("finder compose, graph only (no draw)") { _ = XAFinder.compose(small(810), format: .mm35, long: long, wide: wide, ratio: 2) }
        time("film finder + ultra-wide, settled patch") { draw(XAFinder.compose(small(810), format: .mm35, shift: 0, long: long, wide: wide, ratio: 2, intro: 1)) }
        for (name, change) in [("glare 0", { (d: inout DevelopSettings) in d.filmRecipe.glare = 0 }),
                               ("halation 0", { (d: inout DevelopSettings) in d.filmRecipe.halation = 0 }),
                               ("grain 0", { (d: inout DevelopSettings) in d.filmRecipe.grain = 0 }),
                               ("labAuto 0", { (d: inout DevelopSettings) in d.filmRecipe.labAuto = 0 }),
                               ("lens 0 flash 0 mist 0", { (d: inout DevelopSettings) in d.filmRecipe.lens = 0; d.filmRecipe.flash = 0; d.filmRecipe.mist = 0 })] {
            var d = accurate
            change(&d)
            time("accurate develop, \(name)") { draw(Darkroom.develop(small(810), d, date: Date(), preview: true).0) }
        }
        time("accurate develop 640") { draw(Darkroom.develop(small(640), accurate, date: Date(), preview: true).0) }
        time("brightness of the raw frame") { _ = XAFinder.brightness(small(810)) }
        time("brightness of the accurate develop") { _ = XAFinder.brightness(Darkroom.develop(small(810), accurate, date: Date(), preview: true).0) }
        time("match gain on the raw frame") { _ = XAFinder.matchGain(main: small(810), wide: wide, ratio: 2) }
        time("small copy, waited for (the old way)") {
            let s = small(810)
            let k: CGFloat = 640 / s.extent.width
            _ = Looks.context.createCGImage(s.transformed(by: CGAffineTransform(scaleX: k, y: k)), from: CGRect(x: 0, y: 0, width: 640, height: 853))
        }
        // the copies the frame queue now only starts (GPURead): what they cost the frame queue,
        // and that they arrive as a real picture
        let pool = FramePool()
        let done = DispatchGroup()
        var copied: CIImage?
        time("side copy, started (async)") {
            let s = small(810)
            let k: CGFloat = 640 / s.extent.width
            let h = Int((s.extent.height * k).rounded(.down))
            let img = s.transformed(by: CGAffineTransform(scaleX: k, y: k)).cropped(to: CGRect(x: 0, y: 0, width: 640, height: h))
            if let pb = pool.buffer(width: 640, height: h) {
                done.enter()
                if !GPURead.copy(img, into: pb, context: Looks.context, done: { c in copied = c; done.leave() }) { done.leave() }
            }
        }
        done.wait()
        let copy = try XCTUnwrap(copied)
        let y = try XCTUnwrap(XAFinder.brightness(copy))
        let y0 = try XCTUnwrap(XAFinder.brightness(small(810)))
        report.append(String(format: "side copy brightness %.3f, frame %.3f", y, y0))
        XCTAssertEqual(Double(y), Double(y0), accuracy: 0.03)
        var digi = DevelopSettings()
        digi.stack = Stack(simID: env["XA_DIGI_SIM"] ?? Sim.presets.first(where: { !$0.isNeutral })?.id ?? "")
        time("digi develop (\(digi.stack.simID ?? "-"))") { draw(Darkroom.develop(small(810), digi, date: Date(), preview: true).0) }
        let text = report.joined(separator: "\n")
        print("FINDER TIMING\n" + text)
        if let out = env["XA_FILM_OUT"] {
            try text.write(to: URL(fileURLWithPath: out).appendingPathComponent("finder-timing.txt"), atomically: true, encoding: .utf8)
        }
    }

    private func cameraFrame(_ path: String?, width: Int, ci: CIContext) throws -> CVPixelBuffer {
        let height = width * 3 / 4
        var out: CVPixelBuffer?
        let attrs: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                                    kCVPixelBufferMetalCompatibilityKey as String: true]
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &out), kCVReturnSuccess)
        let pb = try XCTUnwrap(out)
        var img = CIImage(color: CIColor(red: 0.45, green: 0.45, blue: 0.45)).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        if let path, let photo = CIImage(contentsOf: URL(fileURLWithPath: path), options: [.applyOrientationProperty: true]) {
            // landscape, as the sensor reads
            var p = photo
            if p.extent.height > p.extent.width { p = CameraModel.rotated(p, clockwise: 270) }
            let s = max(CGFloat(width) / p.extent.width, CGFloat(height) / p.extent.height)
            p = p.transformed(by: CGAffineTransform(scaleX: s, y: s))
            img = p.transformed(by: CGAffineTransform(translationX: -p.extent.minX, y: -p.extent.minY)).cropped(to: img.extent)
        }
        ci.render(img, to: pb)
        return pb
    }
}
