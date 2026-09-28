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
        guard writer.status == .writing else { return }
        if !started { writer.startSession(atSourceTime: time); started = true; firstTime = time }
        guard time > lastTime || lastTime == .zero, video.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        guard let pb else { return }
        let e = img.extent
        let fitted = img.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
            .transformed(by: CGAffineTransform(scaleX: size.width / max(e.width, 1), y: size.height / max(e.height, 1)))
        VideoRecorder.context.render(fitted, to: pb, bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        if adaptor.append(pb, withPresentationTime: time) { lastTime = time }
    }

    func append(audio sample: CMSampleBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard started, writer.status == .writing, let audio, audio.isReadyForMoreMediaData else { return }
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
        guard started, writer.status == .writing else { lock.unlock(); writer.cancelWriting(); done(nil); return }
        video.markAsFinished()
        audio?.markAsFinished()
        writer.endSession(atSourceTime: lastTime)
        lock.unlock()
        writer.finishWriting { [url, writer] in done(writer.status == .completed ? url : nil) }
    }
}
