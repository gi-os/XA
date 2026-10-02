import XCTest
import CoreImage
@testable import XA

final class FilmLabTests: XCTestCase {
    func testSpeedsPushAndPull() {
        let s = FilmStock.stock("bowery400")!
        XCTAssertEqual(s.ei(0), 400)
        XCTAssertEqual(s.ei(1), 800)
        XCTAssertEqual(s.ei(2), 1600)
        XCTAssertEqual(s.ei(-1), 200)
        XCTAssertEqual(FilmStock.stock("canal500t")!.ei(1), 1000)
        XCTAssertEqual(FilmStock.stock("chelsea100")!.ei(-2), 25)
        XCTAssertEqual(FilmStock.stock("ludlow1600")!.ei(2), 6400)
    }

    func testDXChangesWithSpeed() {
        let a = FilmStock.dx(400), b = FilmStock.dx(800)
        XCTAssertEqual(a.count, 12)
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a[0] && a[6], "contacts are always silver")
    }

    func testPushIsClampedAndOldStacksLoad() throws {
        var st = Stack(simID: "bowery400")
        st.push = 5
        XCTAssertEqual(st.push, 2)
        st.push = 0
        XCTAssertNil(st.pushStops)
        let old = try JSONDecoder().decode(Stack.self, from: Data(#"{"simID":"nocturne","look":0,"shape":0}"#.utf8))
        XCTAssertEqual(old.push, 0)
    }

    func testEveryStockHasTablesAndDevelops() {
        // An 18% grey card in linear light (Core Image's working space), read back linear.
        let lin = CGColorSpace(name: CGColorSpace.linearSRGB)!
        let grey = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1, colorSpace: lin)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 96, height: 72))
        let ctx = CIContext(options: [.workingColorSpace: lin])
        FilmLab.trace = { name, img in
            var q = [Float](repeating: 0, count: 4)
            ctx.render(img.cropped(to: CGRect(x: 48, y: 36, width: 1, height: 1)), toBitmap: &q, rowBytes: 16,
                       bounds: CGRect(x: 48, y: 36, width: 1, height: 1), format: .RGBAf, colorSpace: lin)
            XCTAssertEqual(q[3], 1, accuracy: 0.001, "\(name): alpha stays 1")
        }
        defer { FilmLab.trace = nil }
        for st in FilmStock.all {
            XCTAssertNotNil(FilmLab.tables(st.id), st.id)
            for push in [-1, 0, 1] {
                let out = FilmLab.develop(grey, stock: st, push: push, preview: false, seed: 3)
                XCTAssertEqual(out.extent, grey.extent, st.id)
                var px = [Float](repeating: 0, count: 4)
                ctx.render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 48, y: 36, width: 1, height: 1), format: .RGBAf, colorSpace: lin)
                // An 18% grey card prints as 18% grey at any push: the lab prints a pushed roll back.
                XCTAssertEqual(px[1], 0.18, accuracy: 0.045, "\(st.id) push \(push) mid grey")
                for c in 0..<3 {
                    XCTAssertTrue(px[c].isFinite, "\(st.id) push \(push)")
                    XCTAssertGreaterThan(px[c], 0.0, "\(st.id) push \(push) not black")
                    XCTAssertLessThan(px[c], 1.0, "\(st.id) push \(push) not white")
                }
            }
        }
    }

    /// The film table on its own: a flat 0.5 must come out as the table's own entry.
    func testCubeAppliesTheTable() {
        let lin = CGColorSpace(name: CGColorSpace.linearSRGB)!
        let ctx = CIContext(options: [.workingColorSpace: lin])
        let t = FilmLab.tables("bowery400")!
        let r = CGRect(x: 0, y: 0, width: 8, height: 8)
        let flat = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1, colorSpace: lin)!).cropped(to: r)
        let out = FilmLab.cube(flat, t.film, t.size, r)
        var px = [Float](repeating: 0, count: 4)
        ctx.render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 4, y: 4, width: 1, height: 1), format: .RGBAf, colorSpace: lin)
        let i = (16 * 33 * 33 + 16 * 33 + 16) * 4
        let want = t.film.withUnsafeBytes { Array($0.bindMemory(to: Float.self)[i..<(i + 3)]) }
        XCTAssertEqual(px[1], want[1], accuracy: 0.02)
    }

    func testEveryStockHasAFaceAtEverySpeed() {
        for st in FilmStock.all {
            for push in FilmStock.pushRange {
                XCTAssertNotNil(FilmLab.bundle.url(forResource: "box_\(st.id)_\(st.ei(push))", withExtension: "jpg"), "\(st.id) EI \(st.ei(push))")
            }
        }
    }

    func testFilmLoadsOnlyStocksAndDigiNone() {
        XCTAssertEqual(Set(FilmCatalog.sims(for: .film).map(\.id)), Set(FilmStock.all.map(\.id)))
        XCTAssertTrue(FilmCatalog.sims(for: .digi).allSatisfy { $0.stock == nil })
        XCTAssertTrue(FilmCatalog.sims(for: .digi).contains { $0.id == Sim.neutral.id })
        XCTAssertEqual(Recipe.describe(Stack(simID: "bowery400"), megapixels: 12, film: true), "XA FILM · BOWERY 400")
    }

    func testFilmDevelopKeepsFullSize() {
        let big = CIImage(color: CIColor(red: 0.2, green: 0.2, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 4032, height: 3024))
        var d = DevelopSettings(); d.stack = Stack(simID: "bowery400"); d.film = true
        d.filmRecipe.scan = .full; d.filmRecipe.format = .half
        let (out, alpha) = Darkroom.develop(big, d, date: Date(), preview: false)
        XCTAssertEqual(out.extent.size, big.extent.size)
        XCTAssertFalse(alpha)
        // 35mm at the lab: cut to 2:3 and scanned at a Frontier's 3088 on the long side.
        d.filmRecipe = FilmRecipe()
        let lab = Darkroom.develop(big, d, date: Date(), preview: false).0.extent.size
        XCTAssertEqual(lab.width, 3088, accuracy: 2)
        XCTAssertEqual(lab.height, 3088 * 2 / 3, accuracy: 3)
        // 120 is square.
        d.filmRecipe.format = .mf120
        let sq = Darkroom.develop(big, d, date: Date(), preview: false).0.extent.size
        XCTAssertEqual(sq.width, sq.height, accuracy: 2)
        d.film = false; d.stack = Stack(simID: "nocturne"); d.megapixels = 2
        XCTAssertLessThan(Darkroom.develop(big, d, date: Date(), preview: false).0.extent.width, 2000)
    }

    func testStocksAreFilmBoxes() {
        let ids = Sim.presets.compactMap { $0.stock }
        XCTAssertEqual(Set(ids), Set(FilmStock.all.map { $0.id }))
    }

    func testCameraAndLabKeepTheFrameAndStayFinite() {
        let src = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18)).cropped(to: CGRect(x: 0, y: 0, width: 600, height: 400))
        var r = FilmRecipe(); r.lens = 1; r.flash = 1; r.leak = 1; r.mist = 1; r.warmth = 1; r.tint = -1; r.preflash = 1
        for seed in 0..<4 {
            let out = FilmLab.develop(src, stock: FilmStock.all[0], push: 0, preview: false, seed: seed, shot: FilmShot(recipe: r, flashFired: true, seed: seed))
            XCTAssertEqual(out.extent, src.extent)
            var px = [Float](repeating: 0, count: 4)
            CIContext().render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 300, y: 200, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
            XCTAssertTrue(px.allSatisfy { $0.isFinite })
        }
        // Warmer printing: more red than blue in a grey.
        var warm = FilmRecipe(); warm.lens = 0; warm.flash = 0; warm.leak = 0; warm.warmth = 1
        let w = FilmLab.develop(src, stock: FilmStock.all[0], push: 0, preview: false, seed: 1, shot: FilmShot(recipe: warm))
        var px = [Float](repeating: 0, count: 4)
        CIContext().render(w, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 300, y: 200, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        XCTAssertGreaterThan(px[0], px[2])
    }
}
