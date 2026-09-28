import SwiftUI

/// Something that has a box: a sim, a look or a shape.
enum FilmItem: Hashable, Identifiable {
    case sim(Sim), look(Look), shape(FrameShape)
    var id: String {
        switch self {
        case .sim(let s): return "sim-\(s.id)"
        case .look(let l): return "look-\(l.rawValue)"
        case .shape(let s): return "shape-\(s.rawValue)"
        }
    }
    var title: String {
        switch self {
        case .sim(let s): return s.title
        case .look(let l): return l.title
        case .shape(let s): return s.title
        }
    }
}

// MARK: layout helpers (the boxes are drawn at 160 × 106 and scaled)

private extension View {
    func tl(_ x: CGFloat, _ y: CGFloat) -> some View { offset(x: x, y: y) }
    func tr(_ r: CGFloat, _ y: CGFloat) -> some View {
        padding(.trailing, r).frame(maxWidth: .infinity, alignment: .trailing).offset(y: y)
    }
    func bl(_ x: CGFloat, _ b: CGFloat) -> some View {
        padding(.bottom, b).frame(maxHeight: .infinity, alignment: .bottom).offset(x: x)
    }
    func br(_ r: CGFloat, _ b: CGFloat) -> some View {
        padding(.trailing, r).padding(.bottom, b).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

private func T(_ s: String, _ ps: String, _ size: CGFloat, _ c: Color, _ tracking: CGFloat = 0) -> some View {
    Text(s).font(.custom(ps, fixedSize: size)).tracking(tracking).foregroundStyle(c).lineLimit(1).fixedSize()
}

private struct BoxCanvas<Content: View>: View {
    let bg: Color
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(bg)
            content()
        }
        .frame(width: 160, height: 106)
        .clipped()
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width / 24, rect.height / 22)
        return Path(Shapes.heart(scale: k, offset: CGPoint(x: rect.midX - 12 * k, y: rect.midY - 11 * k)))
    }
}

struct FrameShapeView: Shape {
    let shape: FrameShape
    func path(in rect: CGRect) -> Path {
        guard let p = shape.path(in: rect) else { return Path(rect) }
        return Path(p)
    }
}

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let o = min(rect.width, rect.height) / 2, i = o * 0.45
        for n in 0..<10 {
            let r: CGFloat = n % 2 == 0 ? o : i
            let a: CGFloat = -.pi / 2 + CGFloat(n) * .pi / 5
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            if n == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct Rays: View {
    let color: Color
    var count = 18
    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Rectangle().fill(color).frame(width: 6, height: 240)
                    .rotationEffect(.degrees(Double(i) * 180 / Double(count)))
            }
        }
    }
}

// MARK: the box

/// A film box at any size. The design is 160 × 106; `width` scales it.
struct FilmBox: View {
    let item: FilmItem
    var width: CGFloat = 80
    var body: some View {
        let s = width / 160
        content
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: 160 * s, height: 106 * s, alignment: .topLeading)
            .clipped()
    }

    @ViewBuilder private var content: some View {
        switch item {
        case .look(let l): LookBox(look: l)
        case .shape(let s): ShapeBox(shape: s)
        case .sim(let s):
            if s.isPreset { PresetSimBox(sim: s) } else { CustomBox(design: s.box, name: s.name, iso: s.iso, exposures: s.exposures) }
        }
    }
}

private struct LookBox: View {
    let look: Look
    var body: some View {
        switch look {
        case .none: clean
        case .film: grain
        case .sixteen: sixteen
        case .gameboy: pocket
        case .dither: onebit
        case .halftone: press
        case .thermal: heat
        case .purikura: booth
        }
    }

    private var clean: some View {
        let fg = Color(hex: "#141414"), f = "SpaceMono-Bold"
        return BoxCanvas(bg: Color(hex: "#F4F1EA")) {
            VStack(spacing: 3) {
                Rectangle().fill(fg).frame(height: 1)
                HStack { T("XA LAB", f, 9, fg, 2); Spacer(); T("NO. 001", f, 9, fg, 2) }
                Rectangle().fill(fg).frame(height: 1)
            }.frame(width: 140).tl(10, 9)
            T("CLEAN", f, 22, fg, 1).tl(10, 34)
            T("100", f, 18, Color(hex: "#D8412F")).tr(10, 36)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach([2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2].indices, id: \.self) { i in
                    Rectangle().fill(fg).frame(width: CGFloat([2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2][i]), height: 22)
                }
            }.bl(10, 10)
            T("NATURAL · 24", f, 8, fg, 1).br(10, 10)
        }
    }

    private var grain: some View {
        let f = "RacingSansOne-Regular", fg = Color(hex: "#1A1206")
        return BoxCanvas(bg: Color(hex: "#F2B51E")) {
            Rectangle().fill(Color(hex: "#D8412F")).frame(width: 220, height: 12).rotationEffect(.degrees(-8)).tl(-30, 58)
            Rectangle().fill(Color(hex: "#1B4FA0")).frame(width: 220, height: 7).rotationEffect(.degrees(-8)).tl(-30, 74)
            T("XA", f, 13, fg, 1).tl(10, 6)
            T("Grain", f, 26, fg).tl(10, 24)
            T("200", f, 38, Color(hex: "#1B4FA0")).shadow(color: Color(hex: "#D8412F"), radius: 0, x: 2, y: 2).tr(8, 4)
            T("24 EXP · DAYLIGHT", f, 11, fg).bl(10, 6)
        }
    }

    private var sixteen: some View {
        let f = "PressStart2P-Regular"
        let pal: [String] = ["#000000", "#7F0000", "#007F00", "#7F7F00", "#00007F", "#7F007F", "#007F7F", "#C0C0C0",
                             "#7F7F7F", "#FF0000", "#00FF00", "#FFFF00", "#0000FF", "#FF00FF", "#00FFFF", "#FFFFFF"]
        return BoxCanvas(bg: Color(hex: "#141414")) {
            T("M-CAS", f, 7, .white, 1).tl(10, 10)
            T("SIXTEEN", f, 10, .white).tl(10, 28)
            T("16", f, 22, XA.orange).tl(10, 52)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(12.5), spacing: 1), count: 4), spacing: 1) {
                ForEach(pal, id: \.self) { Rectangle().fill(Color(hex: $0)).frame(height: 12.5) }
            }
            .frame(width: 54).padding(1).border(Color.white, width: 2).tr(10, 10)
            T("COLORS · 320 PX", f, 6, .white, 1).bl(10, 8)
        }
    }

    private var pocket: some View {
        let f = "Silkscreen-Regular", fg = Color(hex: "#2B2A6E"), dark = Color(hex: "#0F380F")
        return BoxCanvas(bg: Color(hex: "#C4C0B8")) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(hex: "#9BBC0F"))
                T("4", f, 26, dark).tl(8, 2)
                T("TONE", f, 13, dark).tr(8, 6)
                HStack(spacing: 3) {
                    ForEach(["#0F380F", "#306230", "#8BAC0F", "#9BBC0F"], id: \.self) { Rectangle().fill(Color(hex: $0)).frame(width: 14, height: 8) }
                }.bl(8, 5)
            }
            .frame(width: 140, height: 60).border(fg, width: 3).tl(10, 8)
            T("POCKET", f, 13, fg).bl(10, 9)
            HStack(spacing: 6) { Circle().fill(fg).frame(width: 11); Circle().fill(fg).frame(width: 11).offset(y: -5) }.br(12, 12)
        }
    }

    private var onebit: some View {
        let f = "Bungee-Regular"
        return BoxCanvas(bg: .white) {
            Path { p in p.move(to: CGPoint(x: 99, y: 0)); p.addLine(to: CGPoint(x: 160, y: 0)); p.addLine(to: CGPoint(x: 160, y: 106)); p.addLine(to: CGPoint(x: 61, y: 106)); p.closeSubpath() }
                .fill(Color.black)
            HStack(spacing: 0) {
                ForEach(0..<27, id: \.self) { i in
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { j in Rectangle().fill((i + j) % 2 == 0 ? Color.black : Color.white).frame(width: 6, height: 6) }
                    }
                }
            }.bl(0, 0)
            T("1-BIT", f, 22, .black).tl(10, 10)
            T("B&W", f, 10, .black).tl(10, 38)
            T("1600", f, 20, .white).tr(10, 44)
            T("PUSH +2", f, 9, .white).tr(10, 68)
        }
    }

    private var press: some View {
        let f = "Anton-Regular", fg = Color(hex: "#111111")
        return BoxCanvas(bg: Color(hex: "#F4F1EA")) {
            ZStack {
                Rectangle().fill(Color(hex: "#00A6D6"))
                HalftoneDots(color: Color(hex: "#E5007E"), spacing: 7)
            }.frame(width: 160, height: 56)
            T("PRESS", f, 40, fg, 1).padding(.horizontal, 4).background(Color(hex: "#F4F1EA")).tl(10, 4)
            T("DOT · 85 LPI", f, 12, fg, 3).tl(10, 62)
            HStack(spacing: 3) { ForEach(["#00A6D6", "#E5007E", "#FFE500", "#111111"], id: \.self) { Circle().fill(Color(hex: $0)).frame(width: 9) } }.tr(10, 64)
            VStack(alignment: .leading, spacing: 2) { Rectangle().fill(fg).frame(width: 140, height: 1); T("EARLY EDITION", f, 8, fg, 1) }.bl(10, 6)
        }
    }

    private var heat: some View {
        let f = "Orbitron-ExtraBold", fg = Color(hex: "#FFE08A")
        return BoxCanvas(bg: Color(hex: "#1B0B3A")) {
            LinearGradient(colors: [Color(hex: "#2B0B5E"), Color(hex: "#FF6A00"), Color(hex: "#FFD23F"), Color(hex: "#FFFBE0")], startPoint: .leading, endPoint: .trailing)
                .frame(width: 160, height: 40).bl(0, 0)
            VStack(spacing: 2) { ForEach(0..<36, id: \.self) { _ in Rectangle().fill(Color.black.opacity(0.25)).frame(height: 1) } }
            T("XA IR", f, 10, fg, 3).tl(10, 10)
            T("HEAT", f, 22, Color(hex: "#FF6A00"), 1).tl(10, 26)
            T("800", f, 18, fg).tr(10, 10)
            T("INFRARED", f, 7, fg, 1.5).tr(10, 34)
        }
    }

    private var booth: some View {
        let f = "MochiyPopOne-Regular", fg = Color(hex: "#3A0A24"), pink = Color(hex: "#E5007E")
        return BoxCanvas(bg: Color(hex: "#FF8FC8")) {
            HStack { ForEach(0..<7, id: \.self) { i in Text(i % 2 == 0 ? "♥" : "★").font(.system(size: 13)).foregroundStyle(Color(hex: "#FF8FC8")).frame(maxWidth: .infinity) } }
                .frame(width: 160, height: 26).background(pink).bl(0, 0)
            T("STICKER", f, 11, fg).tl(10, 8)
            T("Booth", f, 22, fg).tl(10, 24)
            VStack(spacing: 3) { T("400", f, 13, pink); T("LOVE", f, 7, pink) }
                .frame(width: 52, height: 52).background(Circle().fill(Color.white))
                .overlay(Circle().strokeBorder(pink, style: StrokeStyle(lineWidth: 3, dash: [4, 3])))
                .rotationEffect(.degrees(12)).tr(8, 8)
        }
    }
}

private struct HalftoneDots: View {
    let color: Color
    let spacing: CGFloat
    var body: some View {
        SwiftUI.Canvas { ctx, size in
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

private struct PresetSimBox: View {
    let sim: Sim
    var body: some View {
        switch sim.id {
        case "nocturne": nocturne
        case "visage": visage
        case "prima": prima
        case "amethyst": amethyst
        case "sunday": sunday
        case "sundayRound": round
        default: onyx
        }
    }

    private var nocturne: some View {
        let f = "Oxanium-ExtraBold", fg = Color(hex: "#EAF2F5"), red = Color(hex: "#D8412F")
        return BoxCanvas(bg: Color(hex: "#0E1A22")) {
            Circle().fill(RadialGradient(colors: [.white, red, red.opacity(0)], center: .center, startRadius: 2, endRadius: 22))
                .frame(width: 44, height: 44).tr(18, 16)
            T("XACOLOR", f, 10, Color(hex: "#6FB6C9"), 3).tl(10, 8)
            HStack(spacing: 0) { T("800", f, 32, fg); T("T", f, 32, red) }.tl(10, 24)
            Rectangle().fill(Color(hex: "#6FB6C9")).frame(width: 160, height: 1).tl(0, 85)
            T("NOCTURNE · 3200K", f, 11, fg, 2).bl(10, 5)
        }
    }

    private var visage: some View {
        let f = "CormorantGaramond-Bold", fg = Color(hex: "#4A3A6A"), paper = Color(hex: "#F3E7C9")
        return BoxCanvas(bg: paper) {
            LinearGradient(colors: [Color(hex: "#7F78D2"), Color(hex: "#D98BB5")], startPoint: .top, endPoint: .bottom).frame(width: 58, height: 106)
            T("135-36", f, 11, paper, 1).tl(8, 8)
            T("800", f, 30, paper).bl(6, 6)
            T("VISAGE", f, 16, Color(hex: "#7F78D2"), 2).tl(70, 16)
            VStack(alignment: .leading, spacing: 4) { Rectangle().fill(fg).frame(width: 80, height: 1); T("portrait · professional", f, 10, fg) }.tl(70, 44)
            T("XACOLOR PRO", "ChakraPetch-SemiBold", 9, Color(hex: "#D98BB5"), 1).bl(70, 8)
        }
    }

    private var prima: some View {
        let f = "Archivo-ExtraBold", green = Color(hex: "#3F9A45")
        return BoxCanvas(bg: green) {
            Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: 150, y: 0)); p.addLine(to: CGPoint(x: 132, y: 26)); p.addLine(to: CGPoint(x: 0, y: 26)); p.closeSubpath() }.fill(Color.white)
            T("XACOLOR", f, 13, green, 1).tl(10, 5)
            Path { p in p.move(to: CGPoint(x: 0, y: 30)); p.addLine(to: CGPoint(x: 130, y: 30)); p.addLine(to: CGPoint(x: 112, y: 76)); p.addLine(to: CGPoint(x: 0, y: 76)); p.closeSubpath() }
                .fill(RadialGradient(colors: [Color(hex: "#E24DA0"), Color(hex: "#8E1E6E")], center: UnitPoint(x: 0.2, y: 0.5), startRadius: 2, endRadius: 110))
            T("400", f, 38, .white).tl(12, 32)
            T("36", f, 26, .white).tr(12, 40)
            T("PRIMA X · EVERY DAY", f, 9, .white, 1).bl(10, 8)
        }
    }

    private var amethyst: some View {
        let f = "Unbounded-ExtraBold", fg = Color(hex: "#2A124F")
        return BoxCanvas(bg: Color(hex: "#C9B6F2")) {
            LinearGradient(colors: [Color(hex: "#C9B6F2"), Color(hex: "#F1B6E6")], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 0) { T("AME", f, 16, fg); T("THYST", f, 16, fg) }.tl(10, 10)
            T("400", f, 22, Color(hex: "#7A2BD1")).tr(10, 8)
            T("XACOLOR", f, 8, fg, 1).tr(10, 36)
            HStack(spacing: 3) { ForEach(["#3B1E6E", "#6A3FB5", "#B56BD9", "#F1B6E6"], id: \.self) { Rectangle().fill(Color(hex: $0)).frame(width: 14, height: 6) } }.bl(10, 8)
        }
    }

    private func print(round: Bool) -> some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color.white).shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            if round {
                Circle().fill(LinearGradient(colors: [Color(hex: "#E56B9E"), Color(hex: "#F2B51E")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44).padding(.top, 5)
            } else {
                LinearGradient(colors: [Color(hex: "#7FC8C4"), Color(hex: "#E07A5F")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 48, height: 48).padding(.top, 4)
            }
        }
        .frame(width: 56, height: 68)
    }

    private var sunday: some View {
        let f = "Nunito-Black", fg = Color(hex: "#1A1A1A")
        return BoxCanvas(bg: Color(hex: "#F7F5F0")) {
            print(round: false).tr(12, 10)
            T("SUNDAY", f, 18, fg).tl(10, 10)
            T("600", f, 18, Color(hex: "#E07A5F")).tl(10, 34)
            T("XA INSTANT · 8 SHOTS", f, 9, fg, 1).bl(10, 8)
        }
    }

    private var round: some View {
        let f = "Fredoka-Bold", fg = Color(hex: "#F7F5F0")
        return BoxCanvas(bg: Color(hex: "#1A1A1A")) {
            print(round: true).tr(12, 10)
            T("Sunday", f, 22, fg).tl(10, 8)
            T("600", f, 18, Color(hex: "#F2B51E")).tl(10, 38)
            T("ROUND · XA INSTANT", f, 9, fg, 1).bl(10, 8)
        }
    }

    private var onyx: some View {
        let f = "BebasNeue-Regular", paper = Color(hex: "#F4F1EA"), ink = Color(hex: "#0A0A0A")
        return BoxCanvas(bg: paper) {
            Rectangle().fill(ink).frame(width: 64, height: 106)
            VStack(alignment: .leading, spacing: -6) { T("32", f, 44, paper); T("00", f, 44, paper) }.tl(6, 6)
            T("ONYX", f, 40, ink, 2).tl(76, 8)
            T("PUSH +2 · B&W", f, 11, Color(hex: "#8A8A8A"), 1).tl(76, 54)
            T("XAPAN · HI-CON", f, 11, ink, 1).bl(76, 8)
        }
    }
}

private struct ShapeBox: View {
    let shape: FrameShape
    var body: some View {
        switch shape {
        case .capsule: capsule
        case .porthole: porthole
        case .window: window
        case .crush: crush
        default: nova
        }
    }

    private var capsule: some View {
        let f = "IBMPlexSansCond-Bold", fg = Color(hex: "#1A1A1A"), red = Color(hex: "#D8412F")
        return BoxCanvas(bg: .white) {
            Rectangle().fill(red).frame(width: 14, height: 106)
            T("XA SHAPE · Rx", f, 10, fg, 1).tl(24, 8)
            T("CAPSULE", f, 24, fg).tl(24, 22)
            T("Twice daily.", f, 9, fg).tl(24, 52)
            ZStack(alignment: .top) {
                Capsule().fill(Color.white)
                Rectangle().fill(red).frame(height: 32)
            }
            .frame(width: 28, height: 64).clipShape(Capsule()).overlay(Capsule().stroke(fg, lineWidth: 2))
            .rotationEffect(.degrees(28)).tr(16, 14)
            T("24 FRAMES", f, 8, fg, 1).bl(24, 8)
        }
    }

    private var porthole: some View {
        let f = "Righteous-Regular"
        return BoxCanvas(bg: Color(hex: "#1B4FA0")) {
            ZStack { ForEach(0..<7, id: \.self) { i in Circle().strokeBorder(Color(hex: "#FFD23F"), lineWidth: 8).frame(width: CGFloat(112 - i * 16), height: CGFloat(112 - i * 16)) } }
                .frame(width: 112, height: 112).tl(114, -8)
            T("XA SHAPE", f, 10, .white, 2).tl(10, 10)
            T("PORTHOLE", f, 19, .white).tl(10, 28)
            T("360°", f, 10, .white, 1).bl(10, 10)
        }
    }

    private var window: some View {
        let f = "DMSerifDisplay-Regular", fg = Color(hex: "#0F1A05")
        return BoxCanvas(bg: Color(hex: "#6F9A3A")) {
            FrameShapeView(shape: .window).fill(Color(hex: "#F4F1EA"))
                .overlay(FrameShapeView(shape: .window).stroke(fg, lineWidth: 3))
                .frame(width: 70, height: 118).tr(4, 4)
            Rectangle().fill(fg).frame(width: 2, height: 90).tr(38, 12)
            T("XA SHAPE", f, 10, fg, 3).tl(10, 8)
            T("Window", f, 21, fg).tl(10, 28)
            T("Est. 1994", f, 10, fg, 1).bl(10, 9)
        }
    }

    private var crush: some View {
        let fg = Color(hex: "#7A0F3A")
        return BoxCanvas(bg: Color(hex: "#FFD6E7")) {
            HeartShape().fill(Color(hex: "#E5007E")).frame(width: 70, height: 64).tr(-4, 16)
            T("XA SHAPE", "ChakraPetch-SemiBold", 10, fg, 2).tl(10, 8)
            T("Crush", "Yellowtail-Regular", 32, fg).tl(8, 28)
            T("xoxo", "Yellowtail-Regular", 16, fg).bl(10, 8)
        }
    }

    private var nova: some View {
        let f = "RussoOne-Regular", gold = Color(hex: "#FFD23F")
        return BoxCanvas(bg: Color(hex: "#141414")) {
            Rays(color: gold.opacity(0.35)).frame(width: 140, height: 140).tl(60, -30)
            StarShape().fill(gold).frame(width: 68, height: 68).tr(12, 14)
            T("XA SHAPE", f, 10, .white, 2).tl(10, 10)
            T("NOVA", f, 26, gold).tl(10, 26)
            T("SUPERSTAR · 5", f, 9, .white, 1).bl(10, 9)
        }
    }
}

/// A box someone designed in the sim editor.
struct CustomBox: View {
    let design: BoxDesign
    let name: String
    let iso: String
    let exposures: Int
    var body: some View {
        let bg = Color(hex: design.bg), fg = Color(hex: design.fg), a = Color(hex: design.accent), b = Color(hex: design.second)
        let f = design.font.postScript
        return BoxCanvas(bg: bg) {
            pattern(a: a, b: b)
            T("XA", f, 11, fg, 2).tl(10, 8)
            T(name, f, name.count > 8 ? 20 : 26, fg).tl(10, 26)
            T(iso, f, 30, a).tr(10, 4)
            T("\(exposures) EXP", f, 10, fg, 1).bl(10, 8)
        }
    }

    @ViewBuilder private func pattern(a: Color, b: Color) -> some View {
        switch design.pattern {
        case .sunburst: Rays(color: b.opacity(0.4)).frame(width: 240, height: 240).tl(-60, -70)
        case .split: Rectangle().fill(b).frame(width: 58, height: 106).tr(0, 0)
        case .swoosh: Ellipse().fill(b).frame(width: 220, height: 60).rotationEffect(.degrees(-12)).tl(-30, 60)
        case .band: Rectangle().fill(b).frame(width: 160, height: 26).tl(0, 58)
        case .stamp: RoundedRectangle(cornerRadius: 0).strokeBorder(b, lineWidth: 2).frame(width: 148, height: 94).tl(6, 6)
        case .plain: EmptyView()
        }
    }
}
