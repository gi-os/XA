import CoreImage
import Foundation

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

    static func sim(_ id: String?) -> Sim? {
        guard let id else { return nil }
        return sims.first { $0.id == id }
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
}

/// The darkroom: the same chain for the viewfinder and for the saved photograph.
enum Darkroom {
    /// Returns the developed image and whether it has transparent pixels.
    static func develop(_ src: CIImage, _ s: DevelopSettings, date: Date, preview: Bool) -> (CIImage, Bool) {
        var img = preview ? src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
                          : Digicam.shrink(src, megapixels: s.megapixels)
        let sim = FilmCatalog.sim(s.stack.simID)
        if let sim { img = SimEngine.apply(sim, to: img, preview: preview) } else { img = Digicam.tone(img) }
        if s.stack.look != .none {
            let w: CGFloat? = s.stack.look.pixelWidth != nil && !preview ? img.extent.width : nil
            img = Looks.apply(s.stack.look, to: img, outputWidth: w)
        }
        if !preview { img = Digicam.crunch(img, noise: CGFloat(s.noise) * 0.05) }
        let mono = (sim?.mono ?? false) || s.stack.look.mono
        var alpha = false
        var shapeForDate: FrameShape = .none
        var instant: SimFrame = .none
        if let sim, sim.frame != .none {
            img = Shapes.instant(img, round: sim.frame == .round)
            instant = sim.frame
        } else if let shape = s.stack.effectiveShape {
            let bg = preview ? Shapes.checker(extent: img.extent) : nil
            img = Shapes.apply(shape, to: img, background: bg)
            alpha = !preview
            shapeForDate = shape
        }
        if let overlay = DateBack.overlayImage(size: img.extent.size, date: date, config: s.date, shape: shapeForDate, mono: mono, instant: instant) {
            img = overlay.transformed(by: CGAffineTransform(translationX: img.extent.minX, y: img.extent.minY)).composited(over: img)
        }
        return (img, alpha)
    }
}
