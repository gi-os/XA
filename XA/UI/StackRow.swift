import SwiftUI

/// SIM + LOOK + SHAPE, each tappable, empty slots dashed.
struct StackRow: View {
    let stack: Stack
    var onTap: () -> Void
    var body: some View {
        let sim = FilmCatalog.sim(stack.simID)
        let shapeTaken = sim?.frame != nil && sim?.frame != SimFrame.none
        HStack(spacing: 6) {
            slot(sim?.title, empty: "+ SIM")
            plus
            slot(stack.look == .none ? nil : stack.look.title, empty: "+ LOOK")
            plus
            slot(shapeTaken ? "PRINT" : (stack.shape == .none ? nil : stack.shape.title), empty: "+ SHAPE")
        }
        .frame(maxWidth: .infinity)
    }
    private var plus: some View { Text("+").font(.system(size: 13)).foregroundStyle(XA.faint) }
    private func slot(_ name: String?, empty: String) -> some View {
        Button(action: onTap) {
            Text(name ?? empty).font(XA.display(12)).lineLimit(1)
                .foregroundStyle(name == nil ? XA.faint : XA.orange)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(name == nil ? Color.clear : XA.fill)
                .overlay(Rectangle().strokeBorder(name == nil ? Color.white.opacity(0.25) : XA.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: name == nil ? [3, 3] : [])))
        }
        .buttonStyle(.plain)
    }
}

