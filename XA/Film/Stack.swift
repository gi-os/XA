import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

/// One sim, one look, one shape. Any of them can be empty.
struct Stack: Codable, Equatable, Hashable {
    var simID: String?
    var look: Look = .none
    var shape: FrameShape = .none
    /// Stops pushed (+) or pulled (−) from the stock's box speed. Optional so old stacks load.
    var pushStops: Int? = nil
    var push: Int {
        get { pushStops ?? 0 }
        set { pushStops = newValue == 0 ? nil : min(max(newValue, FilmStock.pushRange.lowerBound), FilmStock.pushRange.upperBound) }
    }
    /// The loaded sim, with the push it shows on its box.
    var shownSim: Sim? {
        guard var s = FilmCatalog.sim(simID) else { return nil }
        if s.stock != nil { s.shownPush = push }
        return s
    }
    /// The film's name as the LCD writes it: a pushed stock gives the speed it is shot at.
    var filmTitle: String {
        guard let s = FilmCatalog.sim(simID) else { return Sim.neutral.title }
        if let st = FilmStock.stock(s.stock), push != 0 { return "\(st.name) \(st.ei(push))\(st.suffix) \(push > 0 ? "+" : "")\(push)".uppercased() }
        return s.title
    }

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

    /// What each mode can load: FILM only the stocks, DIGI everything else.
    static func sims(for mode: CaptureMode) -> [Sim] {
        mode == .film ? Sim.stocks : sims.filter { $0.stock == nil }
    }

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
    /// FILM: full size, the stock only, none of the digicam's processing.
    var film = false
    /// FILM's camera and lab.
    var filmRecipe = FilmRecipe()
    /// BOOTH: the skin setting, and (in the viewfinder) where the eyes were last seen.
    var booth: BoothSkin? = nil
    var eyes: Booth.Eyes? = nil
    /// BOOTH: this shot's backdrop and doodles.
    var deco: BoothDeco? = nil
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
        // BOOTH: full size, the skin filter and nothing else.
        if let skin = s.booth {
            let faces = preview ? s.eyes : (s.eyes ?? Booth.eyes(in: src))
            return (Booth.develop(src, skin, deco: s.deco, faces: faces, preview: preview), false)
        }
        if s.film { return (developFilm(src, s, date: date, preview: preview, dateShift: dateShift, flashFired: conditions.flashFired), false) }
        var img = preview || s.film ? src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
                                    : Digicam.shrink(src, megapixels: s.megapixels)
        let sim = FilmCatalog.sim(s.stack.simID)
        if let sim, !sim.isNeutral {
            img = SimEngine.apply(sim, to: img, preview: preview, push: s.stack.push, seed: preview ? nil : Int(date.timeIntervalSince1970 * 1000) % 100_000)
        } else if !s.film { img = Digicam.tone(img) }
        // FILM stops here: the stock is the whole look, at full size, with the date back if it is on.
        if s.film { return (stamp(img, s, date: date, dateShift: dateShift, mono: sim?.mono ?? false), false) }
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
        img = stamp(img, s, date: date, dateShift: dateShift, mono: mono, shape: shapeForDate, instant: instant)
        return (img, alpha)
    }

    /// FILM: the frame cut to the format, scanned at the lab's size, the camera, the stock and the
    /// lab's printing; then the date back.
    private static func developFilm(_ src: CIImage, _ s: DevelopSettings, date: Date, preview: Bool, dateShift: CGFloat, flashFired: Bool) -> CIImage {
        var img = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
        let r = s.filmRecipe
        let frame = r.format.frame(in: img.extent)
        if !preview {
            img = img.cropped(to: frame).transformed(by: CGAffineTransform(translationX: -frame.minX, y: -frame.minY))
            if let edge = r.scan.longEdge, max(img.extent.width, img.extent.height) > edge {
                let down = CIFilter.lanczosScaleTransform()
                down.inputImage = img
                down.scale = Float(edge / max(img.extent.width, img.extent.height))
                if let o = down.outputImage { img = o.transformed(by: CGAffineTransform(translationX: -o.extent.minX, y: -o.extent.minY)) }
                img = img.cropped(to: img.extent.integral)
            }
        }
        var shot = FilmShot(recipe: r, flashFired: flashFired, seed: Int(date.timeIntervalSince1970 * 1000) % 100_000)
        // A leak is a surprise on the print, never in the finder.
        if preview { shot.recipe.leak = 0 }
        let sim = FilmCatalog.sim(s.stack.simID)
        if let sim, !sim.isNeutral {
            img = SimEngine.apply(sim, to: img, preview: preview, push: s.stack.push, seed: preview ? nil : shot.seed, shot: shot)
        }
        if preview && frame != img.extent {
            // The finder shows the frame lines: what falls outside the format is dimmed.
            let e = img.extent
            let dim = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.6)).cropped(to: e)
            let hole = CIImage(color: .white).cropped(to: frame)
            let mask = hole.composited(over: CIImage(color: .black).cropped(to: e))
            let b = CIFilter.blendWithMask()
            b.inputImage = CIImage(color: .clear).cropped(to: e)
            b.backgroundImage = dim
            b.maskImage = mask
            if let m = b.outputImage { img = m.cropped(to: e).composited(over: img) }
        }
        return stamp(img, s, date: date, dateShift: dateShift, mono: sim?.mono ?? false)
    }

    /// The date back's orange numbers, burned into the corner.
    private static func stamp(_ img: CIImage, _ s: DevelopSettings, date: Date, dateShift: CGFloat, mono: Bool, shape: FrameShape = .none, instant: InstantKind = .none) -> CIImage {
        guard let overlay = DateBack.overlayImage(size: img.extent.size, date: date, config: s.date, shape: shape, mono: mono, instant: instant) else { return img }
        let e = img.extent
        let drop: CGFloat = -dateShift * e.height * 0.35
        let placed = overlay.transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY + drop)).cropped(to: e)
        return placed.composited(over: img)
    }
}

/// The line XA writes into a photo's metadata, so the roll can say how it was made.
enum Recipe {
    static func describe(_ s: Stack, megapixels: Int, film: Bool = false) -> String {
        if film { return "XA FILM · \(s.filmTitle)" }
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
