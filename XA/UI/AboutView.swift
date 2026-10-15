import SwiftUI

/// Customize's last group: the privacy policy, support, the source code and the licenses of
/// what XA ships with. Shown always (App Review looks for the policy and a contact in the app).
struct AboutGroup: View {
    static let privacy = URL(string: "https://gi-os.github.io/XA/privacy.html")!
    static let support = URL(string: "https://gi-os.github.io/XA/")!
    static let source = URL(string: "https://github.com/gi-os/XA")!
    static let email = "gio@gi-os.com"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "ABOUT")
            VStack(alignment: .leading, spacing: 0) {
                link("Privacy policy", "Nothing collected", Self.privacy)
                link("Help and support", "gi-os.github.io/XA", Self.support)
                link("Contact", Self.email, URL(string: "mailto:\(Self.email)")!)
                link("Source code", "GPLv3", Self.source)
                NavigationLink { LicensesView() } label: {
                    row("Licenses", "spektrafilm, fonts")
                }
                .accessibilityHint("Shows the licenses of the film tables and fonts XA uses")
                Text(Self.version)
                    .font(.system(size: 12)).foregroundStyle(XA.faint)
                    .padding(.top, 8)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(XA.fill)
        }
    }

    /// "XA 1.0 (75)".
    static var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "XA \(v) (\(b))"
    }

    private func link(_ label: String, _ value: String, _ url: URL) -> some View {
        Link(destination: url) { row(label, value, icon: "arrow.up.right") }
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }

    private func row(_ label: String, _ value: String, icon: String = "chevron.right") -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(.white)
            Spacer()
            Text(value).font(.system(size: 15)).foregroundStyle(XA.dim).lineLimit(1)
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(XA.faint)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

/// The licenses of what XA ships with: its own, spektrafilm's tables, and every font's, read
/// from the license files in the app.
struct LicensesView: View {
    private struct Doc: Identifiable { let id: String; let url: URL }

    private var docs: [Doc] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? []
        return urls
            .filter { let n = $0.lastPathComponent.lowercased(); return n.contains("ofl") || n.contains("license") || n.contains("apache") }
            .map { Doc(id: Self.title($0), url: $0) }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section("XA", "XA is free software under the GNU General Public License, version 3, with an additional permission for distribution through the App Store (EXCEPTION.md). The source code is at github.com/gi-os/XA.")
                section("FILM TABLES", "The color film stocks are developed through tables generated with spektrafilm by Andrea Volpato (github.com/andreavolpato/spektrafilm), modified by baking them into color tables for XA. They are licensed under CC BY-SA 4.0 (creativecommons.org/licenses/by-sa/4.0), and XA's tables are shared under the same licence.")
                section("FONTS", "The film-box fonts are used under the SIL Open Font License 1.1 or the Apache License 2.0. Their licenses:")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(docs) { d in
                        NavigationLink { LicenseText(title: d.id, url: d.url) } label: {
                            HStack {
                                Text(d.id).font(.system(size: 15)).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(XA.faint)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(XA.fill)
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            Text(text).font(.system(size: 13)).foregroundStyle(XA.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "anton-OFL.txt" → "Anton (OFL)"; "yellowtail-Apache-2.0.txt" → "Yellowtail (Apache 2.0)".
    private static func title(_ url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        let parts = stem.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
        let name = parts.first.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() } ?? stem
        let up = stem.uppercased()
        let kind = up.contains("OFL") ? " (OFL)" : up.contains("APACHE") ? " (Apache 2.0)" : ""
        return name + kind
    }
}

private struct LicenseText: View {
    let title: String
    let url: URL

    var body: some View {
        ScrollView {
            Text((try? String(contentsOf: url, encoding: .utf8)) ?? "")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(XA.dim)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
