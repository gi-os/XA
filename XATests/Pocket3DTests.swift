import XCTest
import CoreImage
import CoreMedia
import AVFoundation
@testable import XA

/// POCKET 3D against the 3DS camera's own files: 480 × 240, 20 frames a second, IMA ADPCM sound.
final class Pocket3DTests: XCTestCase {
    private func frame(_ w: CGFloat, _ h: CGFloat, _ c: CGFloat = 0.5) -> CIImage {
        CIImage(color: CIColor(red: c, green: c * 0.9, blue: c * 0.7)).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    }

    func testItFilmsAt480By240WhicheverWayThePhoneIsHeld() {
        for src in [frame(1080, 1440), frame(1440, 1080)] {
            let fx = VideoFX()
            let out = fx.apply(.pocket3D, to: src, time: 0, date: Date())
            XCTAssertEqual(out.extent, CGRect(x: 0, y: 0, width: 480, height: 240))
            XCTAssertNotNil(Looks.context.createCGImage(out, from: out.extent))
        }
    }

    func testTwentyEvenFramesASecond() {
        let fx = VideoFX()
        var stamps: [Double] = []
        for k in 0..<30 {
            _ = fx.apply(.pocket3D, to: frame(144, 108), time: Double(k) / 30, date: Date())
            if fx.lastWasNew { stamps.append(fx.lastStamp) }
        }
        XCTAssertEqual(stamps.count, 20, "two of every three of the camera's 30")
        for (a, b) in zip(stamps, stamps.dropFirst()) { XCTAssertEqual(b - a, 0.05, accuracy: 1e-6) }
    }

    func testTenInTheDark() {
        let fx = VideoFX()
        fx.pocket3D.dark = 0.9
        var fresh = 0
        for k in 0..<30 {
            _ = fx.apply(.pocket3D, to: frame(144, 108, 0.1), time: Double(k) / 30, date: Date())
            if fx.lastWasNew { fresh += 1 }
        }
        XCTAssertEqual(fresh, 10)
    }

    func testDarknessComesFromTheScenesBrightness() {
        XCTAssertEqual(Pocket3DLook.darkness(brightness: 8), 0)       // daylight
        XCTAssertEqual(Pocket3DLook.darkness(brightness: -2), 1)      // a dark room
        XCTAssertGreaterThan(Pocket3DLook.darkness(brightness: 2), 0.2) // a lit room is dim for it
    }

    /// Each frame is a picture of its own (its last frame is kept): a minute must not slow down.
    func testFramesStayPictures() {
        let fx = VideoFX()
        fx.pocket3D.dark = 0.5   // the smear keeps the last frame
        var times: [TimeInterval] = []
        for k in 0..<60 {
            let t0 = Date()
            let out = fx.apply(.pocket3D, to: frame(360, 270, CGFloat(k % 10) / 10), time: Double(k) / 30, date: Date())
            XCTAssertNotNil(Looks.context.createCGImage(out, from: out.extent))
            times.append(Date().timeIntervalSince(t0))
        }
        let early = times[10..<30].reduce(0, +), late = times[40..<60].reduce(0, +)
        XCTAssertLessThan(late, early * 2.5 + 0.5)
    }

    /// In a dim room a flat gray card comes out grainy and blotchy, JPEG and all.
    func testItIsNoisyInTheDark() {
        let fx = VideoFX()
        fx.pocket3D.dark = 0.9
        let out = fx.apply(.pocket3D, to: frame(1440, 1080), time: 0, date: Date())
        var px = [Float](repeating: 0, count: 64 * 64 * 4)
        Looks.context.render(out, toBitmap: &px, rowBytes: 64 * 16, bounds: CGRect(x: 200, y: 90, width: 64, height: 64), format: .RGBAf, colorSpace: nil)
        let ys = stride(from: 0, to: px.count, by: 4).map { px[$0 + 1] }
        let mean = ys.reduce(0, +) / Float(ys.count)
        let sd = sqrt(ys.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(ys.count))
        XCTAssertGreaterThan(sd, 0.003)
    }

    // MARK: sound

    func testADPCMDecoderHearsWhatTheEncoderMeant() {
        var enc = IMAADPCM(), dec = IMAADPCM()
        var err: Double = 0, sig: Double = 0
        for i in 0..<16_000 {
            let x = Int16(12_000 * sin(2 * Double.pi * 1000 * Double(i) / 16_000))
            let y = dec.decode(enc.encode(x))
            XCTAssertEqual(Int32(y), enc.predictor)
            if i > 200 { err += pow(Double(y) - Double(x), 2); sig += pow(Double(x), 2) }
        }
        let snr = 10 * log10(sig / max(err, 1))
        XCTAssertGreaterThan(snr, 12, "a tone still comes through")
        XCTAssertLessThan(snr, 60, "but four bits a sample are not clean")
    }

    private func rms(_ hz: Double, rate: Double = 48_000) -> Float {
        let a = Pocket3DAudio()
        var x = (0..<Int(rate)).map { Float(0.3 * sin(2 * Double.pi * hz * Double($0) / rate)) }
        a.process(&x, rate: rate)
        let tail = x[Int(rate / 2)...]
        return sqrt(tail.map { $0 * $0 }.reduce(0, +) / Float(tail.count))
    }

    func testItHearsVoicesButNothingAbove8kHz() {
        let voice = rms(1000), hiss = rms(12_000), rumble = rms(60)
        XCTAssertGreaterThan(voice, 0.1)
        XCTAssertLessThan(hiss, voice * 0.25, "16 kHz sampling: nothing above 8 kHz")
        XCTAssertLessThan(rumble, voice * 0.4, "a tiny microphone: no low end")
    }

    func testABufferKeepsItsFormatTimingAndLength() throws {
        let rate = 48_000.0, n = 1024
        var asbd = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1,
                                               mBitsPerChannel: 16, mReserved: 0)
        var fmt: CMAudioFormatDescription?
        XCTAssertEqual(CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                                      magicCookie: nil, extensions: nil, formatDescriptionOut: &fmt), noErr)
        var samples = (0..<n).map { Int16(10_000 * sin(2 * Double.pi * 440 * Double($0) / rate)) }
        var block: CMBlockBuffer?
        XCTAssertEqual(CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: n * 2, blockAllocator: nil,
                                                          customBlockSource: nil, offsetToData: 0, dataLength: n * 2,
                                                          flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block), kCMBlockBufferNoErr)
        samples.withUnsafeMutableBytes { _ = CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block!, offsetIntoDestination: 0, dataLength: n * 2) }
        var sb: CMSampleBuffer?
        let pts = CMTime(value: 4800, timescale: 48_000)
        XCTAssertEqual(CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block!, formatDescription: fmt!,
                                                                           sampleCount: n, presentationTimeStamp: pts,
                                                                           packetDescriptions: nil, sampleBufferOut: &sb), noErr)
        let out = try XCTUnwrap(Pocket3DAudio().process(try XCTUnwrap(sb)))
        XCTAssertEqual(CMSampleBufferGetNumSamples(out), n)
        XCTAssertEqual(CMSampleBufferGetPresentationTimeStamp(out), pts)
        XCTAssertTrue(CMFormatDescriptionEqual(CMSampleBufferGetFormatDescription(out), otherFormatDescription: fmt))
    }

    /// A take that starts on another tape and moves to POCKET 3D (or the other way) is fitted
    /// into the file, never stretched.
    func testTheRecorderFitsAnotherShape() {
        guard let r = VideoRecorder(size: CGSize(width: 480, height: 240), audio: false) else { return XCTFail("no writer") }
        let wide = CIImage(color: .green).cropped(to: CGRect(x: 0, y: 0, width: 480, height: 240))
        let tall = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 1080, height: 1440))
        for i in 0..<20 { r.append(i % 2 == 0 ? wide : tall, at: CMTime(value: CMTimeValue(i), timescale: 20)) }
        let done = expectation(description: "finished")
        var url: URL?
        r.finish { url = $0; done.fulfill() }
        wait(for: [done], timeout: 20)
        XCTAssertNotNil(url)
    }
}
