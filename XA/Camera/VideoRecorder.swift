import AVFoundation
import CoreImage

/// Writes developed frames and microphone audio to a movie file.
final class VideoRecorder {
    let url: URL
    let size: CGSize
    private let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let audio: AVAssetWriterInput?
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private var started = false
    /// Once finishing starts nothing more may be appended (AVFoundation throws if it is).
    private var finished = false
    private var firstTime: CMTime = .invalid
    private(set) var lastTime: CMTime = .zero
    private let lock = NSLock()
    static let context = CIContext(options: [.cacheIntermediates: false])

    init?(size: CGSize, audio withAudio: Bool) {
        let w = Int(size.width) / 2 * 2, h = Int(size.height) / 2 * 2
        self.size = CGSize(width: w, height: h)
        url = FileManager.default.temporaryDirectory.appendingPathComponent("XA-\(Int(Date().timeIntervalSince1970 * 1000)).mov")
        guard let wr = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return nil }
        writer = wr
        let codec: AVVideoCodecType = .h264
        let settings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: max(4_000_000, w * h * 5)],
        ]
        video = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        video.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
        ])
        guard writer.canAdd(video) else { return nil }
        writer.add(video)
        if withAudio {
            let a = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44_100,
                AVEncoderBitRateKey: 96_000,
            ])
            a.expectsMediaDataInRealTime = true
            if writer.canAdd(a) { writer.add(a); audio = a } else { audio = nil }
        } else { audio = nil }
        guard writer.startWriting() else { return nil }
    }

    /// Render `img` (already `size`, origin at zero) into the file at `time`.
    func append(_ img: CIImage, at time: CMTime) {
        lock.lock(); defer { lock.unlock() }
        guard writer.status == .writing, !finished else { return }
        if !started { writer.startSession(atSourceTime: time); started = true; firstTime = time }
        guard time > lastTime || lastTime == .zero, video.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        guard let pb else { return }
        let e = img.extent
        let sx = size.width / max(e.width, 1), sy = size.height / max(e.height, 1)
        let placed = img.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
        var fitted: CIImage
        if abs(sx / sy - 1) < 0.01 {
            // the take's own shape (a pixel or two off from rounding): fill it exactly
            fitted = placed.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        } else {
            // A tape of another shape joined the take (POCKET 3D's 2:1 into a 4:3 one, or the
            // other way): fitted whole, black around it, never stretched.
            let s = min(sx, sy)
            fitted = placed.transformed(by: CGAffineTransform(scaleX: s, y: s))
                .transformed(by: CGAffineTransform(translationX: (size.width - e.width * s) / 2, y: (size.height - e.height * s) / 2))
            fitted = fitted.composited(over: CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size)))
        }
        VideoRecorder.context.render(fitted, to: pb, bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        if adaptor.append(pb, withPresentationTime: time) { lastTime = time }
    }

    func append(audio sample: CMSampleBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard started, !finished, writer.status == .writing, let audio, audio.isReadyForMoreMediaData else { return }
        if CMSampleBufferGetPresentationTimeStamp(sample) < firstTime { return }
        audio.append(sample)
    }

    var duration: Double {
        lock.lock(); defer { lock.unlock() }
        guard started else { return 0 }
        return max(0, (lastTime - firstTime).seconds)
    }

    func finish(_ done: @escaping (URL?) -> Void) {
        lock.lock()
        guard started, writer.status == .writing, !finished else { lock.unlock(); writer.cancelWriting(); done(nil); return }
        finished = true
        video.markAsFinished()
        audio?.markAsFinished()
        writer.endSession(atSourceTime: lastTime)
        lock.unlock()
        writer.finishWriting { [url, writer] in done(writer.status == .completed ? url : nil) }
    }
}
