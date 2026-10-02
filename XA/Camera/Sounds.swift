import AVFoundation

/// XA's own two-stage camera sounds, synthesized once at launch: the AF motor hunting when
/// focus is aimed, and a fast metal focal-plane shutter when the picture is taken. They play
/// through the ambient category, so the silent switch mutes them and music keeps playing.
final class CameraSounds {
    static let shared = CameraSounds()
    enum Cue { case focus, shutter, beep }

    private var players: [Cue: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "xa.sounds")

    func prepare() {
        queue.async {
            let session = AVAudioSession.sharedInstance()
            if session.category != .playAndRecord { try? session.setCategory(.ambient, options: [.mixWithOthers]) }
            for (cue, samples) in [(Cue.focus, Synth.hunt()), (Cue.shutter, Synth.fastMetal()), (Cue.beep, Synth.beep())] {
                if let p = try? AVAudioPlayer(data: Synth.wav(samples)) { p.prepareToPlay(); self.players[cue] = p }
            }
        }
    }

    func play(_ cue: Cue) {
        queue.async {
            guard let p = self.players[cue] else { return }
            p.currentTime = 0
            p.play()
        }
    }
}

/// A tiny offline synth: the same recipes as the design canvas's Web Audio versions.
enum Synth {
    static let rate: Double = 44_100

    enum Wave { case sine, triangle, square, saw }
    enum Filter { case low, high, band }

    /// AF motor, hunting: a buzz that runs past the mark, comes back, and clicks into place.
    static func hunt() -> [Float] {
        var b = silence(0.26)
        buzz(&b, at: 0, from: 95, to: 110, dur: 0.08, gain: 0.05, cutoff: 900)
        buzz(&b, at: 0.11, from: 120, to: 100, dur: 0.07, gain: 0.05, cutoff: 900)
        noise(&b, at: 0.19, dur: 0.008, filter: .band, freq: 4800, q: 4, gain: 1.0)
        return normalized(b, peak: 0.5)
    }

    /// Fast metal focal plane, about 1/4000: two curtains almost on top of each other.
    static func fastMetal() -> [Float] {
        var b = silence(0.09)
        noise(&b, at: 0, dur: 0.01, filter: .high, freq: 5000, q: 1, gain: 1.3)
        noise(&b, at: 0.016, dur: 0.012, filter: .high, freq: 4200, q: 1, gain: 1.2)
        tone(&b, at: 0.016, from: 2000, to: 1400, dur: 0.03, wave: .triangle, gain: 0.05)
        return normalized(b, peak: 0.7)
    }

    /// BOOTH's countdown: a short bright beep.
    static func beep() -> [Float] {
        var b = silence(0.09)
        tone(&b, at: 0, from: 1568, to: 1568, dur: 0.07, wave: .square, gain: 0.06)
        return normalized(b, peak: 0.3)
    }

    static func silence(_ seconds: Double) -> [Float] { [Float](repeating: 0, count: Int(seconds * rate)) }

    static func normalized(_ b: [Float], peak: Float) -> [Float] {
        let m = b.map { abs($0) }.max() ?? 0
        guard m > 0 else { return b }
        let k = peak / m
        return b.map { $0 * k }
    }

    private static func sample(_ wave: Wave, _ phase: Double) -> Double {
        let p = phase - floor(phase)
        switch wave {
        case .sine: return sin(2 * .pi * p)
        case .triangle: return 1 - 4 * abs(p - 0.5)
        case .square: return p < 0.5 ? 1 : -1
        case .saw: return 2 * p - 1
        }
    }

    /// An exponential pitch glide under a fast attack and an exponential decay.
    static func tone(_ b: inout [Float], at t: Double, from f: Double, to f2: Double? = nil, dur: Double, wave: Wave, gain: Double) {
        let start = Int(t * rate), n = Int(dur * rate)
        let attack = 0.004 * rate
        let k: Double = log(max(gain, 1e-4) / 1e-4) / max(1, Double(n) - attack)
        var phase = 0.0
        for i in 0..<n where start + i < b.count {
            let x = Double(i) / Double(n)
            let freq = f2.map { f * pow($0 / f, x) } ?? f
            phase += freq / rate
            let env = Double(i) < attack ? gain * Double(i) / attack : gain * exp(-k * (Double(i) - attack))
            b[start + i] += Float(sample(wave, phase) * env)
        }
    }

    /// A sawtooth motor through a low-pass, with a short ramp in and out.
    static func buzz(_ b: inout [Float], at t: Double, from f: Double, to f2: Double, dur: Double, gain: Double, cutoff: Double) {
        let start = Int(t * rate), n = Int(dur * rate)
        var tone = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let x = Double(i) / Double(n)
            phase += (f + (f2 - f) * x) / rate
            let tIn = Double(i) / rate, tOut = Double(n - i) / rate
            let env = gain * min(1, tIn / 0.02) * min(1, tOut / 0.04)
            tone[i] = Float(sample(.saw, phase) * env)
        }
        var bq = Biquad(.low, freq: cutoff, q: 0.707)
        for i in 0..<n where start + i < b.count { b[start + i] += bq.process(tone[i]) }
    }

    /// White noise with a cubic decay, filtered.
    static func noise(_ b: inout [Float], at t: Double, dur: Double, filter: Filter, freq: Double, q: Double, gain: Double) {
        let start = Int(t * rate), n = max(1, Int(dur * rate))
        var bq = Biquad(filter, freq: freq, q: q)
        var rng = SystemRandomNumberGenerator()
        for i in 0..<n where start + i < b.count {
            let white = Double.random(in: -1...1, using: &rng)
            let env = pow(1 - Double(i) / Double(n), 3)
            b[start + i] += bq.process(Float(white * env * gain))
        }
    }

    /// The RBJ cookbook biquad.
    struct Biquad {
        var b0: Float = 1, b1: Float = 0, b2: Float = 0, a1: Float = 0, a2: Float = 0
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0
        init(_ kind: Filter, freq: Double, q: Double) {
            let w = 2 * Double.pi * min(freq, rate * 0.45) / rate
            let alpha = sin(w) / (2 * max(q, 0.01)), c = cos(w)
            var nb0 = 0.0, nb1 = 0.0, nb2 = 0.0
            switch kind {
            case .low: nb0 = (1 - c) / 2; nb1 = 1 - c; nb2 = (1 - c) / 2
            case .high: nb0 = (1 + c) / 2; nb1 = -(1 + c); nb2 = (1 + c) / 2
            case .band: nb0 = alpha; nb1 = 0; nb2 = -alpha
            }
            let a0 = 1 + alpha
            b0 = Float(nb0 / a0); b1 = Float(nb1 / a0); b2 = Float(nb2 / a0)
            a1 = Float(-2 * c / a0); a2 = Float((1 - alpha) / a0)
        }
        mutating func process(_ x: Float) -> Float {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            return y
        }
    }

    /// 16-bit mono PCM in a WAV container.
    static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        let bytes = UInt32(samples.count * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + bytes); d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(bytes)
        for s in samples {
            let v = Int16(max(-1, min(1, s)) * 32767)
            u16(UInt16(bitPattern: v))
        }
        return d
    }
}
