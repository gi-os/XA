import CoreImage
import CoreImage.CIFilterBuiltins

/// Which of the digicam's faults a DIGI photo gets, and how much of each. 0.5 is how XA has
/// always shot; 1 is twice that. Edited live in the recipe editor, saved in settings.
struct DigiRecipe: Codable, Equatable {
    struct Part: Codable, Equatable {
        var on: Bool
        var amount: Double
        var level: Double { on ? min(1, max(0, amount)) : 0 }
    }
    enum Key: String, CaseIterable, Identifiable, Codable {
        case ccd, sharpen, fringe, flash, night, jpeg, lens, smear, grain, leak
        var id: String { rawValue }
        var title: String {
            switch self {
            case .ccd: return "CCD COLOR"
            case .sharpen: return "EDGE CRUNCH"
            case .fringe: return "COLOR FRINGE"
            case .flash: return "FLASH LOOK"
            case .night: return "NIGHT SMEAR"
            case .jpeg: return "JPEG CRUNCH"
            case .lens: return "CHEAP LENS"
            case .smear: return "CCD SMEAR"
            case .grain: return "GRAIN"
            case .leak: return "LIGHT LEAK"
            }
        }
        var detail: String {
            switch self {
            case .ccd: return "A 2005 pocket Sony's color: deep cyan-blue skies, reds a touch hot, punchy contrast and highlights that clip hard. Also in the viewfinder."
            case .sharpen: return "The camera's own sharpening: crunchy edges with a thin halo."
            case .fringe: return "Red and blue edges toward the corners, from a tiny zoom lens."
            case .flash: return "Hot faces, warm whites, green shadows. Only when the flash fires."
            case .night: return "Low light goes waxy with faint color blotches."
            case .jpeg: return "Blocks in flat areas, smeared color."
            case .lens: return "Soft corners and a little bulge."
            case .smear: return "Bright lights bleed a line down the frame."
            case .grain: return "Clumpy, mostly in the mid-tones."
            case .leak: return "A warm leak from one edge."
            }
        }
    }

    var ccd = Part(on: true, amount: 0.6)
    var sharpen = Part(on: true, amount: 0.5)
    var fringe = Part(on: true, amount: 0.4)
    var flash = Part(on: true, amount: 0.5)
    var night = Part(on: true, amount: 0.5)
    var jpeg = Part(on: true, amount: 0.5)
    var lens = Part(on: true, amount: 0.5)
    var smear = Part(on: true, amount: 0.4)
    var grain = Part(on: false, amount: 0.4)
    var leak = Part(on: false, amount: 0.5)

    subscript(_ k: Key) -> Part {
        get {
            switch k {
            case .ccd: return ccd
            case .sharpen: return sharpen
            case .fringe: return fringe
            case .flash: return flash
            case .night: return night
            case .jpeg: return jpeg
            case .lens: return lens
            case .smear: return smear
            case .grain: return grain
            case .leak: return leak
            }
        }
        set {
            switch k {
            case .ccd: ccd = newValue
            case .sharpen: sharpen = newValue
            case .fringe: fringe = newValue
            case .flash: flash = newValue
            case .night: night = newValue
            case .jpeg: jpeg = newValue
            case .lens: lens = newValue
            case .smear: smear = newValue
            case .grain: grain = newValue
            case .leak: leak = newValue
            }
        }
    }

    init() {}

    // Recipes saved before a part existed still load, with that part at its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DigiRecipe()
        ccd = try c.decodeIfPresent(Part.self, forKey: .ccd) ?? d.ccd
        sharpen = try c.decodeIfPresent(Part.self, forKey: .sharpen) ?? d.sharpen
        fringe = try c.decodeIfPresent(Part.self, forKey: .fringe) ?? d.fringe
        flash = try c.decodeIfPresent(Part.self, forKey: .flash) ?? d.flash
        night = try c.decodeIfPresent(Part.self, forKey: .night) ?? d.night
        jpeg = try c.decodeIfPresent(Part.self, forKey: .jpeg) ?? d.jpeg
        lens = try c.decodeIfPresent(Part.self, forKey: .lens) ?? d.lens
        smear = try c.decodeIfPresent(Part.self, forKey: .smear) ?? d.smear
        grain = try c.decodeIfPresent(Part.self, forKey: .grain) ?? d.grain
        leak = try c.decodeIfPresent(Part.self, forKey: .leak) ?? d.leak
    }
    private enum CodingKeys: String, CodingKey { case ccd, sharpen, fringe, flash, night, jpeg, lens, smear, grain, leak }

    var onCount: Int { Key.allCases.filter { self[$0].on }.count }

    /// The JPEG pass's quality: 0.42 at the usual strength, down to 0.05 at full.
    var jpegQuality: CGFloat { CGFloat(max(0.05, min(0.95, 0.9 - 0.96 * jpeg.level))) }
}

extension DigicamFX {
    /// Bright points bleed a vertical line the full height of the frame, the way a CCD's columns
    /// overflow. Each column's brightest light, stretched top to bottom.
    static func smear(_ img: CIImage, amount: Double) -> CIImage {
        let e = img.extent
        guard amount > 0, e.width > 1, e.height > 1 else { return img }
        // Only what is close to clipping.
        let m = CIFilter.colorMatrix()
        m.inputImage = img
        let k: CGFloat = 6
        m.rVector = CIVector(x: k, y: 0, z: 0, w: 0); m.gVector = CIVector(x: 0, y: k, z: 0, w: 0); m.bVector = CIVector(x: 0, y: 0, z: k, w: 0)
        m.biasVector = CIVector(x: -k * 0.86, y: -k * 0.86, z: -k * 0.86, w: 0)
        guard let hot = m.outputImage?.cropped(to: e) else { return img }
        let clamp = CIFilter.colorClamp(); clamp.inputImage = hot
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 1); clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        guard let lights = clamp.outputImage else { return img }
        // Squash each column to a few pixels and stretch it back: the column's average light.
        let origin = lights.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
        let rows: CGFloat = 3
        let squash = CIFilter.lanczosScaleTransform()
        squash.inputImage = origin; squash.scale = Float(rows / e.height); squash.aspectRatio = Float(e.height / rows)
        guard let thin = squash.outputImage else { return img }
        let tall = thin.clampedToExtent().transformed(by: CGAffineTransform(scaleX: e.width / max(thin.extent.width, 1), y: e.height / rows))
            .cropped(to: CGRect(origin: .zero, size: e.size))
            .transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY))
        let gain = CIFilter.colorMatrix(); gain.inputImage = tall
        let g = CGFloat(amount) * 9
        gain.rVector = CIVector(x: g, y: 0, z: 0, w: 0); gain.gVector = CIVector(x: 0, y: g * 0.96, z: 0, w: 0); gain.bVector = CIVector(x: 0, y: 0, z: g * 0.9, w: 0)
        gain.aVector = CIVector(x: 0, y: 0, z: 0, w: 0); gain.biasVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let line = gain.outputImage?.cropped(to: e) else { return img }
        let add = CIFilter.screenBlendMode(); add.inputImage = line; add.backgroundImage = img
        return (add.outputImage ?? img).cropped(to: e)
    }

    /// A warm leak from one edge. `seed` picks the edge, so a photo keeps its leak.
    static func leak(_ img: CIImage, amount: Double, seed: Int = 0) -> CIImage {
        let e = img.extent
        guard amount > 0 else { return img }
        let side = ((seed % 4) + 4) % 4
        let d = max(e.width, e.height)
        let center: CGPoint
        switch side {
        case 0: center = CGPoint(x: e.minX, y: e.midY + e.height * 0.18)
        case 1: center = CGPoint(x: e.maxX, y: e.midY - e.height * 0.12)
        case 2: center = CGPoint(x: e.midX + e.width * 0.2, y: e.maxY)
        default: center = CGPoint(x: e.midX - e.width * 0.15, y: e.minY)
        }
        let a = CGFloat(min(1, amount))
        let g = CIFilter.radialGradient()
        g.center = center
        g.radius0 = Float(d * 0.02); g.radius1 = Float(d * (0.35 + 0.25 * a))
        g.color0 = CIColor(red: 1, green: 0.42 * 1, blue: 0.12, alpha: 0.85 * a)
        g.color1 = CIColor(red: 1, green: 0.2, blue: 0.05, alpha: 0)
        guard let glow = g.outputImage?.cropped(to: e) else { return img }
        let s = CIFilter.screenBlendMode(); s.inputImage = glow; s.backgroundImage = img
        return (s.outputImage ?? img).cropped(to: e)
    }
}
