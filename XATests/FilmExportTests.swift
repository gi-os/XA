import XCTest
import CoreImage
import UniformTypeIdentifiers
@testable import XA

/// Not a check: exports FILM develops of a picture to look at and to compare with spektrafilm
/// (tools/filmsim/compare.py). Skipped unless XA_FILM_IN is set; from the command line pass it
/// to the simulator as TEST_RUNNER_XA_FILM_IN (also XA_FILM_OUT, XA_FILM_STOCKS, XA_FILM_SCANS).
final class FilmExportTests: XCTestCase {
    func testExportFilmDevelops() throws {
        let env = ProcessInfo.processInfo.environment
        guard let input = env["XA_FILM_IN"] else { throw XCTSkip("set XA_FILM_IN to export FILM develops") }
        let out = URL(fileURLWithPath: env["XA_FILM_OUT"] ?? NSTemporaryDirectory(), isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let stocks = (env["XA_FILM_STOCKS"] ?? "bowery400").split(separator: ",").map(String.init)
        let scans = (env["XA_FILM_SCANS"] ?? "drum").split(separator: ",").compactMap { FilmScan(rawValue: String($0)) }
        let src = try XCTUnwrap(CIImage(contentsOf: URL(fileURLWithPath: input), options: [.applyOrientationProperty: true]))
        let name = URL(fileURLWithPath: input).deletingPathExtension().lastPathComponent
        var report: [String] = []
        for id in stocks {
            for scan in scans {
                var d = DevelopSettings()
                d.film = true
                d.stack = Stack(simID: id)
                d.filmRecipe.scan = scan
                d.filmRecipe.leak = 0
                d.date.placement = .off
                let t0 = CACurrentMediaTime()
                let img = Darkroom.develop(src, d, date: Date(timeIntervalSince1970: 1_700_000_000), preview: false).0
                let cg = try XCTUnwrap(Encoder.render(img, reference: nil), "\(id) \(scan)")
                let t1 = CACurrentMediaTime()
                let heic = try XCTUnwrap(Encoder.encode(cg, type: .heic, quality: 0.95, properties: [:]))
                let t2 = CACurrentMediaTime()
                let stem = "\(name)-\(id)-\(scan.rawValue)"
                try heic.write(to: out.appendingPathComponent(stem + ".heic"))
                if let png = Encoder.encode(cg, type: .png, quality: 1, properties: [:]) {
                    try png.write(to: out.appendingPathComponent(stem + ".png"))
                }
                // the middle at 1:1 and enlarged 4×, to see the grain
                let side = min(512, cg.width, cg.height)
                if let crop = cg.cropping(to: CGRect(x: (cg.width - side) / 2, y: (cg.height - side) / 2, width: side, height: side)),
                   let png = Encoder.encode(crop, type: .png, quality: 1, properties: [:]) {
                    try png.write(to: out.appendingPathComponent(stem + "-crop.png"))
                }
                report.append(String(format: "%@ %@ %dx%d (%.1f MP) develop+render %.2f s, HEIC %.2f s, %.1f MB",
                                     id, scan.rawValue, cg.width, cg.height, Double(cg.width * cg.height) / 1e6,
                                     t1 - t0, t2 - t1, Double(heic.count) / 1e6))
            }
        }
        let text = report.joined(separator: "\n")
        try text.write(to: out.appendingPathComponent("\(name)-report.txt"), atomically: true, encoding: .utf8)
        print(text)
    }
}
