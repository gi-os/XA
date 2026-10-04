import SwiftUI

/// Every film in a grid, and the stack being built. Sims pick one; looks and shapes one or none.
struct FilmPicker: View {
    @ObservedObject var camera: CameraModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Sim?
    @State private var tick = 0

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    stackBar
                    let all = FilmCatalog.sims(for: camera.mode)
                    let favs = camera.favorites.compactMap { id in all.first { $0.id == id } }
                    if !favs.isEmpty {
                        SectionLabel(text: "FAVORITES").padding(.top, 6)
                        LazyVGrid(columns: cols, spacing: 12) { ForEach(favs) { s in simCard(s) } }
                    }
                    SectionLabel(text: camera.mode == .film ? "COLOR STOCKS · PICK ONE" : "SIMS · PICK ONE").padding(.top, 6)
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(all.filter { camera.mode != .film || !$0.mono }) { s in simCard(s) }
                        if camera.mode != .film {
                        Button { editing = newSim() } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Rectangle().strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    .frame(width: 80, height: 53)
                                    .overlay(Image(systemName: "plus").font(.system(size: 20, weight: .semibold)).foregroundStyle(XA.orange))
                                Text("NEW SIM").font(XA.display(11, bold: false))
                            }
                        }
                        .buttonStyle(.plain)
                        }
                    }
                    if camera.mode == .film {
                        SectionLabel(text: "BLACK & WHITE").padding(.top, 8)
                        LazyVGrid(columns: cols, spacing: 12) { ForEach(all.filter { $0.mono }) { s in simCard(s) } }
                    }
                    if camera.mode != .film {
                    SectionLabel(text: "LOOKS · PICK ONE OR NONE").padding(.top, 8)
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(Look.allCases) { l in
                            card(.look(l), on: camera.stack.look == l) { camera.stack.look = l }
                        }
                    }
                    SectionLabel(text: "SHAPES · PICK ONE OR NONE").padding(.top, 8)
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(FilmCatalog.shapes) { s in
                            card(.shape(s), on: camera.stack.shape == s) { camera.stack.shape = camera.stack.shape == s ? .none : s }
                        }
                    }
                    Text("Long-press a sim to edit it. Instant sims print their own frame, so they replace the shape.")
                        .font(.system(size: 12)).foregroundStyle(XA.faint).padding(.top, 8)
                    } else {
                    Text("FILM shoots only the stocks, at full size. Swipe a stock's box up to push it a stop, down to pull. Long-press a box to star it: the corner box then swipes through your favorites.")
                        .font(.system(size: 12)).foregroundStyle(XA.faint).padding(.top, 8)
                    }
                }
                .padding(16)
                .id(tick)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(item: $editing, onDismiss: { tick += 1; camera.rebuildControls() }) { s in
            SimEditor(camera: camera, sim: s)
        }
    }

    private var header: some View {
        HStack {
            Button("Done") { dismiss() }.font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 11).background(XA.fill, in: Capsule())
            Spacer()
            Text("FILM").font(XA.display(24))
            Spacer()
            Button("Edit") { if let s = FilmCatalog.sim(camera.stack.simID) { editing = s } }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 11).background(XA.fill, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
    }

    private var stackBar: some View {
        HStack(spacing: 8) {
            StackRow(stack: camera.stack, onTap: {})
            Button("Save") { saveStack() }.font(XA.display(13)).foregroundStyle(XA.orange).buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 10).background(XA.fill)
    }

    private func simCard(_ s: Sim) -> some View {
        card(.sim(s), on: FilmCatalog.sim(camera.stack.simID)?.id == s.id) { camera.stack.simID = s.id; applySaved(s) }
            .overlay(alignment: .topLeading) { if camera.isFavorite(s.id) { FavoriteStar().offset(x: 68, y: -7) } }
            .contextMenu {
                Button(camera.isFavorite(s.id) ? "Unstar" : "Star", systemImage: camera.isFavorite(s.id) ? "star.slash" : "star") {
                    camera.toggleFavorite(s.id)
                }
                Button("Edit") { editing = s }
                if !s.isPreset { Button("Delete", role: .destructive) { delete(s) } }
            }
    }

    private func card(_ item: FilmItem, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                FilmBox(item: item, width: 80)
                    .overlay(Rectangle().strokeBorder(on ? XA.orange : .clear, lineWidth: 2).padding(-3))
                Text(item.title).font(XA.display(11, bold: false)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
    }

    private func applySaved(_ s: Sim) {
        if let l = s.look, let look = Look(rawValue: l) { camera.stack.look = look }
        if let sh = s.shape, let shape = FrameShape(rawValue: sh) { camera.stack.shape = shape }
    }

    private func newSim() -> Sim {
        var s = FilmCatalog.sim(camera.stack.simID) ?? Sim.neutral
        s.id = "custom-\(Int(Date().timeIntervalSince1970))"
        s.name = "My film"
        s.iso = "400"
        s.look = nil; s.shape = nil
        return s
    }

    /// The stack becomes a sim of its own, look and shape included.
    private func saveStack() {
        var s = newSim()
        s.name = "Stack \(FilmCatalog.custom.count + 1)"
        s.look = camera.stack.look.rawValue
        s.shape = camera.stack.shape.rawValue
        FilmCatalog.setCustom(FilmCatalog.custom + [s])
        camera.stack.simID = s.id
        tick += 1
        camera.rebuildControls()
    }

    private func delete(_ s: Sim) {
        FilmCatalog.setCustom(FilmCatalog.custom.filter { $0.id != s.id })
        if camera.stack.simID == s.id { camera.stack.simID = Sim.neutral.id }
        tick += 1
        camera.rebuildControls()
    }
}
