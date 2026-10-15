import XCTest
import CoreImage
@testable import XA

/// FILM's grain against spektrafilm's model (model/grain.py, baked by tools/filmsim/grain_bake.py):
/// as strong as spektrafilm's where a phone screen's pixel sees it, each dye layer its own, and
/// never repeating (CIRandomGenerator's did, every 256 px).
final class FilmGrainTests: XCTestCase {
    private let lin = CGColorSpace(name: CGColorSpace.linearSRGB)!

    private struct Field {
        let w: Int, h: Int
        let um: CGFloat
        /// density of the negative before the grain, and the grain itself (density), per channel
        let density: [Float]
        let grain: [[Float]]
        func at(_ c: Int, _ x: Int, _ y: Int) -> Float { grain[c][y * w + x] }
    }

    /// A grey frame `w` wide (35 mm across it) through the lab, the negative read just before and
    /// just after the grain.
    private func field(_ stock: FilmStock, w: Int, h: Int, seed: Int = 7) throws -> Field {
        let grey = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1, colorSpace: lin)!)
            .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        var r = FilmRecipe()
        r.format = .mm35
        r.lens = 0; r.flash = 0; r.leak = 0; r.mist = 0; r.halation = 0; r.glare = 0; r.labAuto = 0
        let ctx = CIContext(options: [.workingColorSpace: lin, .cacheIntermediates: false])
        var stages: [String: [Float]] = [:]
        FilmLab.trace = { name, img in
            guard name == "developed" || name == "grained" else { return }
            var px = [Float](repeating: 0, count: w * h * 4)
            px.withUnsafeMutableBytes { raw in
                ctx.render(img, toBitmap: raw.baseAddress!, rowBytes: w * 16, bounds: CGRect(x: 0, y: 0, width: w, height: h),
                           format: .RGBAf, colorSpace: nil)
            }
            stages[name] = px
        }
        defer { FilmLab.trace = nil }
        _ = FilmLab.develop(grey, stock: stock, push: 0, preview: false, seed: seed, shot: FilmShot(recipe: r, seed: seed))
        let before = try XCTUnwrap(stages["developed"]), after = try XCTUnwrap(stages["grained"])
        let t = try XCTUnwrap(FilmLab.tables(stock.id))
        let span = [t.dmax.x - t.dmin.x, t.dmax.y - t.dmin.y, t.dmax.z - t.dmin.z].map { Float($0) }
        let lo = [t.dmin.x, t.dmin.y, t.dmin.z].map { Float($0) }
        var g = [[Float]](repeating: [Float](repeating: 0, count: w * h), count: 3)
        var d = [Float](repeating: 0, count: 3)
        for i in 0..<(w * h) {
            for c in 0..<3 {
                g[c][i] = (after[i * 4 + c] - before[i * 4 + c]) * span[c]
                d[c] += before[i * 4 + c] * span[c] + lo[c]
            }
        }
        return Field(w: w, h: h, um: 36000 / CGFloat(w), density: d.map { $0 / Float(w * h) }, grain: g)
    }

    private func std(_ v: [Float]) -> Double {
        let m = v.reduce(0, +) / Float(v.count)
        return (Double(v.reduce(0) { $0 + ($1 - m) * ($1 - m) }) / Double(v.count)).squareRoot()
    }

    /// The grain averaged over boxes `a` pixels wide (a screen pixel seeing several of the scan's).
    private func boxStd(_ f: Field, _ c: Int, _ a: Int) -> Double {
        var means: [Float] = []
        for by in stride(from: 0, to: f.h - a + 1, by: a) {
            for bx in stride(from: 0, to: f.w - a + 1, by: a) {
                var s: Float = 0
                for y in by..<(by + a) { for x in bx..<(bx + a) { s += f.at(c, x, y) } }
                means.append(s / Float(a * a))
            }
        }
        return std(means)
    }

    private func correlation(_ a: [Float], _ b: [Float]) -> Double {
        let n = Float(a.count)
        let ma = a.reduce(0, +) / n, mb = b.reduce(0, +) / n
        var ab: Float = 0, aa: Float = 0, bb: Float = 0
        for i in 0..<a.count { let x = a[i] - ma, y = b[i] - mb; ab += x * y; aa += x * x; bb += y * y }
        return Double(ab / max((aa * bb).squareRoot(), 1e-12))
    }

    /// spektrafilm's grain at a box `a` pixels wide: each sublayer's granularity at this density
    /// over the pixel (Selwyn), through spektrafilm's own blur.
    private func spektrafilm(_ stock: FilmStock, _ f: Field, _ c: Int, _ a: Int) throws -> Double {
        let url = try XCTUnwrap(FilmLab.bundle.url(forResource: "grain", withExtension: "json"))
        let all = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: Any]])
        let m = try XCTUnwrap(all[stock.id])
        let top = try XCTUnwrap(m["dmax"] as? Double)
        let sd = try XCTUnwrap(m["sd"] as? [[[Double]]]), clouds = try XCTUnwrap(m["cloud_um"] as? [[Double]])
        let g = try XCTUnwrap(FilmLab.grain(stock))
        var v = 0.0
        for l in 0..<3 {
            let row = sd[l][c], n = row.count
            let t = max(0, min(1, Double(f.density[c]) / top)) * Double(n - 1)
            let i = min(n - 2, Int(t)), k = t - Double(i)
            let s = (row[i] * (1 - k) + row[i + 1] * k) / Double(f.um) * Double(g.scale)
            let cloud = clouds[l][c] / Double(f.um)
            let sigma = CGFloat((1.0 / 12 + 0.65 * 0.65 + cloud * cloud).squareRoot())
            let keep = Double(FilmLab.boxKeeps(CGFloat(a), sigma: sigma))
            v += s * s * keep * keep
        }
        return v.squareRoot()
    }

    func testGrainMatchesSpektrafilmOnAScreenAndIsEachLayersOwn() throws {
        let stock = try XCTUnwrap(FilmStock.stock("bowery400"))
        var report: [String] = []
        // a drum scan (4.5 µm a pixel) and a lab scan (11.7 µm)
        for (w, h) in [(8000, 128), (3088, 128)] {
            let f = try field(stock, w: w, h: h)
            let a = max(1, Int((FilmLab.Fit.grainViewUM / f.um).rounded()))
            for c in 0..<3 {
                let ours = boxStd(f, c, a), theirs = try spektrafilm(stock, f, c, a)
                report.append(String(format: "%.1f um, channel %d: %.4f at a screen pixel (spektrafilm %.4f), %.4f a pixel",
                                     f.um, c, ours, theirs, std(f.grain[c])))
                XCTAssertEqual(ours / theirs, 1, accuracy: 0.2, "\(f.um) µm, channel \(c): as strong as spektrafilm's on a screen")
            }
            // every dye layer has its own grain
            XCTAssertLessThan(abs(correlation(f.grain[0], f.grain[1])), 0.1, "\(f.um) µm: red and green grain independent")
            XCTAssertLessThan(abs(correlation(f.grain[0], f.grain[2])), 0.1, "\(f.um) µm: red and blue grain independent")
            // and it never repeats
            var a0: [Float] = [], a1: [Float] = []
            for y in 0..<f.h { for x in 0..<(f.w - 256) { a0.append(f.at(1, x, y)); a1.append(f.at(1, x + 256, y)) } }
            XCTAssertLessThan(abs(correlation(a0, a1)), 0.05, "\(f.um) µm: no repeat at 256 px")
        }
        print("GRAIN\n" + report.joined(separator: "\n"))
    }

    /// Not a check: what the grain costs a drum scan (XA_GRAIN_SPEED; TEST_RUNNER_XA_GRAIN_SPEED from the command line).
    func testGrainSpeed() throws {
        guard ProcessInfo.processInfo.environment["XA_GRAIN_SPEED"] != nil else { throw XCTSkip("set XA_GRAIN_SPEED") }
        let stock = try XCTUnwrap(FilmStock.stock("bowery400"))
        // a 12 MP camera frame, drum scanned (8000 px on the long side), the way the camera develops it
        let src = CIImage(color: CIColor(red: 0.18, green: 0.12, blue: 0.1, alpha: 1, colorSpace: lin)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 4032, height: 3024))
        _ = stock
        var lines: [String] = []
        for grain in [0.0, 1.0, 0.0, 1.0] {
            var d = DevelopSettings()
            d.film = true
            d.stack = Stack(simID: "bowery400")
            d.filmRecipe.scan = .drum
            d.filmRecipe.leak = 0
            d.filmRecipe.grain = grain
            d.date.placement = .off
            let t0 = CACurrentMediaTime()
            let img = Darkroom.develop(src, d, date: Date(timeIntervalSince1970: 1_700_000_000), preview: false).0
            let cg = try XCTUnwrap(Encoder.render(img, reference: nil))
            lines.append(String(format: "grain %.0f: %.2f s (%d x %d)", grain, CACurrentMediaTime() - t0, cg.width, cg.height))
        }
        print("GRAIN SPEED\n" + lines.joined(separator: "\n"))
    }

    func testEveryStockHasGrain() {
        for st in FilmStock.all {
            let g = FilmLab.grain(st)
            XCTAssertNotNil(g, st.id)
            XCTAssertGreaterThan(g?.scale ?? 0, 0.5, st.id)
            XCTAssertLessThan(g?.scale ?? 9, 2, st.id)
        }
    }
}
