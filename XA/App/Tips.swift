import StoreKit
import SwiftUI

/// The tip jar: optional tips through the App Store. They unlock nothing: every part of XA is
/// there for everyone. Consumable in-app purchases, made in App Store Connect with these ids.
@MainActor
final class TipJar: ObservableObject {
    static let shared = TipJar()
    static let ids = ["com.gios.xa.tip.small", "com.gios.xa.tip.medium", "com.gios.xa.tip.large"]

    @Published private(set) var products: [Product] = []
    /// The tip being paid for, while the App Store sheet is up.
    @Published private(set) var buying: String?
    @Published var thanked = false
    @Published var failed = false
    @Published private(set) var tips = UserDefaults.standard.integer(forKey: "tips")
    private var updates: Task<Void, Never>?

    private init() {
        // A tip that finishes away from the button (Ask to Buy approved later, a payment that
        // needed an extra step) arrives here and is finished, so the App Store stops offering it.
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates { await self?.finish(result) }
        }
    }

    func load() async {
        guard products.isEmpty else { return }
        // No products (not set up in App Store Connect, no network): the jar stays hidden.
        products = ((try? await Product.products(for: Self.ids)) ?? []).sorted { $0.price < $1.price }
    }

    func buy(_ p: Product) async {
        buying = p.id
        defer { buying = nil }
        do {
            if case .success(let result) = try await p.purchase() { await finish(result) }
            // .pending (Ask to Buy) finishes through `updates`; .userCancelled is nothing
        } catch {
            failed = true
        }
    }

    private func finish(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result else { return }
        if Self.ids.contains(t.productID), t.revocationDate == nil {
            tips += 1
            UserDefaults.standard.set(tips, forKey: "tips")
            thanked = true
        }
        await t.finish()
    }
}

/// Customize's last group. Shown only once the App Store has the tips to offer.
struct TipJarView: View {
    @ObservedObject private var jar = TipJar.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !jar.products.isEmpty {
                SectionLabel(text: "SUPPORT XA")
                tips.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(XA.fill)
            }
        }
        .padding(.top, jar.products.isEmpty ? 0 : 6)
        .task { await jar.load() }
        .alert("Thank you!", isPresented: $jar.thanked) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your tip means a lot. XA stays free for everyone.")
        }
        .alert("The tip didn't go through", isPresented: $jar.failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The App Store couldn't complete it. You can try again later.")
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(jar.tips > 0
                 ? "Thank you for supporting XA. Every tip goes into making it better."
                 : "XA is free, with every feature, no ads and no subscription. If you love it, a tip helps keep it going. Tips don't unlock anything.")
                .font(.system(size: 13)).foregroundStyle(XA.dim)
            HStack(spacing: 8) {
                ForEach(jar.products, id: \.id) { p in
                    Button { Task { await jar.buy(p) } } label: {
                        VStack(spacing: 3) {
                            Text(p.displayName).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            if jar.buying == p.id { ProgressView().tint(.black) } else { Text(p.displayPrice).font(XA.mono(13)) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(.black).background(XA.orange)
                    }
                    .buttonStyle(.plain)
                    .disabled(jar.buying != nil)
                    .accessibilityLabel("Tip \(p.displayPrice): \(p.displayName)")
                }
            }
        }
    }
}

/// Asks for an App Store rating at most once a version and only once XA has been used for a
/// while: 20 pictures saved over three different days. Asked as the roll is closed, never
/// while shooting. iOS itself shows it at most three times a year.
enum ReviewPrompt {
    private static let d = UserDefaults.standard

    /// A picture went into Photos.
    static func noteShot() {
        d.set(d.integer(forKey: "review.shots") + 1, forKey: "review.shots")
        let day = String(Int(Date().timeIntervalSince1970 / 86_400))
        var days = d.stringArray(forKey: "review.days") ?? []
        if !days.contains(day) { days.append(day); d.set(Array(days.suffix(10)), forKey: "review.days") }
    }

    static var due: Bool {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard d.string(forKey: "review.version") != version else { return false }
        return d.integer(forKey: "review.shots") >= 20 && (d.stringArray(forKey: "review.days")?.count ?? 0) >= 3
    }

    static func asked() {
        d.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "", forKey: "review.version")
    }
}
