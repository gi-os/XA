import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMedia
import AudioToolbox
import ImageIO
import UniformTypeIdentifiers

// POCKET 3D: video the way the 3DS camera films it. Its files (Nintendo's spec sheet, and the
// MediaInfo of real HNI_xxxx.AVI files) are 480 × 240 Motion JPEG at 20 frames a second, 4:2:0
// color, with sound in IMA ADPCM: 4 bits a sample, 16 kHz, mono. The cameras are 0.3-megapixel
// (640 × 480); the video is a 2:1 band of that frame. 3D is left out: one eye, flat.

/// The picture.
final class Pocket3DLook {
    static let size = CGSize(width: 480, height: 240)
    /// 0 in good light … 1 in a dark room, eased the way its exposure catches up.
    var dark: Double = 0
    private var previous: CIImage?
    private var frame = 0
    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    private static var full: CGRect { CGRect(origin: .zero, size: size) }

    func reset() { previous = nil }

    /// The scene's brightness (APEX Bv, from the camera's frame metadata) as how dark it is
    /// for a sensor this small: a lit room is already dim for it, a dark one is too much.
    static func darkness(brightness bv: Double) -> Double { max(0, min(1, (4 - bv) / 5)) }

    /// Frames a second: 20, half that when it runs out of light (each frame exposes longer).
    var fps: Double { dark > 0.6 ? 10 : 20 }

    /// One frame of the camera (any size, upright) into one frame of the 3DS's file.
    func render(_ src: CIImage, ctx: CIContext) -> CIImage {
        frame &+= 1
        let full = Self.full
        let e = src.extent
        guard e.width >= 2, e.height >= 2 else { return src }
        // the 2:1 band across the middle, as the 3DS cuts its video out of its 4:3 frame
        let bh = min(e.height, e.width / 2), bw = bh * 2
        let band = CGRect(x: e.midX - bw / 2, y: e.midY - bh / 2, width: bw, height: bh)
        let down = CIFilter.lanczosScaleTransform()
        down.inputImage = src.clampedToExtent().cropped(to: band.insetBy(dx: -8, dy: -8))
            .transformed(by: CGAffineTransform(translationX: -band.minX, y: -band.minY))
        down.scale = Float(Self.size.width / bw)
        down.aspectRatio = 1
        var img = (down.outputImage ?? src).clampedToExtent().cropped(to: full)
        // a tiny plastic lens on a tiny sensor: soft before anything is sharpened
        img = img.clampedToExtent().applyingGaussianBlur(sigma: 0.6).cropped(to: full)
        // too little light for it: the picture sinks (it has run out of exposure)
        if dark > 0.01 { img = img.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -1.3 * dark]) }
        // the camera's own processing, on its display-encoded values
        img = img.applyingFilter("CILinearToSRGBToneCurve")
        img = Self.tone?.apply(extent: full, arguments: [img]) ?? img
        // sensor noise: a fine grain in brightness and coarse blotches of color, worst in shadow
        if let rnd = CIFilter.randomGenerator().outputImage {
            // whole-pixel offsets (a fraction would blur the noise away), new every frame
            let ox = CGFloat((frame &* 7919) % 997), oy = CGFloat((frame &* 6271) % 991)
            let fine = rnd.transformed(by: CGAffineTransform(translationX: -ox, y: -oy)).cropped(to: full)
            let coarse = rnd.transformed(by: CGAffineTransform(translationX: -oy, y: -ox)).samplingLinear()
                .transformed(by: CGAffineTransform(scaleX: 2.5, y: 2.5)).cropped(to: full)
            // (in good light it is faint, and the JPEG mostly takes it; in the dark it is all over)
            img = Self.noise?.apply(extent: full, arguments: [img, fine, coarse, Float(0.035 + 0.15 * dark)]) ?? img
        }
        // its sharpening: crunchy edges with a halo, the noise sharpened along with them
        img = img.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 1.3, kCIInputIntensityKey: 0.9]).cropped(to: full)
        img = img.applyingFilter("CIVignette", parameters: [kCIInputRadiusKey: 1.6, kCIInputIntensityKey: 0.35]).cropped(to: full)
        // 4:2:0: color at half the resolution of brightness, bleeding past edges
        let soft = img.clampedToExtent().applyingGaussianBlur(sigma: 1.1).cropped(to: full)
        img = Self.chroma?.apply(extent: full, arguments: [img, soft]) ?? img
        img = img.applyingFilter("CISRGBToneCurveToLinear").cropped(to: full)
        // a long exposure in the dark: what moved is still on the frame a moment later
        if dark > 0.05, let prev = previous, prev.extent == full {
            img = img.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: prev, kCIInputTimeKey: 0.35 * dark]).cropped(to: full)
        }
        // Motion JPEG: every frame its own JPEG, blocks and all. What comes back is a picture
        // (not a recipe that grows from the last frame), so it can be kept for the next one.
        let out = Self.jpeg(img, ctx: ctx, quality: Self.quality) ?? img
        previous = out
        return out
    }

    /// The JPEG quality: about a bit per pixel on an ordinary scene, like the 3DS's own files
    /// (12 to 16 KB a frame).
    static let quality = 0.65

    /// Through a real JPEG encoder and back, at the 3DS's size.
    static func jpeg(_ img: CIImage, ctx: CIContext, quality: Double) -> CIImage? {
        guard let cg = ctx.createCGImage(img, from: full, format: .RGBA8, colorSpace: sRGB) else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let back = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        return CIImage(cgImage: back)
    }

    /// A small sensor's range and color, on display-encoded values: a yellow-green cast its white
    /// balance never quite takes out, washed-out color, highlights that clip early, blacks that
    /// never reach black.
    private static let tone = CIColorKernel(source: """
    kernel vec4 xa3dsTone(__sample c) {
        vec3 x = c.rgb * vec3(1.03, 1.04, 0.90);
        float y = dot(x, vec3(0.299, 0.587, 0.114));
        x = mix(vec3(y), x, 0.8);
        x = clamp(x / 0.86, 0.0, 1.0);
        x = mix(x, x * x * (3.0 - 2.0 * x), 0.25);
        x = 0.045 + x * 0.955;
        return vec4(x, 1.0);
    }
    """)

    /// Fine brightness noise and coarse color blotches, both stronger in the shadows.
    private static let noise = CIColorKernel(source: """
    kernel vec4 xa3dsNoise(__sample c, __sample fine, __sample coarse, float amount) {
        float y = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        float w = amount * (0.4 + 0.6 * (1.0 - smoothstep(0.05, 0.75, y)));
        vec3 col = coarse.rgb - vec3(0.5);
        col -= vec3(dot(col, vec3(0.3333)));
        vec3 x = c.rgb + vec3(fine.r - 0.5) * w + col * w * 1.6;
        return vec4(clamp(x, 0.0, 1.0), 1.0);
    }
    """)

    /// Brightness from the sharp frame, color from the soft one.
    private static let chroma = CIColorKernel(source: """
    kernel vec4 xa3ds420(__sample sharp, __sample soft) {
        vec3 k = vec3(0.299, 0.587, 0.114);
        float y = dot(sharp.rgb, k);
        vec3 c = soft.rgb - vec3(dot(soft.rgb, k));
        return vec4(clamp(vec3(y) + c, 0.0, 1.0), 1.0);
    }
    """)
}

// MARK: the sound

/// IMA ADPCM, the code the 3DS writes its sound in: each sample is a 4-bit step up or down from
/// the last, the step growing on loud sound and shrinking on quiet. Transients smear, quiet
/// passages hiss.
struct IMAADPCM {
    static let steps: [Int32] = [
        7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
        107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724,
        796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026,
        4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500,
        20350, 22385, 24623, 27086, 29794, 32767,
    ]
    static let indexShift: [Int32] = [-1, -1, -1, -1, 2, 4, 6, 8]

    /// What the decoder hears after the last sample.
    private(set) var predictor: Int32 = 0
    private(set) var index: Int32 = 0

    /// One 16-bit sample in, its 4-bit code out.
    mutating func encode(_ sample: Int16) -> UInt8 {
        var step = Self.steps[Int(index)]
        var diff = Int32(sample) - predictor
        var code: UInt8 = 0
        if diff < 0 { code = 8; diff = -diff }
        var vp = step >> 3
        if diff >= step { code |= 4; diff -= step; vp += step }
        step >>= 1
        if diff >= step { code |= 2; diff -= step; vp += step }
        step >>= 1
        if diff >= step { code |= 1; vp += step }
        advance(code, vp)
        return code
    }

    /// One 4-bit code in, the sample a player hears out.
    mutating func decode(_ code: UInt8) -> Int16 {
        let step = Self.steps[Int(index)]
        var vp = step >> 3
        if code & 4 != 0 { vp += step }
        if code & 2 != 0 { vp += step >> 1 }
        if code & 1 != 0 { vp += step >> 2 }
        advance(code, vp)
        return Int16(predictor)
    }

    private mutating func advance(_ code: UInt8, _ vp: Int32) {
        predictor += code & 8 != 0 ? -vp : vp
        predictor = min(32767, max(-32768, predictor))
        index = min(88, max(0, index + Self.indexShift[Int(code & 7)]))
    }
}

/// A second-order filter (the Audio EQ Cookbook's), run sample by sample.
struct Biquad {
    private var b0: Float = 1, b1: Float = 0, b2: Float = 0, a1: Float = 0, a2: Float = 0
    private var z1: Float = 0, z2: Float = 0

    private init(_ b: (Double, Double, Double), _ a: (Double, Double, Double)) {
        b0 = Float(b.0 / a.0); b1 = Float(b.1 / a.0); b2 = Float(b.2 / a.0)
        a1 = Float(a.1 / a.0); a2 = Float(a.2 / a.0)
    }
    init() {}

    static func lowPass(_ f: Double, q: Double, rate: Double) -> Biquad {
        let w = 2 * Double.pi * min(f, rate * 0.45) / rate, c = cos(w), al = sin(w) / (2 * q)
        return Biquad(((1 - c) / 2, 1 - c, (1 - c) / 2), (1 + al, -2 * c, 1 - al))
    }
    static func highPass(_ f: Double, q: Double, rate: Double) -> Biquad {
        let w = 2 * Double.pi * f / rate, c = cos(w), al = sin(w) / (2 * q)
        return Biquad(((1 + c) / 2, -(1 + c), (1 + c) / 2), (1 + al, -2 * c, 1 - al))
    }
    static func peak(_ f: Double, q: Double, gainDB: Double, rate: Double) -> Biquad {
        let A = pow(10, gainDB / 40), w = 2 * Double.pi * f / rate, c = cos(w), al = sin(w) / (2 * q)
        return Biquad((1 + al * A, -2 * c, 1 - al * A), (1 + al / A, -2 * c, 1 - al / A))
    }

    mutating func run(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}

/// The sound: its little microphone (no low end, a tinny bump, its own hiss), the console's
/// automatic gain pulling quiet rooms up and pushing loud ones down, an input stage that runs
/// out of room, then 16 kHz at 4 bits a sample. Runs on the audio queue, buffer after buffer.
final class Pocket3DAudio {
    static let rate: Double = 16_000
    private var fs: Double = 0
    private var hp1 = Biquad(), hp2 = Biquad(), bump = Biquad()
    private var aa1 = Biquad(), aa2 = Biquad(), re1 = Biquad(), re2 = Biquad()
    private var codec = IMAADPCM()
    private var clock: Double = 1
    private var held: Float = 0
    private var env: Float = 0
    private var gain: Float = 1
    private var attack: Float = 0, release: Float = 0, glide: Float = 0
    private var seed: UInt32 = 0x9E37_79B9

    func reset() { fs = 0 }

    private func setUp(_ rate: Double) {
        fs = rate
        hp1 = .highPass(220, q: 0.5412, rate: rate); hp2 = .highPass(220, q: 1.3066, rate: rate)
        bump = .peak(2800, q: 0.9, gainDB: 4, rate: rate)
        // a fourth-order filter at 7 kHz before the 16 kHz sampling, another after (a player's)
        aa1 = .lowPass(7000, q: 0.5412, rate: rate); aa2 = .lowPass(7000, q: 1.3066, rate: rate)
        re1 = .lowPass(7600, q: 0.5412, rate: rate); re2 = .lowPass(7600, q: 1.3066, rate: rate)
        codec = IMAADPCM(); clock = 1; held = 0; env = 0; gain = 1
        attack = Float(1 - exp(-1 / (0.008 * rate)))
        release = Float(1 - exp(-1 / (0.45 * rate)))
        glide = Float(1 - exp(-1 / (0.18 * rate)))
    }

    /// A mono buffer at `rate` samples a second, in place.
    func process(_ x: inout [Float], rate: Double) {
        guard rate > 1000 else { return }
        if rate != fs { setUp(rate) }
        let tick = Self.rate / rate
        for i in x.indices {
            var s = bump.run(hp2.run(hp1.run(x[i].isFinite ? x[i] : 0)))
            s += noise() * 0.0012
            let a = abs(s)
            env += (a > env ? attack : release) * (a - env)
            let want = min(3, max(0.6, 0.2 / max(env, 0.0005)))
            gain += glide * (want - gain)
            s = min(1, max(-1, s * gain * 1.2))
            s = aa2.run(aa1.run(s))
            clock += tick
            if clock >= 1 {
                clock -= 1
                _ = codec.encode(Int16(clamping: Int((s * 32767).rounded())))
                held = Float(codec.predictor) / 32768
            }
            x[i] = re2.run(re1.run(held)) * 0.9
        }
    }

    private func noise() -> Float {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    /// The same buffer (format, timing, length) with the 3DS's sound, or nil when the format is
    /// one this doesn't read (the caller keeps the original then).
    func process(_ sb: CMSampleBuffer) -> CMSampleBuffer? {
        guard let fmt = CMSampleBufferGetFormatDescription(sb),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee,
              asbd.mFormatID == kAudioFormatLinearPCM else { return nil }
        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let planar = asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        let bits = Int(asbd.mBitsPerChannel)
        guard (isFloat && bits == 32) || (!isFloat && bits == 16) else { return nil }
        let ch = max(1, Int(asbd.mChannelsPerFrame))
        let n = CMSampleBufferGetNumSamples(sb)
        let size = bits / 8
        let total = n * ch * size
        guard n > 0, let block = CMSampleBufferGetDataBuffer(sb), CMBlockBufferGetDataLength(block) >= total else { return nil }
        var raw = [UInt8](repeating: 0, count: total)
        guard CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: total, destination: &raw) == kCMBlockBufferNoErr else { return nil }
        var mono = [Float](repeating: 0, count: n)
        raw.withUnsafeBytes { p in
            for i in 0..<n {
                var sum: Float = 0
                for c in 0..<ch {
                    let k = planar ? c * n + i : i * ch + c
                    sum += isFloat ? p.loadUnaligned(fromByteOffset: k * 4, as: Float.self)
                                   : Float(p.loadUnaligned(fromByteOffset: k * 2, as: Int16.self)) / 32768
                }
                mono[i] = sum / Float(ch)
            }
        }
        process(&mono, rate: asbd.mSampleRate)
        raw.withUnsafeMutableBytes { p in
            for i in 0..<n {
                let v = mono[i]
                for c in 0..<ch {
                    let k = planar ? c * n + i : i * ch + c
                    if isFloat { p.storeBytes(of: v, toByteOffset: k * 4, as: Float.self) }
                    else { p.storeBytes(of: Int16(clamping: Int((v * 32767).rounded())), toByteOffset: k * 2, as: Int16.self) }
                }
            }
        }
        var out: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: total,
                                                 blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
                                                 dataLength: total, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &out) == kCMBlockBufferNoErr,
              let out,
              raw.withUnsafeBytes({ CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: out, offsetIntoDestination: 0, dataLength: total) }) == kCMBlockBufferNoErr
        else { return nil }
        var made: CMSampleBuffer?
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: out, formatDescription: fmt,
                                                                   sampleCount: n, presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sb),
                                                                   packetDescriptions: nil, sampleBufferOut: &made) == noErr else { return nil }
        return made
    }
}
