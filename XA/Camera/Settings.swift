import Foundation
import Combine

enum ProFormat: String, CaseIterable, Codable { case heif, jpeg }
enum DigiSlide: String, CaseIterable, Codable { case sim, look }
enum ProSlide: String, CaseIterable, Codable { case exposure, zoom }
enum OpenIn: String, CaseIterable, Codable { case last, digi, pro }

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
    @Published var proFormat: ProFormat { didSet { d.set(proFormat.rawValue, forKey: "proFormat") } }
    @Published var digiSlide: DigiSlide { didSet { d.set(digiSlide.rawValue, forKey: "digiSlide") } }
    @Published var proSlide: ProSlide { didSet { d.set(proSlide.rawValue, forKey: "proSlide") } }
    @Published var openIn: OpenIn { didSet { d.set(openIn.rawValue, forKey: "openIn") } }
    @Published var grid: Bool { didSet { d.set(grid, forKey: "grid") } }
    @Published var afMode: AFMode { didSet { d.set(afMode.rawValue, forKey: "afMode") } }
    @Published var afArea: AFArea { didSet { d.set(afArea.rawValue, forKey: "afArea") } }
    @Published var showRollButton: Bool { didSet { d.set(showRollButton, forKey: "showRollButton") } }
    @Published var showFlipButton: Bool { didSet { d.set(showFlipButton, forKey: "showFlipButton") } }

    init() {
        digiMegapixels = d.object(forKey: "digiMP") as? Int ?? 2
        proMegapixels = d.object(forKey: "proMP") as? Int ?? 0
        crunch = d.object(forKey: "crunch") as? Double ?? 0.6
        noise = d.object(forKey: "noise") as? Double ?? 0.5
        date = AppSettings.load("dateConfig") ?? DateConfig()
        proFormat = ProFormat(rawValue: d.string(forKey: "proFormat") ?? "") ?? .heif
        digiSlide = DigiSlide(rawValue: d.string(forKey: "digiSlide") ?? "") ?? .sim
        proSlide = ProSlide(rawValue: d.string(forKey: "proSlide") ?? "") ?? .exposure
        openIn = OpenIn(rawValue: d.string(forKey: "openIn") ?? "") ?? .last
        grid = d.object(forKey: "grid") as? Bool ?? false
        afMode = AFMode(rawValue: d.string(forKey: "afMode") ?? "") ?? .single
        afArea = AFArea(rawValue: d.string(forKey: "afArea") ?? "") ?? .auto
        showRollButton = d.object(forKey: "showRollButton") as? Bool ?? true
        showFlipButton = d.object(forKey: "showFlipButton") as? Bool ?? true
    }

    private func save<T: Encodable>(_ v: T, _ key: String) {
        if let data = try? JSONEncoder().encode(v) { d.set(data, forKey: key) }
    }

    static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
