import Foundation
import Combine

enum ProFormat: String, CaseIterable, Codable { case heif, jpeg }
enum DigiSlide: String, CaseIterable, Codable { case sim, look }
enum ProSlide: String, CaseIterable, Codable { case exposure, zoom }
enum OpenIn: String, CaseIterable, Codable { case last, digi, film, pro }
/// The flash. In DIGI a shot the flash lit gets the party-flash look.
enum FlashSetting: String, CaseIterable, Codable {
    case off, auto, on
    var next: FlashSetting { self == .off ? .auto : (self == .auto ? .on : .off) }
    var icon: String { self == .off ? "bolt.slash" : (self == .auto ? "bolt.badge.automatic" : "bolt.fill") }
    var label: String { self == .off ? "Flash off" : (self == .auto ? "Flash auto" : "Flash on") }
}

/// Everything in Customize, saved as it changes.
final class AppSettings: ObservableObject {
    private let d = UserDefaults.standard

    @Published var digiMegapixels: Int { didSet { d.set(digiMegapixels, forKey: "digiMP") } }
    /// 0 means the biggest the sensor makes.
    @Published var proMegapixels: Int { didSet { d.set(proMegapixels, forKey: "proMP") } }
    static let digiOptions = [1, 2, 3, 5, 8, 12]
    @Published var crunch: Double { didSet { d.set(crunch, forKey: "crunch") } }
    @Published var noise: Double { didSet { d.set(noise, forKey: "noise") } }
    @Published var date: DateConfig { didSet { save(date, "dateConfig") } }
    /// Which digicam faults DIGI photos get, and how much.
    @Published var recipe: DigiRecipe { didSet { save(recipe, "digiRecipe") } }
    /// DIGI shows each shot on the viewfinder for a moment, like a digicam's review.
    @Published var instantReview: Bool { didSet { d.set(instantReview, forKey: "instantReview") } }
    /// DIGI ZERO: shoot RAW and develop it with none of the iPhone's own processing, so the film
    /// is the only look on the picture.
    @Published var digiZero: Bool { didSet { d.set(digiZero, forKey: "digiZero") } }
    @Published var proFormat: ProFormat { didSet { d.set(proFormat.rawValue, forKey: "proFormat") } }
    @Published var digiSlide: DigiSlide { didSet { d.set(digiSlide.rawValue, forKey: "digiSlide") } }
    @Published var proSlide: ProSlide { didSet { d.set(proSlide.rawValue, forKey: "proSlide") } }
    @Published var openIn: OpenIn { didSet { d.set(openIn.rawValue, forKey: "openIn") } }
    @Published var grid: Bool { didSet { d.set(grid, forKey: "grid") } }
    @Published var afMode: AFMode { didSet { d.set(afMode.rawValue, forKey: "afMode") } }
    @Published var afArea: AFArea { didSet { d.set(afArea.rawValue, forKey: "afArea") } }
    @Published var flash: FlashSetting { didSet { d.set(flash.rawValue, forKey: "flash") } }
    /// XA's own focus and shutter sounds instead of the system click.
    @Published var sounds: Bool { didSet { d.set(sounds, forKey: "sounds") } }
    @Published var showRollButton: Bool { didSet { d.set(showRollButton, forKey: "showRollButton") } }
    @Published var showFlipButton: Bool { didSet { d.set(showFlipButton, forKey: "showFlipButton") } }
    /// BOOTH: the skin setting and the sticker sheet's layout.
    @Published var boothSkin: BoothSkin { didSet { d.set(boothSkin.rawValue, forKey: "boothSkin") } }
    @Published var boothLayout: BoothLayout { didSet { d.set(boothLayout.rawValue, forKey: "boothLayout") } }

    init() {
        digiMegapixels = d.object(forKey: "digiMP") as? Int ?? 2
        proMegapixels = d.object(forKey: "proMP") as? Int ?? 0
        crunch = d.object(forKey: "crunch") as? Double ?? 0.6
        noise = d.object(forKey: "noise") as? Double ?? 0.5
        date = AppSettings.load("dateConfig") ?? DateConfig()
        recipe = AppSettings.load("digiRecipe") ?? DigiRecipe()
        instantReview = d.object(forKey: "instantReview") as? Bool ?? true
        digiZero = d.object(forKey: "digiZero") as? Bool ?? false
        proFormat = ProFormat(rawValue: d.string(forKey: "proFormat") ?? "") ?? .heif
        digiSlide = DigiSlide(rawValue: d.string(forKey: "digiSlide") ?? "") ?? .sim
        proSlide = ProSlide(rawValue: d.string(forKey: "proSlide") ?? "") ?? .exposure
        openIn = OpenIn(rawValue: d.string(forKey: "openIn") ?? "") ?? .last
        grid = d.object(forKey: "grid") as? Bool ?? false
        afMode = AFMode(rawValue: d.string(forKey: "afMode") ?? "") ?? .single
        afArea = AFArea(rawValue: d.string(forKey: "afArea") ?? "") ?? .auto
        showRollButton = d.object(forKey: "showRollButton") as? Bool ?? true
        showFlipButton = d.object(forKey: "showFlipButton") as? Bool ?? true
        flash = FlashSetting(rawValue: d.string(forKey: "flash") ?? "") ?? .off
        sounds = d.object(forKey: "sounds") as? Bool ?? true
        boothSkin = BoothSkin(rawValue: d.string(forKey: "boothSkin") ?? "") ?? .doll
        boothLayout = BoothLayout(rawValue: d.string(forKey: "boothLayout") ?? "") ?? .sheet
    }

    private func save<T: Encodable>(_ v: T, _ key: String) {
        if let data = try? JSONEncoder().encode(v) { d.set(data, forKey: key) }
    }

    static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
