import SwiftUI
import Photos

// MARK: piles

/// Shots of the same moment go on the table as one pile, held with a clip. Grouping is plain
/// and predictable: pictures (not videos) taken within `window` seconds of the one before,
/// facing the same way. Which print sits on top, and which piles were unclipped, is kept.
enum RollPiles {
    struct Item: Equatable {
        let id: String
        let date: Date
        let width: Int
        let height: Int
        let isVideo: Bool
    }

    static let window: TimeInterval = 10

    /// Groups of indexes into `items`, which run newest first, each group newest first.
    static func group(_ items: [Item], unclipped: Set<String> = []) -> [[Int]] {
        var out: [[Int]] = []
        for (i, it) in items.enumerated() {
            if let last = out.last, let j = last.last {
                let prev = items[j]
                let near = abs(prev.date.timeIntervalSince(it.date)) <= window
                let sameWay = (prev.width >= prev.height) == (it.width >= it.height)
                let key = items[last[0]].id
                if near && sameWay && !it.isVideo && !prev.isVideo && !unclipped.contains(key) {
                    out[out.count - 1].append(i)
                    continue
                }
            }
            out.append([i])
        }
        return out
    }

    // Remembered choices, keyed by the pile's first (newest) shot.
    private static let d = UserDefaults.standard
    static func top(for key: String) -> String? { (d.dictionary(forKey: "pileTops") as? [String: String])?[key] }
    static func setTop(_ id: String, for key: String) {
        var m = (d.dictionary(forKey: "pileTops") as? [String: String]) ?? [:]
        m[key] = id; d.set(m, forKey: "pileTops")
    }
    static var unclipped: Set<String> { Set(d.stringArray(forKey: "unclippedPiles") ?? []) }
    static func unclip(_ key: String) { d.set(Array(unclipped.union([key])), forKey: "unclippedPiles") }
}

/// A pile on the table, or a single print.
struct Pile: Identifiable {
    let assets: [PHAsset]
    var id: String { assets[0].localIdentifier }
    var top: PHAsset {
        if let t = RollPiles.top(for: id), let a = assets.first(where: { $0.localIdentifier == t }) { return a }
        return assets[0]
    }
    var others: [PHAsset] { assets.filter { $0.localIdentifier != top.localIdentifier } }
}

// MARK: the table

/// The roll as prints on a table: loose columns, every picture in its own shape and a white
/// border, a little askew. Pinch in for three or four columns, out for two.
struct RollTable: View {
    @ObservedObject var library: Library
    var onOpen: (PHAsset) -> Void
    /// Pulled past the top and let go: the roll closes, the way a sheet does.
    var onPullClose: (() -> Void)?
    @State private var overscroll: CGFloat = 0
    @AppStorage("rollColumns") private var columns = 2
    @State private var pinchStart: Int?
    @State private var showCols = false
    @State private var openPile: Pile?
    @State private var version = 0

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(library.days, id: \.title) { day in
                        Tape(text: Self.tapeText(day.assets.first?.creationDate))
                        Masonry(piles: piles(day.assets), columns: columns, library: library, onTap: { pile in
                            if pile.assets.count > 1 { withAnimation(.snappy) { openPile = pile } } else { onOpen(pile.top) }
                        }, onStep: { pile, by in
                            // Swipe a pile sideways: the next shot in it comes to the top.
                            let a = pile.assets
                            guard a.count > 1, let i = a.firstIndex(where: { $0.localIdentifier == pile.top.localIdentifier }) else { return }
                            let next = a[((i + by) % a.count + a.count) % a.count]
                            RollPiles.setTop(next.localIdentifier, for: pile.id)
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.snappy) { version += 1 }
                        })
                        .id("\(day.title)-\(columns)-\(version)")
                    }
                }
                .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 60)
            }
            .background(Table())
            .onScrollGeometryChange(for: CGFloat.self, of: { -($0.contentOffset.y + $0.contentInsets.top) }) { _, v in overscroll = max(0, v) }
            .onScrollPhaseChange { old, new in
                if old == .interacting && new != .interacting && overscroll > 70 { onPullClose?() }
            }
            .simultaneousGesture(MagnifyGesture()
                .onChanged { v in
                    if pinchStart == nil { pinchStart = columns; withAnimation { showCols = true } }
                    let start = pinchStart ?? columns
                    let want = v.magnification < 0.8 ? start + 1 : (v.magnification > 1.25 ? start - 1 : start)
                    let c = min(4, max(2, want))
                    if c != columns { withAnimation(.snappy) { columns = c }; UISelectionFeedbackGenerator().selectionChanged() }
                }
                .onEnded { _ in
                    pinchStart = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { showCols = false } }
                })
            if showCols { ColumnPill(columns: columns).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 28).transition(.opacity) }
            if let p = openPile {
                PileSpread(pile: p, library: library, onOpen: onOpen) { action in
                    switch action {
                    case .done: break
                    case .unclip: RollPiles.unclip(p.id)
                    case .deleteRest: library.delete(p.others)
                    }
                    version += 1
                    withAnimation(.snappy) { openPile = nil }
                } onTop: { a in
                    RollPiles.setTop(a.localIdentifier, for: p.id); version += 1
                    openPile = Pile(assets: p.assets)
                }
                .transition(.opacity)
            }
        }
    }

    private func piles(_ assets: [PHAsset]) -> [Pile] {
        let items = assets.map { RollPiles.Item(id: $0.localIdentifier, date: $0.creationDate ?? .distantPast, width: $0.pixelWidth, height: $0.pixelHeight, isVideo: $0.mediaType == .video) }
        return RollPiles.group(items, unclipped: RollPiles.unclipped).map { g in Pile(assets: g.map { assets[$0] }) }
    }

    static func tapeText(_ d: Date?) -> String {
        guard let d else { return "" }
        let f = DateFormatter(); f.dateFormat = "EEE · MMM d"
        return f.string(from: d).lowercased()
    }
}

/// OLED black: the prints float on nothing, and the screen's pixels are off between them.
private struct Table: View {
    var body: some View { Color.black.ignoresSafeArea() }
}

/// The day on a strip of masking tape.
private struct Tape: View {
    let text: String
    var body: some View {
        Text(text).font(.custom("Caveat-Bold", fixedSize: 19)).foregroundStyle(Color(hex: "#2A1A06"))
            .padding(.horizontal, 16).padding(.vertical, 3)
            .background(Color(hex: "#ECE2C4").opacity(0.94))
            .rotationEffect(.degrees(-1.5))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
            .frame(maxWidth: .infinity)
    }
}

private struct ColumnPill: View {
    let columns: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach([2, 3, 4], id: \.self) { c in
                Text("\(c)").font(XA.display(12))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .foregroundStyle(c == columns ? Color(red: 0.16, green: 0.08, blue: 0) : .white.opacity(0.7))
                    .background(c == columns ? XA.orange : .clear, in: Capsule())
            }
        }
        .padding(3).background(Color.black.opacity(0.72), in: Capsule())
    }
}

/// Loose columns: each pile goes under the shortest column so far.
private struct Masonry: View {
    let piles: [Pile]
    let columns: Int
    let library: Library
    var onTap: (Pile) -> Void
    var onStep: (Pile, Int) -> Void = { _, _ in }

    var body: some View {
        GeometryReader { g in
            let gap: CGFloat = columns == 2 ? 16 : (columns == 3 ? 12 : 9)
            let cw = (g.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let cols = layout(width: cw, gap: gap)
            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<columns, id: \.self) { c in
                    VStack(spacing: gap + 8) {
                        ForEach(cols.items[c], id: \.id) { p in
                            PileView(pile: p, width: cw, library: library, onStep: onStep).onTapGesture { onTap(p) }
                        }
                    }
                    .frame(width: cw)
                }
            }
        }
        .frame(height: layout(width: approxWidth, gap: 12).height)
    }

    /// The table is the phone's width minus its margins.
    private var approxWidth: CGFloat {
        let w = UIScreen.main.bounds.width - 24
        let gap: CGFloat = columns == 2 ? 16 : (columns == 3 ? 12 : 9)
        return (w - gap * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func layout(width cw: CGFloat, gap: CGFloat) -> (items: [[Pile]], height: CGFloat) {
        var items = Array(repeating: [Pile](), count: columns)
        var h = Array(repeating: CGFloat(0), count: columns)
        for p in piles {
            let c = h.firstIndex(of: h.min() ?? 0) ?? 0
            items[c].append(p)
            h[c] += PrintView.height(for: p.top, width: cw) + gap + 8 + (p.assets.count > 1 ? 8 : 0)
        }
        return (items, (h.max() ?? 0) + 12)
    }
}

/// A pile: the chosen print on top, up to two more peeking out, a clip and a count.
private struct PileView: View {
    let pile: Pile
    let width: CGFloat
    let library: Library
    var onStep: (Pile, Int) -> Void = { _, _ in }
    @State private var drag: CGFloat = 0
    var body: some View {
        ZStack(alignment: .top) {
            if pile.assets.count > 1 {
                ForEach(Array(pile.others.prefix(2).enumerated()), id: \.offset) { i, a in
                    PrintView(asset: a, width: width, library: library, tilt: i == 0 ? 3 : -4)
                        .offset(x: i == 0 ? 5 : -6, y: CGFloat(3 + 2 * i))
                }
            }
            PrintView(asset: pile.top, width: width, library: library, tilt: Self.tilt(pile.top.localIdentifier))
                .offset(x: drag * 0.5).rotationEffect(.degrees(Double(drag) * 0.05))
            if pile.assets.count > 1 {
                Clip().frame(width: 40 * scale, height: 34 * scale).offset(y: -20 * scale)
                Text("×\(pile.assets.count)").font(.custom("Caveat-Bold", fixedSize: 15 * scale)).foregroundStyle(Color(hex: "#2A1A06"))
                    .padding(.horizontal, 6 * scale).padding(.vertical, 1)
                    .background(Color(hex: "#F2D35B")).rotationEffect(.degrees(6))
                    .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1.5)
                    .frame(maxWidth: .infinity, alignment: .trailing).offset(x: 4, y: -4)
            }
        }
        .padding(.top, pile.assets.count > 1 ? 8 : 0)
        .simultaneousGesture(pile.assets.count > 1 ? DragGesture(minimumDistance: 16)
            .onChanged { v in if abs(v.translation.width) > abs(v.translation.height) * 1.4 { drag = v.translation.width } }
            .onEnded { v in
                let dx = v.translation.width
                if abs(dx) > 40 && abs(dx) > abs(v.translation.height) * 1.4 { onStep(pile, dx < 0 ? 1 : -1) }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { drag = 0 }
            } : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pile.assets.count > 1 ? "Pile of \(pile.assets.count) shots" : "Photo")
        .accessibilityAddTraits(.isButton)
    }
    private var scale: CGFloat { max(0.6, width / 165) }
    /// The same slight angle every time for the same picture.
    static func tilt(_ id: String) -> Double {
        let h = id.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
        return Double(Int(h % 37)) / 10 - 1.8
    }
}

/// A flat binder clip: a black jaw and one grey handle.
private struct Clip: View {
    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 44
            var handle = Path()
            handle.move(to: CGPoint(x: 14 * k, y: 18 * k)); handle.addLine(to: CGPoint(x: 12 * k, y: 4 * k))
            handle.addLine(to: CGPoint(x: 32 * k, y: 4 * k)); handle.addLine(to: CGPoint(x: 30 * k, y: 18 * k))
            ctx.stroke(handle, with: .color(Color(hex: "#B8B8BC")), style: StrokeStyle(lineWidth: 2.4 * k, lineJoin: .round))
            var jaw = Path()
            jaw.move(to: CGPoint(x: 6 * k, y: 34 * k)); jaw.addLine(to: CGPoint(x: 11 * k, y: 16 * k))
            jaw.addLine(to: CGPoint(x: 33 * k, y: 16 * k)); jaw.addLine(to: CGPoint(x: 38 * k, y: 34 * k)); jaw.closeSubpath()
            ctx.fill(jaw, with: .color(Color(hex: "#141416")))
        }
        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
        .allowsHitTesting(false)
    }
}

/// One print. Plain photos get a white border; instant prints and cut-outs are already objects.
struct PrintView: View {
    let asset: PHAsset
    let width: CGFloat
    let library: Library
    var tilt: Double = 0
    @State private var img: UIImage?

    static func aspect(_ a: PHAsset) -> CGFloat { a.pixelHeight > 0 ? CGFloat(a.pixelWidth) / CGFloat(a.pixelHeight) : 0.75 }
    /// Instant film comes out of the camera with its paper on.
    static func isInstant(_ a: PHAsset) -> Bool {
        let r = aspect(a)
        return [1.12 / 1.276, 54.0 / 86.0, 108.0 / 86.0].contains { abs($0 - r) < 0.012 }
    }
    static func bordered(_ a: PHAsset, _ library: Library) -> Bool { !isInstant(a) && !library.isTransparentCached(a) }
    static func height(for a: PHAsset, width: CGFloat) -> CGFloat {
        let b = isInstant(a) ? 0 : max(3, width * 0.035)
        return (width - 2 * b) / aspect(a) + 2 * b
    }

    var body: some View {
        let border = Self.bordered(asset, library)
        let b: CGFloat = border ? max(3, width * 0.035) : 0
        let w = width - 2 * b
        let h = w / Self.aspect(asset)
        ZStack {
            if let img { Image(uiImage: img).resizable().scaledToFill() } else { Color.white.opacity(0.06) }
        }
        .frame(width: w, height: h).clipped()
        .overlay(alignment: .bottomTrailing) {
            if asset.mediaType == .video {
                Text(Library.clock(asset.duration)).font(XA.mono(10)).padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Color.black.opacity(0.6)).padding(4)
            }
        }
        .padding(b)
        .background(border ? Color(hex: "#F4F1EA") : .clear)
        .rotationEffect(.degrees(tilt))
        .shadow(color: .black.opacity(border || Self.isInstant(asset) ? 0.55 : 0), radius: 6, y: 5)
        .onAppear { library.thumbnail(asset, side: max(320, width * 2)) { img = $0 } }
    }
}

// MARK: an opened pile

private struct PileSpread: View {
    enum Action { case done, unclip, deleteRest }
    let pile: Pile
    let library: Library
    var onOpen: (PHAsset) -> Void
    var onAction: (Action) -> Void
    var onTop: (PHAsset) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
                .onTapGesture { onAction(.done) }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(pile.assets.count) SHOTS · \(spanText)").font(XA.display(18))
                    Spacer()
                }
                Text("Tap the one that goes on top, or swipe the pile on the roll. Double-tap to look closer.").font(.system(size: 12)).foregroundStyle(XA.dim)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(pile.assets, id: \.localIdentifier) { a in
                            let on = a.localIdentifier == pile.top.localIdentifier
                            VStack(spacing: 12) {
                                PrintView(asset: a, width: 170, library: library, tilt: PileView.tilt(a.localIdentifier))
                                    .overlay(Rectangle().strokeBorder(on ? XA.orange : .clear, lineWidth: 3).padding(-6))
                                Text("ON TOP").font(XA.display(11)).foregroundStyle(Color(red: 0.16, green: 0.08, blue: 0))
                                    .padding(.horizontal, 8).padding(.vertical, 3).background(XA.orange)
                                    .opacity(on ? 1 : 0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onOpen(a) }
                            .onTapGesture { withAnimation(.snappy) { onTop(a) }; UISelectionFeedbackGenerator().selectionChanged() }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 14)
                }
                HStack(spacing: 8) {
                    button("DONE", primary: true) { onAction(.done) }
                    button("UNCLIP ALL") { onAction(.unclip) }
                    button("DELETE REST") { onAction(.deleteRest) }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var spanText: String {
        let ds = pile.assets.compactMap(\.creationDate)
        guard let a = ds.min(), let b = ds.max() else { return "" }
        let s = Int(b.timeIntervalSince(a).rounded())
        return s < 1 ? "SAME SECOND" : "\(s) S APART"
    }

    private func button(_ t: String, primary: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(t).font(XA.display(12)).padding(.horizontal, 12).padding(.vertical, 9)
                .foregroundStyle(primary ? Color(red: 0.16, green: 0.08, blue: 0) : .white)
                .background(primary ? XA.orange : XA.fill)
        }
        .buttonStyle(.plain)
    }
}
