import CoreImage
import Foundation
import ImageIO

/// One sim, one look, one shape. Any of them can be empty.
struct Stack: Codable, Equatable, Hashable {
    var simID: String?
    var look: Look = .none
    var shape: FrameShape = .none

    /// An instant sim prints its own frame, so it takes over from the shape.
    var effectiveShape: FrameShape? {
        if let id = simID, let s = FilmCatalog.sim(id), s.frame != .none { return nil }
        return shape == .none ? nil : shape
    }
}

/// Every film XA knows: the presets plus the ones people made.
enum FilmCatalog {
    static var looks: [Look] { Look.allCases }
    static var shapes: [FrameShape] { FrameShape.allCases.filter { $0 != .none } }

    private static let lock = NSLock()
    private static var _custom: [Sim] = SimStore.load()

    static var custom: [Sim] {
        lock.lock(); defer { lock.unlock() }
        return _custom
    }

    static var sims: [Sim] { Sim.presets + custom }

    /// No sim is Neutral: there is always a film loaded.
    static func sim(_ id: String?) -> Sim? {
        guard let id else { return Sim.neutral }
        return sims.first { $0.id == id } ?? Sim.neutral
    }

    static func setCustom(_ list: [Sim]) {
        lock.lock(); _custom = list; lock.unlock()
        SimStore.save(list)
    }
}

/// Custom sims live in UserDefaults as JSON.
enum SimStore {
    static let key = "customSims"
    static func load() -> [Sim] {
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Sim].self, from: d)) ?? []
    }
    static func save(_ list: [Sim]) {
        if let d = try? JSONEncoder().encode(list) { UserDefaults.standard.set(d, forKey: key) }
    }
}

/// What a press needs to know, copied off the main thread's settings at the instant of capture.
struct DevelopSettings {
    var stack = Stack()
    var megapixels = 2
    var noise: Double = 0.5
    var date = DateConfig()
    var recipe = DigiRecipe()
}

/// The darkroom: the same chain for the viewfinder and for the saved photograph.
enum Darkroom {
    /// Returns the developed image and whether it has transparent pixels.
    /// `dateShift` pushes the date back down and out of the frame (0 = in place, 1 = gone),
    /// for the slide when switching from PRO to DIGI.
    /// `demo` stands in for the photo's own EXIF, for the recipe editor's day, flash and night.
    static func develop(_ src: CIImage, _ s: DevelopSettings, date: Date, preview: Bool, dateShift: CGFloat = 0, demo: DigicamFX.Conditions? = nil) -> (CIImage, Bool) {
        // Read before any filter: the photo's EXIF says whether the flash fired and how dark it was.
        let conditions = demo ?? DigicamFX.Conditions(properties: src.properties)
        let src = Sanitize.apply(src)
        var img = preview ? src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
                          : Digicam.shrink(src, megapixels: s.megapixels)
        let sim = FilmCatalog.sim(s.stack.simID)
        if let sim, !sim.isNeutral { img = SimEngine.apply(sim, to: img, preview: preview) } else { img = Digicam.tone(img) }
        if s.stack.look != .none {
            let w: CGFloat? = s.stack.look.pixelWidth != nil && !preview ? img.extent.width : nil
            img = Looks.apply(s.stack.look, to: img, outputWidth: w)
        }
        if !preview {
            img = Digicam.crunch(img, noise: CGFloat(s.noise) * 0.03)
            img = DigicamFX.apply(img, conditions, recipe: s.recipe, pixel: s.stack.look.pixelWidth != nil, seed: Int(date.timeIntervalSince1970))
        }
        let mono = (sim?.mono ?? false) || s.stack.look.mono
        var alpha = false
        var shapeForDate: FrameShape = .none
        var instant: InstantKind = .none
        if let kind = s.stack.effectiveShape?.instant {
            img = Shapes.instant(img, kind: kind)
            instant = kind
        } else if let sim, sim.frame != .none {
            // Sims made before instant film became a shape.
            let kind: InstantKind = sim.frame == .round ? .round : .square
            img = Shapes.instant(img, kind: kind)
            instant = kind
        } else if let shape = s.stack.effectiveShape {
            let bg = preview ? Shapes.checker(extent: img.extent) : nil
            img = Shapes.apply(shape, to: img, background: bg)
            alpha = !preview
            shapeForDate = shape
        }
        if let overlay = DateBack.overlayImage(size: img.extent.size, date: date, config: s.date, shape: shapeForDate, mono: mono, instant: instant) {
            let e = img.extent
            let drop: CGFloat = -dateShift * e.height * 0.35
            let placed = overlay.transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY + drop)).cropped(to: e)
            img = placed.composited(over: img)
        }
        return (img, alpha)
    }
}

/// The line XA writes into a photo's metadata, so the roll can say how it was made.
enum Recipe {
    static func describe(_ s: Stack, megapixels: Int) -> String {
        var parts: [String] = []
        if let sim = FilmCatalog.sim(s.simID) { parts.append(sim.title) }
        if s.look != .none { parts.append(s.look.title) }
        if let shape = s.effectiveShape { parts.append(shape.title) }
        let film = parts.isEmpty ? "NO FILM" : parts.joined(separator: " + ")
        return "XA DIGI \(megapixels)MP · \(film)"
    }

    /// Metadata for a developed DIGI photo: the source's EXIF kept, orientation reset (the
    /// pixels are already upright), and the recipe in the description and user comment.
    static func properties(from src: [String: Any], recipe: String) -> [String: Any] {
        var p = src
        p[kCGImagePropertyOrientation as String] = 1
        var tiff = (p[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        tiff[kCGImagePropertyTIFFOrientation as String] = 1
        tiff[kCGImagePropertyTIFFSoftware as String] = "XA"
        tiff[kCGImagePropertyTIFFImageDescription as String] = recipe
        p[kCGImagePropertyTIFFDictionary as String] = tiff
        var exif = (p[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        exif[kCGImagePropertyExifUserComment as String] = recipe
        p[kCGImagePropertyExifDictionary as String] = exif
        p.removeValue(forKey: kCGImagePropertyPixelWidth as String)
        p.removeValue(forKey: kCGImagePropertyPixelHeight as String)
        return p
    }
}
