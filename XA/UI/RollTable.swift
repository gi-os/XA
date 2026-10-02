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
    /// A print laid out of a fanned pile: the pile's id, its place in the fan and the fan's size.
    var fanOf: String? = nil
    var fanIndex = 0
    var fanCount = 0
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
    /// How far past the top this drag has pulled. Kept for the whole drag, because by the time
    /// the finger lifts the scroll view may already be springing back.
    @State private var pullPeak: CGFloat = 0
    @State private var dragging = false
    private static let pullToClose: CGFloat = 60
    @AppStorage("rollColumns") private var columns = 2
    @State private var pinchStart: Int?
    @State private var showCols = false
    @State private var version = 0
    /// Piles laid out flat on the table: tap a pile and its prints fan into the columns.
    @State private var fanned: Set<String> = []

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(library.days, id: \.title) { day in
                        Tape(text: Self.tapeText(day.assets.first?.creationDate))
                        Masonry(piles: piles(day.assets), columns: columns, library: library, onTap: { pile in
                            if pile.fanOf == nil && pile.assets.count > 1 {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { _ = fanned.insert(pile.id) }
                            } else { onOpen(pile.top) }
                        }, onAction: { pile, action in
                            switch action {
                            case .restack:
                                if let k = pile.fanOf { withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { _ = fanned.remove(k) } }
                            case .onTop:
                                if let k = pile.fanOf {
                                    RollPiles.setTop(pile.top.localIdentifier, for: k)
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { _ = fanned.remove(k); version += 1 }
                                }
                            case .unclip:
                                RollPiles.unclip(pile.fanOf ?? pile.id); fanned.remove(pile.fanOf ?? pile.id)
                                withAnimation(.snappy) { version += 1 }
                            case .deleteRest:
                                library.delete(pile.others); withAnimation(.snappy) { version += 1 }
                            }
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
            .onScrollGeometryChange(for: CGFloat.self, of: { -($0.contentOffset.y + $0.contentInsets.top) }) { _, v in
                overscroll = max(0, v)
                if dragging {
                    if overscroll > Self.pullToClose && pullPeak <= Self.pullToClose { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    pullPeak = max(pullPeak, overscroll)
                }
            }
            .onScrollPhaseChange { old, new in
                if new == .interacting { dragging = true; pullPeak = 0 }
                if old == .interacting && new != .interacting {
                    dragging = false
                    // Pulled down past the top and let go: back to the camera.
                    if max(pullPeak, overscroll) > Self.pullToClose { onPullClose?() }
                    pullPeak = 0
                }
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
            if overscroll > 8 {
                VStack(spacing: 4) {
                    Image(systemName: overscroll > Self.pullToClose ? "camera.fill" : "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                    Text(overscroll > Self.pullToClose ? "Let go for the camera" : "Pull for the camera").font(XA.display(11))
                }
                .foregroundStyle(.white.opacity(min(1, overscroll / Self.pullToClose)))
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, 6)
                .allowsHitTesting(false)
            }
            if showCols { ColumnPill(columns: columns).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 28).transition(.opacity) }
        }
    }

    private func piles(_ assets: [PHAsset]) -> [Pile] {
        let items = assets.map { RollPiles.Item(id: $0.localIdentifier, date: $0.creationDate ?? .distantPast, width: $0.pixelWidth, height: $0.pixelHeight, isVideo: $0.mediaType == .video) }
        var out: [Pile] = []
        for g in RollPiles.group(items, unclipped: RollPiles.unclipped) {
            let pile = Pile(assets: g.map { assets[$0] })
            if pile.assets.count > 1 && fanned.contains(pile.id) {
                // Fanned: the one on top first, then the rest in the order they were taken.
                let order = [pile.top] + pile.others
                out += order.enumerated().map { i, a in Pile(assets: [a], fanOf: pile.id, fanIndex: i, fanCount: order.count) }
            } else {
                out.append(pile)
            }
        }
        return out
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
        // Caveat's last letter swings past its own width: the tape runs a little longer on the right.
        Text(text).font(.custom("Caveat-Bold", fixedSize: 19)).foregroundStyle(Color(hex: "#2A1A06"))
            .fixedSize()
            .padding(.leading, 16).padding(.trailing, 22).padding(.vertical, 3)
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
    var onAction: (Pile, PileAction) -> Void = { _, _ in }
    var onStep: (Pile, Int) -> Void = { _, _ in }
    @Namespace private var table

    var body: some View {
        GeometryReader { g in
            let gap: CGFloat = columns == 2 ? 16 : (columns == 3 ? 12 : 9)
            let cw = (g.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let cols = layout(width: cw, gap: gap)
            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<columns, id: \.self) { c in
                    VStack(spacing: gap + 8) {
                        ForEach(cols.items[c], id: \.id) { p in
                            PileView(pile: p, width: cw, library: library, onStep: onStep, onRestack: { onAction(p, .restack) })
                                // Every print is the same print wherever it lies: fanning a pile
                                // slides its prints out of it into their places, and restacking
                                // slides them back in, across columns.
                                .matchedGeometryEffect(id: p.id, in: table)
                                .background {
                                    if p.fanOf == nil && p.assets.count > 1 {
                                        ZStack {
                                            ForEach(p.assets.dropFirst(), id: \.localIdentifier) { a in
                                                Color.clear.matchedGeometryEffect(id: a.localIdentifier, in: table)
                                            }
                                        }
                                    }
                                }
                                .onTapGesture { onTap(p) }
                                .contextMenu { menu(p) }
                                .transition(.asymmetric(insertion: .identity, removal: .opacity.animation(.easeIn(duration: 0.12).delay(0.25))))
                        }
                    }
                    .frame(width: cw)
                }
            }
        }
        .frame(height: layout(width: approxWidth, gap: 12).height)
    }

    @ViewBuilder private func menu(_ p: Pile) -> some View {
        if p.fanOf != nil {
            Button { onAction(p, .onTop) } label: { Label("Put this one on top", systemImage: "square.stack") }
            Button { onAction(p, .restack) } label: { Label("Stack them again", systemImage: "rectangle.stack") }
        } else if p.assets.count > 1 {
            Button { onAction(p, .unclip) } label: { Label("Unclip for good", systemImage: "paperclip") }
            Button(role: .destructive) { onAction(p, .deleteRest) } label: { Label("Delete all but the top one", systemImage: "trash") }
        }
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
            h[c] += PrintView.height(for: p.top, width: cw) + gap + 8 + (p.assets.count > 1 || p.fanOf != nil ? 8 : 0)
        }
        return (items, (h.max() ?? 0) + 12)
    }
}

enum PileAction { case restack, onTop, unclip, deleteRest }

/// A pile: the chosen print on top, up to two more peeking out, a clip and a count.
private struct PileView: View {
    let pile: Pile
    let width: CGFloat
    let library: Library
    var onStep: (Pile, Int) -> Void = { _, _ in }
    var onRestack: () -> Void = {}
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
            if pile.fanOf != nil {
                // A fanned pile's prints keep a strip of the same yellow tape, numbered, so they
                // still read as one group; the first carries the button that stacks them again.
                HStack(spacing: 4) {
                    Text("\(pile.fanIndex + 1)/\(pile.fanCount)").font(.custom("Caveat-Bold", fixedSize: 14 * scale))
                    if pile.fanIndex == 0 {
                        Button(action: onRestack) {
                            Image(systemName: "rectangle.stack").font(.system(size: 11 * scale, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stack them again")
                    }
                }
                .foregroundStyle(Color(hex: "#2A1A06"))
                .padding(.horizontal, 6 * scale).padding(.vertical, 1)
                .background(Color(hex: "#F2D35B")).rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1.5)
                .frame(maxWidth: .infinity, alignment: .leading).offset(x: -4, y: -6)
            }
        }
        .padding(.top, pile.assets.count > 1 || pile.fanOf != nil ? 8 : 0)
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
