import Foundation

/// Everything that shapes a picture, handed from the app to the Lock Screen camera.
///
/// The Lock Screen camera can't read the app's settings (and its own container is wiped after
/// every session), so they travel as JSON in the capture intent's app context (4 KB at most).
/// Fields decode one by one, so a context written by an older build still applies what it has.
struct LockSettings: Codable {
    var mode: CaptureMode = .digi
    var digiStack = Stack(simID: "nocturne")
    var filmStack = Stack(simID: "bowery400")
    var digiMegapixels = 2
    var crunch = 0.6
    var noise = 0.5
    var date = DateConfig()
    var filmDate = DateConfig()
    var recipe = DigiRecipe()
    var filmRecipe = FilmRecipe()
    var filmAlwaysOn = false
    var digiOSD = true
    var instantReview = true
    var flash: FlashSetting = .off
    var sounds = true
    var blink: ShutterBlink = .white
    var grid = false
    var afMode: AFMode = .single
    var afArea: AFArea = .auto
    var proFormat: ProFormat = .heif
    var digiSlide: DigiSlide = .sim
    var proSlide: ProSlide = .exposure
    var showRollButton = true
    var showFlipButton = true
    var favoritesDigi: [String] = []
    var favoritesFilm: [String] = []
    /// Only the custom sims a loaded stack uses (the context is small).
    var customSims: [Sim] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LockSettings()
        func v<T: Decodable>(_ k: CodingKeys, _ fallback: T) -> T {
            if let x = try? c.decodeIfPresent(T.self, forKey: k) { return x }
            return fallback
        }
        mode = v(.mode, d.mode); digiStack = v(.digiStack, d.digiStack); filmStack = v(.filmStack, d.filmStack)
        digiMegapixels = v(.digiMegapixels, d.digiMegapixels); crunch = v(.crunch, d.crunch); noise = v(.noise, d.noise)
        date = v(.date, d.date); filmDate = v(.filmDate, d.filmDate); recipe = v(.recipe, d.recipe); filmRecipe = v(.filmRecipe, d.filmRecipe)
        filmAlwaysOn = v(.filmAlwaysOn, d.filmAlwaysOn); digiOSD = v(.digiOSD, d.digiOSD); instantReview = v(.instantReview, d.instantReview)
        flash = v(.flash, d.flash); sounds = v(.sounds, d.sounds); blink = v(.blink, d.blink); grid = v(.grid, d.grid)
        afMode = v(.afMode, d.afMode); afArea = v(.afArea, d.afArea); proFormat = v(.proFormat, d.proFormat)
        digiSlide = v(.digiSlide, d.digiSlide); proSlide = v(.proSlide, d.proSlide)
        showRollButton = v(.showRollButton, d.showRollButton); showFlipButton = v(.showFlipButton, d.showFlipButton)
        favoritesDigi = v(.favoritesDigi, d.favoritesDigi); favoritesFilm = v(.favoritesFilm, d.favoritesFilm)
        customSims = v(.customSims, d.customSims)
    }

    private enum CodingKeys: String, CodingKey {
        case mode, digiStack, filmStack, digiMegapixels, crunch, noise, date, filmDate, recipe, filmRecipe
        case filmAlwaysOn, digiOSD, instantReview, flash, sounds, blink, grid, afMode, afArea, proFormat
        case digiSlide, proSlide, showRollButton, showFlipButton, favoritesDigi, favoritesFilm, customSims
    }

    /// The modes the Lock Screen camera offers.
    static let modes: [CaptureMode] = [.digi, .film, .pro]

    /// The app's settings now (main thread).
    static func current(_ settings: AppSettings, camera: CameraModel) -> LockSettings {
        var l = LockSettings()
        let m: CaptureMode
        switch settings.openIn {
        case .last: m = camera.mode
        case .digi: m = .digi
        case .film: m = .film
        case .pro: m = .pro
        }
        l.mode = modes.contains(m) ? m : .digi
        l.digiStack = camera.mode == .film ? CameraModel.loadStack(for: .digi) : camera.stack
        l.filmStack = camera.mode == .film ? camera.stack : CameraModel.loadStack(for: .film)
        l.digiMegapixels = settings.digiMegapixels; l.crunch = settings.crunch; l.noise = settings.noise
        l.date = settings.date; l.filmDate = settings.filmDate; l.recipe = settings.recipe; l.filmRecipe = settings.filmRecipe
        l.filmAlwaysOn = settings.filmAlwaysOn; l.digiOSD = settings.digiOSD; l.instantReview = settings.instantReview
        l.flash = settings.flash; l.sounds = settings.sounds; l.blink = settings.blink; l.grid = settings.grid
        l.afMode = settings.afMode; l.afArea = settings.afArea; l.proFormat = settings.proFormat
        l.digiSlide = settings.digiSlide; l.proSlide = settings.proSlide
        l.showRollButton = settings.showRollButton; l.showFlipButton = settings.showFlipButton
        l.favoritesDigi = UserDefaults.standard.stringArray(forKey: "favorites.digi") ?? []
        l.favoritesFilm = UserDefaults.standard.stringArray(forKey: "favorites.film") ?? []
        let used = Set([l.digiStack.simID, l.filmStack.simID].compactMap { $0 })
        l.customSims = FilmCatalog.custom.filter { used.contains($0.id) }
        return l
    }

    /// As JSON for the app context, made to fit: the custom sims and favorites go first if needed.
    func encoded(limit: Int = 3000) -> String? {
        let e = JSONEncoder()
        var me = self
        for step in 0..<3 {
            if step == 1 { me.customSims = [] }
            if step == 2 { me.favoritesDigi = []; me.favoritesFilm = [] }
            if let d = try? e.encode(me), d.count <= limit { return String(data: d, encoding: .utf8) }
        }
        return nil
    }

    static func decode(_ s: String?) -> LockSettings? {
        guard let s, let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LockSettings.self, from: d)
    }

    /// Into the Lock Screen camera's (wiped every session) settings, before its camera starts.
    func apply(to settings: AppSettings) {
        if !customSims.isEmpty { FilmCatalog.setCustom(customSims) }
        let d = UserDefaults.standard
        let e = JSONEncoder()
        d.set(try? e.encode(digiStack), forKey: CameraModel.stackKey(.digi))
        d.set(try? e.encode(filmStack), forKey: CameraModel.stackKey(.film))
        d.set(favoritesDigi, forKey: "favorites.digi")
        d.set(favoritesFilm, forKey: "favorites.film")
        d.set(mode.rawValue, forKey: "mode")
        settings.openIn = .last
        settings.digiMegapixels = digiMegapixels; settings.crunch = crunch; settings.noise = noise
        settings.date = date; settings.filmDate = filmDate; settings.recipe = recipe; settings.filmRecipe = filmRecipe
        settings.filmAlwaysOn = filmAlwaysOn; settings.digiOSD = digiOSD; settings.instantReview = instantReview
        settings.flash = flash; settings.sounds = sounds; settings.blink = blink; settings.grid = grid
        settings.afMode = afMode; settings.afArea = afArea; settings.proFormat = proFormat
        settings.digiSlide = digiSlide; settings.proSlide = proSlide
        settings.showRollButton = showRollButton; settings.showFlipButton = showFlipButton
        // RAW and the biggest PRO sizes stay off here: the Lock Screen camera's memory is small.
        settings.digiZero = false
        settings.proMegapixels = 12
    }
}

/// One Lock Screen shot's recipe, written next to the camera's own file the moment the photo
/// arrives. A shot whose develop the Lock Screen didn't get to finish (the camera was put away)
/// is developed by the app with it, the same way.
struct LockShot: Codable {
    var mode: CaptureMode
    var stack: Stack
    var megapixels: Int
    var noise: Double
    var date: DateConfig
    var recipe: DigiRecipe
    var film: Bool
    var filmRecipe: FilmRecipe
    var crunch: Double
    var taken: Date
    var front: Bool
}
