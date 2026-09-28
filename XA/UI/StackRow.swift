import SwiftUI

/// SIM + LOOK + SHAPE, each tappable, empty slots dashed.
struct StackRow: View {
    let stack: Stack
    var onTap: () -> Void
    /// Which slot was tapped: 0 sim, 1 look, 2 shape.
    var onSlot: ((Int) -> Void)? = nil
    var body: some View {
        let sim = FilmCatalog.sim(stack.simID)
        let shapeTaken = sim?.frame != nil && sim?.frame != SimFrame.none
        HStack(spacing: 6) {
            slot(sim?.title, empty: "+ SIM", 0)
            plus
            slot(stack.look == .none ? nil : stack.look.title, empty: "+ LOOK", 1)
            plus
            slot(shapeTaken ? "PRINT" : (stack.shape == .none ? nil : stack.shape.title), empty: "+ SHAPE", 2)
        }
        .frame(maxWidth: .infinity)
    }
    private var plus: some View { Text("+").font(.system(size: 13)).foregroundStyle(XA.faint) }
    private func slot(_ name: String?, empty: String, _ index: Int) -> some View {
        Button { if let onSlot { onSlot(index) } else { onTap() } } label: {
            Text(name ?? empty).font(XA.display(12)).lineLimit(1)
                .foregroundStyle(name == nil ? XA.faint : XA.orange)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(name == nil ? Color.clear : XA.fill)
                .overlay(Rectangle().strokeBorder(name == nil ? Color.white.opacity(0.25) : XA.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: name == nil ? [3, 3] : [])))
        }
        .buttonStyle(.plain)
    }
}

