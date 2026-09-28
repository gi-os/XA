import SwiftUI

/// The typefaces a film box can be set in. All bundled, all open licence.
enum BoxFont: String, Codable, CaseIterable, Hashable {
    case chakra, spaceMono, racing, pressStart, silkscreen, bungee, anton, orbitron, mochiy, plex,
         righteous, dmSerif, yellowtail, russo, cormorant, archivo, unbounded, fredoka, bebas, nunito,
         oxanium, caveat, shareTech, robotoCondensed

    var postScript: String {
        switch self {
        case .chakra: return "ChakraPetch-Bold"
        case .spaceMono: return "SpaceMono-Bold"
        case .racing: return "RacingSansOne-Regular"
        case .pressStart: return "PressStart2P-Regular"
        case .silkscreen: return "Silkscreen-Regular"
        case .bungee: return "Bungee-Regular"
        case .anton: return "Anton-Regular"
        case .orbitron: return "Orbitron-ExtraBold"
        case .mochiy: return "MochiyPopOne-Regular"
        case .plex: return "IBMPlexSansCond-Bold"
        case .righteous: return "Righteous-Regular"
        case .dmSerif: return "DMSerifDisplay-Regular"
        case .yellowtail: return "Yellowtail-Regular"
        case .russo: return "RussoOne-Regular"
        case .cormorant: return "CormorantGaramond-Bold"
        case .archivo: return "Archivo-ExtraBold"
        case .unbounded: return "Unbounded-ExtraBold"
        case .fredoka: return "Fredoka-Bold"
        case .bebas: return "BebasNeue-Regular"
        case .nunito: return "Nunito-Black"
        case .oxanium: return "Oxanium-ExtraBold"
        case .caveat: return "Caveat-Bold"
        case .shareTech: return "ShareTechMono-Regular"
        case .robotoCondensed: return "RobotoCondensed-Bold"
        }
    }

    var label: String {
        switch self {
        case .chakra: return "Chakra"
        case .spaceMono: return "Space Mono"
        case .racing: return "Racing"
        case .pressStart: return "Pixel"
        case .silkscreen: return "Silkscreen"
        case .bungee: return "Bungee"
        case .anton: return "Anton"
        case .orbitron: return "Orbitron"
        case .mochiy: return "Pop"
        case .plex: return "Plex"
        case .righteous: return "Righteous"
        case .dmSerif: return "Serif"
        case .yellowtail: return "Script"
        case .russo: return "Russo"
        case .cormorant: return "Cormorant"
        case .archivo: return "Archivo"
        case .unbounded: return "Unbounded"
        case .fredoka: return "Fredoka"
        case .bebas: return "Bebas"
        case .nunito: return "Nunito"
        case .oxanium: return "Oxanium"
        case .caveat: return "Marker"
        case .shareTech: return "Mono"
        case .robotoCondensed: return "Condensed"
        }
    }
}

enum BoxPattern: String, Codable, CaseIterable, Hashable {
    case sunburst, split, swoosh, band, stamp, plain
    var label: String { rawValue.capitalized }
}

/// A film box a person designs for their own sim.
struct BoxDesign: Codable, Equatable, Hashable {
    var bg: String = "#F2B51E"
    var fg: String = "#1A1206"
    var accent: String = "#D8412F"
    var second: String = "#1B4FA0"
    var font: BoxFont = .chakra
    var pattern: BoxPattern = .sunburst
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hex: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int((min(1, max(0, r)) * 255).rounded())
        let gi = Int((min(1, max(0, g)) * 255).rounded())
        let bi = Int((min(1, max(0, b)) * 255).rounded())
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}
