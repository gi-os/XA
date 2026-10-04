import SwiftUI
import UIKit

/// XA's look: black, flat dark fills, square corners, one orange.
enum XA {
    static let orange = Color(red: 1, green: 0.541, blue: 0.169)
    static let orangeUI = UIColor(red: 1, green: 0.541, blue: 0.169, alpha: 1)
    static let fill = Color(red: 0.11, green: 0.11, blue: 0.118)
    static let fill2 = Color(red: 0.165, green: 0.165, blue: 0.173)
    static let strip = Color(red: 0.082, green: 0.082, blue: 0.09)
    static let dim = Color.white.opacity(0.62)
    static let faint = Color.white.opacity(0.45)

    /// Chakra Petch, the display face. Fixed size: camera chrome should not reflow.
    static func display(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "ChakraPetch-Bold" : "ChakraPetch-SemiBold", fixedSize: size)
    }
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
    static func font(_ ps: String, _ size: CGFloat) -> Font { .custom(ps, fixedSize: size) }

    static func uiFont(_ ps: String, _ size: CGFloat) -> UIFont {
        UIFont(name: ps, size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }
}

/// A flat dark circle button, 44 pt.
struct RoundButton<Label: View>: View {
    var size: CGFloat = 44
    var action: () -> Void
    @ViewBuilder var label: () -> Label
    var body: some View {
        Button(action: action) {
            label().frame(width: size, height: size).background(XA.fill, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

/// Section label used across the sheets.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold)).tracking(1)
            .foregroundStyle(XA.faint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A square segmented control.
struct Segmented<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 3) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let on = item.0 == selection
                Button { selection = item.0 } label: {
                    Text(item.1).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .foregroundStyle(on ? Color.black : Color.white.opacity(0.75))
                        .background(on ? Color.white : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3).background(XA.fill)
    }
}

/// A flat slider row: label, value, orange track.
struct FlatSlider: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var format: (Double) -> String = { String(format: "%.2f", $0) }
    /// What the setting does, shown under the slider.
    var note: String? = nil
    /// Its default: shown with the note; double-tap the name to go back to it.
    var standard: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 14))
                    .onTapGesture(count: 2) { if let standard { value = standard } }
                Spacer()
                Text(format(value)).font(XA.mono(13)).foregroundStyle(XA.orange)
            }
            Slider(value: $value, in: range).tint(XA.orange)
            if note != nil || standard != nil {
                let d = standard.map { "Default \(format($0))." } ?? ""
                Text([note, d].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
                    .font(.system(size: 12)).foregroundStyle(XA.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
